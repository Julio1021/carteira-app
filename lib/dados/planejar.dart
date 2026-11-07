// Regras da aba Planejar, iguais às do site: contas a pagar, recebimentos
// fixos, cartões de crédito e dinheiro emprestado.

import '../util/fmt.dart';
import 'modelos.dart';
import 'repo.dart';

int diasEntre(String a, String b) => dataDe(b).difference(dataDe(a)).inHours ~/ 24 + 1;

int ymDiff(String a, String b) {
  final y1 = int.parse(a.substring(0, 4)), m1 = int.parse(a.substring(5, 7));
  final y2 = int.parse(b.substring(0, 4)), m2 = int.parse(b.substring(5, 7));
  return (y2 - y1) * 12 + (m2 - m1);
}

String ymd(String ym, int dia) => '$ym-${doisDig(dia.clamp(1, diasNoMes(ym)).toInt())}';

const _acentos = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c', 'ñ': 'n',
};

/// Mesma normalização do site: sem acentos e em maiúsculas.
String norm(String? s) {
  final b = StringBuffer();
  for (final r in (s ?? '').toLowerCase().runes) {
    final c = String.fromCharCode(r);
    b.write(_acentos[c] ?? c);
  }
  return b.toString().toUpperCase();
}

// =====================================================================
// Contas a pagar
// =====================================================================

class ContaPagar {
  final Doc d;
  ContaPagar(this.d);
  String get id => str(d['id']);
  String get nome => str(d['nome'], 'Conta');
  double get valor => numD(d['valor']);
  String get rep => str(d['rep'], 'mensal'); // mensal | parcelas | unica
  int get dia => numI(d['dia']) ?? 1;
  String get ini => str(d['ini'], '0000-00');
  String? get fim => d['fim'] is String && (d['fim'] as String).isNotEmpty ? d['fim'] as String : null;
  String? get data => d['data'] is String ? d['data'] as String : null;
  int get parc => numI(d['parc']) ?? 1;
  int get cada => numI(d['cada']) ?? 1;
  String get cat => str(d['cat'], 'contas');
  String get pag => str(d['pag'], 'Boleto');
  String get chave => str(d['chave']);
  bool get variavel => d['variavel'] == true;
  int get criado => numI(d['criado']) ?? 0;

  String get criadoYm {
    if (criado <= 0) return '0000-00';
    final t = DateTime.fromMillisecondsSinceEpoch(criado, isUtc: true);
    return '${t.year}-${doisDig(t.month)}';
  }

  String venc(String ym) => rep == 'unica' && data != null ? data! : ymd(ym, dia);

  bool ativa(String ym) {
    if (rep == 'unica') return (data ?? '').startsWith(ym);
    if (ym.compareTo(ini) < 0) return false;
    if (rep == 'parcelas') return ymDiff(ini, ym) < parc;
    if (cada > 1 && ymDiff(ini, ym) % cada != 0) return false;
    return fim == null || ym.compareTo(fim!) <= 0;
  }

  /// Próximo mês de vencimento, para contas "a cada X meses".
  String proxYm(String ym) {
    if (cada <= 1) return ym;
    if (ym.compareTo(ini) <= 0) return ini;
    final r = ymDiff(ini, ym) % cada;
    return r == 0 ? ym : ymAdd(ym, cada - r);
  }

  String get repTexto {
    if (rep == 'parcelas') return 'Em $parc parcelas';
    if (rep == 'unica') return 'Uma vez';
    if (cada <= 1) return 'Todo mês';
    return const {2: 'A cada 2 meses', 3: 'A cada 3 meses', 6: 'A cada 6 meses', 12: 'Uma vez por ano'}[cada] ?? 'A cada $cada meses';
  }
}

/// Uma conta num mês: vencimento, situação e, se paga, como.
class InstConta {
  final ContaPagar b;
  final String ym, venc;
  Doc? p; // registro de pagamento (kind pagto)
  int? n; // número da parcela
  bool antes = false; // mês anterior ao cadastro da conta
  String st = 'futura'; // atrasada | hoje | breve | futura | pago
  double valor = 0;
  String? pagoEm;
  String? fonte; // manual | vinculo | extrato
  Gasto? gasto;
  int dias = 0;
  Gasto? sug;
  InstConta(this.b, this.ym, this.venc);
  String get key => '${b.id}|$ym';
  String get idPagto => 'pp_${b.id}_$ym';

