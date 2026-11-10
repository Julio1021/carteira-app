// Análise da evolução dos investimentos: comparação com CDI/poupança/IPCA,
// desempenho por ativo, renda passiva, diversificação e destaques.
import 'dart:math' as math;

import '../util/fmt.dart';
import 'indices.dart';
import 'modelos.dart';
import 'patrimonio.dart';
import 'planejar.dart' show contasPagar;
import 'repo.dart';

/// Período da análise: '12m', 'ano' ou 'tudo'.
List<String> mesesDoPeriodo(Carteira c, String periodo, {String? hoje}) {
  final todos = [for (final m in c.meses) m.ym];
  if (todos.isEmpty) return const [];
  final h = ymDe(hoje ?? hojeIso());
  return switch (periodo) {
    '12m' => todos.where((ym) => ym.compareTo(ymAdd(h, -11)) >= 0).toList(),
    'ano' => todos.where((ym) => ym.startsWith(h.substring(0, 4))).toList(),
    _ => todos,
  };
}

/// Comparação da carteira com os índices num período.
class Comparacao {
  final List<String> meses; // meses usados (com índice disponível)
  final double carteira; // retorno no período (0,05 = 5%)
  final double? cdi, poup, ipca;
  final List<double> curvaCart, curvaCdi, curvaPoup, curvaIpca; // base 100
  final double ganhoReal; // R$ acima da inflação no período
  Comparacao(this.meses, this.carteira, this.cdi, this.poup, this.ipca, this.curvaCart, this.curvaCdi, this.curvaPoup, this.curvaIpca, this.ganhoReal);

  /// % do CDI (1,02 = 102% do CDI).
  double? get pctCdi => (cdi == null || cdi! <= 0) ? null : carteira / cdi!;
  double? get real => ipca == null ? null : (1 + carteira) / (1 + ipca!) - 1;
}

Comparacao? compararComIndices(Carteira c, Indices idx, List<String> periodo) {
  final porYm = {for (final m in c.meses) m.ym: m};
  // usa só os meses que já têm CDI publicado (o mês corrente costuma faltar)
  final meses = periodo.where((ym) => idx.cdi.containsKey(ym) && porYm.containsKey(ym)).toList();
  if (meses.isEmpty) return null;
  var fc = 1.0, fcdi = 1.0, fp = 1.0, fi = 1.0;
  var temP = true, temI = true;
  final cc = <double>[100], cd = <double>[100], cp = <double>[100], ci = <double>[100];
  var real = 0.0;
  for (final ym in meses) {
    final m = porYm[ym]!;
    fc *= 1 + m.rent;
    fcdi *= 1 + idx.cdi[ym]! / 100;
    final p = idx.poup[ym], i = idx.ipca[ym];
    if (p == null) {
      temP = false;
    } else {
      fp *= 1 + p / 100;
    }
    if (i == null) {
      temI = false;
    } else {
      fi *= 1 + i / 100;
      real += m.ganho - (m.ini + m.aportes / 2) * i / 100;
    }
    cc.add(100 * fc);
    cd.add(100 * fcdi);
    cp.add(100 * fp);
    ci.add(100 * fi);
  }
  return Comparacao(meses, fc - 1, fcdi - 1, temP ? fp - 1 : null, temI ? fi - 1 : null, cc, cd, temP ? cp : const [], temI ? ci : const [], real);
}

/// Desempenho de um ativo num período.
class DesempenhoAtivo {
  final Ativo a;
  final int indice;
  final double saldo, ganho, rent;
  final double? pctCdi;
  final List<double> curva; // saldo ao fim de cada lançamento no período
  DesempenhoAtivo(this.a, this.indice, this.saldo, this.ganho, this.rent, this.pctCdi, this.curva);
}

