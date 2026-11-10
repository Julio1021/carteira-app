// Índices de referência do Banco Central (API pública SGS): CDI, poupança e
// IPCA, mês a mês, em % ao mês. Ficam guardados no celular e se atualizam
// quando há internet (no máximo uma vez por dia).
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../util/fmt.dart';

class Indices {
  /// ym ('2026-10') -> % no mês (0,85 = 0,85%).
  final Map<String, double> cdi, ipca, poup;
  final int atualizado; // ms
  final bool exemplo;
  const Indices(this.cdi, this.ipca, this.poup, this.atualizado, {this.exemplo = false});
  static const vazio = Indices({}, {}, {}, 0);
  bool get temDados => cdi.isNotEmpty;

  Map<String, dynamic> toJson() => {'cdi': cdi, 'ipca': ipca, 'poup': poup, 'at': atualizado};
  static Indices deJson(Map j) {
    Map<String, double> m(Object? x) => {for (final e in ((x as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble()};
    return Indices(m(j['cdi']), m(j['ipca']), m(j['poup']), (j['at'] as num?)?.toInt() ?? 0);
  }

  /// Fator acumulado (1,05 = +5%) de um índice nos meses pedidos; null se faltar algum mês.
  double? fator(Map<String, double> serie, Iterable<String> meses) {
    var f = 1.0;
    for (final ym in meses) {
      final v = serie[ym];
      if (v == null) return null;
      f *= 1 + v / 100;
    }
    return f;
  }

  /// Último mês publicado de uma série.
  String? ultimo(Map<String, double> serie) => serie.isEmpty ? null : (serie.keys.toList()..sort()).last;
}

/// Índices de mentira, só para a demonstração e os prints.
Indices indicesExemplo(String ateYm, {int meses = 72}) {
  final cdi = <String, double>{}, ipca = <String, double>{}, poup = <String, double>{};
  for (var k = 0; k < meses; k++) {
    final ym = ymAdd(ateYm, -k);
    final w = math.sin(k / 5);
    cdi[ym] = double.parse((0.88 + 0.12 * w).toStringAsFixed(2));
    ipca[ym] = double.parse((0.36 + 0.18 * math.cos(k / 3)).toStringAsFixed(2));
    poup[ym] = double.parse((0.62 + 0.04 * w).toStringAsFixed(2));
  }
  return Indices(cdi, ipca, poup, DateTime.now().millisecondsSinceEpoch, exemplo: true);
}

final indicesAtuais = ValueNotifier<Indices>(Indices.vazio);
const _kIdx = 'indices.bcb.v1';
bool _buscando = false;

Future<void> carregarIndices({bool forcar = false}) async {
  try {
    final sp = await SharedPreferences.getInstance();
    if (!indicesAtuais.value.temDados) {
      final t = sp.getString(_kIdx);
      if (t != null) indicesAtuais.value = Indices.deJson(jsonDecode(t) as Map);
    }
    final idade = DateTime.now().millisecondsSinceEpoch - indicesAtuais.value.atualizado;
    if (!forcar && indicesAtuais.value.temDados && idade < 20 * 3600 * 1000) return;
    if (_buscando) return;
    _buscando = true;
    final novo = await _buscarBcb();
    if (novo != null) {
      indicesAtuais.value = novo;
      await sp.setString(_kIdx, jsonEncode(novo.toJson()));
    }
  } catch (e) {
    debugPrint('indices: $e');
  } finally {
    _buscando = false;
  }
}

String _br(DateTime d) => '${doisDig(d.day)}/${doisDig(d.month)}/${d.year}';

Future<List<Map<String, dynamic>>?> _serie(int codigo, DateTime de) async {
  final uri = Uri.parse('https://api.bcb.gov.br/dados/serie/bcdata.sgs.$codigo/dados?formato=json&dataInicial=${_br(de)}&dataFinal=${_br(DateTime.now())}');
  final r = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
  if (r.statusCode != 200) return null;
  final j = jsonDecode(r.body);
  if (j is! List) return null;
  return [for (final x in j) if (x is Map) Map<String, dynamic>.from(x)];
}

/// '01/10/2026' -> '2026-10'
String? _ym(Object? data) {
  if (data is! String || data.length < 10) return null;
  return '${data.substring(6, 10)}-${data.substring(3, 5)}';
}

double? _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v'.replaceAll(',', '.'));

Future<Indices?> _buscarBcb() async {
  final de = DateTime.now().subtract(const Duration(days: 365 * 9));
  // 4391 = CDI acumulado no mês (% a.m.); 433 = IPCA (% a.m.); 196 = poupança (rentabilidade por aniversário, diária)
  final res = await Future.wait([_serie(4391, de), _serie(433, de), _serie(196, de)]);
  if (res[0] == null || res[0]!.isEmpty) return null;
  Map<String, double> mensal(List<Map<String, dynamic>>? l) => {
        for (final x in l ?? const <Map<String, dynamic>>[])
          if (_ym(x['data']) != null && _num(x['valor']) != null) _ym(x['data'])!: _num(x['valor'])!
      };
  // poupança: usa a rentabilidade do aniversário no dia 1 de cada mês
  final poup = <String, double>{};
  for (final x in res[2] ?? const <Map<String, dynamic>>[]) {
    final d = x['data'];
    final v = _num(x['valor']);
    if (d is String && d.startsWith('01/') && v != null) poup[_ym(d)!] = v;
  }
  return Indices(mensal(res[0]), mensal(res[1]), poup, DateTime.now().millisecondsSinceEpoch);
}