  String get statusTexto {
    if (st == 'pago') return fonte == 'extrato' ? 'Paga em ${dataCurta(pagoEm!)} · encontrada nos gastos' : 'Paga em ${dataCurta(pagoEm!)}';
    if (st == 'atrasada') return -dias == 1 ? 'Venceu ontem' : 'Atrasada há ${-dias} dias';
    if (st == 'hoje') return 'Vence hoje';
    if (dias == 1) return 'Vence amanhã';
    return 'Vence em $dias dias';
  }
}

List<ContaPagar> contasPagar(Repo r) => r.doTipo('pagar').map(ContaPagar.new).toList();
Map<String, Doc> pagtos(Repo r) => {for (final d in r.doTipo('pagto')) str(d['id']): d};

List<InstConta> calcularContas(Repo repo, String de, String ate, {String? hoje}) {
  final h = hoje ?? hojeIso();
  final bills = contasPagar(repo);
  final pg = pagtos(repo);
  final insts = <InstConta>[];
  for (var m = de; m.compareTo(ate) <= 0; m = ymAdd(m, 1)) {
    for (final b in bills) {
      if (b.ativa(m)) insts.add(InstConta(b, m, b.venc(m)));
    }
  }
  insts.sort((x, y) => x.venc.compareTo(y.venc));
  final usados = <String>{
    for (final p in pg.values)
      if (p['pago'] == true && p['gasto'] is String) p['gasto'] as String
  };
  final gastos = repo.gastos;
  final ultimoValor = <String, double>{};
  for (final it in insts) {
    final b = it.b;
    final p = pg['pp_${b.id}_${it.ym}'];
    final rej = <String>{if (p != null && p['rej'] is List) ...(p['rej'] as List).whereType<String>()};
    it.p = p;
    it.n = b.rep == 'parcelas' ? ymDiff(b.ini, it.ym) + 1 : null;
    it.antes = it.ym.compareTo(b.criadoYm) < 0 && !(p != null && p['pago'] == true);
    final est = b.variavel && ultimoValor[b.id] != null ? ultimoValor[b.id]! : b.valor;
    if (p != null && p['pago'] == true) {
      it.st = 'pago';
      it.valor = numD(p['valor']);
      it.pagoEm = str(p['data'], it.venc);
      it.fonte = p['gasto'] is String ? 'vinculo' : 'manual';
      final gid = p['gasto'];
      if (gid is String) {
        final gd = repo.porId(gid);
        it.gasto = gd == null ? null : Gasto(gd);
      }
    } else if (b.chave.isNotEmpty) {
      final ch = norm(b.chave), ini = addDias(it.venc, -25), fim = addDias(it.venc, 20);
      final cands = gastos
          .where((g) =>
              !usados.contains(g.id) &&
              !rej.contains(g.id) &&
              g.data.compareTo(ini) >= 0 &&
              g.data.compareTo(fim) <= 0 &&
              norm(g.desc).contains(ch) &&
              (b.variavel || (g.valor - b.valor).abs() <= (b.valor * .2 > 3 ? b.valor * .2 : 3)))
          .toList()
        ..sort((x, y) => (diasEntre(x.data, it.venc)).abs().compareTo((diasEntre(y.data, it.venc)).abs()));
      if (cands.isNotEmpty) {
        final c = cands.first;
        usados.add(c.id);
        it.st = 'pago';
        it.valor = c.valor;
        it.pagoEm = c.data;
        it.fonte = 'extrato';
        it.gasto = c;
      }
    }
    if (it.st == 'pago') {
      ultimoValor[b.id] = it.valor;
      continue;
    }
    it.valor = est;
    final dd = diasEntre(h, it.venc) - 1;
    it.dias = dd;
    it.st = dd < 0 ? 'atrasada' : (dd == 0 ? 'hoje' : (dd <= 7 ? 'breve' : 'futura'));
    if (!it.antes) {
      final ini = addDias(it.venc, -12), fim = addDias(it.venc, 12);
      final tol = it.valor * (b.variavel ? .25 : .02);
      final s = gastos
          .where((g) =>
              !usados.contains(g.id) &&
              !rej.contains(g.id) &&
              g.d['pg'] == null &&
              g.data.compareTo(ini) >= 0 &&
              g.data.compareTo(fim) <= 0 &&
              (g.valor - it.valor).abs() <= (tol > .05 ? tol : .05))
          .toList()
        ..sort((x, y) {
          final c = (x.valor - it.valor).abs().compareTo((y.valor - it.valor).abs());
          return c != 0 ? c : diasEntre(x.data, it.venc).abs().compareTo(diasEntre(y.data, it.venc).abs());
        });
      it.sug = s.isEmpty ? null : s.first;
    }
  }
  return insts;
}

