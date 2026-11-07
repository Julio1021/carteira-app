// Importação do extrato do banco em OFX, com as mesmas regras do site.
import '../util/fmt.dart';
import 'modelos.dart';
import 'planejar.dart';
import 'repo.dart';

class TxOfx {
  final String tipo, data, fitid, memo, nome;
  final double valor;
  TxOfx({required this.tipo, required this.data, required this.valor, this.fitid = '', this.memo = '', this.nome = ''});
}

class Ofx {
  String banco = '', bancoId = '', conta = '';
  String? inicio, fim;
  double? saldo;
  String? saldoData;
  final List<TxOfx> tx = [];
}

String? _d8(String v) => v.length >= 8 ? '${v.substring(0, 4)}-${v.substring(4, 6)}-${v.substring(6, 8)}' : null;
String _tag(String blk, String k) {
  final m = RegExp('<$k>([^<\\r\\n]*)', caseSensitive: false).firstMatch(blk);
  return m == null ? '' : m.group(1)!.trim();
}

double? _num(String s) => double.tryParse(s.replaceAll(RegExp(r'\s'), '').replaceFirstMapped(RegExp(r',(\d{1,2})$'), (m) => '.${m[1]}'));

Ofx lerOfx(String texto) {
  final o = Ofx();
  o.banco = _tag(texto, 'ORG');
  o.inicio = _d8(_tag(texto, 'DTSTART'));
  o.fim = _d8(_tag(texto, 'DTEND'));
  o.conta = _tag(texto, 'ACCTID');
  o.bancoId = _tag(texto, 'BANKID');
  final lb = RegExp(r'<LEDGERBAL>([\s\S]*?)</LEDGERBAL>', caseSensitive: false).firstMatch(texto) ??
      RegExp(r'<AVAILBAL>([\s\S]*?)</AVAILBAL>', caseSensitive: false).firstMatch(texto);
  if (lb != null) {
    final v = _num(_tag(lb.group(1)!, 'BALAMT'));
    final d = _d8(_tag(lb.group(1)!, 'DTASOF'));
    if (v != null && d != null) {
      o.saldo = v;
      o.saldoData = d;
    }
  }
  final partes = texto.split(RegExp('<STMTTRN>', caseSensitive: false)).skip(1);
  for (final p0 in partes) {
    final p = p0.split(RegExp('</STMTTRN>', caseSensitive: false)).first;
    final amt = _num(_tag(p, 'TRNAMT'));
    final data = _d8(_tag(p, 'DTPOSTED'));
    if (data == null || amt == null) continue;
    o.tx.add(TxOfx(
      tipo: _tag(p, 'TRNTYPE').toUpperCase(),
      data: data,
      valor: amt,
      fitid: _tag(p, 'FITID'),
      memo: _tag(p, 'MEMO').replaceAll('&quot;', '"').replaceAll('&amp;', '&'),
      nome: _tag(p, 'NAME').replaceAll('&amp;', '&'),
    ));
  }
  o.tx.sort((a, b) => a.data.compareTo(b.data));
  return o;
}

/// "SUPERMERCADO DIA LTDA" -> "Supermercado Dia LTDA"
String tituloOfx(String s) {
  s = s.replaceFirst(RegExp(r'^ifd\*', caseSensitive: false), 'iFood · ');
  final b = StringBuffer();
  var inicio = true;
  for (final ch in s.toLowerCase().split('')) {
    b.write(inicio && RegExp(r'[a-zà-ú]').hasMatch(ch) ? ch.toUpperCase() : ch);
    inicio = RegExp(r'[\s(/*\-]').hasMatch(ch);
  }
  return b
      .toString()
      .replaceAllMapped(RegExp(r'\b(Ltda|Sa|S/a|Me|Eireli|Epp)\b', caseSensitive: false), (m) => m[0]!.length <= 3 ? m[0]!.toUpperCase() : m[0]!)
      .trim();
}

