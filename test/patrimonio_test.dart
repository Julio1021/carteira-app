import 'package:carteira/dados/patrimonio.dart';
import 'package:carteira/dados/repo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('carteira', () {
    test('primeiro lançamento é o valor aplicado; depois separa aporte de rendimento', () {
      final r = Repo.memoria([
        {'kind': 'ativo', 'id': 'a', 'nome': 'CDB', 'classe': 'Renda Fixa', 'cor': 0, 'ordem': 1},
        {'kind': 'lanc', 'id': 'l_a_2026-10-01', 'ativo': 'a', 'data': '2026-10-01', 'saldo': 1000, 'aporte': 0},
        {'kind': 'lanc', 'id': 'l_a_2026-10-15', 'ativo': 'a', 'data': '2026-10-15', 'saldo': 1010, 'aporte': 0},
        {'kind': 'lanc', 'id': 'l_a_2026-11-01', 'ativo': 'a', 'data': '2026-11-01', 'saldo': 1520, 'aporte': 500},
      ]);
      final c = calcularCarteira(r);
      expect(c.total, 1520);
      expect(c.investido, 1500);
      expect(c.rendeu, closeTo(20, 1e-9));
      expect(c.dias[1].ganho, closeTo(10, 1e-9));
      expect(c.dias[1].r, closeTo(.01, 1e-9));
      expect(c.ganhoUltimo, closeTo(10, 1e-9));
      expect(c.meses.map((m) => m.ym), ['2026-10', '2026-11']);
      expect(c.meses.first.aportes, 1000); // o 1º mês traz o saldo inicial
      expect(c.meses.last.ganho, closeTo(10, 1e-9));
      expect(c.posicoes.single.rent, closeTo(20 / 1500, 1e-9));
    });

    test('ativos agrupados somam no grupo e o saldo do dia é distribuído pela proporção', () {
      final r = Repo.memoria([
        {'kind': 'ativo', 'id': 'inter', 'nome': 'Inter', 'classe': 'Renda Fixa', 'ordem': 1},
        {'kind': 'ativo', 'id': 'f1', 'nome': 'CDB 1', 'pai': 'inter', 'ordem': 1},
        {'kind': 'ativo', 'id': 'f2', 'nome': 'CDB 2', 'pai': 'inter', 'ordem': 2},
        {'kind': 'lanc', 'id': 'l_f1_2026-10-01', 'ativo': 'f1', 'data': '2026-10-01', 'saldo': 750, 'aporte': 0},
        {'kind': 'lanc', 'id': 'l_f2_2026-10-01', 'ativo': 'f2', 'data': '2026-10-01', 'saldo': 250, 'aporte': 0},
      ]);
      final c = calcularCarteira(r);
      expect(c.posicoes.single.valor, 1000);
      expect(c.posicoes.single.filhos!.length, 2);
      final g = estadoGrupo(r, c, 'inter', '2026-11-01');
      expect(g.totalAnterior, 1000);
      final docs = docsGrupo(g, '2026-11-01', 1100.01, 0);
      expect(docs.map((d) => d['saldo']), [825.01, 275.0]);
    });

    test('ativo oculto fica fora', () {
      final r = Repo.memoria([
        {'kind': 'ativo', 'id': 'a', 'nome': 'X', 'oculto': true},
        {'kind': 'lanc', 'id': 'l1', 'ativo': 'a', 'data': '2026-10-01', 'saldo': 500},
      ]);
      expect(calcularCarteira(r).vazia, isTrue);
    });
  });

  group('projeção', () {
    test('juros compostos mensais a partir da taxa anual', () {
      final p = projetar(1000, 0, .12, 12);
      expect(p.last.saldo, closeTo(1120, .01));
      final q = projetar(0, 100, 0, 10);
      expect(q.last.saldo, 1000);
      expect(q.last.investido, 1000);
    });
    test('tempo até a meta', () {
      expect(mesesAteMeta(0, 100, 0, 1000), 10);
      expect(tempoTexto(14), '1 ano e 2 meses');
      expect(pct(.1234), '12,34%');
      expect(pct(-.05, casas: 1), '−5,0%');
    });
  });

  group('movimentações', () {
    test('várias no mesmo dia: guarda cada uma e o aporte é a soma', () {
      final d = docLanc('a', '2026-11-23', 2000, 0, movs: const [Mov(false, 1000, nome: 'Salário'), Mov(true, 300, nome: 'IPVA')]);
      expect(d['aporte'], 700);
      final l = Lancamento(d);
      expect(l.movs.length, 2);
      expect(l.movs.last.tirou, isTrue);
      expect(l.movs.last.nome, 'IPVA');
    });

    test('histórico: valor inicial, movimentações e o líquido dos antigos', () {
      final ls = [
        Lancamento({'id': '1', 'ativo': 'a', 'data': '2026-10-01', 'saldo': 1000, 'aporte': 0}),
        Lancamento({'id': '2', 'ativo': 'a', 'data': '2026-10-15', 'saldo': 1460, 'aporte': 450}),
        Lancamento(docLanc('a', '2026-11-23', 2200, 0, movs: const [Mov(false, 1000), Mov(true, 300, nome: 'IPVA')])),
      ];
      final h = historicoMovs(ls);
      expect(h.length, 4);
      expect(h.last.inicial, isTrue);
      expect(h.last.m.valor, 1000);
      expect(h[2].m.liquido, isTrue);
      final colocou = h.where((x) => !x.m.tirou).fold<double>(0, (t, x) => t + x.m.valor);
      final tirou = h.where((x) => x.m.tirou).fold<double>(0, (t, x) => t + x.m.valor);
      expect(colocou - tirou, 1000 + 450 + 700);
    });

    test('grupo: a lista fica num filho e o aporte é repartido', () {
      final r = Repo.memoria([
        {'kind': 'ativo', 'id': 'g', 'nome': 'Inter'},
        {'kind': 'ativo', 'id': 'f1', 'nome': 'CDB 1', 'pai': 'g'},
        {'kind': 'ativo', 'id': 'f2', 'nome': 'CDB 2', 'pai': 'g'},
        {'kind': 'lanc', 'id': 'l_f1_2026-10-01', 'ativo': 'f1', 'data': '2026-10-01', 'saldo': 3000, 'aporte': 0},
        {'kind': 'lanc', 'id': 'l_f2_2026-10-01', 'ativo': 'f2', 'data': '2026-10-01', 'saldo': 1000, 'aporte': 0},
      ]);
      final c = calcularCarteira(r);
      final docs = docsGrupo(estadoGrupo(r, c, 'g', '2026-11-01'), '2026-11-01', 5000, 0, movs: const [Mov(false, 1200), Mov(true, 200)]);
      expect(docs.fold<double>(0, (t, d) => t + (d['aporte'] as num)), 1000);
      expect(docs.where((d) => d['movsG'] is List).length, 1);
      final h = historicoMovs([for (final d in docs) Lancamento(d), Lancamento(r.porId('l_f1_2026-10-01')!), Lancamento(r.porId('l_f2_2026-10-01')!)], grupo: true);
      expect(h.where((x) => !x.inicial).map((x) => x.m.comSinal), [1200, -200]);
    });
  });
}