class MesContas {
  final List<InstConta> doMes, atrasoAnt;
  final double total, pago, falta;
  MesContas(this.doMes, this.atrasoAnt, this.total, this.pago, this.falta);
  List<InstConta> get abertas {
    const ordem = {'atrasada': 0, 'hoje': 1, 'breve': 2, 'futura': 3, 'pago': 4};
    final l = [...atrasoAnt, ...doMes.where((i) => i.st != 'pago')];
    l.sort((a, b) {
      final c = ordem[a.st]!.compareTo(ordem[b.st]!);
      return c != 0 ? c : a.venc.compareTo(b.venc);
    });
    return l;
  }

  List<InstConta> get pagas => doMes.where((i) => i.st == 'pago').toList()..sort((a, b) => a.venc.compareTo(b.venc));
  int get nAtrasadas => abertas.where((i) => i.st == 'atrasada').length;
}

MesContas mesContas(Repo repo, String ym, {String? hoje}) {
  final h = hoje ?? hojeIso();
  final mAtual = ymDe(h);
  final de = ymAdd(ym.compareTo(mAtual) < 0 ? ym : mAtual, -6);
  final all = calcularContas(repo, de, ym.compareTo(mAtual) > 0 ? ym : mAtual, hoje: h);
  final doMes = all.where((i) => i.ym == ym && !i.antes).toList();
  final atr = ym == mAtual ? all.where((i) => i.ym.compareTo(ym) < 0 && !i.antes && i.st == 'atrasada').toList() : <InstConta>[];
  final total = doMes.fold<double>(0, (a, i) => a + i.valor);
  final pago = doMes.where((i) => i.st == 'pago').fold<double>(0, (a, i) => a + i.valor);
  final falta = [...doMes, ...atr].where((i) => i.st != 'pago').fold<double>(0, (a, i) => a + i.valor);
  return MesContas(doMes, atr, total, pago, falta);
}

/// Registros para marcar uma conta como paga (e, se pedido, lançar o gasto).
List<Doc> docsPagamento(InstConta it, double valor, String data, {required bool lancarGasto}) {
  final b = it.b;
  final p = <String, dynamic>{...?it.p, 'kind': 'pagto', 'id': it.idPagto, 'conta': b.id, 'mes': it.ym, 'pago': true, 'valor': valor, 'data': data};
  p.remove('gasto');
  p.remove('criouGasto');
  final out = <Doc>[];
  if (lancarGasto) {
    final g = <String, dynamic>{
      'kind': 'gasto',
      'id': novoId('g'),
      'desc': b.nome + (b.rep == 'parcelas' ? ' (${it.n}/${b.parc})' : ''),
      'valor': valor,
      'data': data,
      'cat': b.cat,
      'pag': b.pag,
      'fixo': false,
      'criado': DateTime.now().millisecondsSinceEpoch,
      'pg': b.id,
    };
    out.add(g);
    p['gasto'] = g['id'];
    p['criouGasto'] = true;
  }
  out.add(p);
  if (b.variavel && (b.valor - valor).abs() > .009) out.add({...b.d, 'valor': valor});
  return out;
}

List<Doc> docsVincular(InstConta it, Gasto g) {
  final b = it.b;
  final p = <String, dynamic>{...?it.p, 'kind': 'pagto', 'id': it.idPagto, 'conta': b.id, 'mes': it.ym, 'pago': true, 'valor': g.valor, 'data': g.data, 'gasto': g.id};
  p.remove('criouGasto');
  final out = <Doc>[p];
  if (b.chave.isEmpty && g.doExtrato) out.add({...b.d, 'chave': g.desc});
  return out;
}

Doc docRejeitar(InstConta it, String gastoId) {
  final rej = <String>{if (it.p != null && it.p!['rej'] is List) ...(it.p!['rej'] as List).whereType<String>(), gastoId};
  return {...?it.p, 'kind': 'pagto', 'id': it.idPagto, 'conta': it.b.id, 'mes': it.ym, 'pago': false, 'rej': rej.toList()};
}

