import '../util/fmt.dart';
import 'modelos.dart';

/// Dados de exemplo, usados só para gerar prints (endereço com ?demo=1).
List<Doc> dadosDemo() {
  final h = hojeIso();
  final ym = ymDe(h);
  final out = <Doc>[];
  var n = 0;
  void g(String desc, double v, int diasAtras, String cat, String pag) {
    out.add({'kind': 'gasto', 'id': 'g_demo${n++}', 'desc': desc, 'valor': v, 'data': addDias(h, -diasAtras), 'cat': cat, 'pag': pag, 'fixo': false, 'criado': 1000 + n});
  }

  g('Supermercado Dia', 202.95, 0, 'mercado', 'Débito');
  g('iFood', 48.90, 0, 'alimentacao', 'Crédito');
  g('Posto Shell', 154.01, 1, 'transporte', 'Pix');
  g('Drogasil', 30.68, 1, 'saude', 'Débito');
  g('Supermercado Dia', 189.60, 2, 'mercado', 'Crédito');
  g('Vivo Fibra', 120.00, 3, 'internet', 'Boleto');
  g('Cinema', 45.19, 3, 'lazer', 'Crédito');
  g('Spotify', 21.90, 4, 'assinaturas', 'Crédito');
  g('Amazon', 194.13, 5, 'compras', 'Pix');
  g('Conta de luz EDP', 187.40, 6, 'contas', 'Boleto');
  for (var i = 7; i < 40; i += 3) {
    g(i % 2 == 0 ? 'Padaria' : 'Supermercado Dia', i % 2 == 0 ? 23.5 + i : 96.0 + i * 2, i, i % 2 == 0 ? 'alimentacao' : 'mercado', 'Pix');
  }
  out.add({'kind': 'entrada', 'id': 'e_demo1', 'desc': 'Salário', 'valor': 4800.0, 'data': '$ym-01', 'cat': 'salario', 'criado': 1});
  out.add({'kind': 'entrada', 'id': 'e_demo2', 'desc': 'Vale alimentação', 'valor': 900.0, 'data': '$ym-${doisDig(diasNoMes(ym) < 20 ? diasNoMes(ym) : 5)}', 'cat': 'beneficios', 'criado': 2});
  out.add({'kind': 'entrada', 'id': 'e_demo3', 'desc': 'Pix recebido · Maria', 'valor': 150.0, 'data': addDias(h, -2), 'cat': 'pix', 'criado': 3});
  out.add({'kind': 'conta', 'id': 'ct_demo', 'nome': 'Banco Inter', 'saldo': 3250.40, 'data': addDias(h, -3), 'ts': 1});
  out.add({'kind': 'orc', 'id': 'orc_mercado', 'cat': 'mercado', 'limite': 900.0});
  out.add({'kind': 'orc', 'id': 'orc_alimentacao', 'cat': 'alimentacao', 'limite': 300.0});
  out.add({'kind': 'orc', 'id': 'orc_lazer', 'cat': 'lazer', 'limite': 200.0});
  // Planejar
  final criado = DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch;
  out.add({'kind': 'pagar', 'id': 'pg_demo1', 'nome': 'Aluguel', 'valor': 1300.0, 'rep': 'mensal', 'dia': 10, 'ini': ymAdd(ym, -2), 'cat': 'moradia', 'pag': 'Pix', 'criado': criado});
  out.add({'kind': 'pagar', 'id': 'pg_demo2', 'nome': 'Internet', 'valor': 120.0, 'rep': 'mensal', 'dia': 15, 'ini': ymAdd(ym, -2), 'cat': 'internet', 'pag': 'Boleto', 'criado': criado});
  out.add({'kind': 'pagar', 'id': 'pg_demo3', 'nome': 'Luz', 'valor': 187.4, 'rep': 'mensal', 'dia': 6, 'ini': ymAdd(ym, -1), 'cat': 'contas', 'pag': 'Boleto', 'variavel': true, 'criado': criado});
  out.add({'kind': 'pagar', 'id': 'pg_demo4', 'nome': 'Geladeira', 'valor': 350.0, 'rep': 'parcelas', 'parc': 6, 'dia': 3, 'ini': ymAdd(ym, -1), 'cat': 'compras', 'pag': 'Boleto', 'criado': criado});
  out.add({'kind': 'pagto', 'id': 'pp_pg_demo1_${ymAdd(ym, -2)}', 'conta': 'pg_demo1', 'mes': ymAdd(ym, -2), 'pago': true, 'valor': 1300.0, 'data': '${ymAdd(ym, -2)}-10'});
  out.add({'kind': 'pagto', 'id': 'pp_pg_demo2_${ymAdd(ym, -2)}', 'conta': 'pg_demo2', 'mes': ymAdd(ym, -2), 'pago': true, 'valor': 120.0, 'data': '${ymAdd(ym, -2)}-15'});
  out.add({'kind': 'renda', 'id': 'rd_salario', 'nome': 'Salário', 'valor': 4800.0, 'regra': 'util', 'mesSeg': false});
  out.add({'kind': 'renda', 'id': 'rd_va', 'nome': 'Vale alimentação', 'valor': 900.0, 'regra': 'dia', 'dia': 20});
  out.add({'kind': 'cartao', 'id': 'cc_demo', 'nome': 'Nubank', 'banco': 'Nubank', 'limite': 4000.0, 'fecha': 3, 'vence': 10, 'cor': '#820ad1', 'criado': 1});
  out.add({'kind': 'gasto', 'id': 'g_cc1', 'desc': 'Amazon', 'valor': 189.9, 'data': addDias(h, -1), 'cat': 'compras', 'pag': 'Crédito', 'cartao': 'cc_demo', 'fat': ymAdd(ym, 1), 'criado': 5000});
  for (var i = 0; i < 2; i++) {
    out.add({'kind': 'gasto', 'id': 'g_ccp$i', 'desc': 'Celular (${i + 1}/10)', 'valor': 249.9, 'data': '${ymAdd(ym, i - 1)}-20', 'cat': 'compras', 'pag': 'Crédito', 'cartao': 'cc_demo', 'fat': ymAdd(ym, i), 'parc': {'i': i + 1, 'n': 10, 'g': 'cpdemo'}, 'criado': 5001 + i});
  }
  out.add({'kind': 'emprestimo', 'id': 'em_demo', 'pessoa': 'Carlos Souza', 'valor': 1500.0, 'data': '${ymAdd(ym, -3)}-05', 'ini': ymAdd(ym, -2), 'parc': 5, 'dia': 10, 'obs': '', 'criado': 1});
  out.add({'kind': 'receb', 'id': 'rc_demo1', 'emp': 'em_demo', 'valor': 300.0, 'data': '${ymAdd(ym, -2)}-10'});
  // Patrimônio: 4 ativos com lançamentos semanais nos últimos 10 meses
  const ativos = [('a_demo1', 'Inter CDB', 'Renda Fixa', 'Banco Inter', 18000.0, 600.0), ('a_demo2', 'Tesouro Selic', 'Tesouro Direto', 'Banco Inter', 12000.0, 400.0),
    ('a_demo3', 'Nubank Caixinha', 'Renda Fixa', 'Nubank', 9000.0, 300.0), ('a_demo4', 'Mercado Pago Cofrinho', 'Renda Fixa', 'Mercado Pago', 6000.0, 200.0)];
  for (var k = 0; k < ativos.length; k++) {
    final (id, nome, classe, inst, v0, ap) = ativos[k];
    out.add({'kind': 'ativo', 'id': id, 'nome': nome, 'classe': classe, 'inst': inst, 'cor': k, 'ordem': k});
    var v = v0;
    for (var w = 40; w >= 0; w--) {
      final d = addDias(h, -w * 7);
      final aporte = (w < 40 && w % 4 == 0) ? ap : 0.0;
      if (w < 40) v = v * (1.0022 + (k * 0.0003) + ((w * 7 + k) % 5 - 2) * 0.0004) + aporte;
      out.add({'kind': 'lanc', 'id': 'l_${id}_$d', 'ativo': id, 'data': d, 'saldo': (v * 100).round() / 100, 'aporte': aporte});
    }
  }
  return out;
}
