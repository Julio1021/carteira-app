import 'package:carteira/dados/analise_inv.dart';
import 'package:carteira/dados/indices.dart';
import 'package:carteira/dados/patrimonio.dart';
import 'package:carteira/dados/repo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // um ativo que rende exatamente 1% ao mês, sem aportes
  Repo carteira() {
    final docs = <Map<String, dynamic>>[
      {'kind': 'ativo', 'id': 'a1', 'nome': 'CDB Inter'},
      {'kind': 'ativo', 'id': 'a2', 'nome': 'Caixinha Nubank'},
    ];
    var s1 = 1000.0, s2 = 500.0;
    for (var m = 1; m <= 6; m++) {
      final d = '2026-0$m-28';
      docs.add({'kind': 'lanc', 'id': 'l1$m', 'ativo': 'a1', 'data': d, 'saldo': s1, 'aporte': 0});
      docs.add({'kind': 'lanc', 'id': 'l2$m', 'ativo': 'a2', 'data': d, 'saldo': s2, 'aporte': 0});
      s1 *= 1.01;
      s2 *= 1.005;
    }
    return Repo.memoria(docs);
  }

  final idx = Indices({for (var m = 1; m <= 6; m++) '2026-0$m': 1.0}, {for (var m = 1; m <= 6; m++) '2026-0$m': 0.5}, {for (var m = 1; m <= 6; m++) '2026-0$m': 0.6}, 1);

  test('compara a carteira com CDI e inflação', () {
    final c = calcularCarteira(carteira());
    final meses = mesesDoPeriodo(c, 'tudo', hoje: '2026-07-10');
    final cmp = compararComIndices(c, idx, meses)!;
    expect(cmp.cdi, greaterThan(0));
    expect(cmp.pctCdi, isNotNull);
    expect(cmp.curvaCart.first, 100);
    expect(cmp.curvaCart.length, cmp.meses.length + 1);
    expect(cmp.real, isNotNull);
  });

  test('ranking por ativo põe o que rende mais em primeiro', () {
    final c = calcularCarteira(carteira());
    final l = desempenhoPorAtivo(c, idx, mesesDoPeriodo(c, 'tudo', hoje: '2026-07-10'));
    expect(l.first.a.nome, 'CDB Inter');
    expect(l.first.rent, closeTo(1.01 * 1.01 * 1.01 * 1.01 * 1.01 - 1, 1e-6));
    expect(l.first.pctCdi, closeTo(1, 0.02));
  });

  test('diversificação adivinha instituição e tipo pelo nome', () {
    final c = calcularCarteira(carteira());
    final (inst, cls) = diversificacao(c);
    expect(inst.map((f) => f.nome), containsAll(['Banco Inter', 'Nubank']));
    expect(cls.single.nome, 'Renda Fixa');
  });
}