/// Gastos perto do vencimento com valor parecido (para vincular em vez de lançar).
List<Gasto> gastosParecidos(Repo repo, InstConta it) {
  final usados = <String>{
    for (final p in repo.doTipo('pagto'))
      if (p['pago'] == true && p['gasto'] is String) p['gasto'] as String
  };
  final ini = addDias(it.venc, -15), fim = addDias(it.venc, 15);
  final tol = it.valor * .3 > 5 ? it.valor * .3 : 5;
  return (repo.gastos
          .where((g) => !usados.contains(g.id) && g.d['pg'] == null && g.data.compareTo(ini) >= 0 && g.data.compareTo(fim) <= 0 && (g.valor - it.valor).abs() <= tol)
          .toList()
        ..sort((x, y) => (x.valor - it.valor).abs().compareTo((y.valor - it.valor).abs())))
      .take(3)
      .toList();
}

// =====================================================================
// Recebimentos fixos (salário e vale)
// =====================================================================

class TipoRenda {
  final String id, nome, cat, regra;
  final int dia;
  const TipoRenda(this.id, this.nome, this.cat, this.regra, this.dia);
}

const tiposRenda = [
  TipoRenda('rd_salario', 'Salário', 'salario', 'util', 30),
  TipoRenda('rd_va', 'Vale alimentação', 'beneficios', 'dia', 20),
];

String dataRenda(Renda r, String ym) => r.regra == 'util' ? ultimoDiaUtil(ym) : ymd(ym, r.dia);

class StatusRenda {
  final String data;
  final Entrada? rec;
  final int dias;
  StatusRenda(this.data, this.rec, this.dias);
}

StatusRenda statusRenda(Repo repo, Renda r, String ym, {String? hoje}) {
  final data = dataRenda(r, ym);
  final ini = addDias(data, -10), fim = addDias(data, 10);
  final cat = tiposRenda.where((t) => t.id == r.id).map((t) => t.cat).firstOrNull;
  final cand = repo.entradas.where((e) {
    if (e.data.compareTo(ini) < 0 || e.data.compareTo(fim) > 0 || e.cat == 'proprias') return false;
    if (e.rd != null && e.rd != r.id) return false;
    if (r.id == 'rd_va' ? e.cat == 'salario' : e.cat == 'beneficios') return false;
    return e.rd == r.id || e.cat == cat || (r.valor > 0 && (e.valor - r.valor).abs() <= r.valor * .15);
  }).toList()
    ..sort((a, b) {
      final ra = a.rd == r.id ? 1 : 0, rb = b.rd == r.id ? 1 : 0;
      if (ra != rb) return rb - ra;
      return diasEntre(a.data, data).abs().compareTo(diasEntre(b.data, data).abs());
    });
  return StatusRenda(data, cand.isEmpty ? null : cand.first, diasEntre(hoje ?? hojeIso(), data) - 1);
}

/// Item da linha do tempo "Próximos recebimentos".
class ItemAgenda {
  final String id, data, nome;
  final double valor;
  final bool recebido, atrasado;
  ItemAgenda(this.id, this.data, this.nome, this.valor, this.recebido, this.atrasado);
}

List<ItemAgenda> agendaRecebimentos(Repo repo, {String? hoje}) {
  final h = hoje ?? hojeIso(), mA = ymDe(h);
  final it = <ItemAgenda>[];
  for (final r in repo.rendas.where((r) => r.valor > 0)) {
    final nome = tiposRenda.where((t) => t.id == r.id).map((t) => t.nome).firstOrNull ?? 'Recebimento';
    for (final ym in [mA, ymAdd(mA, 1)]) {
      final st = statusRenda(repo, r, ym, hoje: h);
      final d = st.rec?.data ?? dataRenda(r, ym);
      if (st.rec != null && ymDe(d) != mA) continue;
      if (st.rec == null && ym != mA && it.any((x) => x.id == r.id && !x.recebido)) continue;
      it.add(ItemAgenda(r.id, d, nome, st.rec?.valor ?? r.valor, st.rec != null, st.rec == null && d.compareTo(h) < 0));
    }
  }
  for (final e in emprestimos(repo)) {
    final D = dadosEmprestimo(repo, e, hoje: h);
    if (D.quitado || D.prox == null) continue;
    final v = D.prox!.valor - D.prox!.coberto;
    it.add(ItemAgenda(e.id, D.prox!.venc, 'Parcela · ${e.pessoa}', v < 0 ? 0 : v, false, D.prox!.venc.compareTo(h) < 0));
  }
  it.sort((a, b) => a.data.compareTo(b.data));
  final rec = it.where((x) => x.recebido).toList();
  final fut = it.where((x) => !x.recebido).toList();
  return [if (rec.isNotEmpty) rec.last, ...fut].take(3).toList();
}

