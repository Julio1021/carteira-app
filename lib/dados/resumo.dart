import '../util/fmt.dart';
import 'modelos.dart';
import 'repo.dart';

/// Um lançamento na lista (gasto ou entrada).
class Lanc {
  final Gasto? g;
  final Entrada? e;
  Lanc.gasto(Gasto this.g) : e = null;
  Lanc.entrada(Entrada this.e) : g = null;
  bool get ehEntrada => e != null;
  String get id => g?.id ?? e!.id;
  String get desc => g?.desc ?? e!.desc;
  double get valor => g?.valor ?? e!.valor;
  String get data => g?.data ?? e!.data;
  int get criado => g?.criado ?? e!.criado;
}

int ordemLanc(Lanc a, Lanc b) {
  final c = b.data.compareTo(a.data);
  return c != 0 ? c : b.criado.compareTo(a.criado);
}

/// Data em que o salário "conta" (com a opção "salário conta no mês seguinte").
String dataPagamento(Renda r, String ym) =>
    r.regra == 'util' ? ultimoDiaUtil(ym) : '$ym-${doisDig(r.dia.clamp(1, diasNoMes(ym)).toInt())}';

String mesDaEntrada(Entrada e, Renda? salario) {
  if (salario == null || !salario.mesSeguinte) return e.data;
  if (!(e.rd == 'rd_salario' || e.cat == 'salario')) return e.data;
  final ym = ymDe(e.data);
  return e.data.compareTo(addDias(dataPagamento(salario, ym), -6)) >= 0 ? '${ymAdd(ym, 1)}-01' : e.data;
}

/// Tudo o que as telas precisam saber sobre um mês.
class ResumoMes {
  final String ym;
  final List<Gasto> gastos; // do mês, mais novos primeiro
  final List<Entrada> entradas;
  final double saiu, entrou, entreContas;
  final Map<String, double> porCategoria;
  final Map<String, double> limites; // categoria -> limite mensal
  final double limiteTotal, gastoComLimite;
  final double? emConta;
  final bool temContas;

  ResumoMes._({
    required this.ym,
    required this.gastos,
    required this.entradas,
    required this.saiu,
    required this.entrou,
    required this.entreContas,
    required this.porCategoria,
    required this.limites,
    required this.limiteTotal,
    required this.gastoComLimite,
    required this.emConta,
    required this.temContas,
  });

  double get sobra => entrou - saiu;
  double? get usoLimite => limiteTotal > 0 ? gastoComLimite / limiteTotal : null;

  List<Lanc> get lancamentos {
    final l = <Lanc>[...gastos.map(Lanc.gasto), ...entradas.map(Lanc.entrada)];
    l.sort(ordemLanc);
    return l;
  }

  factory ResumoMes.de(Repo repo, String ym) {
    final de = '$ym-01', ate = '$ym-${doisDig(diasNoMes(ym))}';
    final gs = repo.gastos.where((g) => g.data.compareTo(de) >= 0 && g.data.compareTo(ate) <= 0).toList()
      ..sort((a, b) {
        final c = b.data.compareTo(a.data);
        return c != 0 ? c : b.criado.compareTo(a.criado);
      });
    Renda? sal;
    for (final r in repo.rendas) {
      if (r.id == 'rd_salario') sal = r;
    }
    final es = repo.entradas.where((e) {
      final d = mesDaEntrada(e, sal);
      return d.compareTo(de) >= 0 && d.compareTo(ate) <= 0;
    }).toList()
      ..sort((a, b) {
        final c = b.data.compareTo(a.data);
        return c != 0 ? c : b.criado.compareTo(a.criado);
      });
    final porCat = <String, double>{};
    var saiu = 0.0;
    for (final g in gs) {
      saiu += g.valor;
      porCat[g.cat] = (porCat[g.cat] ?? 0) + g.valor;
    }
    var entrou = 0.0, proprias = 0.0;
    for (final e in es) {
      if (e.entreContas) {
        proprias += e.valor;
      } else {
        entrou += e.valor;
      }
    }
    final lim = <String, double>{for (final l in repo.limites) l.cat: l.limite};
    final limTotal = lim.values.fold<double>(0, (a, b) => a + b);
    final comLim = lim.keys.fold<double>(0, (a, c) => a + (porCat[c] ?? 0));
    final contas = repo.contas;
    return ResumoMes._(
      ym: ym,
      gastos: gs,
      entradas: es,
      saiu: saiu,
      entrou: entrou,
      entreContas: proprias,
      porCategoria: porCat,
      limites: lim,
      limiteTotal: limTotal,
      gastoComLimite: comLim,
      emConta: contas.isEmpty ? null : saldoEmConta(repo),
      temContas: contas.isNotEmpty,
    );
  }
}

/// Saldo das contas: o último saldo informado, menos o que saiu e mais o que
/// entrou depois dele (mesma regra do site).
double saldoEmConta(Repo repo) {
  final contas = repo.contas;
  if (contas.isEmpty) return 0;
  final padrao = (contas.toList()..sort((a, b) => b.saldo.compareTo(a.saldo))).first.id;
  final ids = {for (final c in contas) c.id};
  String contaDe(String? c) => (c != null && ids.contains(c)) ? c : padrao;
  bool depois(String data, int criado, ContaBancaria c) {
    final x = data.compareTo(c.data);
    if (x != 0) return x > 0;
    return c.ts > 0 && criado > c.ts;
  }

  var total = 0.0;
  for (final c in contas) {
    var v = c.saldo;
    for (final g in repo.gastos) {
      if (g.doExtrato || g.pag == 'Crédito' || contaDe(g.conta) != c.id || !depois(g.data, g.criado, c)) continue;
      v -= g.valor;
    }
    for (final e in repo.entradas) {
      if (e.doExtrato || e.entreContas || contaDe(e.conta) != c.id || !depois(e.data, e.criado, c)) continue;
      v += e.valor;
    }
    total += (v * 100).round() / 100;
  }
  return total;
}