List<DesempenhoAtivo> desempenhoPorAtivo(Carteira c, Indices idx, List<String> periodo) {
  if (periodo.isEmpty) return const [];
  final ini = periodo.first, fim = periodo.last;
  final out = <DesempenhoAtivo>[];
  for (var k = 0; k < c.ativos.length; k++) {
    final a = c.ativos[k];
    final ls = [...?c.porAtivo[a.id]]..sort((x, y) => x.data.compareTo(y.data));
    if (ls.isEmpty) continue;
    var f = 1.0, g = 0.0;
    final curva = <double>[];
    final mesesUsados = <String>{};
    for (var i = 0; i < ls.length; i++) {
      final ym = ymDe(ls[i].data);
      if (ym.compareTo(fim) > 0) break;
      if (ym.compareTo(ini) < 0) continue;
      curva.add(ls[i].saldo);
      if (i == 0) continue;
      final base = ls[i - 1].saldo;
      if (base <= 0) continue;
      final ganho = ls[i].saldo - ls[i].aporte - base;
      g += ganho;
      f *= 1 + ganho / base;
      mesesUsados.add(ym);
    }
    final saldo = ls.lastWhere((l) => ymDe(l.data).compareTo(fim) <= 0, orElse: () => ls.first).saldo;
    if (curva.isEmpty && saldo <= 0) continue;
    final mc = mesesUsados.where((ym) => idx.cdi.containsKey(ym)).toList();
    final fcdi = idx.fator(idx.cdi, mc);
    final rent = f - 1;
    out.add(DesempenhoAtivo(a, k, saldo, g, rent, (fcdi != null && fcdi > 1 && mesesUsados.isNotEmpty) ? rent / (fcdi - 1) : null, curva));
  }
  out.sort((x, y) => y.rent.compareTo(x.rent));
  return out;
}

/// Renda passiva: quanto os investimentos rendem por mês.
class RendaPassiva {
  final double media; // R$/mês (últimos até 12 meses)
  final List<String> meses;
  final List<double> ganhos;
  final double? pctSalario;
  final String? pagaConta; // nome de uma conta que o rendimento já cobre
  final double? valorConta;
  RendaPassiva(this.media, this.meses, this.ganhos, this.pctSalario, this.pagaConta, this.valorConta);
}

RendaPassiva? rendaPassiva(Repo repo, Carteira c, {String? hoje}) {
  final h = ymDe(hoje ?? hojeIso());
  final ms = c.meses.where((m) => m.ym.compareTo(h) < 0).toList(); // meses fechados
  final ult = ms.length > 12 ? ms.sublist(ms.length - 12) : ms;
  if (ult.isEmpty) return null;
  final media = ult.fold<double>(0, (t, m) => t + m.ganho) / ult.length;
  final salario = repo.rendas.fold<double>(0, (t, r) => t + r.valor);
  String? conta;
  double? vc;
  if (media > 0) {
    for (final p in contasPagar(repo)) {
      if (p.valor > 0 && p.valor <= media && (vc == null || p.valor > vc)) {
        conta = p.nome;
        vc = p.valor;
      }
    }
  }
  return RendaPassiva(media, [for (final m in ult) m.ym], [for (final m in ult) m.ganho], salario > 0 ? media / salario : null, conta, vc);
}

/// Diversificação: fatias por instituição e por classe.
class Fatia {
  final String nome;
  final double valor;
  Fatia(this.nome, this.valor);
}

