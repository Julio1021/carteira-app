import 'package:carteira/dados/planejar.dart';
import 'package:carteira/dados/repo.dart';
import 'package:flutter_test/flutter_test.dart';

// "hoje" fixo para os testes: 07/11/2026 (sábado)
const hoje = '2026-11-07';
const criadoOut = 1790000000000; // ~ out/2026

void main() {
  group('contas a pagar', () {
    test('situação: atrasada, vence hoje, próximos 7 dias e futura', () {
      final r = Repo.memoria([
        {'kind': 'pagar', 'id': 'a', 'nome': 'Aluguel', 'valor': 1300, 'rep': 'mensal', 'dia': 5, 'ini': '2026-08', 'criado': 1754000000000},
        {'kind': 'pagar', 'id': 'b', 'nome': 'Luz', 'valor': 180, 'rep': 'mensal', 'dia': 7, 'ini': '2026-11', 'criado': criadoOut},
        {'kind': 'pagar', 'id': 'c', 'nome': 'Internet', 'valor': 120, 'rep': 'mensal', 'dia': 12, 'ini': '2026-11', 'criado': criadoOut},
        {'kind': 'pagar', 'id': 'd', 'nome': 'IPVA', 'valor': 900, 'rep': 'unica', 'data': '2026-11-28', 'dia': 28, 'ini': '2026-11', 'criado': criadoOut},
      ]);
      final m = mesContas(r, '2026-11', hoje: hoje);
      final st = {for (final i in m.doMes) i.b.id: i.st};
      expect(st, {'a': 'atrasada', 'b': 'hoje', 'c': 'breve', 'd': 'futura'});
      // aluguel de agosto, setembro e outubro também estão atrasados
      expect(m.atrasoAnt.where((i) => i.b.id == 'a').length, 3);
      expect(m.falta, 1300 * 4 + 180 + 120 + 900);
      expect(m.doMes.firstWhere((i) => i.b.id == 'a').statusTexto, 'Atrasada há 2 dias');
    });

    test('pagamento manual marca como paga', () {
      final r = Repo.memoria([
        {'kind': 'pagar', 'id': 'b', 'nome': 'Luz', 'valor': 180, 'rep': 'mensal', 'dia': 7, 'ini': '2026-11', 'criado': criadoOut},
        {'kind': 'pagto', 'id': 'pp_b_2026-11', 'conta': 'b', 'mes': '2026-11', 'pago': true, 'valor': 175.5, 'data': '2026-11-06'},
      ]);
      final i = mesContas(r, '2026-11', hoje: hoje).doMes.single;
      expect(i.st, 'pago');
      expect(i.valor, 175.5);
      expect(i.statusTexto, 'Paga em 06/11');
    });

    test('conta com palavra do extrato é reconhecida nos gastos', () {
      final r = Repo.memoria([
        {'kind': 'pagar', 'id': 'c', 'nome': 'Internet', 'valor': 120, 'rep': 'mensal', 'dia': 12, 'ini': '2026-11', 'chave': 'vivo', 'criado': criadoOut},
        {'kind': 'gasto', 'id': 'g1', 'desc': 'Pagamento VIVO Fibra', 'valor': 119.9, 'data': '2026-11-03', 'cat': 'internet'},
      ]);
      final i = mesContas(r, '2026-11', hoje: hoje).doMes.single;
      expect(i.st, 'pago');
      expect(i.fonte, 'extrato');
    });

    test('parcelas e "a cada 3 meses"', () {
      final r = Repo.memoria([
        {'kind': 'pagar', 'id': 'p', 'nome': 'Geladeira', 'valor': 300, 'rep': 'parcelas', 'parc': 3, 'dia': 10, 'ini': '2026-10', 'criado': criadoOut},
        {'kind': 'pagar', 'id': 't', 'nome': 'Seguro', 'valor': 600, 'rep': 'mensal', 'cada': 3, 'dia': 15, 'ini': '2026-09', 'criado': criadoOut},
      ]);
      final nov = mesContas(r, '2026-11', hoje: hoje).doMes;
      expect(nov.map((i) => i.b.id), ['p']);
      expect(nov.single.n, 2);
      expect(mesContas(r, '2027-01', hoje: hoje).doMes.isEmpty, isTrue);
      expect(mesContas(r, '2026-12', hoje: hoje).doMes.map((i) => i.b.id).toSet(), {'p', 't'});
    });

    test('pagar e lançar nos gastos cria o gasto ligado', () {
      final r = Repo.memoria([
        {'kind': 'pagar', 'id': 'b', 'nome': 'Luz', 'valor': 180, 'rep': 'mensal', 'dia': 7, 'ini': '2026-11', 'cat': 'contas', 'pag': 'Boleto', 'criado': criadoOut},
      ]);
      final i = mesContas(r, '2026-11', hoje: hoje).doMes.single;
      final docs = docsPagamento(i, 180, '2026-11-07', lancarGasto: true);
      expect(docs.length, 2);
      expect(docs.first['kind'], 'gasto');
      expect(docs.last['gasto'], docs.first['id']);
      expect(docs.last['criouGasto'], true);
    });
  });

  group('recebimentos', () {
    test('salário reconhecido perto do último dia útil', () {
      final r = Repo.memoria([
        {'kind': 'renda', 'id': 'rd_salario', 'nome': 'Salário', 'valor': 4800, 'regra': 'util'},
        {'kind': 'entrada', 'id': 'e1', 'desc': 'Pix recebido', 'valor': 4800, 'data': '2026-10-30', 'cat': 'pix'},
      ]);
      final s = statusRenda(r, r.rendas.single, '2026-10', hoje: hoje);
      expect(s.data, '2026-10-30');
      expect(s.rec?.id, 'e1');
      final n = statusRenda(r, r.rendas.single, '2026-11', hoje: hoje);
      expect(n.data, '2026-11-30');
      expect(n.rec, isNull);
      expect(n.dias, 23);
    });
  });

  group('cartões', () {
    final cartao = {'kind': 'cartao', 'id': 'cc1', 'nome': 'Nubank', 'limite': 3000, 'fecha': 3, 'vence': 10, 'criado': 1};
    test('compra cai na fatura certa e parcelas vão para os meses seguintes', () {
      final c = CartaoCredito(cartao);
      expect(c.faturaDe('2026-11-02'), '2026-11'); // antes do fechamento (03/11)
      expect(c.faturaDe('2026-11-03'), '2026-12'); // no dia do fechamento já vai para a próxima
      final docs = docsCompra(c, desc: 'TV', valor: 1000, parcelas: 3, data: '2026-11-05', cat: 'compras');
      expect(docs.map((d) => d['fat']), ['2026-12', '2027-01', '2027-02']);
      expect(docs.map((d) => d['valor']), [333.34, 333.33, 333.33]);
      expect(docs.first['desc'], 'TV (1/3)');
    });

    test('fatura soma compras, desconta pagamentos e prevê parcelas', () {
      final r = Repo.memoria([
        cartao,
        {'kind': 'gasto', 'id': 'g1', 'desc': 'Mercado', 'valor': 200, 'data': '2026-10-20', 'cartao': 'cc1', 'fat': '2026-11', 'pag': 'Crédito'},
        {'kind': 'gasto', 'id': 'g2', 'desc': 'TV (1/3)', 'valor': 300, 'data': '2026-10-21', 'cartao': 'cc1', 'fat': '2026-11', 'parc': {'i': 1, 'n': 3, 'g': 'x'}},
        {'kind': 'cpag', 'id': 'p1', 'cartao': 'cc1', 'fat': '2026-11', 'valor': 100, 'data': '2026-11-05'},
      ]);
      final res = resumoCartao(r, CartaoCredito(cartao), hoje: hoje);
      final nov = res.faturas.firstWhere((f) => f.ym == '2026-11');
      expect(nov.total, 500);
      expect(nov.falta, 400);
      expect(nov.st, 'fechada');
      final jan = res.faturas.firstWhere((f) => f.ym == '2027-01');
      expect(jan.itens.single.prevista, isTrue);
      expect(jan.itens.single.parcI, 3);
      expect(res.atual, '2026-12');
    });
  });

  group('empréstimos', () {
    test('pagamentos cobrem as parcelas em ordem', () {
      final r = Repo.memoria([
        {'kind': 'emprestimo', 'id': 'em1', 'pessoa': 'Maria Silva', 'valor': 1000, 'data': '2026-08-01', 'ini': '2026-09', 'parc': 4, 'dia': 10},
        {'kind': 'receb', 'id': 'rc1', 'emp': 'em1', 'valor': 250, 'data': '2026-09-10'},
        {'kind': 'receb', 'id': 'rc2', 'emp': 'em1', 'valor': 100, 'data': '2026-10-10'},
      ]);
      final d = dadosEmprestimo(r, emprestimos(r).single, hoje: hoje);
      expect(d.recebido, 350);
      expect(d.falta, 650);
      expect(d.agenda.map((a) => a.st), ['pago', 'parcial', 'mes', 'futura']);
      expect(d.prox!.k, 2);
      expect(emprestimos(r).single.primeiroNome, 'Maria');
    });
  });

  test('norm tira acentos', () {
    expect(norm('Pagamento Conta Água'), 'PAGAMENTO CONTA AGUA');
  });
}
