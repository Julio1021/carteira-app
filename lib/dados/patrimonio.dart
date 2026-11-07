// Regras da aba Patrimônio, iguais às do site.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../util/fmt.dart';
import 'modelos.dart';
import 'repo.dart';

const classesAtivo = ['Renda Fixa', 'Tesouro Direto', 'Ações', 'Fundos Imobiliários', 'Fundos de Investimento', 'Previdência', 'Criptomoedas', 'Exterior', 'Poupança', 'Outros'];

/// Cores de série (as mesmas do tema do site) para ativos com cor numérica.
const coresSerie = [Color(0xFFB9BFF6), Color(0xFF4FD98C), Color(0xFFFF8A7A), Color(0xFF6EC1FF), Color(0xFFF5C26B), Color(0xFFF28DC0), Color(0xFF5ED6C8), Color(0xFF9AA0BC)];

class Ativo {
  final Doc d;
  Ativo(this.d);
  String get id => str(d['id']);
  String get nome => str(d['nome'], 'Ativo');
  String get classe => str(d['classe'], 'Outros');
  String get inst => str(d['inst']);
  String? get pai => d['pai'] is String ? d['pai'] as String : null;
  bool get oculto => d['oculto'] == true;
  num get ordem => d['ordem'] is num ? d['ordem'] as num : 0;
  Color cor(int i) {
    final c = d['cor'];
    if (c is String && c.startsWith('#') && c.length >= 7) {
      return Color(int.tryParse('FF${c.substring(1, 7)}', radix: 16) ?? 0xFFB9BFF6);
    }
    final n = c is num ? c.toInt() : i;
    return coresSerie[((n % 8) + 8) % 8];
  }
}

class Lancamento {
  final Doc d;
  Lancamento(this.d);
  String get id => str(d['id']);
  String get ativo => str(d['ativo']);
  String get data => str(d['data'], '1970-01-01');
  double get saldo => numD(d['saldo']);
  double get aporte => numD(d['aporte']);
}

/// Um dia com lançamentos: total da carteira, quanto entrou/saiu e o rendimento.
class LinhaDia {
  final String data;
  final double total, fluxo, investido, r, ganho, indice;
  final Map<String, double> porAtivo, investidoPorAtivo;
  LinhaDia(this.data, this.total, this.fluxo, this.investido, this.r, this.ganho, this.indice, this.porAtivo, this.investidoPorAtivo);
}

class PosAtivo {
  final Ativo a;
  final int indice;
  final double valor, investido;
  final Lancamento? ultima;
  final int n;
  final List<PosAtivo>? filhos;
  PosAtivo(this.a, this.indice, this.valor, this.investido, this.ultima, this.n, [this.filhos]);
  double get lucro => valor - investido;
  double get rent => investido > 0 ? (valor - investido) / investido : double.nan;
  Color get cor => a.cor(indice);
}

class MesPat {
  final String ym;
  double ini, aportes = 0, ganho = 0, f = 1, fim = 0;
  MesPat(this.ym, this.ini);
  double get rent => f - 1;
}

class Carteira {
  final List<Ativo> ativos; // os que recebem lançamentos
  final List<Ativo> topo; // como aparecem na lista (grupos no lugar dos filhos)
  final Set<String> pais;
  final Map<String, List<Lancamento>> porAtivo;
  final List<LinhaDia> dias;
  final List<PosAtivo> posicoes; // nível de cima
  final List<MesPat> meses;
  Carteira(this.ativos, this.topo, this.pais, this.porAtivo, this.dias, this.posicoes, this.meses);

  LinhaDia? get ultimo => dias.isEmpty ? null : dias.last;
  double get total => ultimo?.total ?? 0;
  double get investido => ultimo?.investido ?? 0;
  double get rendeu => total - investido;
  bool get vazia => dias.isEmpty;

  /// Variação do último lançamento (rendimento, sem contar aportes).
  double get ganhoUltimo => ultimo?.ganho ?? 0;
  double get rUltimo => ultimo?.r ?? 0;