String limpaNome(TxOfx t) {
  var n = t.nome;
  if (n.isEmpty) {
    final m = RegExp(r'"(.+)"').firstMatch(t.memo);
    n = m != null ? m.group(1)! : t.memo;
  }
  n = n.replaceFirst(RegExp(r'^no estabelecimento\s+', caseSensitive: false), '');
  final pad = n.split(RegExp(r'\s{2,}'));
  if (pad.length > 1) {
    n = pad[0];
  } else if (n.length >= 25 && RegExp(r'\S{3,}bra$', caseSensitive: false).hasMatch(n) && !RegExp(r'\sbra$', caseSensitive: false).hasMatch(n)) {
    n = n.substring(0, 22);
  }
  return n.replaceFirst(RegExp(r'\s+bra$', caseSensitive: false), '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

String chaveOfx(TxOfx t) {
  final n = norm(limpaNome(t)).replaceFirst(RegExp(r'^IFD\*'), 'IFD ').replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final k = n.split(' ').take(2).join(' ');
  if (k.isNotEmpty) return k;
  final m = norm(t.memo);
  return m.length > 20 ? m.substring(0, 20) : m;
}

/// Chave para não duplicar: data|valor|estabelecimento|ocorrência no dia
List<String> chavesUnicas(List<TxOfx> tx) {
  final cont = <String, int>{};
  return tx.map((t) {
    final b = '${t.data}|${t.valor.abs().toStringAsFixed(2)}|${chaveOfx(t)}';
    cont[b] = (cont[b] ?? 0) + 1;
    return '$b|${cont[b]}';
  }).toList();
}

final _regras = <(String, RegExp)>[
  ('mercado', RegExp(r'SUPERM|SUPERMERC|\bMERCADO\b(?! ?PAGO| ?LIVRE)|RECOBASE|\bSUP DOS|SUP\b.*AMIGOS|MINIMERC|MERCEARIA|FRUTA|ATACAD|ASSAI|HORTI|SACOLAO|ACOUGUE|HIPER|EMPORIO|QUITANDA')),
  ('alimentacao', RegExp(r'RESTAUR|\bREST\b|PRATO FEITO|SNACK|LANCHONETE|IFD\*|IFOOD|LANCH|PADARIA|PANIFIC|PIZZ|BURGER|HAMBURG|\bBAR\b|CAFE|SORVET|PASTEL|MC ?DONALD|SUBWAY|DOCERIA|CHURRASC|ESPETINHO|ACAI|BOTECO|RAPPI|AIQFOME')),
  ('transporte', RegExp(r'UBER|\b99\b|99APP|99POP|BILHETAGEM|BUS SERVICOS|POSTO|COMBUST|AUTO POSTO|SHELL|IPIRANGA|ESTACION|PEDAGIO|SEM PARAR|CONECTCAR|VELOE|BUSER|CLICKBUS|RODOVIARIA|METRO|CPTM|MEIO DE TRANSPORTE|AUTO ?PECAS|\bPECAS\b|OFICINA|BORRACH')),
  ('recarga', RegExp(r'RECARGA|PRE ?PAGO|CREDITO CELULAR|CELULAR PRE')),
  ('internet', RegExp(r'TELECOM|INTERNET|FIBRA|NET SERVICOS|BANDA LARGA|PROVEDOR|\bVIVO\b|\bCLARO\b|\bTIM\b|\bOI\b|SKY\b|TELEFONICA|WEBNET|LINK\b')),
  ('contas', RegExp(r'\bEDP\b|SAEG|SABESP|ENEL|CPFL|ELEKTRO|COMGAS|CONVENIO')),
  ('impostos', RegExp(r'MUNICIPIO|PREFEITURA|DETRAN|DARF|IPVA|IPTU|RECEITA FEDERAL|CARTORIO|TARIFA')),
  ('saude', RegExp(r'FARMA|DROGA|RAIA|PANVEL|PAGUE MENOS|CLINICA|HOSPITAL|LABORAT|ODONTO|MEDIC|UNIMED|OTICA|PSICO')),
  ('educacao', RegExp(r'LIVRO|ESCOLA|FACULD|CURSO|UDEMY|ALURA|\bGRAN\b|ESTRATEGIA|QCONCURSOS|EDUCAC|PAPELARIA')),
  ('assinaturas', RegExp(r'NETFLIX|SPOTIFY|PRIME VIDEO|AMAZON PRIME|DISNEY|HBO|YOUTUBE|APPLE\.COM|GOOGLE|ICLOUD|DEEZER|GLOBOPLAY|PARAMOUNT|CLAUDE|ANTHROPIC|OPENAI|CHATGPT|PIX AUTOMATICO|ASSINATURA|SMILES')),
  ('compras', RegExp(r'SHOPEE|AMAZON|MAGAZ|MERCADOLIVRE|MERCADO LIVRE|SHEIN|ALIEXPRESS|AMERICANAS|CASAS BAHIA|MARKETPLACE|PAGARME|PAGAR\.ME|\bLOJA|RENNER|RIACHUELO|\bC&A\b|CENTAURO|KABUM|NETSHOES|HAVAN|TEMU|VULCABRAS|PERNAMBUCANAS|\bSBF\b|SHPP|DAFITI|ZARA|HERING|CALCADOS|\bMODA\b|SPORTS|ELETRO')),
  ('pets', RegExp(r'\bPET\b|PETSHOP|VETERIN|RACAO|COBASI|PETZ')),
  ('lazer', RegExp(r'CINEMA|INGRESSO|SYMPLA|SORTEZINHA|LOTERI|STEAM|PLAYSTATION|XBOX|NINTENDO|PARQUE|CLUBE|TEATRO')),
  ('cuidados', RegExp(r'BARBEAR|SALAO|CABELEIR|ESTETIC|COSMET|BOTICARIO|NATURA|PERFUM')),
  ('moradia', RegExp(r'ALUGUEL|CONDOMIN|IMOBILI|CONSTRU|LEROY|TELHANORTE|MADEIR|ELETRIC|HIDRAUL|VIDRA')),
];
final _empresa = RegExp(r'\b(LTDA|S ?A|S/A|ME|EIRELI|EPP|INSTITUICAO|PAGAMENTOS|SERVICOS|COMERCIO|BANCO|DISTR|HOLDING|TECNOLOGIA|AGENCIA)\b');

String nomeChave(String? n) =>
    norm(n ?? '').replaceAll(RegExp(r'[^A-Z ]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !RegExp(r'^(DE|DA|DO|DAS|DOS|E|D)$').hasMatch(w)).join(' ');

bool nomeIgual(String? a, String? b) {
  final x = nomeChave(a), y = nomeChave(b);
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  final aa = x.split(' '), bb = y.split(' ');
  if (aa[0] != bb[0]) return false;
  final (m, mm) = aa.length <= bb.length ? (aa, bb) : (bb, aa);
  return m.length >= 3 && m.every(mm.contains);
}

/// ({acao: gasto|ignorar, cat, pag, motivo})
({String acao, String cat, String pag, String motivo}) classificaGasto(TxOfx t, String dono) {
  final memo = norm(t.memo), nome = norm(t.nome), txt = '$memo $nome';
  if (t.valor >= 0) return (acao: 'ignorar', cat: '', pag: '', motivo: 'Entrada de dinheiro');
  if (RegExp(r'^(APLICACAO|DEBITO RENDA FIXA|DEBITO TESOURO|DEBITO RF|APLIC)').hasMatch(memo)) return (acao: 'ignorar', cat: '', pag: '', motivo: 'Aplicação em investimento');
  if (memo.contains('RECEBIDO DEVOLVIDO')) return (acao: 'ignorar', cat: '', pag: '', motivo: 'Devolução de Pix recebido');
  if (dono.isNotEmpty && nomeIgual(nome, dono)) return (acao: 'ignorar', cat: '', pag: '', motivo: 'Transferência entre suas contas');
  final pag = memo.startsWith('PIX')
      ? 'Pix'
      : RegExp(r'DEBITO|COMPRA').hasMatch(memo)
          ? 'Débito'
          : RegExp(r'PAGAMENTO|CONVENIO|BOLETO').hasMatch(memo)
              ? 'Boleto'
              : 'Débito';
  if (txt.contains('FATURA')) return (acao: 'gasto', cat: 'cartao', pag: 'Boleto', motivo: '');
  for (final (cat, re) in _regras) {
    if (re.hasMatch(txt)) return (acao: 'gasto', cat: cat, pag: pag, motivo: '');
  }
  if (memo.startsWith('PIX') && nome.isNotEmpty && !_empresa.hasMatch(nome)) return (acao: 'gasto', cat: 'transferencias', pag: pag, motivo: '');
  return (acao: 'gasto', cat: 'outros', pag: pag, motivo: '');
}

({String acao, String cat, String motivo}) classificaEntrada(TxOfx t, String dono) {
  final memo = norm(t.memo), nome = norm(t.nome), txt = '$memo $nome';
  if (RegExp(r'^(RESGATE|VENCIMENTO RENDA FIXA|VENCIMENTO EVENTOS|VENCIMENTO|CREDITO RENDA FIXA|RESG)').hasMatch(memo)) return (acao: 'ignorar', cat: '', motivo: 'Resgate de investimento');
  if (dono.isNotEmpty && nomeIgual(nome, dono)) return (acao: 'propria', cat: 'proprias', motivo: '');
  if (RegExp(r'ESTORNO|DEVOLVID|REEMBOLSO|CHARGEBACK').hasMatch(memo)) return (acao: 'entrada', cat: 'reembolso', motivo: '');
  if (RegExp(r'SALARIO|FOLHA|PROVENTOS|REMUNERACAO|PAGAMENTO DE SALARIO|13O|FERIAS').hasMatch(txt)) return (acao: 'entrada', cat: 'salario', motivo: '');
  if (RegExp(r'CASHBACK|PONTOS|JUROS|RENDIMENTO|PORQUINHO').hasMatch(txt)) return (acao: 'entrada', cat: 'rendimentos', motivo: '');
  if (RegExp(r'PIX RECEBIDO|TRANSFERENCIA RECEBIDA|TED|DOC').hasMatch(memo)) return (acao: 'entrada', cat: 'pix', motivo: '');
  return (acao: 'entrada', cat: 'outros_e', motivo: '');
}

/// Nomes que podem ser do titular (quem mais aparece enviando e recebendo Pix, ou no pagamento da fatura).
List<({String nome, int score})> candidatosDono(List<TxOfx> tx) {
  final d = <String, ({String nome, int env, int rec, Set<String> cps, int fat})>{};
  void reg(String nome, {bool env = false, bool rec = false, bool fat = false, String? cp}) {
    final k = nomeChave(nome);
    if (k.isEmpty || k.split(' ').length < 2) return;
    final x = d[k] ?? (nome: tituloOfx(nome), env: 0, rec: 0, cps: <String>{}, fat: 0);
    if (cp != null) x.cps.add(cp);
    d[k] = (nome: x.nome, env: x.env + (env ? 1 : 0), rec: x.rec + (rec ? 1 : 0), cps: x.cps, fat: x.fat + (fat ? 1 : 0));
  }

  for (final t in tx) {
    final m = norm(t.memo), nm = norm(t.nome);
    if ('$m $nm'.contains('FATURA')) {
      final f = t.nome.split(RegExp(r'\s+-\s+')).last;
      if (f.isNotEmpty && f != t.nome) reg(f, fat: true);
      continue;
    }
    if (!RegExp(r'^PIX (ENVIADO|RECEBIDO)|TRANSFERENCIA|TED|DOC').hasMatch(m)) continue;
    final cp = RegExp(r'CP\s*:\s*(\d{4,})').firstMatch(m)?.group(1);
    reg(t.nome, env: t.valor < 0, rec: t.valor >= 0, cp: cp);
  }
  int score(({String nome, int env, int rec, Set<String> cps, int fat}) x) =>
      x.fat * 100 + (x.cps.length >= 2 ? 40 * x.cps.length : 0) + (x.env > 0 && x.rec > 0 && x.cps.length >= 2 ? (x.env < x.rec ? x.env : x.rec) : 0);
  final l = d.values.toList()
    ..sort((a, b) {
      final c = score(b).compareTo(score(a));
      return c != 0 ? c : (b.env + b.rec).compareTo(a.env + a.rec);
    });
  return l.take(5).map((x) => (nome: x.nome, score: score(x))).toList();
}

/// Melhor palpite do titular (só quando há pistas fortes).
String adivinhaDono(List<TxOfx> tx) {
  final c = candidatosDono(tx);
  return c.isNotEmpty && c.first.score > 0 ? c.first.nome : '';
}

String nomeBanco(Ofx o) {
  final b = norm(o.banco);
  if (RegExp('INTER|INTERMEDIUM').hasMatch(b) || o.bancoId == '077') return 'Inter';
  if (RegExp('NU PAG|NUBANK').hasMatch(b) || o.bancoId == '260') return 'Nubank';
  if (b.contains('MERCADO PAGO') || o.bancoId == '323') return 'Mercado Pago';
  if (b.contains('ITAU') || o.bancoId == '341') return 'Itaú';
  if (b.contains('BRADESCO') || o.bancoId == '237') return 'Bradesco';
  if (b.contains('SANTANDER') || o.bancoId == '033') return 'Santander';
  if (b.contains('CAIXA') || o.bancoId == '104') return 'Caixa';
  if (b.contains('BRASIL') || o.bancoId == '001') return 'Banco do Brasil';
  return tituloOfx(o.banco.isEmpty ? 'Conta' : o.banco);
}

String contaIdOfx(Ofx o) => 'ct_${'${o.bancoId.isEmpty ? 'x' : o.bancoId}_${o.conta.isEmpty ? 'x' : o.conta}'.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}';

String _idRegra(String ch) => ch.replaceAll(RegExp(r'[^A-Z0-9]+'), '_');

// ---------------------------------------------------------------------
// Plano de importação
// ---------------------------------------------------------------------

class ItemImport {
  final TxOfx t;
  final String ext, ch, desc;
  String cat, pag;
  final double valor;
  bool dup;
  final String? rd, upd;
  ItemImport({required this.t, required this.ext, required this.ch, required this.cat, required this.desc, required this.valor, this.pag = 'Pix', this.dup = false, this.rd, this.upd});
}

class PlanoImport {
  final List<ItemImport> gastos = [], entradas = [];
  final Map<String, ({int n, double v})> ignorados = {};
  final List<Doc> pagFatura = [];
  final List<String> apagarEntradas = [];
  int jaImportados = 0;
  int get duplicados => gastos.where((g) => g.dup).length;
  void ignorar(String motivo, double v) {
    final x = ignorados[motivo] ?? (n: 0, v: 0.0);
    ignorados[motivo] = (n: x.n + 1, v: x.v + v.abs());
  }
}

/// Monta o que entra e o que fica de fora. [over] guarda as categorias que você trocou
/// na prévia (por estabelecimento; entradas com prefixo "E|").
PlanoImport planoImport(Repo repo, Ofx o, {required String dono, String desde = '', Map<String, String> over = const {}, bool proprias = true}) {
  final p = PlanoImport();
  final chaves = chavesUnicas(o.tx);
  final existentes = {for (final g in repo.gastos) if (g.d['ext'] is String) g.d['ext'] as String};
  final existE = {for (final e in repo.entradas) if (e.d['ext'] is String) e.d['ext'] as String: e};
  final regras = {for (final r in repo.doTipo('regra')) str(r['id']): r};
  final manuais = <String, int>{};
  for (final g in repo.gastos.where((g) => !g.doExtrato)) {
    final k = '${g.data}|${g.valor.toStringAsFixed(2)}';
    manuais[k] = (manuais[k] ?? 0) + 1;
  }
  final pgManuais = repo.gastos.where((g) => !g.doExtrato && g.d['pg'] != null).toList();
  final manuaisE = repo.entradas.where((x) => !x.doExtrato && (x.d['emp'] != null || x.rd != null || x.d['rapido'] != null)).toList();
  final propMes = <String, ({double entrou, double saiu, String ult})>{};
  final rendas = repo.rendas.where((r) => r.valor > 0).toList();
  final ccs = cartoes(repo);
  final emps = emprestimos(repo);

  for (var i = 0; i < o.tx.length; i++) {
    final t = o.tx[i];
    if (desde.isNotEmpty && t.data.compareTo(desde) < 0) continue;
    final ext = chaves[i];
    if (t.valor > 0) {
      final ke = classificaEntrada(t, dono);
      if (ke.acao == 'ignorar') {
        p.ignorar(ke.motivo, t.valor);
        continue;
      }
      final jm = manuaisE.indexWhere((x) => (x.valor - t.valor).abs() < .01 && (diasEntre(x.data, t.data) - 1).abs() <= 5);
      if (jm >= 0) {
        manuaisE.removeAt(jm);
        p.jaImportados++;
        continue;
      }
      // salário ou vale reconhecido pelo valor e pela data
      Renda? melhor;
      var dist = 99;
      for (final r in rendas) {
        if ((t.valor - r.valor).abs() > r.valor * .15) continue;
        final ym = ymDe(t.data);
        for (final m in [ym, ymAdd(ym, 1), ymAdd(ym, -1)]) {
          final dd = (diasEntre(t.data, dataRenda(r, m)) - 1).abs();
          if (dd <= 10 && dd < dist) {
            dist = dd;
            melhor = r;
          }
        }
      }
      if (melhor != null) {
        if (existE.containsKey(ext)) {
          p.jaImportados++;
          continue;
        }
        final tipo = tiposRenda.firstWhere((x) => x.id == melhor!.id, orElse: () => tiposRenda.first);
        p.entradas.add(ItemImport(t: t, ext: ext, ch: '__rd_${melhor.id}', cat: tipo.cat, desc: tipo.nome, valor: (t.valor * 100).round() / 100, rd: melhor.id));
        continue;
      }
      if (ke.acao == 'propria') {
        final ym = ymDe(t.data);
        final x = propMes[ym] ?? (entrou: 0.0, saiu: 0.0, ult: t.data);
        propMes[ym] = (entrou: x.entrou + t.valor, saiu: x.saiu, ult: t.data.compareTo(x.ult) > 0 ? t.data : x.ult);
        if (!proprias) p.ignorar('Transferências entre suas contas', t.valor);
        continue;
      }
      if (existE.containsKey(ext)) {
        p.jaImportados++;
        continue;
      }
      final ch = chaveOfx(t);
      final rg = regras['rge_${_idRegra(ch)}'];
      final cat = over['E|$ch'] ?? (rg != null ? str(rg['cat'], ke.cat) : ke.cat);
      final desc = tituloOfx(limpaNome(t));
      p.entradas.add(ItemImport(t: t, ext: ext, ch: ch, cat: cat, desc: desc.isEmpty ? 'Entrada' : desc, valor: (t.valor * 100).round() / 100));
      continue;
    }
    // pagamento de fatura de cartão cadastrado: vira pagamento da fatura, não gasto
    final txt = norm('${t.memo} ${t.nome}');
    CartaoCredito? cc;
    if (ccs.isNotEmpty) {
      if (RegExp('NU PAGAMENTOS|NUBANK').hasMatch(txt)) {
        cc = ccs.where((x) => x.banco.toLowerCase() == 'nubank' || norm(x.nome).contains('NUBANK')).firstOrNull;
      } else if (txt.contains('FATURA')) {
        cc = ccs.where((x) => x.banco.toLowerCase() == 'inter' || norm(x.nome).contains('INTER')).firstOrNull ?? (ccs.length == 1 ? ccs.first : null);
      }
      if (cc != null && t.data.compareTo(str(cc.d['desde'])) < 0) cc = null;
    }
    if (cc != null) {
      p.ignorar('Pagamento da fatura do ${cc.nome} (as compras já estão em Cartões)', t.valor);
      // fatura de vencimento mais próximo
      String? best;
      var bd = 1 << 30;
      for (var k = -2; k <= 2; k++) {
        final ym = ymAdd(ymDe(t.data), k);
        final dd = diasEntre(t.data, cc.dias(ym).venc) - 1;
        if (dd >= -25 && dd.abs() < bd) {
          bd = dd.abs();
          best = ym;
        }
      }
      p.pagFatura.add({'kind': 'cpag', 'id': '${novoId('cp')}$i', 'cartao': cc.id, 'fat': best ?? cc.faturaDe(t.data), 'valor': (t.valor.abs() * 100).round() / 100, 'data': t.data, 'ext': 'ccp|$ext', 'criado': DateTime.now().millisecondsSinceEpoch + i});
      continue;
    }
    final emS = emps.where((e) => (e.valor - t.valor.abs()).abs() <= (e.valor * .01 > 1 ? e.valor * .01 : 1) && (diasEntre(e.data, t.data) - 1).abs() <= 15 && norm('${t.nome} ${t.memo}').contains(norm(e.primeiroNome))).firstOrNull;
    if (emS != null) {
      p.ignorar('Empréstimo para ${emS.primeiroNome}', t.valor);
      continue;
    }
    final k = classificaGasto(t, dono);
    if (k.acao == 'ignorar' && k.motivo.contains('suas contas')) {
      final ym = ymDe(t.data);
      final x = propMes[ym] ?? (entrou: 0.0, saiu: 0.0, ult: t.data);
      propMes[ym] = (entrou: x.entrou, saiu: x.saiu + t.valor.abs(), ult: x.ult);
    }
    if (k.acao == 'ignorar') {
      p.ignorar(k.motivo, t.valor);
      continue;
    }
    if (existentes.contains(ext)) {
      p.jaImportados++;
      continue;
    }
    final ch = chaveOfx(t);
    Doc? rg = regras['rg_${_idRegra(ch)}'];
    if (rg == null) {
      final alvo = norm('${t.nome} ${t.memo} ${tituloOfx(limpaNome(t))}');
      rg = repo.doTipo('regra').where((r) => r['termo'] is String && (r['termo'] as String).isNotEmpty && alvo.contains(r['termo'] as String)).firstOrNull;
    }
    final cat = over[ch] ?? (rg != null ? str(rg['cat'], k.cat) : k.cat);
    if (cat == 'ignorar') p.ignorar('Marcado por você como não sendo gasto', t.valor);
    final desc = tituloOfx(limpaNome(t));
    final item = ItemImport(t: t, ext: ext, ch: ch, cat: cat, pag: k.pag, desc: desc.isEmpty ? 'Sem descrição' : desc, valor: (t.valor.abs() * 100).round() / 100);
    final mk = '${t.data}|${item.valor.toStringAsFixed(2)}';
    if ((manuais[mk] ?? 0) > 0 && cat != 'ignorar') {
      manuais[mk] = manuais[mk]! - 1;
      item.dup = true;
      final j = pgManuais.indexWhere((g) => g.data == t.data && (g.valor - item.valor).abs() < .01);
      if (j >= 0) pgManuais.removeAt(j);
    } else if (cat != 'ignorar') {
      final j = pgManuais.indexWhere((g) => (g.valor - item.valor).abs() < .01 && diasEntre(g.data, t.data).abs() <= 5);
      if (j >= 0) {
        final g = pgManuais.removeAt(j);
        final mg = '${g.data}|${g.valor.toStringAsFixed(2)}';
        if ((manuais[mg] ?? 0) > 0) manuais[mg] = manuais[mg]! - 1;
        item.dup = true;
      }
    }
    p.gastos.add(item);
  }
  // transferências entre suas contas: uma entrada por mês com o saldo líquido
  if (proprias) {
    final cid = contaIdOfx(o);
    propMes.forEach((ym, x) {
      final liq = ((x.entrou - x.saiu) * 100).round() / 100;
      final ext = 'proprias|$cid|$ym';
      final ex = existE[ext] ?? existE['proprias|$ym'];
      if (liq <= 0) {
        if (ex != null) p.apagarEntradas.add(ex.id);
        return;
      }
      if (ex != null && (ex.valor - liq).abs() < .01 && ex.d['ext'] == ext) {
        p.jaImportados++;
        return;
      }
      p.entradas.add(ItemImport(
        t: TxOfx(tipo: '', data: x.ult, valor: liq),
        ext: ext,
        ch: '__proprias',
        cat: 'proprias',
        desc: 'Transferências das suas outras contas para o ${nomeBanco(o)} (saldo do mês)',
        valor: liq,
        upd: ex?.id,
      ));
    });
  }
  // pagamentos de fatura que já existem não entram de novo
  final cpags = repo.doTipo('cpag').toList();
  final extP = {for (final c in cpags) if (c['ext'] is String) c['ext'] as String};
  p.pagFatura.removeWhere((x) =>
      extP.contains(x['ext']) || cpags.any((q) => q['cartao'] == x['cartao'] && (numD(q['valor']) - numD(x['valor'])).abs() < .01 && diasEntre(str(q['data'], hojeIso()), x['data'] as String).abs() <= 6));
  return p;
}

/// Registros para gravar a importação.
List<Doc> docsImportacao(Repo repo, Ofx o, PlanoImport p, {required String dono, required Map<String, String> over, bool pularDup = true}) {
  final impId = 'gimp_${DateTime.now().millisecondsSinceEpoch}';
  final agora = DateTime.now().millisecondsSinceEpoch;
  final cid = contaIdOfx(o), cnome = nomeBanco(o);
  final docs = <Doc>[];
  var i = 0;
  for (final x in p.gastos) {
    if (x.cat == 'ignorar' || (x.dup && pularDup)) continue;
    docs.add({'kind': 'gasto', 'id': '${novoId('g')}${i++}', 'desc': x.desc, 'valor': x.valor, 'data': x.t.data, 'cat': x.cat, 'pag': x.pag, 'fixo': false, 'criado': agora + i, 'ext': x.ext, 'imp': impId, 'conta': cid, 'orig': cnome});
  }
  for (final x in p.entradas) {
    if (x.cat == 'ignorar') continue;
    docs.add({
      'kind': 'entrada',
      'id': x.upd ?? '${novoId('e')}${i++}',
      'desc': x.desc,
      'valor': x.valor,
      'data': x.t.data,
      'cat': x.cat,
      'ext': x.ext,
      'imp': impId,
      'criado': agora + i,
      'conta': cid,
      'orig': cnome,
      if (x.rd != null) 'rd': x.rd,
    });
  }
  for (final c in p.pagFatura) {
    docs.add({...c, 'imp': impId});
  }
  over.forEach((k, cat) {
    if (k.startsWith('E|')) {
      docs.add({'kind': 'regra', 'id': 'rge_${_idRegra(k.substring(2))}', 'chave': k.substring(2), 'cat': cat, 'alvo': 'entrada'});
    } else {
      docs.add({'kind': 'regra', 'id': 'rg_${_idRegra(k)}', 'chave': k, 'cat': cat});
    }
  });
  // saldo da conta informado no extrato
  if (o.saldo != null && o.saldoData != null) {
    final ex = repo.porId(cid);
    final velho = ex != null && str(ex['data']).compareTo(o.saldoData!) > 0;
    final igual = ex != null && ex['data'] == o.saldoData && (numD(ex['saldo']) - o.saldo!).abs() < .005;
    if (!velho && !igual) {
      docs.add({...?ex, 'kind': 'conta', 'id': cid, 'nome': ex?['nome'] ?? cnome, 'saldo': o.saldo, 'data': o.saldoData, 'origem': 'extrato', 'ts': agora, if (dono.isNotEmpty) 'dono': dono});
    }
  } else if (dono.isNotEmpty) {
    final ex = repo.porId(cid);
    if (ex != null && ex['dono'] != dono) docs.add({...ex, 'dono': dono});
  }
  return docs;
}

/// Importações já feitas (para desfazer).
List<({String id, int quando, int n, String ini, String fim})> importacoesFeitas(Repo repo) {
  final m = <String, ({String id, int quando, int n, String ini, String fim})>{};
  for (final d in [...repo.doTipo('gasto'), ...repo.doTipo('entrada')]) {
    final imp = d['imp'];
    if (imp is! String || d['cartao'] != null) continue;
    final data = str(d['data']);
    final x = m[imp] ?? (id: imp, quando: int.tryParse(imp.split('_').last) ?? 0, n: 0, ini: data, fim: data);
    m[imp] = (id: x.id, quando: x.quando, n: x.n + 1, ini: data.compareTo(x.ini) < 0 ? data : x.ini, fim: data.compareTo(x.fim) > 0 ? data : x.fim);
  }
  return m.values.toList()..sort((a, b) => b.quando.compareTo(a.quando));
}
