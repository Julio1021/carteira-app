// Sincronização com o Google Drive: o mesmo arquivo "carteira-sync.json" (pasta
// oculta do app no Drive) que o site do GitHub usa. Junta os dois lados com a
// mesma regra do site: vale a versão mais nova de cada registro, e o que foi
// apagado vence se foi apagado depois da última alteração.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../util/fmt.dart';
import 'modelos.dart';
import 'repo.dart';

const driveClienteWeb = '1041319567421-qrl6cj7mibldnddric4ej5a3gnuk303o.apps.googleusercontent.com';
const driveEscopo = 'https://www.googleapis.com/auth/drive.appdata';
const driveArquivo = 'carteira-sync.json';

/// Resultado da junção de dois lados.
class Juncao {
  final List<Doc> docs;
  final Map<String, int> tomb;
  Juncao(this.docs, this.tomb);
}

int _u(Doc d) => (d['_u'] is num) ? (d['_u'] as num).toInt() : 0;

/// Mesma regra do site (gdJuntar). [pref] decide empates: 'local' ou 'drive'.
Juncao juntar(List<Doc> l, Map<String, int> tl, List<Doc> r, Map<String, int> tr, {String pref = 'local', int? agora}) {
  final t = <String, int>{...tr};
  tl.forEach((k, v) {
    if (t[k] == null || v > t[k]!) t[k] = v;
  });
  final lm = {for (final d in l) d['id'] as String: d};
  final rm = {for (final d in r) d['id'] as String: d};
  final out = <String, Doc>{};
  for (final id in {...lm.keys, ...rm.keys}) {
    final a = lm[id], b = rm[id];
    Doc d;
    if (a != null && b != null) {
      d = _u(b) > _u(a) ? b : (_u(a) > _u(b) ? a : (pref == 'drive' ? b : a));
    } else {
      d = (a ?? b)!;
    }
    if (t[id] != null && t[id]! >= _u(d)) continue;
    out[id] = d;
  }
  final lim = (agora ?? DateTime.now().millisecondsSinceEpoch) - 120 * 86400000;
  t.removeWhere((_, v) => v < lim);
  return Juncao(out.values.toList(), t);
}

enum EstadoDrive { desligado, pronto, sincronizando, pendente, entrar, erro }

/// Escolha pedida na primeira conexão, quando os dois lados já têm dados.
class EscolhaPrimeira {
  final int noDrive, noCelular;
  final String quando;
  EscolhaPrimeira(this.noDrive, this.noCelular, this.quando);
}

class SyncDrive extends ChangeNotifier {
  SyncDrive(this.repo);
  final Repo repo;

  EstadoDrive estado = EstadoDrive.desligado;
  String erro = '';
  String? email;
  int ultima = 0;
  bool ligado = false;
  EscolhaPrimeira? escolha;

  String? _token;
  bool _rodando = false;
  bool _aplicando = false;
  Timer? _espera;
  bool _iniciado = false;

