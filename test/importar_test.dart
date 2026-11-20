import 'package:carteira/dados/avisos.dart';
import 'package:carteira/dados/importar.dart';
import 'package:carteira/dados/inter.dart';
import 'package:carteira/dados/repo.dart';
import 'package:flutter_test/flutter_test.dart';

const ofx = '''
OFXHEADER:100
<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS>
<BANKACCTFROM><BANKID>077<ACCTID>12345</BANKACCTFROM>
<BANKTRANLIST><DTSTART>20261101<DTEND>20261106
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20261102120000<TRNAMT>-202,95<FITID>1<NAME>No estabelecimento SUPERMERCADO DIA   GUARATINGUETA BRA</NAME><MEMO>COMPRA NO DEBITO</STMTTRN>
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20261103<TRNAMT>-48.90<FITID>2<NAME>IFD*IFOOD</NAME><MEMO>COMPRA NO DEBITO</STMTTRN>
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20261103<TRNAMT>-1000.00<FITID>3<MEMO>APLICACAO CDB</STMTTRN>
<STMTTRN><TRNTYPE>CREDIT<DTPOSTED>20261104<TRNAMT>150.00<FITID>4<NAME>Maria Souza</NAME><MEMO>PIX RECEBIDO - Cp :12345678-Maria Souza</STMTTRN>
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20261105<TRNAMT>-50.00<FITID>5<NAME>Joao Pedro Lima</NAME><MEMO>PIX ENVIADO - Cp :99999999-Joao Pedro Lima</STMTTRN>
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20261105<TRNAMT>-80.00<FITID>6<MEMO>PAGAMENTO VIVO FIBRA</STMTTRN>
</BANKTRANLIST>
<LEDGERBAL><BALAMT>2350,40<DTASOF>20261106</LEDGERBAL>
</STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>
''';