// =====================================================================
// Cartões de crédito
// =====================================================================

class CartaoCredito {
  final Doc d;
  CartaoCredito(this.d);
  String get id => str(d['id']);
  String get nome => str(d['nome'], 'Cartão');
  String get banco => str(d['banco']);
  double get limite => numD(d['limite']);
  int get fecha => numI(d['fecha']) ?? 1;
  int get vence => numI(d['vence']) ?? 10;
  String get cor => str(d['cor'], '#820ad1');
  int get criado => numI(d['criado']) ?? 0;

  /// Datas de fechamento e vencimento da fatura que vence no mês [ym].
  ({String fech, String venc}) dias(String ym) {
    final fy = fecha < vence ? ym : ymAdd(ym, -1);
    return (fech: ymd(fy, fecha), venc: ymd(ym, vence));
  }

  /// Fatura (mês do vencimento) em que cai uma compra feita na data [d].
  String faturaDe(String data) {
    final b = ymDe(data);
    for (var k = -1; k <= 3; k++) {
      final ym = ymAdd(b, k);
      if (data.compareTo(dias(ym).fech) < 0) return ym;
    }
    return ymAdd(b, 1);
  }
}

List<CartaoCredito> cartoes(Repo r) => r.doTipo('cartao').map(CartaoCredito.new).toList()..sort((a, b) => a.criado.compareTo(b.criado));

/// Compra no cartão (lançada ou parcela prevista).
class ItemFatura {
  final Gasto? g;
  final String desc, cat, fat;
  final double valor;
  final int? parcI, parcN;
  final bool prevista;
  ItemFatura({this.g, required this.desc, required this.cat, required this.fat, required this.valor, this.parcI, this.parcN, this.prevista = false});
}

String _baseDesc(String d) => d
    .replaceAll(RegExp(r'\s*[-–·]?\s*\(?\s*parcela\s*\d{1,2}\s*(\/|de)\s*\d{1,2}\s*\)?\s*$', caseSensitive: false), '')
    .replaceAll(RegExp(r'\s*\(?\d{1,2}\/\d{1,2}\)?\s*$'), '')
    .trim();

Map? _parc(Gasto g) => g.d['parc'] is Map ? g.d['parc'] as Map : null;

String _chaveGrupo(Gasto g) {
  final p = _parc(g);
  if (p != null && p['g'] is String) return p['g'] as String;
  return '${_baseDesc(g.desc).toLowerCase()}|${p != null ? numI(p['n']) : 1}|${g.valor.toStringAsFixed(2)}';
}

class Fatura {
  final String ym, fech, venc, st; // st: futura | aberta | fechada | vencida | paga
  final List<ItemFatura> itens;
  final double total, pago;
  Fatura(this.ym, this.fech, this.venc, this.st, this.itens, this.total, this.pago);
  double get falta => total - pago > 0 ? ((total - pago) * 100).round() / 100 : 0;
  String get stTexto => const {'futura': 'Próxima', 'aberta': 'Aberta', 'fechada': 'Fechada', 'vencida': 'Vencida', 'paga': 'Paga'}[st]!;
}

class ResumoCartao {
  final CartaoCredito c;
  final String atual;
  final List<Fatura> faturas;
  final double usado;
  ResumoCartao(this.c, this.atual, this.faturas, this.usado);
  double? get disponivel => c.limite > 0 ? c.limite - usado : null;
  Fatura get faturaAtual => faturas.firstWhere((f) => f.ym == atual);
}