  static const _kOn = 'drive.on', _kUlt = 'drive.ultima', _kEmail = 'drive.email';

  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    try {
      final sp = await SharedPreferences.getInstance();
      ligado = sp.getBool(_kOn) ?? false;
      ultima = sp.getInt(_kUlt) ?? 0;
      email = sp.getString(_kEmail);
    } catch (_) {}
    try {
      // no navegador o cliente é o próprio; no Android ele vai como "servidor"
      await GoogleSignIn.instance.initialize(clientId: kIsWeb ? driveClienteWeb : null, serverClientId: kIsWeb ? null : driveClienteWeb);
    } catch (e) {
      debugPrint('google_sign_in: $e');
    }
    estado = ligado ? EstadoDrive.pronto : EstadoDrive.desligado;
    notifyListeners();
    repo.addListener(_mudou);
    if (ligado) unawaited(sincronizar());
  }

  @override
  void dispose() {
    repo.removeListener(_mudou);
    _espera?.cancel();
    super.dispose();
  }

  void _mudou() {
    if (!ligado || _aplicando) return;
    _espera?.cancel();
    estado = EstadoDrive.pendente;
    notifyListeners();
    _espera = Timer(const Duration(seconds: 4), () => sincronizar());
  }

  Future<void> _guardar() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_kOn, ligado);
      await sp.setInt(_kUlt, ultima);
      if (email != null) await sp.setString(_kEmail, email!);
    } catch (_) {}
  }

  /// Pega um acesso ao Drive. Sem [interativo], só tenta em silêncio.
  Future<String?> _acesso({bool interativo = false}) async {
    if (kIsWeb) return _acessoWeb(interativo: interativo);
    final gs = GoogleSignIn.instance;
    GoogleSignInClientAuthorization? a;
    try {
      a = await gs.authorizationClient.authorizationForScopes(const [driveEscopo]);
    } catch (_) {}
    if (a == null && interativo) {
      GoogleSignInAccount? conta;
      try {
        if (gs.supportsAuthenticate()) conta = await gs.authenticate(scopeHint: const [driveEscopo]);
      } catch (_) {}
      if (conta != null) email = conta.email;
      a = await (conta?.authorizationClient ?? gs.authorizationClient).authorizeScopes(const [driveEscopo]);
    }
    _token = a?.accessToken;
    return _token;
  }

  // No navegador o Google entrega um acesso que vale 1 hora e não renova sozinho.
  // Ele fica guardado neste navegador até vencer; depois, um toque em
  // "Sincronizar" pede outro (a janelinha do Google abre e fecha sozinha).
  static const _kTok = 'drive.tok', _kTokAte = 'drive.tokAte';

  Future<String?> _acessoWeb({bool interativo = false}) async {
    final agora = DateTime.now().millisecondsSinceEpoch;
    try {
      final sp = await SharedPreferences.getInstance();
      final t = sp.getString(_kTok), ate = sp.getInt(_kTokAte) ?? 0;
      if (t != null && ate - agora > 60000) return _token = t;
    } catch (_) {}
    final gs = GoogleSignIn.instance;
    GoogleSignInClientAuthorization? a;
    try {
      a = await gs.authorizationClient.authorizationForScopes(const [driveEscopo]);
    } catch (_) {}
    if (a == null && interativo) a = await gs.authorizationClient.authorizeScopes(const [driveEscopo]);
    _token = a?.accessToken;
    if (_token != null) {
      try {
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_kTok, _token!);
        await sp.setInt(_kTokAte, agora + 55 * 60000);
      } catch (_) {}
      if (email == null) unawaited(_buscarEmail());
    }
    return _token;
  }

  Future<void> _buscarEmail() async {
    try {
      final r = await _api('GET', 'https://www.googleapis.com/drive/v3/about?fields=user(emailAddress)');
      email = (jsonDecode(r.body)['user']?['emailAddress']) as String?;
      await _guardar();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _esquecerTokenWeb() async {
    if (!kIsWeb) return;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_kTok);
      await sp.remove(_kTokAte);
    } catch (_) {}
  }

  Future<http.Response> _api(String metodo, String url, {Map<String, String>? cab, Object? corpo}) async {
    final t = _token;
    if (t == null) throw const _SemAcesso();
    final h = {'Authorization': 'Bearer $t', ...?cab};
    final uri = Uri.parse(url);
    final r = switch (metodo) {
      'GET' => await http.get(uri, headers: h),
      'PATCH' => await http.patch(uri, headers: h, body: corpo),
      _ => await http.post(uri, headers: h, body: corpo),
    };
    if (r.statusCode == 401) {
      try {
        await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: t);
      } catch (_) {}
      _token = null;
      await _esquecerTokenWeb();
      throw const _SemAcesso();
    }
    if (r.statusCode >= 400) throw _ErroHttp(r.statusCode);
    return r;
  }

  Future<(String?, Map<String, dynamic>?)> _baixar() async {
    final q = Uri.encodeQueryComponent("name='$driveArquivo'");
    final r = await _api('GET', 'https://www.googleapis.com/drive/v3/files?spaces=appDataFolder&q=$q&fields=files(id,modifiedTime)');
    final fs = (jsonDecode(r.body)['files'] as List?) ?? const [];
    if (fs.isEmpty) return (null, null);
    final id = fs.first['id'] as String;
    final r2 = await _api('GET', 'https://www.googleapis.com/drive/v3/files/$id?alt=media');
    Map<String, dynamic>? pk;
    try {
      pk = jsonDecode(utf8.decode(r2.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}
    return (id, pk);
  }

  Future<void> _subir(String? id, Map<String, dynamic> pk) async {
    final corpo = jsonEncode(pk);
    if (id != null) {
      await _api('PATCH', 'https://www.googleapis.com/upload/drive/v3/files/$id?uploadType=media', cab: {'Content-Type': 'application/json'}, corpo: utf8.encode(corpo));
      return;
    }
    final b = 'gd${DateTime.now().microsecondsSinceEpoch}';
    final meta = jsonEncode({'name': driveArquivo, 'parents': ['appDataFolder']});
    final multi = '--$b\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$meta\r\n--$b\r\nContent-Type: application/json\r\n\r\n$corpo\r\n--$b--';
    await _api('POST', 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id',
        cab: {'Content-Type': 'multipart/related; boundary=$b'}, corpo: utf8.encode(multi));
  }

  /// Liga a sincronização (pede login do Google).
  Future<String?> conectar() async {
    try {
      final t = await _acesso(interativo: true);
      if (t == null) return 'Você não autorizou o acesso ao Drive.';
    } on GoogleSignInException catch (e) {
      return e.code == GoogleSignInExceptionCode.canceled ? 'Login cancelado.' : 'O Google recusou o login (${e.code.name}). Confira se o app está cadastrado no Google Cloud.';
    } catch (e) {
      return 'Não deu para entrar com o Google: $e';
    }
    return sincronizar(primeira: true);
  }

  Future<void> desconectar() async {
    ligado = false;
    estado = EstadoDrive.desligado;
    escolha = null;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    _token = null;
    await _esquecerTokenWeb();
    await _guardar();
    notifyListeners();
  }

  /// Sincroniza agora. Retorna uma mensagem de erro (ou null se deu certo).
  /// [modo]: null = juntar; 'drive' = usar o do Drive; 'aparelho' = usar o deste celular.
  Future<String?> sincronizar({bool primeira = false, String? modo, bool interativo = false}) async {
    if (_rodando) return null;
    if (!ligado && !primeira) return null;
    _rodando = true;
    _espera?.cancel();
    estado = EstadoDrive.sincronizando;
    erro = '';
    notifyListeners();
    String? msg;
    try {
      if (_token == null) await _acesso(interativo: interativo);
      if (_token == null) throw const _SemAcesso();
      final (id, pk) = await _baixar();
      final r = <Doc>[
        for (final d in (pk?['docs'] as List? ?? const []))
          if (d is Map && d['id'] is String) Map<String, dynamic>.from(d)
      ];
      final tr = <String, int>{};
      (pk?['tomb'] as Map?)?.forEach((k, v) {
        if (v is num) tr[k as String] = v.toInt();
      });
      final l = repo.todos.where((d) => d['kind'] != 'pref').toList();
      final tl = Map<String, int>.from(repo.tomb);
      if (primeira && modo == null && r.isNotEmpty && l.isNotEmpty) {
        escolha = EscolhaPrimeira(r.length, l.length, str(pk?['atualizado']));
        estado = EstadoDrive.pronto;
        _rodando = false;
        notifyListeners();
        return null;
      }
      final Juncao m = switch (modo) {
        'drive' => Juncao(r, tr),
        'aparelho' => Juncao(l, {...tr, ...tl}),
        _ => juntar(l, tl, r, tr),
      };
      // aplica no celular, se mudou
      final antes = jsonEncode(l), depois = jsonEncode(m.docs);
      if (antes != depois || jsonEncode(tl) != jsonEncode(m.tomb)) {
        _aplicando = true;
        try {
          await repo.aplicarSync(m.docs, m.tomb);
        } finally {
          _aplicando = false;
        }
      }
      // sobe para o Drive, se mudou (as preferências do site viajam intactas)
      final novo = {
        'app': 'diario-da-carteira',
        'versao': 1,
        'atualizado': DateTime.now().toUtc().toIso8601String(),
        'docs': m.docs,
        'tomb': m.tomb,
        if (pk?['prefs'] != null) 'prefs': pk!['prefs'],
      };
      final mudouDrive = pk == null || jsonEncode(pk['docs']) != depois || jsonEncode(pk['tomb'] ?? {}) != jsonEncode(m.tomb);
      if (mudouDrive) await _subir(id, novo);
      ligado = true;
      escolha = null;
      ultima = DateTime.now().millisecondsSinceEpoch;
      estado = EstadoDrive.pronto;
      await _guardar();
    } on _SemAcesso {
      estado = EstadoDrive.entrar;
      msg = kIsWeb ? 'Toque em "Sincronizar" para continuar (o acesso do Google no navegador vale 1 hora).' : 'Toque em "Sincronizar agora" para entrar de novo com o Google.';
    } on _ErroHttp catch (e) {
      estado = EstadoDrive.erro;
      msg = e.status == 403 ? 'O Google recusou o acesso. Confira se o seu e-mail está nos usuários de teste do projeto.' : 'O Drive respondeu com erro ${e.status}. Tento de novo depois.';
    } catch (e) {
      estado = EstadoDrive.erro;
      msg = 'Sem conexão com o Drive. Tento de novo depois.';
    }
    erro = msg ?? '';
    _rodando = false;
    notifyListeners();
    return msg;
  }

  /// "agora", "há 5 min"…
  String get quando {
    if (ultima == 0) return 'nunca';
    final m = (DateTime.now().millisecondsSinceEpoch - ultima) ~/ 60000;
    if (m < 1) return 'agora';
    if (m < 60) return 'há $m min';
    if (m < 1440) return 'há ${m ~/ 60} h';
    return 'há ${m ~/ 1440} dia(s)';
  }
}

class _SemAcesso implements Exception {
  const _SemAcesso();
}

class _ErroHttp implements Exception {
  final int status;
  const _ErroHttp(this.status);
}

/// Sincronização do app (null no modo de demonstração e nos testes).
SyncDrive? syncDrive;