  double rentAno(String ano) => meses.where((m) => m.ym.startsWith(ano)).fold<double>(1, (f, m) => f * (1 + m.rent)) - 1;
  double rendimentoAno(String ano) => meses.where((m) => m.ym.startsWith(ano)).fold<double>(0, (t, m) => t + m.ganho);
  double aportesAno(String ano) => meses.where((m) => m.ym.startsWith(ano)).fold<double>(0, (t, m) => t + m.aportes);
  List<String> get anos => {for (final m in meses) m.ym.substring(0, 4)}.toList()..sort();
}

Carteira calcularCarteira(Repo repo) {
  final todos = repo.doTipo('ativo').map(Ativo.new).toList();
  final vis = todos.where((a) => !a.oculto).toList();
  final visIds = {for (final a in vis) a.id};
  int ord(Ativo a, Ativo b) {
    final c = a.ordem.compareTo(b.ordem);
    return c != 0 ? c : a.nome.compareTo(b.nome);
  }

  bool ehTopo(Ativo a) => a.pai == null || !visIds.contains(a.pai);
  final topo = vis.where(ehTopo).toList()..sort(ord);
  final pais = {for (final a in vis.where((a) => !ehTopo(a))) a.pai!};
  final ativos = <Ativo>[];
  for (final t in topo) {
    if (pais.contains(t.id)) {
      ativos.addAll(vis.where((a) => a.pai == t.id).toList()..sort(ord));
    } else {
      ativos.add(t);
    }
  }
  final ids = {for (final a in ativos) a.id};
  final by = <String, List<Lancamento>>{};
  final datas = <String>{};
  for (final e in repo.doTipo('lanc').map(Lancamento.new)) {
    if (!ids.contains(e.ativo)) continue;
    (by[e.ativo] ??= []).add(e);
    datas.add(e.data);
  }
  for (final l in by.values) {
    l.sort((a, b) => a.data.compareTo(b.data));
  }
  final ds = datas.toList()..sort();
  final ptr = {for (final a in ativos) a.id: 0};
  final cur = {for (final a in ativos) a.id: 0.0};
  final inv = {for (final a in ativos) a.id: 0.0};
  final comecou = <String>{};
  final dias = <LinhaDia>[];
  var prevTotal = 0.0, idx = 1.0, investido = 0.0;
  for (final d in ds) {
    var fluxo = 0.0;
    final per = <String, double>{};
    for (final a in ativos) {
      final l = by[a.id];
      if (l == null) {
        per[a.id] = 0;
        continue;
      }
      while (ptr[a.id]! < l.length && l[ptr[a.id]!].data == d) {
        final e = l[ptr[a.id]!];
        ptr[a.id] = ptr[a.id]! + 1;
        final f = comecou.contains(a.id) ? e.aporte : e.saldo; // 1º lançamento = valor aplicado inicial
        comecou.add(a.id);
        fluxo += f;
        inv[a.id] = inv[a.id]! + f;
        cur[a.id] = e.saldo;
      }
      per[a.id] = cur[a.id]!;
    }
    final total = ativos.fold<double>(0, (s, a) => s + per[a.id]!);
    investido += fluxo;
    final r = prevTotal > 0 ? (total - fluxo - prevTotal) / prevTotal : 0.0;
    final ganho = prevTotal > 0 ? total - fluxo - prevTotal : 0.0;
    idx *= 1 + r;
    dias.add(LinhaDia(d, total, fluxo, investido, r, ganho, idx, Map.of(per), Map.of(inv)));
    prevTotal = total;
  }
  final ult = dias.isEmpty ? null : dias.last;
  final pos = <String, PosAtivo>{};
  for (var i = 0; i < ativos.length; i++) {
    final a = ativos[i];
    final l = by[a.id] ?? const <Lancamento>[];
    pos[a.id] = PosAtivo(a, i, ult?.porAtivo[a.id] ?? 0, ult?.investidoPorAtivo[a.id] ?? 0, l.isEmpty ? null : l.last, l.length);
  }
  final posicoes = <PosAtivo>[];
  for (var i = 0; i < topo.length; i++) {
    final t = topo[i];
    if (!pais.contains(t.id)) {
      posicoes.add(pos[t.id]!);
      continue;
    }
    final fs = ativos.where((a) => a.pai == t.id).map((a) => pos[a.id]!).toList();
    final ultimas = fs.map((f) => f.ultima).whereType<Lancamento>().toList()..sort((x, y) => y.data.compareTo(x.data));
    posicoes.add(PosAtivo(t, ativos.indexOf(fs.isEmpty ? t : fs.first.a), fs.fold<double>(0, (s, f) => s + f.valor), fs.fold<double>(0, (s, f) => s + f.investido), ultimas.isEmpty ? null : ultimas.first,
        fs.fold<int>(0, (s, f) => s + f.n), fs));
  }
  final meses = <MesPat>[];
  for (var i = 0; i < dias.length; i++) {
    final r = dias[i];
    final ym = ymDe(r.data);
    if (meses.isEmpty || meses.last.ym != ym) meses.add(MesPat(ym, i > 0 ? dias[i - 1].total : 0));
    final m = meses.last;
    m.aportes += r.fluxo;
    m.ganho += r.ganho;
    m.f *= 1 + r.r;
    m.fim = r.total;
  }
  return Carteira(ativos, topo, pais, by, dias, posicoes, meses);
}

