import '../util/fmt.dart';
import 'modelos.dart';
import 'repo.dart';

/// Um lançamento na lista (gasto, entrada ou investido).
class Lanc {
  final Gasto? g;
  final Entrada? e;
  final Investido? i;
  Lanc.gasto(Gasto this.g)
      : e = null,
        i = null;
  Lanc.entrada(Entrada this.e)
      : g = null,
        i = null;
  Lanc.invest(Investido this.i)
      : g = null,
        e = null;
  bool get ehEntrada => e != null;
  bool get ehGasto => g != null;
  bool get ehInvest => i != null;
  Doc get doc => g?.d ?? e?.d ?? i!.d;
  String get id => g?.id ?? e?.id ?? i!.id;
  String get desc => g?.desc ?? e?.desc ?? i!.desc;
  double get valor => g?.valor ?? e?.valor ?? i!.valor;
  String get data => g?.data ?? e?.data ?? i!.data;
  int get criado => g?.criado ?? e?.criado ?? i!.criado;
  /// Efeito no "Entrou − Saiu" (investido e entre contas não contam).
  double get efeito => g != null ? -g!.valor : (e != null ? (e!.entreContas ? 0 : e!.valor) : 0);
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
  final List<Investido> investimentos;
  /// Aplicado − resgatado no mês.
  final double investiu, aplicou, resgatou;
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
    required this.investimentos,
    required this.investiu,
    required this.aplicou,
    required this.resgatou,
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
  /// Parte da sobra que não foi investida.
  double get sobraEmConta => sobra - investiu;
  /// Quanto do que entrou foi investido (0..1), ou null sem entradas.
  double? get pctInvestido => entrou > 0 ? investiu / entrou : null;
  double? get usoLimite => limiteTotal > 0 ? gastoComLimite / limiteTotal : null;

  List<Lanc> get lancamentos {
    final l = <Lanc>[...gastos.map(Lanc.gasto), ...entradas.map(Lanc.entrada), ...investimentos.map(Lanc.invest)];
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
    final inv = repo.investidos.where((i) => i.data.compareTo(de) >= 0 && i.data.compareTo(ate) <= 0).toList()
      ..sort((a, b) {
        final c = b.data.compareTo(a.data);
        return c != 0 ? c : b.criado.compareTo(a.criado);
      });
    var aplicou = 0.0, resgatou = 0.0;
    for (final i in inv) {
      if (i.resgate) {
        resgatou += i.valor;
      } else {
        aplicou += i.valor;
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
      investimentos: inv,
      investiu: aplicou - resgatou,
      aplicou: aplicou,
      resgatou: resgatou,
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
    for (final i in repo.investidos) {
      if (i.doExtrato || contaDe(i.conta) != c.id || !depois(i.data, i.criado, c)) continue;
      v -= i.liquido;
    }
    total += (v * 100).round() / 100;
  }
  return total;
}