ResumoCartao resumoCartao(Repo repo, CartaoCredito c, {String? hoje}) {
  final h = hoje ?? hojeIso();
  final gs = repo.gastos.where((g) => g.d['cartao'] == c.id).toList();
  // parcelas futuras ainda não lançadas
  final grupos = <String, List<Gasto>>{};
  for (final g in gs) {
    final p = _parc(g);
    if (p != null && (numI(p['n']) ?? 1) > 1 && g.d['fat'] is String) (grupos[_chaveGrupo(g)] ??= []).add(g);
  }
  final proj = <ItemFatura>[];
  for (final l in grupos.values) {
    final top = l.reduce((a, b) => (numI(_parc(b)!['i']) ?? 1) > (numI(_parc(a)!['i']) ?? 1) ? b : a);
    final tem = {for (final g in l) numI(_parc(g)!['i'])};
    final ti = numI(_parc(top)!['i']) ?? 1, tn = numI(_parc(top)!['n']) ?? 1;
    for (var i = ti + 1; i <= tn; i++) {
      if (tem.contains(i)) continue;
      proj.add(ItemFatura(desc: _baseDesc(top.desc), cat: top.cat, fat: ymAdd(top.d['fat'] as String, i - ti), valor: top.valor, parcI: i, parcN: tn, prevista: true));
    }
  }
  final atual = c.faturaDe(h);
  final yms = <String>{atual, for (final g in gs) if (g.d['fat'] is String) g.d['fat'] as String, for (final p in proj) p.fat}.toList()..sort();
  final cpags = repo.doTipo('cpag').where((p) => p['cartao'] == c.id).toList();
  final faturas = <Fatura>[];
  for (final ym in yms) {
    final itens = <ItemFatura>[
      for (final g in gs.where((g) => g.d['fat'] == ym))
        ItemFatura(g: g, desc: g.desc, cat: g.cat, fat: ym, valor: g.valor, parcI: numI(_parc(g)?['i']), parcN: numI(_parc(g)?['n'])),
      ...proj.where((p) => p.fat == ym),
    ]..sort((a, b) => (b.g?.data ?? '').compareTo(a.g?.data ?? ''));
    final total = (itens.fold<double>(0, (t, i) => t + i.valor) * 100).round() / 100;
    final pago = cpags.where((p) => p['fat'] == ym).fold<double>(0, (t, p) => t + numD(p['valor']));
    final dd = c.dias(ym), fechAnt = c.dias(ymAdd(ym, -1)).fech;
    final st = h.compareTo(fechAnt) < 0
        ? 'futura'
        : h.compareTo(dd.fech) < 0
            ? 'aberta'
            : (total <= .009 || pago >= total - .009)
                ? 'paga'
                : h.compareTo(dd.venc) > 0
                    ? 'vencida'
                    : 'fechada';
    faturas.add(Fatura(ym, dd.fech, dd.venc, st, itens, total, pago));
  }
  final usado = faturas.where((f) => f.st != 'paga').fold<double>(0, (t, f) => t + f.falta);
  return ResumoCartao(c, atual, faturas, usado);
}

/// Registros de uma compra no cartão, dividida em parcelas.
List<Doc> docsCompra(CartaoCredito c, {required String desc, required double valor, required int parcelas, required String data, required String cat}) {
  final n = parcelas < 1 ? 1 : parcelas;
  final f0 = c.faturaDe(data), grupo = novoId('cp'), agora = DateTime.now().millisecondsSinceEpoch;
  final cent = (valor * 100).round(), parte = cent ~/ n, resto = cent - parte * n;
  return List.generate(n, (i) {
    final ym = ymAdd(ymDe(data), i);
    return <String, dynamic>{
      'kind': 'gasto',
      'id': '${novoId('g')}$i',
      'desc': n > 1 ? '$desc (${i + 1}/$n)' : desc,
      'valor': (parte + (i < resto ? 1 : 0)) / 100,
      'data': ymd(ym, int.parse(data.substring(8, 10))),
      'cat': cat,
      'pag': 'Crédito',
      'fixo': false,
      'criado': agora + i,
      'cartao': c.id,
      'fat': ymAdd(f0, i),
      if (n > 1) 'parc': {'i': i + 1, 'n': n, 'g': grupo},
    };
  });
}

/// Ids de todas as parcelas da mesma compra.
List<String> idsDaCompra(Repo repo, Gasto g) {
  if (_parc(g) == null) return [g.id];
  final k = _chaveGrupo(g);
  return repo.gastos.where((x) => x.d['cartao'] == g.d['cartao'] && _parc(x) != null && _chaveGrupo(x) == k).map((x) => x.id).toList();
}

// =====================================================================
// Dinheiro emprestado
// =====================================================================

