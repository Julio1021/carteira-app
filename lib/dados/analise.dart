// Números da aba Análise do Extrato.
import '../util/fmt.dart';
import 'categorias.dart';
import 'limites.dart';
import 'repo.dart';
import 'resumo.dart';

class MesValores {
  final String ym;
  final double entrou, saiu, investiu;
  MesValores(this.ym, this.entrou, this.saiu, [this.investiu = 0]);
  double get sobra => entrou - saiu;
}

/// Entradas e saídas dos últimos [n] meses até [ym].
List<MesValores> historicoMeses(Repo repo, String ym, int n) => [
      for (var i = n - 1; i >= 0; i--)
        () {
          final m = ymAdd(ym, -i);
          final r = ResumoMes.de(repo, m);
          return MesValores(m, r.entrou, r.saiu, r.investiu);
        }(),
    ];

/// Gasto acumulado dia a dia: mês escolhido, mês anterior e média dos 3 anteriores.
class Ritmo {
  final String ym;
  final List<double> atual; // até o último dia com dado (ou hoje)
  final List<double> anterior, media; // mês inteiro
  final double limite;
  final int diaHoje; // 0 se não é o mês atual
  Ritmo(this.ym, this.atual, this.anterior, this.media, this.limite, this.diaHoje);
  int get dias => diasNoMes(ym);
  double get gastoAteHoje => atual.isEmpty ? 0 : atual.last;
  double get anteriorMesmoDia => anterior.isEmpty ? 0 : anterior[(atual.length - 1).clamp(0, anterior.length - 1).toInt()];
  double get mediaMesmoDia => media.isEmpty ? 0 : media[(atual.length - 1).clamp(0, media.length - 1).toInt()];
}

List<double> _acumulado(Repo repo, String ym, {int? ateDia}) {
  final n = diasNoMes(ym);
  final porDia = List.filled(n, 0.0);
  for (final g in repo.gastos) {
    if (!g.data.startsWith(ym)) continue;
    final d = int.parse(g.data.substring(8, 10));
    if (d >= 1 && d <= n) porDia[d - 1] += g.valor;
  }
  final out = <double>[];
  var s = 0.0;
  for (var i = 0; i < (ateDia ?? n); i++) {
    s += porDia[i];
    out.add(s);
  }
  return out;
}

Ritmo ritmoDoMes(Repo repo, String ym, {String? hoje}) {
  final h = hoje ?? hojeIso();
  final atualMes = ymDe(h) == ym;
  final dia = atualMes ? int.parse(h.substring(8, 10)) : 0;
  final n = diasNoMes(ym);
  final atual = _acumulado(repo, ym, ateDia: atualMes ? dia : n);
  List<double> ajusta(List<double> l) => [for (var i = 0; i < n; i++) l.isEmpty ? 0 : l[i < l.length ? i : l.length - 1]];
  final ant = ajusta(_acumulado(repo, ymAdd(ym, -1)));
  final prevs = [1, 2, 3].map((i) => ymAdd(ym, -i)).where((m) => repo.gastos.any((g) => g.data.startsWith(m))).toList();
  final media = List.filled(n, 0.0);
  for (final m in prevs) {
    final l = ajusta(_acumulado(repo, m));
    for (var i = 0; i < n; i++) {
      media[i] += l[i] / prevs.length;
    }
  }
  final lm = limitesDoMes(repo, ym);
  final lim = lm.geral ?? lm.cat.values.fold<double>(0, (a, b) => a + b);
  return Ritmo(ym, atual, ant, prevs.isEmpty ? <double>[] : media, lim, dia);
}

/// Gasto por categoria no mês (até o mesmo dia, se for o mês atual) contra a média dos 3 meses anteriores no mesmo trecho.
class CompCategoria {
  final String cat;
  final double atual, media;
  CompCategoria(this.cat, this.atual, this.media);
  double get dif => atual - media;
  double? get var_ => media > 0 ? atual / media - 1 : null;
}

({List<CompCategoria> itens, int ateDia, int nMeses}) comparativoCategorias(Repo repo, String ym, {String? hoje}) {
  final h = hoje ?? hojeIso();
  final ateDia = ymDe(h) == ym ? int.parse(h.substring(8, 10)) : 31;
  bool noTrecho(String data) => int.parse(data.substring(8, 10)) <= ateDia;
  final atual = <String, double>{};
  for (final g in repo.gastos) {
    if (g.data.startsWith(ym) && noTrecho(g.data)) atual[g.cat] = (atual[g.cat] ?? 0) + g.valor;
  }
  final prevs = [1, 2, 3].map((i) => ymAdd(ym, -i)).where((m) => repo.gastos.any((g) => g.data.startsWith(m))).toList();
  final media = <String, double>{};
  for (final g in repo.gastos) {
    if (prevs.contains(ymDe(g.data)) && noTrecho(g.data)) media[g.cat] = (media[g.cat] ?? 0) + g.valor / prevs.length;
  }
  final cats = {...atual.keys, ...media.keys}.where((c) => c != 'cartao');
  final itens = [for (final c in cats) CompCategoria(c, atual[c] ?? 0, media[c] ?? 0)]
    ..sort((a, b) => (b.atual > b.media ? b.atual : b.media).compareTo(a.atual > a.media ? a.atual : a.media));
  return (itens: itens, ateDia: ateDia, nMeses: prevs.length);
}

