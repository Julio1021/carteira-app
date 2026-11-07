import 'dart:convert';

import 'package:carteira/dados/repo.dart';
import 'package:carteira/dados/resumo.dart';
import 'package:carteira/util/fmt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatação', () {
    test('brl', () {
      expect(brl(1234.5), 'R\$ 1.234,50');
      expect(brl(0), 'R\$ 0,00');
      expect(brl(-12.3), '− R\$ 12,30');
      expect(brl(1000000), 'R\$ 1.000.000,00');
      expect(brl(5, sinal: true), '+ R\$ 5,00');
    });
    test('lerValor', () {
      expect(lerValor('1.234,56'), 1234.56);
      expect(lerValor('12,5'), 12.5);
      expect(lerValor('12.50'), 12.5);
      expect(lerValor('1.000'), 1000);
      expect(lerValor('R\$ 99'), 99);
      expect(lerValor(''), null);
    });
    test('datas', () {
      expect(ymAdd('2026-01', -1), '2025-12');
      expect(ymAdd('2026-12', 1), '2027-01');
      expect(diasNoMes('2028-02'), 29);
      expect(addDias('2026-02-28', 1), '2026-03-01');
      expect(feriado('2026-11-20'), isTrue);
      expect(feriado('2026-04-03'), isTrue); // Sexta-feira Santa
      expect(ultimoDiaUtil('2026-10'), '2026-10-30');
    });
  });

  group('repositório', () {
    test('importa backup do site sem perder campos desconhecidos', () async {
      final r = Repo.memoria(const []);
      final backup = jsonEncode({
        'app': 'diario-da-carteira',
        'versao': 1,
        'docs': [
          {'kind': 'gasto', 'id': 'g1', 'desc': 'Mercado', 'valor': 10, 'data': '2026-11-02', 'cat': 'mercado', 'pag': 'Pix'},
          {'kind': 'ativo', 'id': 'a1', 'nome': 'CDB', 'classe': 'Renda Fixa', 'extra': {'x': 1}},
          {'sem': 'id'},
        ],
      });
      final res = await r.importar(backup);
      expect(res.novos, 2);
      expect(res.ignorados, 1);
      final volta = jsonDecode(r.exportar()) as Map;
      final ativo = (volta['docs'] as List).firstWhere((d) => d['id'] == 'a1') as Map;
      expect(ativo['extra'], {'x': 1});
      expect(volta['app'], 'diario-da-carteira');
    });

    test('na importação vale a versão mais nova', () async {
      final r = Repo.memoria([
        {'kind': 'gasto', 'id': 'g1', 'desc': 'Novo', 'valor': 20, 'data': '2026-11-02', '_u': 200},
      ]);
      await r.importar(jsonEncode({
        'docs': [
          {'kind': 'gasto', 'id': 'g1', 'desc': 'Velho', 'valor': 10, 'data': '2026-11-02', '_u': 100},
        ]
      }));
      expect(r.porId('g1')!['desc'], 'Novo');
    });

    test('registro apagado no Drive some ao importar', () async {
      final r = Repo.memoria([
        {'kind': 'gasto', 'id': 'g1', 'desc': 'X', 'valor': 20, 'data': '2026-11-02', '_u': 100},
      ]);
      await r.importar(jsonEncode({'docs': [], 'tomb': {'g1': 500}}));
      expect(r.porId('g1'), isNull);
    });
  });

  group('resumo do mês', () {
    test('soma entradas sem as transferências entre contas próprias', () {
      final r = Repo.memoria([
        {'kind': 'gasto', 'id': 'g1', 'valor': 100, 'data': '2026-11-03', 'cat': 'mercado'},
        {'kind': 'gasto', 'id': 'g2', 'valor': 50, 'data': '2026-10-30', 'cat': 'mercado'},
        {'kind': 'entrada', 'id': 'e1', 'valor': 1000, 'data': '2026-11-05', 'cat': 'pix'},
        {'kind': 'entrada', 'id': 'e2', 'valor': 300, 'data': '2026-11-05', 'cat': 'proprias'},
        {'kind': 'orc', 'id': 'orc_mercado', 'cat': 'mercado', 'limite': 80},
      ]);
      final m = ResumoMes.de(r, '2026-11');
      expect(m.saiu, 100);
      expect(m.entrou, 1000);
      expect(m.entreContas, 300);
      expect(m.sobra, 900);
      expect(m.limiteTotal, 80);
      expect(m.usoLimite, closeTo(1.25, 1e-9));
    });

    test('salário do fim do mês conta no mês seguinte quando a opção está ligada', () {
      final r = Repo.memoria([
        {'kind': 'renda', 'id': 'rd_salario', 'valor': 4800, 'regra': 'util', 'mesSeg': true},
        {'kind': 'entrada', 'id': 'e1', 'valor': 4800, 'data': '2026-10-30', 'cat': 'salario'},
      ]);
      expect(ResumoMes.de(r, '2026-10').entrou, 0);
      expect(ResumoMes.de(r, '2026-11').entrou, 4800);
    });

    test('saldo em conta desconta o que saiu depois do último saldo', () {
      final r = Repo.memoria([
        {'kind': 'conta', 'id': 'c1', 'saldo': 1000, 'data': '2026-11-01'},
        {'kind': 'gasto', 'id': 'g1', 'valor': 100, 'data': '2026-11-02', 'pag': 'Pix'},
        {'kind': 'gasto', 'id': 'g2', 'valor': 70, 'data': '2026-11-02', 'pag': 'Crédito'},
        {'kind': 'gasto', 'id': 'g3', 'valor': 40, 'data': '2026-10-31', 'pag': 'Pix'},
        {'kind': 'entrada', 'id': 'e1', 'valor': 500, 'data': '2026-11-03', 'cat': 'pix'},
      ]);
      expect(saldoEmConta(r), 1400);
    });
  });

  test('investido não entra no Saiu e aparece no resumo do mês', () {
    final r = Repo.memoria([
      {'kind': 'entrada', 'id': 'e1', 'desc': 'Salário', 'valor': 5000, 'data': '2026-10-31', 'cat': 'salario'},
      {'kind': 'gasto', 'id': 'g1', 'desc': 'Mercado', 'valor': 1000, 'data': '2026-10-10', 'cat': 'mercado'},
      {'kind': 'invest', 'id': 'i1', 'desc': 'CDB', 'valor': 1500, 'data': '2026-10-12', 'mov': 'aplic'},
      {'kind': 'invest', 'id': 'i2', 'desc': 'Resgate', 'valor': 300, 'data': '2026-10-20', 'mov': 'resgate'},
    ]);
    final m = ResumoMes.de(r, '2026-10');
    expect(m.saiu, 1000);
    expect(m.investiu, 1200);
    expect(m.sobraEmConta, 5000 - 1000 - 1200);
    expect(m.pctInvestido, closeTo(.24, .0001));
    expect(m.lancamentos.where((l) => l.ehInvest).length, 2);
    expect(m.lancamentos.fold<double>(0, (a, l) => a + l.efeito), 4000);
  });
}