// ---------- lançar saldos do dia ----------

/// Estado de um grupo (ativo com subcategorias) numa data.
class EstadoGrupo {
  final List<Ativo> filhos;
  final List<Lancamento?> anteriores, doDia;
  EstadoGrupo(this.filhos, this.anteriores, this.doDia);
  double get totalAnterior => anteriores.fold<double>(0, (s, l) => s + (l?.saldo ?? 0));
  String? get dataAnterior {
    final ds = anteriores.whereType<Lancamento>().map((l) => l.data).toList()..sort();
    return ds.isEmpty ? null : ds.last;
  }

  bool get todosDoDia => filhos.isNotEmpty && doDia.every((l) => l != null);
  double? get totalDoDia => todosDoDia ? doDia.fold<double>(0, (s, l) => s + l!.saldo) : null;
  double? get aporteDoDia => todosDoDia ? doDia.fold<double>(0, (s, l) => s + l!.aporte) : null;
}

EstadoGrupo estadoGrupo(Repo repo, Carteira c, String paiId, String data) {
  final fs = c.ativos.where((a) => a.pai == paiId).toList();
  final ant = <Lancamento?>[], dia = <Lancamento?>[];
  for (final f in fs) {
    final l = (c.porAtivo[f.id] ?? const <Lancamento>[]).where((e) => e.data.compareTo(data) < 0).toList();
    ant.add(l.isEmpty ? null : l.last);
    final ex = repo.porId('l_${f.id}_$data');
    dia.add(ex == null ? null : Lancamento(ex));
  }
  return EstadoGrupo(fs, ant, dia);
}

Lancamento? anteriorDe(Carteira c, String ativoId, String data) {
  final l = (c.porAtivo[ativoId] ?? const <Lancamento>[]).where((e) => e.data.compareTo(data) < 0).toList();
  return l.isEmpty ? null : l.last;
}

double _r2(double v) => (v * 100).round() / 100;

Doc docLanc(String ativo, String data, double saldo, double aporte, {bool viaTotal = false}) =>
    {'kind': 'lanc', 'id': 'l_${ativo}_$data', 'ativo': ativo, 'data': data, 'saldo': _r2(saldo), 'aporte': _r2(aporte), if (viaTotal) 'viaTotal': true};

