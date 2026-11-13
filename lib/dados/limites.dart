// Limites de gastos: geral do mês e por categoria, com a sobra do mês anterior
// (opcional), a média dos meses passados como sugestão e o ritmo do mês.

import '../util/fmt.dart';
import 'repo.dart';

class LimitesMes {
  /// Limite geral que vale no mês (já com a sobra do mês anterior), ou null.
  final double? geral;
  final double geralBase;
  final double sobraGeral;
  /// Limite de cada categoria que vale no mês (com a sobra, se ativada).
  final Map<String, double> cat;
  final Map<String, double> catBase;
  final bool acumula;
  LimitesMes(this.geral, this.geralBase, this.sobraGeral, this.cat, this.catBase, this.acumula);
  double get somaCategorias => catBase.values.fold<double>(0, (a, b) => a + b);
  /// A soma das categorias passa do limite geral?
  bool get categoriasPassamGeral => geral != null && somaCategorias > geralBase + .005;
}

Map<String, double> gastosPorCategoria(Repo repo, String ym) {
  final m = <String, double>{};
  for (final g in repo.gastos) {
    if (g.data.startsWith(ym)) m[g.cat] = (m[g.cat] ?? 0) + g.valor;
  }
  return m;
}

LimitesMes limitesDoMes(Repo repo, String ym) {
  final lg = repo.limiteGeral;
  final acumula = lg?.acumula ?? false;
  final base = <String, double>{for (final l in repo.limites) l.cat: l.limite};
  final geralBase = (lg?.valor ?? 0) > 0 ? lg!.valor : 0.0;
  var sobraG = 0.0;
  final cat = Map<String, double>.from(base);
  if (acumula) {
    // só o mês anterior (sem ir somando mês após mês) e só se ele teve gastos
    final ant = ymAdd(ym, -1);
    final g = gastosPorCategoria(repo, ant);
    if (g.isNotEmpty) {
      if (geralBase > 0) {
        final total = g.values.fold<double>(0, (a, b) => a + b);
        if (total < geralBase) sobraG = geralBase - total;
      }
      base.forEach((c, l) {
        final v = g[c] ?? 0;
        if (v < l) cat[c] = l + (l - v);
      });
    }
  }
  return LimitesMes(geralBase > 0 ? geralBase + sobraG : null, geralBase, sobraG, cat, base, acumula);
}

/// Média de gasto por mês (por categoria e total) nos até 3 meses anteriores com gastos.
({Map<String, double> cat, double total, int meses}) mediaGastos(Repo repo, String ym) {
  final todos = repo.gastos;
  final prevs = [1, 2, 3].map((i) => ymAdd(ym, -i)).where((m) => todos.any((g) => g.data.startsWith(m))).toList();
  final cat = <String, double>{};
  var total = 0.0;
  if (prevs.isEmpty) return (cat: cat, total: 0, meses: 0);
  for (final g in todos) {
    if (!prevs.contains(ymDe(g.data))) continue;
    cat[g.cat] = (cat[g.cat] ?? 0) + g.valor / prevs.length;
    total += g.valor / prevs.length;
  }
  return (cat: cat, total: total, meses: prevs.length);
}

/// Arredonda uma sugestão para um número redondo (R$ 10, 50 ou 100).
double redondo(double v) {
  final passo = v >= 2000 ? 100.0 : (v >= 300 ? 50.0 : 10.0);
  return (v / passo).ceil() * passo;
}

/// Quanto o mês deve fechar mantendo o ritmo até hoje. Só para o mês atual e a
/// partir do 5º dia (antes disso a conta exagera).
double? projecaoMes(double gastoAteHoje, String ym, {String? hoje}) {
  final h = hoje ?? hojeIso();
  if (ymDe(h) != ym) return null;
  final dia = int.parse(h.substring(8, 10)), n = diasNoMes(ym);
  if (dia < 5 || dia >= n) return null;
  return gastoAteHoje / dia * n;
}

/// Dias que faltam no mês contando hoje (0 fora do mês atual).
int diasRestantes(String ym, {String? hoje}) {
  final h = hoje ?? hojeIso();
  if (ymDe(h) != ym) return 0;
  return diasNoMes(ym) - int.parse(h.substring(8, 10)) + 1;
}

/// Um mês do histórico: quanto gastou contra o limite (o de hoje, já que o app
/// não guarda os limites de cada mês).
class MesLimite {
  final String ym;
  final double gasto, limite;
  MesLimite(this.ym, this.gasto, this.limite);
  bool get dentro => gasto <= limite;
}

List<MesLimite> historicoLimite(Repo repo, String ym, {int meses = 6}) {
  final l = limitesDoMes(repo, ym);
  final out = <MesLimite>[];
  for (var k = meses; k >= 1; k--) {
    final m = ymAdd(ym, -k);
    final g = gastosPorCategoria(repo, m);
    if (g.isEmpty) continue;
    if (l.geral != null) {
      out.add(MesLimite(m, g.values.fold<double>(0, (a, b) => a + b), l.geralBase));
    } else if (l.catBase.isNotEmpty) {
      out.add(MesLimite(m, l.catBase.keys.fold<double>(0, (a, c) => a + (g[c] ?? 0)), l.somaCategorias));
    }
  }
  return out;
}
