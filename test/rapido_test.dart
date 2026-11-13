import 'package:carteira/dados/modelos.dart';
import 'package:carteira/dados/rapido.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hist = [
    Gasto({'id': 'a', 'desc': 'Supermercado Dia', 'valor': 10.0, 'data': '2026-01-01', 'cat': 'mercado', 'pag': 'Débito'}),
    Gasto({'id': 'b', 'desc': 'Supermercado Dia', 'valor': 10.0, 'data': '2026-01-02', 'cat': 'mercado', 'pag': 'Débito'}),
    Gasto({'id': 'c', 'desc': 'Barbearia do Zé', 'valor': 40.0, 'data': '2026-01-03', 'cat': 'cuidados', 'pag': 'Pix'}),
  ];

  test('valor, forma de pagamento e data', () {
    final r = lerRapido('uber 23,50 crédito ontem', hist, hoje: '2026-03-10')!;
    expect(r.valor, 23.5);
    expect(r.pag, 'Crédito');
    expect(r.data, '2026-03-09');
    expect(r.cat, 'transporte');
    expect(r.desc, 'Uber');
    expect(r.entrada, false);
  });

  test('aprende a categoria e o nome pelo histórico', () {
    final r = lerRapido('superm 1.234,56', hist, hoje: '2026-03-10')!;
    expect(r.valor, 1234.56);
    expect(r.cat, 'mercado');
    expect(r.pag, 'Débito');
    expect(r.desc, 'Supermercado Dia');
    expect(r.doHistorico, true);
  });

  test('entrada com +', () {
    final r = lerRapido('+ salário 4800', hist, hoje: '2026-03-10')!;
    expect(r.entrada, true);
    expect(r.cat, 'salario');
    expect(r.valor, 4800);
  });

  test('sem valor ainda não está pronto', () {
    final r = lerRapido('padaria', hist, hoje: '2026-03-10')!;
    expect(r.pronto, false);
    expect(r.cat, 'alimentacao');
    expect(lerRapido('   ', hist), isNull);
  });
}