String instituicaoDe(Ativo a, [Ativo? pai]) {
  if (a.inst.trim().isNotEmpty) return a.inst.trim();
  if (pai != null && pai.inst.trim().isNotEmpty) return pai.inst.trim();
  final n = ' ${(pai == null ? a.nome : '${pai.nome} ${a.nome}').toLowerCase()} ';
  const mapa = {
    'inter': 'Banco Inter', 'nubank': 'Nubank', ' nu ': 'Nubank', 'mercado pago': 'Mercado Pago', ' mp ': 'Mercado Pago',
    'xp': 'XP', 'rico': 'Rico', 'btg': 'BTG', 'itaú': 'Itaú', 'itau': 'Itaú', 'bradesco': 'Bradesco', 'caixa': 'Caixa',
    'santander': 'Santander', 'c6': 'C6 Bank', 'picpay': 'PicPay', 'pagbank': 'PagBank', 'banco do brasil': 'Banco do Brasil', ' bb ': 'Banco do Brasil',
  };
  for (final e in mapa.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return 'Outras';
}

String classeDe(Ativo a) {
  if (a.classe != 'Outros' && a.classe.isNotEmpty) return a.classe;
  final n = a.nome.toLowerCase();
  if (RegExp(r'tesouro|selic|ipca\+|prefixado').hasMatch(n)) return 'Tesouro Direto';
  if (RegExp(r'cdb|lci|lca|caixinha|cofrinho|reserva|renda fixa|rdb|cdi|lc\b').hasMatch(n)) return 'Renda Fixa';
  if (n.contains('poupan')) return 'Poupança';
  if (RegExp(r'\bfii\b|imobili').hasMatch(n)) return 'Fundos Imobiliários';
  if (RegExp(r'aç(ão|oes|ões)|acoes|bolsa').hasMatch(n)) return 'Ações';
  if (RegExp(r'cripto|bitcoin|btc|eth').hasMatch(n)) return 'Criptomoedas';
  if (n.contains('previd')) return 'Previdência';
  if (n.contains('fundo')) return 'Fundos de Investimento';
  return 'Outros';
}

(List<Fatia>, List<Fatia>) diversificacao(Carteira c) {
  final inst = <String, double>{}, cls = <String, double>{};
  final porId = {for (final a in c.ativos) a.id: a};
  for (final p in c.posicoes) {
    final filhos = p.filhos;
    if (filhos != null && filhos.isNotEmpty) {
      for (final f in filhos) {
        inst[instituicaoDe(f.a, p.a)] = (inst[instituicaoDe(f.a, p.a)] ?? 0) + f.valor;
        cls[classeDe(f.a)] = (cls[classeDe(f.a)] ?? 0) + f.valor;
      }
    } else {
      final a = porId[p.a.id] ?? p.a;
      inst[instituicaoDe(a)] = (inst[instituicaoDe(a)] ?? 0) + p.valor;
      cls[classeDe(a)] = (cls[classeDe(a)] ?? 0) + p.valor;
    }
  }
  List<Fatia> ord(Map<String, double> m) => (m.entries.where((e) => e.value > 0.005).map((e) => Fatia(e.key, e.value)).toList()..sort((a, b) => b.valor.compareTo(a.valor)));
  return (ord(inst), ord(cls));
}

/// Destaques em frases.
class DestaqueInv {
  final String tipo, antes, forte, depois;
  final int tom;
  DestaqueInv(this.tipo, this.antes, this.forte, this.depois, {this.tom = 0});
}

List<DestaqueInv> destaquesInvest(Carteira c, Comparacao? cmp, {String? hoje}) {
  final out = <DestaqueInv>[];
  final h = ymDe(hoje ?? hojeIso());
  final fechados = c.meses.where((m) => m.ym.compareTo(h) < 0 && m.ini > 0).toList();
  if (cmp?.pctCdi != null) {
    final p = cmp!.pctCdi!;
    out.add(DestaqueInv('cdi', 'No período, sua carteira rendeu ', '${(p * 100).round()}% do CDI', p >= 1 ? '. Bateu o CDI!' : (p >= .85 ? ', perto do CDI.' : ', abaixo do CDI.'), tom: p >= 1 ? 1 : (p >= .85 ? 0 : -1)));
  }
  if (fechados.isNotEmpty) {
    final melhor = fechados.reduce((a, b) => b.rent > a.rent ? b : a);
    out.add(DestaqueInv('melhor', 'Seu melhor mês foi ', mesLongo(melhor.ym), ', com ${pct(melhor.rent, sinal: true)} (${brl(melhor.ganho)} de rendimento).', tom: 1));
  }
  final comAporte = c.meses.where((m) => m.aportes > 0).toList();
  if (comAporte.isNotEmpty) {
    final maior = comAporte.reduce((a, b) => b.aportes > a.aportes ? b : a);
    out.add(DestaqueInv('aporte', 'Seu maior aporte foi em ', mesLongo(maior.ym), ': ${brl(maior.aportes)}.'));
  }
  // meses seguidos investindo (até o último mês com dados)
  var seq = 0;
  for (var i = c.meses.length - 1; i >= 0; i--) {
    if (c.meses[i].aportes > 0) {
      seq++;
    } else if (c.meses[i].ym != h) {
      break;
    }
  }
  if (seq >= 3) out.add(DestaqueInv('seq', 'Você está há ', '$seq meses seguidos', ' colocando dinheiro nos investimentos.', tom: 1));
  // marcos de patrimônio
  const marcos = [1000.0, 5000.0, 10000.0, 25000.0, 50000.0, 75000.0, 100000.0, 150000.0, 200000.0, 250000.0, 500000.0, 1000000.0];
  String? quando;
  double? marco;
  for (var i = 1; i < c.dias.length; i++) {
    for (final m in marcos) {
      if (c.dias[i - 1].total < m && c.dias[i].total >= m) {
        quando = c.dias[i].data;
        marco = m;
      }
    }
  }
  if (marco != null) {
    final prox = marcos.firstWhere((m) => m > c.total, orElse: () => c.total * 2);
    out.add(DestaqueInv('marco', 'Você passou de ', brl(marco).replaceAll(',00', ''), ' em ${dataBr(quando!)}. Próximo marco: ${brl(prox).replaceAll(',00', '')} (faltam ${brl(math.max(0, prox - c.total))}).', tom: 1));
  }
  return out;
}
