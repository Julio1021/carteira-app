// Peças do Início: luz de fundo e linha do mês no cartão principal, e a
// faixa "Para você" (retrospectiva + descobertas automáticas sobre o mês).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dados/analise.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';
import '../widgets/painel.dart';
import 'retro.dart';

/// Sobra acumulada dia a dia (entrou − saiu) até hoje ou até o fim do mês.
List<double> sobraDiaADia(ResumoMes r, {String? hoje}) {
  final h = hoje ?? hojeIso();
  final n = diasNoMes(r.ym);
  final ate = ymDe(h) == r.ym ? int.parse(h.substring(8, 10)).clamp(1, n).toInt() : n;
  final dia = List.filled(n + 1, 0.0);
  int d(String data) => data.startsWith(r.ym) ? int.parse(data.substring(8, 10)).clamp(1, n).toInt() : (data.compareTo('${r.ym}-01') < 0 ? 1 : n);
  for (final g in r.gastos) {
    dia[d(g.data)] -= g.valor;
  }
  for (final e in r.entradas) {
    if (!e.entreContas) dia[d(e.data)] += e.valor;
  }
  final out = <double>[];
  var soma = 0.0;
  for (var k = 1; k <= ate; k++) {
    soma += dia[k];
    out.add(soma);
  }
  return out;
}

/// Saudação pelo horário.
String saudacao([DateTime? agora]) {
  final h = (agora ?? DateTime.now()).hour;
  return h < 5 ? 'Boa noite' : (h < 12 ? 'Bom dia' : (h < 18 ? 'Boa tarde' : 'Boa noite'));
}

String dataPorExtenso([DateTime? agora]) {
  final d = agora ?? DateTime.now();
  const dias = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
  return '${dias[d.weekday - 1]}, ${d.day} de ${mesesLongos[d.month - 1].toLowerCase()}';
}

