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
  return out;
}
