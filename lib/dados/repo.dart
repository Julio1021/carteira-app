import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/fmt.dart';
import 'modelos.dart';

/// Resultado de uma importação de backup.
class Importacao {
  final int novos, atualizados, iguais, ignorados;
  const Importacao(this.novos, this.atualizados, this.iguais, this.ignorados);
  int get total => novos + atualizados + iguais;
}

/// Guarda todos os registros no aparelho e avisa as telas quando algo muda.
class Repo extends ChangeNotifier {
  static const _kDocs = 'carteira.docs.v1';
  static const _kTomb = 'carteira.tomb.v1';

  final Map<String, Doc> _docs = {};

  /// Registros apagados: id -> quando foi apagado (ms). Usado na sincronização.
  final Map<String, int> tomb = {};
  bool carregado = false;
  SharedPreferences? _sp;

  Repo();

  /// Para testes: começa já com estes registros, sem tocar no armazenamento.
  Repo.memoria(Iterable<Doc> docs) {
    for (final d in docs) {
      if (d['id'] is String) _docs[d['id'] as String] = Map<String, dynamic>.from(d);
    }
    carregado = true;
  }

  Future<void> carregar() async {
    _sp = await SharedPreferences.getInstance();
    final t = _sp!.getString(_kDocs);
    if (t != null) {
      try {
        final l = jsonDecode(t) as List;
        for (final x in l) {
          if (x is Map && x['id'] is String) _docs[x['id'] as String] = Map<String, dynamic>.from(x);
        }
      } catch (_) {}
    }
    final tb = _sp!.getString(_kTomb);
    if (tb != null) {
      try {
        (jsonDecode(tb) as Map).forEach((k, v) {
          if (v is num) tomb[k as String] = v.toInt();
        });
      } catch (_) {}
    }
    carregado = true;
    notifyListeners();
  }

  Future<void> _salvar() async {
    final sp = _sp;
    if (sp == null) return;
    await sp.setString(_kDocs, jsonEncode(_docs.values.toList()));
    await sp.setString(_kTomb, jsonEncode(tomb));
  }

  /// Troca tudo pelo resultado de uma sincronização (sem mexer nas datas de alteração).
  Future<void> aplicarSync(List<Doc> docs, Map<String, int> novoTomb) async {
    _docs
      ..clear()
      ..addEntries(docs.where((d) => d['id'] is String).map((d) => MapEntry(d['id'] as String, Map<String, dynamic>.from(d))));
    tomb
      ..clear()
      ..addAll(novoTomb);
    await _salvar();
    notifyListeners();
  }

  // ---------- leitura ----------
  Iterable<Doc> doTipo(String kind) => _docs.values.where((d) => d['kind'] == kind);
  Doc? porId(String id) => _docs[id];
  int get totalRegistros => _docs.length;
  List<Doc> get todos => _docs.values.toList();

  List<Gasto> get gastos => doTipo('gasto').map(Gasto.new).toList();
  List<Entrada> get entradas => doTipo('entrada').map(Entrada.new).toList();
  List<Investido> get investidos => doTipo('invest').map(Investido.new).toList();
  List<ContaBancaria> get contas => doTipo('conta').map(ContaBancaria.new).toList();
  List<Limite> get limites => doTipo('orc').map(Limite.new).where((l) => l.cat.isNotEmpty && l.limite > 0).toList();
  List<Renda> get rendas => doTipo('renda').map(Renda.new).toList();

  bool get vazio => _docs.values.every((d) => d['kind'] == 'pref');

  // ---------- escrita ----------
  Future<void> salvar(Doc d) async {
    final c = Map<String, dynamic>.from(d);
    c['_u'] = DateTime.now().millisecondsSinceEpoch;
    _docs[c['id'] as String] = c;
    tomb.remove(c['id']);
    notifyListeners();
    await _salvar();
  }

  /// Salva vários registros de uma vez (um só aviso às telas).
  Future<void> salvarVarios(Iterable<Doc> docs) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final d in docs) {
      final c = Map<String, dynamic>.from(d);
      c['_u'] = t;
      _docs[c['id'] as String] = c;
      tomb.remove(c['id']);
    }
    notifyListeners();
    await _salvar();
  }

  Future<void> apagarVarios(Iterable<String> ids) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    var mudou = false;
    for (final id in ids) {
      if (_docs.remove(id) != null) {
        tomb[id] = t;
        mudou = true;
      }
    }
    if (!mudou) return;
    notifyListeners();
    await _salvar();
  }

  // ---------- preferências locais ----------
  double get metaSobra => _sp?.getDouble('carteira.meta') ?? _metaMem;
  double _metaMem = 0;
  Future<void> definirMeta(double v) async {
    _metaMem = v;
    await _sp?.setDouble('carteira.meta', v);
    notifyListeners();
  }

  final Map<String, List<String>> _listasMem = {};
  List<String> lista(String k) => _sp?.getStringList('carteira.$k') ?? _listasMem[k] ?? const [];
  Future<void> guardarLista(String k, List<String> v) async {
    _listasMem[k] = v;
    await _sp?.setStringList('carteira.$k', v);
    notifyListeners();
  }

  Future<void> apagar(String id) async {
    if (_docs.remove(id) == null) return;
    tomb[id] = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    await _salvar();
  }

  Future<void> limparTudo() async {
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in _docs.keys) {
      tomb[id] = t;
    }
    _docs.clear();
    notifyListeners();
    await _salvar();
  }

  // ---------- backup ----------
  /// Aceita o backup do site ({docs:[...]}), o arquivo do Drive ({docs, tomb})
  /// ou uma lista pura de registros. Junta com o que já existe:
  /// em cada registro, vale a versão mais nova.
  Future<Importacao> importar(String texto) async {
    final dynamic j = jsonDecode(texto);
    List lista;
    Map? tombs;
    if (j is List) {
      lista = j;
    } else if (j is Map && j['docs'] is List) {
      lista = j['docs'] as List;
      if (j['tomb'] is Map) tombs = j['tomb'] as Map;
    } else {
      throw const FormatException('Este arquivo não parece um backup da carteira.');
    }
    var novos = 0, atual = 0, iguais = 0, ign = 0;
    for (final x in lista) {
      if (x is! Map || x['id'] is! String || x['kind'] is! String) {
        ign++;
        continue;
      }
      final d = Map<String, dynamic>.from(x);
      final id = d['id'] as String;
      final a = _docs[id];
      if (a == null) {
        _docs[id] = d;
        novos++;
      } else if (jsonEncode(a) == jsonEncode(d)) {
        iguais++;
      } else if (numD(d['_u']) >= numD(a['_u'])) {
        _docs[id] = d;
        atual++;
      } else {
        iguais++;
      }
    }
    tombs?.forEach((k, v) {
      if (k is String && v is num) {
        final t = v.toInt();
        if ((tomb[k] ?? 0) < t) tomb[k] = t;
        final d = _docs[k];
        if (d != null && numD(d['_u']) <= t) _docs.remove(k);
      }
    });
    notifyListeners();
    await _salvar();
    return Importacao(novos, atual, iguais, ign);
  }

  /// Mesmo formato do botão "Exportar backup" do site.
  String exportar() {
    final docs = _docs.values.toList();
    return jsonEncode({
      'app': 'diario-da-carteira',
      'versao': 1,
      'exportado': DateTime.now().toUtc().toIso8601String(),
      'total': docs.length,
      'docs': docs,
    });
  }

  String nomeBackup() => 'backup-carteira-${hojeIso()}.json';

  @visibleForTesting
  Map<String, Doc> get docsInternos => _docs;
}