class Emprestimo {
  final Doc d;
  Emprestimo(this.d);
  String get id => str(d['id']);
  String get pessoa => str(d['pessoa'], 'Alguém');
  String get primeiroNome => pessoa.trim().split(RegExp(r'\s+')).first;
  double get valor => numD(d['valor']);
  String get data => str(d['data'], hojeIso());
  String get ini => str(d['ini']);
  int get parc => numI(d['parc']) ?? 0;
  double get vparc => numD(d['vparc']);
  int get dia => numI(d['dia']) ?? 10;
  String get obs => str(d['obs']);
  int get criado => numI(d['criado']) ?? 0;
}

class ParcelaEmp {
  final int k;
  final String ym, venc, st; // pago | parcial | atrasada | mes | futura
  final double valor, coberto;
  ParcelaEmp(this.k, this.ym, this.venc, this.st, this.valor, this.coberto);
}

class DadosEmp {
  final List<Doc> recebimentos;
  final double recebido, falta, valorParcela;
  final List<ParcelaEmp> agenda;
  DadosEmp(this.recebimentos, this.recebido, this.falta, this.valorParcela, this.agenda);
  ParcelaEmp? get prox => agenda.where((a) => a.st != 'pago').firstOrNull;
  List<ParcelaEmp> get atrasadas => agenda.where((a) => a.st == 'atrasada').toList();
  bool get quitado => falta <= .005;
}

List<Emprestimo> emprestimos(Repo r) => r.doTipo('emprestimo').map(Emprestimo.new).toList()..sort((a, b) => b.criado.compareTo(a.criado));

DadosEmp dadosEmprestimo(Repo repo, Emprestimo e, {String? hoje}) {
  final rs = repo.doTipo('receb').where((r) => r['emp'] == e.id).toList()..sort((a, b) => str(a['data']).compareTo(str(b['data'])));
  final recebido = (rs.fold<double>(0, (t, r) => t + numD(r['valor'])) * 100).round() / 100;
  final falta = e.valor - recebido > 0 ? ((e.valor - recebido) * 100).round() / 100 : 0.0;
  final h = hoje ?? hojeIso(), mAtual = ymDe(h);
  final parc = e.parc > 0 ? e.parc : 0;
  final vp = parc > 0 ? (e.valor / parc * 100).round() / 100 : e.vparc;
  final agenda = <ParcelaEmp>[];
  if (e.ini.isNotEmpty && (parc > 0 || vp > 0)) {
    final n = parc > 0 ? parc : (e.valor / (vp > .01 ? vp : .01)).ceil();
    var pago = recebido;
    for (var k = 0; k < n && k < 120; k++) {
      final ym = ymAdd(e.ini, k);
      final val = k == n - 1 ? ((e.valor - vp * (n - 1)) * 100).round() / 100 : vp;
      final cob = pago <= 0 ? 0.0 : (pago < val ? pago : val);
      pago -= val;
      final venc = ymd(ym, e.dia);
      final st = cob >= val - .005 ? 'pago' : (cob > 0 ? 'parcial' : (venc.compareTo(h) < 0 ? 'atrasada' : (ym == mAtual ? 'mes' : 'futura')));
      agenda.add(ParcelaEmp(k + 1, ym, venc, st, val, cob));
    }
  }
  return DadosEmp(rs, recebido, falta, vp, agenda);
}

/// Registros de um pagamento recebido de um empréstimo.
List<Doc> docsRecebimento(Repo repo, Emprestimo e, double valor, String data, {required bool lancarEntrada}) {
  final agora = DateTime.now().millisecondsSinceEpoch;
  final r = <String, dynamic>{'kind': 'receb', 'id': novoId('rc'), 'emp': e.id, 'valor': valor, 'data': data, 'criado': agora};
  final out = <Doc>[];
  if (lancarEntrada) {
    final en = <String, dynamic>{'kind': 'entrada', 'id': novoId('e'), 'desc': 'Pagamento de ${e.primeiroNome} (empréstimo)', 'valor': valor, 'data': data, 'cat': 'emprestimo', 'criado': agora, 'emp': e.id};
    final cs = repo.contas..sort((a, b) => b.saldo.compareTo(a.saldo));
    if (cs.isNotEmpty) en['conta'] = cs.first.id;
    out.add(en);
    r['entrada'] = en['id'];
    r['criouEntrada'] = true;
  }
  out.add(r);
  return out;
}
