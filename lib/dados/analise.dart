// Números da aba Análise do Extrato.
import '../util/fmt.dart';
import 'repo.dart';
import 'resumo.dart';

class MesValores {
  final String ym;
  final double entrou, saiu;
  MesValores(this.ym, this.entrou, this.saiu);
  double get sobra => entrou - saiu;
}

/// Entradas e saídas dos últimos [n] meses até [ym].
List<MesValores> historicoMeses(Repo repo, String ym, int n) => [
      for (var i = n - 1; i >= 0; i--)
        () {
          final m = ymAdd(ym, -i);
          final r = ResumoMes.de(repo, m);
          return MesValores(m, r.entrou, r.saiu);
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
  final lim = repo.limites.fold<double>(0, (a, l) => a + l.limite);
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