// ---------- destaques em frases ----------

/// Uma frase de destaque: [antes] + [forte] (em negrito) + [depois].
class Destaque {
  final String tipo; // maior, semana, sobe, desce, semgasto, invest
  final String antes, forte, depois;
  final int tom; // 1 bom, -1 atenção, 0 neutro
  Destaque(this.tipo, this.antes, this.forte, this.depois, {this.tom = 0});
  String get texto => '$antes$forte$depois';
}

const _diasSemana = ['segundas', 'terças', 'quartas', 'quintas', 'sextas', 'sábados', 'domingos'];

List<Destaque> destaquesDoMes(Repo repo, String ym, {String? hoje}) {
  final h = hoje ?? hojeIso();
  final atual = ymDe(h) == ym;
  final ateDia = atual ? int.parse(h.substring(8, 10)) : diasNoMes(ym);
  final gs = repo.gastos.where((g) => g.data.startsWith(ym) && int.parse(g.data.substring(8, 10)) <= ateDia).toList();
  final out = <Destaque>[];
  // maior gasto
  if (gs.isNotEmpty) {
    final m = gs.reduce((a, b) => b.valor > a.valor ? b : a);
    out.add(Destaque('maior', 'Seu maior gasto foi ', m.desc, ' (${brl(m.valor)}) em ${dataCurta(m.data)}.'));
  }
  // categoria acima e abaixo da média
  final comp = comparativoCategorias(repo, ym, hoje: h);
  if (comp.nMeses > 0) {
    final comMedia = comp.itens.where((c) => c.media > 0).toList();
    if (comMedia.isNotEmpty) {
      final sobe = comMedia.reduce((a, b) => (b.atual - b.media) > (a.atual - a.media) ? b : a);
      if (sobe.atual - sobe.media >= 50) {
        out.add(Destaque('sobe', '${catGasto(sobe.cat).nome} está ', '${brl(sobe.atual - sobe.media)} acima', ' da sua média (+${((sobe.atual / sobe.media - 1) * 100).round()}%).', tom: -1));
      }
      final desce = comMedia.reduce((a, b) => (b.atual - b.media) < (a.atual - a.media) ? b : a);
      if (desce.media - desce.atual >= 50) {
        out.add(Destaque('desce', 'Você gastou ', '${brl(desce.media - desce.atual)} a menos', ' com ${catGasto(desce.cat).nome.toLowerCase()} do que costuma.', tom: 1));
      }
    }
  }
  // dias sem gastos
  if (ateDia >= 7) {
    final dias = {for (final g in gs) g.data};
    final sem = ateDia - dias.length;
    if (sem >= 3) out.add(Destaque('semgasto', 'Você teve ', '$sem dias sem gastos', ' este mês.', tom: 1));
  }
  // dia da semana mais caro (últimos 90 dias)
  final ini = addDias(h, -90);
  final ultimos = repo.gastos.where((g) => g.data.compareTo(ini) > 0 && g.data.compareTo(h) <= 0 && g.d['pg'] == null && g.d['parc'] == null).toList();
  if (ultimos.length >= 20) {
    final soma = List<double>.filled(7, 0);
    for (final g in ultimos) {
      soma[DateTime.parse(g.data).weekday - 1] += g.valor;
    }
    final semanas = 90 / 7;
    var mi = 0;
    for (var k = 1; k < 7; k++) {
      if (soma[k] > soma[mi]) mi = k;
    }
    final media = soma.fold<double>(0, (a, b) => a + b) / 7;
    if (soma[mi] > media * 1.3) {
      out.add(Destaque('semana', 'Você costuma gastar mais às ', _diasSemana[mi], ' (cerca de ${brl(soma[mi] / semanas)} por semana).'));
    }
  }
  // investimento × média
  final r = ResumoMes.de(repo, ym);
  if (r.investiu > 0 && r.entrou > 0) {
    final ps = <double>[];
    for (var k = 1; k <= 3; k++) {
      final m = ResumoMes.de(repo, ymAdd(ym, -k));
      if (m.entrou > 0 && m.investimentos.isNotEmpty) ps.add(m.investiu / m.entrou);
    }
    final p = r.investiu / r.entrou;
    if (ps.isEmpty) {
      out.add(Destaque('invest', 'Você investiu ', '${(p * 100).round()}% do que entrou', ' este mês.', tom: 1));
    } else {
      final med = ps.fold<double>(0, (a, b) => a + b) / ps.length;
      final acima = p >= med;
      out.add(Destaque('invest', 'Você investiu ', '${(p * 100).round()}% do que entrou', ', ${acima ? 'acima' : 'abaixo'} da sua média de ${(med * 100).round()}%.', tom: acima ? 1 : -1));
    }
  }
  return out;
}

/// Total gasto em cada dia do mês (1..n).
Map<int, double> gastosPorDia(Repo repo, String ym) {
  final out = <int, double>{};
  for (final g in repo.gastos) {
    if (!g.data.startsWith(ym)) continue;
    final d = int.parse(g.data.substring(8, 10));
    out[d] = (out[d] ?? 0) + g.valor;
  }
  return out;
}