/// Distribui o total de um grupo entre as subcategorias, na proporção do último saldo de cada uma.
List<Doc> docsGrupo(EstadoGrupo g, String data, double total, double aporte) {
  final base = g.anteriores.map((l) => l?.saldo ?? 0).toList();
  final p0 = base.fold<double>(0, (a, b) => a + b);
  final pesos = p0 > 0 ? base.map((v) => v / p0).toList() : List.generate(g.filhos.length, (k) => k == 0 ? 1.0 : 0.0);
  final saldos = pesos.map((w) => _r2(total * w)).toList(), aps = pesos.map((w) => _r2(aporte * w)).toList();
  if (pesos.isEmpty) return const [];
  final big = pesos.indexOf(pesos.reduce(math.max));
  saldos[big] = _r2(saldos[big] + (_r2(total) - saldos.fold<double>(0, (a, b) => a + b)));
  aps[big] = _r2(aps[big] + (_r2(aporte) - aps.fold<double>(0, (a, b) => a + b)));
  final out = <Doc>[];
  for (var k = 0; k < g.filhos.length; k++) {
    if (p0 > 0 && g.anteriores[k] == null && pesos[k] == 0) continue;
    out.add(docLanc(g.filhos[k].id, data, saldos[k], aps[k], viaTotal: true));
  }
  return out;
}

// ---------- projeção ----------

class PontoProj {
  final int m;
  final double saldo, investido;
  PontoProj(this.m, this.saldo, this.investido);
}

class Historico {
  final double? taxaMedia; // ao ano, pelos últimos 12 meses
  final double aporteMedio;
  Historico(this.taxaMedia, this.aporteMedio);
}

Historico historico(Carteira c) {
  final ms = c.meses.where((m) => m.rent.isFinite).toList();
  final ult = ms.length > 12 ? ms.sublist(ms.length - 12) : ms;
  double? media;
  if (ult.length >= 3) {
    final f = ult.fold<double>(1, (f, m) => f * (1 + m.rent));
    media = math.pow(f, 12 / ult.length).toDouble() - 1;
    if (media <= -.5 || media >= 1) media = null;
  }
  final semPrimeiro = ms.length > 1 ? ms.sublist(1) : <MesPat>[];
  final ap = semPrimeiro.length > 6 ? semPrimeiro.sublist(semPrimeiro.length - 6) : semPrimeiro;
  var apMed = ap.isEmpty ? 0.0 : ap.fold<double>(0, (t, m) => t + m.aportes) / ap.length;
  if (c.total > 0 && apMed > c.total * .25) apMed = 0;
  return Historico(media, apMed < 0 ? 0 : apMed);
}

List<PontoProj> projetar(double inicial, double aporteMensal, double taxaAno, int meses, {double reajusteAno = 0}) {
  final rm = math.pow(1 + taxaAno, 1 / 12).toDouble() - 1;
  var saldo = inicial, inv = inicial, ap = aporteMensal;
  final pts = [PontoProj(0, saldo, inv)];
  for (var m = 1; m <= meses; m++) {
    saldo = saldo * (1 + rm) + ap;
    inv += ap;
    pts.add(PontoProj(m, saldo, inv));
    if (m % 12 == 0 && reajusteAno != 0) ap *= 1 + reajusteAno;
  }
  return pts;
}

/// Em quantos meses chega à meta (ou null se passar de 100 anos).
int? mesesAteMeta(double inicial, double aporteMensal, double taxaAno, double meta) {
  if (inicial >= meta) return 0;
  final rm = math.pow(1 + taxaAno, 1 / 12).toDouble() - 1;
  var saldo = inicial;
  for (var m = 1; m <= 1200; m++) {
    saldo = saldo * (1 + rm) + aporteMensal;
    if (saldo >= meta) return m;
  }
  return null;
}

String tempoTexto(int m) {
  final a = m ~/ 12, r = m % 12;
  final p = [if (a > 0) '$a ano${a > 1 ? 's' : ''}', if (r > 0) '$r ${r > 1 ? 'meses' : 'mês'}'];
  return p.isEmpty ? 'agora' : p.join(' e ');
}

String pct(double v, {int casas = 2, bool sinal = false}) {
  if (!v.isFinite) return '—';
  final s = (v * 100).abs().toStringAsFixed(casas).replaceAll('.', ',');
  return '${v < 0 ? '−' : (sinal ? '+' : '')}$s%';
}
