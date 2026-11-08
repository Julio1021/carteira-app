import 'package:carteira/dados/analise.dart';
import 'package:carteira/dados/invest_pat.dart';
import 'package:carteira/dados/patrimonio.dart';
import 'package:carteira/dados/repo.dart';
import 'package:carteira/dados/resumo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Repo base() => Repo.memoria([
        {'kind': 'ativo', 'id': 'a1', 'nome': 'CDB Inter'},
        {'kind': 'lanc', 'id': 'l_a1_2026-10-01', 'ativo': 'a1', 'data': '2026-10-01', 'saldo': 1000, 'aporte': 0},
      ]);

  test('investido com ativo vira aporte no Patrimônio e some ao apagar', () async {
    final r = base();
    final inv = <String, dynamic>{'kind': 'invest', 'id': 'i1', 'desc': 'CDB', 'valor': 500, 'data': '2026-10-10', 'mov': 'aplic', 'ativo': 'a1'};
    final m = Mudancas(r);
    ligarAoPatrimonio(m, inv, 'a1');
    m.poe(inv);
    await m.gravar();
    final l = r.porId('l_a1_2026-10-10')!;
    expect(l['saldo'], 1500);
    expect(l['aporte'], 500);
    expect(calcularCarteira(r).investido, 1500);
    // apagar desfaz
    final m2 = Mudancas(r);
    cascataApagar(m2, Map<String, dynamic>.from(r.porId('i1')!));
    await m2.gravar();
    expect(r.porId('l_a1_2026-10-10'), isNull);
    expect(r.porId('i1'), isNull);
  });

  test('não duplica um aporte já lançado no Patrimônio', () async {
    final r = base();
    await r.salvar({'kind': 'lanc', 'id': 'l_a1_2026-10-11', 'ativo': 'a1', 'data': '2026-10-11', 'saldo': 1500, 'aporte': 500});
    final inv = <String, dynamic>{'kind': 'invest', 'id': 'i1', 'valor': 500, 'data': '2026-10-10', 'mov': 'aplic'};
    final m = Mudancas(r);
    final msg = ligarAoPatrimonio(m, inv, 'a1');
    m.poe(inv);
    await m.gravar();
    expect(msg, contains('Vinculado'));
    expect(r.porId('l_a1_2026-10-10'), isNull);
    expect(r.porId('l_a1_2026-10-11')!['saldo'], 1500);
    expect(investidosSemAtivo(r), isEmpty);
  });

  test('conferência aponta diferença entre o que saiu e os aportes', () async {
    final r = base();
    await r.salvar({'kind': 'invest', 'id': 'i9', 'valor': 300, 'data': '2026-10-15', 'mov': 'aplic'});
    final c = calcularCarteira(r);
    final cf = conferenciaMeses(r, c, hoje: '2026-10-20');
    expect(cf.single.saiuParaInvestir, 300);
    expect(cf.single.aportes, 1000); // 1º lançamento conta como valor aplicado
    expect(cf.single.bate, isFalse);
  });

  test('apagar o gasto que pagou uma conta reabre a conta', () async {
    final r = Repo.memoria([
      {'kind': 'gasto', 'id': 'g1', 'valor': 100, 'data': '2026-10-05', 'cat': 'moradia'},
      {'kind': 'pagto', 'id': 'p1', 'conta': 'b1', 'mes': '2026-10', 'pago': true, 'gasto': 'g1', 'criouGasto': true},
      {'kind': 'gasto', 'id': 'g2', 'valor': 50, 'data': '2026-10-06', 'cat': 'moradia'},
      {'kind': 'pagto', 'id': 'p2', 'conta': 'b2', 'mes': '2026-10', 'pago': true, 'gasto': 'g2'},
    ]);
    final m = Mudancas(r);
    cascataApagar(m, Map<String, dynamic>.from(r.porId('g1')!));
    cascataApagar(m, Map<String, dynamic>.from(r.porId('g2')!));
    await m.gravar();
    expect(r.porId('p1'), isNull);
    expect(r.porId('p2')!['pago'], false);
  });

  test('pagamento de fatura e lançamentos futuros no saldo em conta', () {
    final r = Repo.memoria([
      {'kind': 'conta', 'id': 'ct', 'nome': 'Inter', 'saldo': 1000, 'data': '2020-01-01'},
      {'kind': 'cpag', 'id': 'cp1', 'cartao': 'cc', 'fat': '2020-01', 'valor': 200, 'data': '2020-01-10'},
      {'kind': 'gasto', 'id': 'gf', 'valor': 300, 'data': '2999-01-01', 'cat': 'outros', 'pag': 'Pix'},
    ]);
    expect(saldoEmConta(r), 800);
  });

  test('destaques do mês trazem o maior gasto', () {
    final r = Repo.memoria([
      {'kind': 'gasto', 'id': 'g1', 'desc': 'Celular', 'valor': 900, 'data': '2026-10-05', 'cat': 'compras'},
      {'kind': 'gasto', 'id': 'g2', 'desc': 'Pão', 'valor': 9, 'data': '2026-10-06', 'cat': 'mercado'},
    ]);
    final ds = destaquesDoMes(r, '2026-10', hoje: '2026-10-20');
    expect(ds.first.forte, 'Celular');
    expect(ds.any((d) => d.tipo == 'semgasto'), isTrue);
  });
}