void main() {
  group('extrato OFX', () {
    test('lê transações, saldo e banco', () {
      final o = lerOfx(ofx);
      expect(o.tx.length, 6);
      expect(o.tx.first.valor, -202.95);
      expect(o.saldo, 2350.40);
      expect(o.saldoData, '2026-11-06');
      expect(nomeBanco(o), 'Inter');
      expect(limpaNome(o.tx.first), 'SUPERMERCADO DIA');
      expect(tituloOfx('SUPERMERCADO DIA LTDA ME'), 'Supermercado Dia Ltda ME');
    });

    test('classifica, guarda aplicação como investido e não duplica o que já foi importado', () {
      final r = Repo.memoria(const []);
      final o = lerOfx(ofx);
      final p = planoImport(r, o, dono: '');
      final cats = {for (final g in p.gastos) g.desc: g.cat};
      expect(cats['Supermercado Dia'], 'mercado');
      expect(cats['Ifood · Ifood'], 'alimentacao');
      expect(cats['Joao Pedro Lima'], 'transferencias');
      expect(cats['Pagamento Vivo Fibra'], 'internet');
      expect(p.ignorados.keys, isNot(contains('Aplicação em investimento')));
      expect(p.invest.single.cat, 'aplic');
      expect(p.invest.single.valor, 1000);
      expect(p.entradas.single.cat, 'pix');
      // grava e importa de novo: nada novo
      final docs = docsImportacao(r, o, p, dono: '', over: const {});
      r.salvarVarios(docs);
      final p2 = planoImport(r, o, dono: '');
      expect(p2.gastos, isEmpty);
      expect(p2.entradas, isEmpty);
      expect(p2.invest, isEmpty);
      expect(p2.jaImportados, 6);
      expect(r.investidos.single.liquido, 1000);
      expect(r.porId(contaIdOfx(o))!['saldo'], 2350.40);
    });

    test('gasto já lançado à mão no mesmo dia e valor é marcado como duplicado', () {
      final r = Repo.memoria([
        {'kind': 'gasto', 'id': 'm1', 'desc': 'Mercado', 'valor': 202.95, 'data': '2026-11-02', 'cat': 'mercado'},
      ]);
      final p = planoImport(r, lerOfx(ofx), dono: '');
      expect(p.gastos.firstWhere((g) => g.desc == 'Supermercado Dia').dup, isTrue);
    });

    test('Pix para as próprias contas vira investido quando você escolhe', () {
      final r = Repo.memoria(const []);
      final o = lerOfx(ofx);
      final sem = planoImport(r, o, dono: 'João Pedro Lima');
      expect(sem.propSaidas, 1);
      expect(sem.invest.length, 1); // só a aplicação
      final com = planoImport(r, o, dono: 'João Pedro Lima', propInvest: true);
      expect(com.invest.length, 2);
      expect(com.invest.map((x) => x.valor), containsAll([1000.0, 50.0]));
    });

    test('Pix para o próprio titular não vira gasto', () {
      final p = planoImport(Repo.memoria(const []), lerOfx(ofx), dono: 'João Pedro Lima');
      expect(p.gastos.where((g) => g.desc == 'Joao Pedro Lima'), isEmpty);
      expect(nomeIgual('Joao P. Lima', 'João Pedro Lima'), isFalse);
      expect(nomeIgual('Joao Pedro Lima', 'JOÃO PEDRO DE LIMA'), isTrue);
    });
  });

  group('transferências entre suas contas', () {
    const ofxProp = '''
OFXHEADER:100
<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS>
<BANKACCTFROM><BANKID>077<ACCTID>12345</BANKACCTFROM>
<BANKTRANLIST><DTSTART>20261101<DTEND>20261120
<STMTTRN><TRNTYPE>CREDIT<DTPOSTED>20261118<TRNAMT>3487.20<FITID>1<NAME>Julio Cesar De Franca Motta</NAME><MEMO>PIX RECEBIDO - Cp :1-Julio Cesar De Franca Motta</STMTTRN>
<STMTTRN><TRNTYPE>CREDIT<DTPOSTED>20261110<TRNAMT>500.00<FITID>2<NAME>Julio Cesar De Franca Motta</NAME><MEMO>PIX RECEBIDO - Cp :1-Julio Cesar De Franca Motta</STMTTRN>
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20261112<TRNAMT>-132.12<FITID>3<NAME>Julio Cesar De Franca Motta</NAME><MEMO>PIX ENVIADO - Cp :2-Julio Cesar De Franca Motta</STMTTRN>
</BANKTRANLIST>
<LEDGERBAL><BALAMT>100<DTASOF>20261120</LEDGERBAL>
</STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>
''';
    const dono = 'Julio Cesar De Franca Motta';

    test('cada uma entra separada; as que chegam ficam para conferir', () {
      final r = Repo.memoria(const []);
      final o = lerOfx(ofxProp);
      final p = planoImport(r, o, dono: dono);
      final ps = p.entradas.where((x) => x.cat == 'proprias').toList();
      expect(ps.map((x) => x.valor), containsAll([3487.20, 500.0, -132.12]));
      r.salvarVarios(docsImportacao(r, o, p, dono: dono, over: const {}));
      expect(r.entradas.where((e) => e.d['pend'] == true).length, 2);
      final p2 = planoImport(r, o, dono: dono);
      expect(p2.entradas, isEmpty);
      expect(p2.jaImportados, 3);
    });

    test('a soma antiga do mês sai e uma divisão feita nela passa para a transferência certa', () {
      final r = Repo.memoria([
        {'kind': 'entrada', 'id': 'soma', 'desc': 'Transferências das suas outras contas para o Inter (saldo do mês)', 'valor': 367.88, 'data': '2026-11-18', 'cat': 'proprias', 'ext': 'proprias|c1|2026-11', 'div': 'dv1', 'divT': 3855.08, 'divO': {'desc': 'x', 'cat': 'salario'}},
        {'kind': 'entrada', 'id': 'va', 'desc': 'Vale alimentação', 'valor': 880, 'data': '2026-11-18', 'cat': 'beneficios', 'rd': 'rd_va', 'ext': 'proprias|c1|2026-11#va', 'div': 'dv1', 'divT': 3855.08},
        {'kind': 'entrada', 'id': 'd13', 'desc': '13º salário', 'valor': 2607.20, 'data': '2026-11-18', 'cat': 'salario', 'ext': 'proprias|c1|2026-11#d13', 'div': 'dv1', 'divT': 3855.08},
      ]);
      final o = lerOfx(ofxProp);
      final p = planoImport(r, o, dono: dono);
      expect(p.apagarEntradas, ['soma']);
      expect(p.entradas.map((x) => x.valor), isNot(contains(3487.20)));
      expect(p.entradas.where((x) => x.cat == 'proprias').map((x) => x.valor), containsAll([500.0, -132.12]));
      expect(p.salvarDocs.length, 2);
      expect(p.salvarDocs.every((d) => d['divT'] == 3487.20 && (d['ext'] as String).startsWith('2026-11-18|3487.20|')), isTrue);
      expect(p.salvarDocs.where((d) => d['divO'] != null).length, 1);
    });
  });

  group('PDF do Inter', () {
    List<ItemTexto> linha(double y, List<(double, String)> partes) => [for (final (x, s) in partes) ItemTexto(s, x, y)];
    test('lê aplicações e resgates e calcula o saldo por tipo', () {
      final pg = <ItemTexto>[
        ...linha(800, [(40, 'Extrato'), (90, 'de'), (110, 'movimentações'), (190, 'de'), (205, '01/10/2026'), (260, 'a'), (270, '31/10/2026')]),
        ...linha(760, [(40, '5'), (50, 'de'), (62, 'outubro'), (100, 'de'), (115, '2026')]),
        ...linha(740, [(40, 'Produto'), (120, 'Ativo'), (220, 'Código'), (300, 'Quantidade'), (370, 'Valor'), (430, 'IOF'), (470, 'IR'), (510, 'Valor'), (540, 'líquido')]),
        ...linha(720, [(40, 'Renda'), (70, 'Fixa'), (120, 'CDB'), (145, 'BANCO'), (180, 'INTER'), (220, 'CDB123456'), (300, '1'), (370, 'R\$'), (385, '1.000,00'), (430, '0,00'), (470, '0,00'), (510, 'R\$'), (525, '1.000,00')]),
        ...linha(690, [(40, '20'), (55, 'de'), (68, 'outubro'), (105, 'de'), (120, '2026')]),
        ...linha(670, [(40, 'Renda'), (70, 'Fixa'), (120, 'CDB'), (145, 'BANCO'), (180, 'INTER'), (220, 'CDB123456'), (300, '-1'), (370, 'R\$'), (385, '1.010,00'), (430, '0,00'), (470, '0,00'), (510, 'R\$'), (525, '1.010,00')]),
        ...linha(650, [(40, 'Tesouro'), (85, 'Direto'), (120, 'Tesouro'), (160, 'Selic'), (190, '2029'), (220, 'TSELIC29XY'), (300, '0,5'), (370, 'R\$'), (385, '8.000,00'), (430, '0,00'), (470, '0,00'), (510, 'R\$'), (525, '8.000,00')]),
      ];
      final ex = lerExtratoInter([pg]);
      expect(ex.inicio, '2026-10-01');
      expect(ex.fim, '2026-10-31');
      expect(ex.rows.length, 3);
      expect(ex.rows[1].tipo, 'resgate');
      final gs = interPorTipo(ex.rows);
      final cdb = gs.firstWhere((g) => g.tipo.key == 'cdbinter');
      expect(cdb.aplicado, 1000);
      expect(cdb.ganho, closeTo(10, 1e-9));
      expect(cdb.saldoFinal, 0);
      final tes = gs.firstWhere((g) => g.tipo.nome == 'Tesouro Selic 2029');
      expect(tes.saldoFinal, 8000);
      final r = Repo.memoria(const []);
      final docs = docsImportInter(r, ex, gs, modo: 'separado');
      expect(docs.where((d) => d['kind'] == 'ativo').length, 3); // Inter + 2 tipos
      expect(docs.where((d) => d['kind'] == 'lanc').length, 3);
    });
  });

  group('avisos', () {
    test('limite estourado e gastos fixos pendentes', () {
      final r = Repo.memoria([
        {'kind': 'orc', 'id': 'orc_mercado', 'cat': 'mercado', 'limite': 100},
        {'kind': 'gasto', 'id': 'g1', 'desc': 'Mercado', 'valor': 150, 'data': '2026-11-03', 'cat': 'mercado'},
        {'kind': 'gasto', 'id': 'g2', 'desc': 'Aluguel', 'valor': 1300, 'data': '2026-10-05', 'cat': 'moradia', 'fixo': true},
      ]);
      final l = avisosDoMes(r, hoje: '2026-11-07');
      expect(l.first.fixos, isTrue);
      expect(l.any((a) => a.k == 'lim+mercado2026-11' && a.sev == 3), isTrue);
      final docs = docsLancarFixos(r, '2026-11');
      expect(docs.single['data'], '2026-11-05');
      expect(docs.single['desc'], 'Aluguel');
    });
  });
}
