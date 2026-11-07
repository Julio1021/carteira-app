// Leitura dos registros ("docs") no mesmo formato do site.
// Os registros são guardados como mapas crus para que nenhum campo
// desconhecido (cartões, ativos, etc.) se perca ao salvar ou sincronizar.

typedef Doc = Map<String, dynamic>;

double numD(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);
int? numI(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
String str(Object? v, [String padrao = '']) => v is String ? v : (v == null ? padrao : v.toString());

class Gasto {
  final Doc d;
  Gasto(this.d);
  String get id => str(d['id']);
  String get desc => str(d['desc'], 'Gasto');
  double get valor => numD(d['valor']);
  String get data => str(d['data'], '1970-01-01');
  String get cat => str(d['cat'], 'outros');
  String get pag => str(d['pag'], 'Pix');
  bool get fixo => d['fixo'] == true;
  int get criado => numI(d['criado']) ?? 0;
  bool get doExtrato => d['ext'] != null && d['ext'] != false && d['ext'] != '';
  String? get conta => d['conta'] is String ? d['conta'] as String : null;
}

class Entrada {
  final Doc d;
  Entrada(this.d);
  String get id => str(d['id']);
  String get desc => str(d['desc'], 'Entrada');
  double get valor => numD(d['valor']);
  String get data => str(d['data'], '1970-01-01');
  String get cat => str(d['cat'], 'outros_e');
  int get criado => numI(d['criado']) ?? 0;
  String? get rd => d['rd'] is String ? d['rd'] as String : null;
  bool get doExtrato => d['ext'] != null && d['ext'] != false && d['ext'] != '';
  String? get conta => d['conta'] is String ? d['conta'] as String : null;
  bool get entreContas => cat == 'proprias';
}

/// Dinheiro que foi para investimentos (kind 'invest'). Não é gasto nem entrada.
/// valor é sempre positivo; mov = 'aplic' (aplicação) ou 'resgate'.
class Investido {
  final Doc d;
  Investido(this.d);
  String get id => str(d['id']);
  String get desc => str(d['desc'], resgate ? 'Resgate' : 'Aplicação');
  double get valor => numD(d['valor']).abs();
  bool get resgate => d['mov'] == 'resgate';
  /// Positivo quando aplicou, negativo quando resgatou.
  double get liquido => resgate ? -valor : valor;
  String get data => str(d['data'], '1970-01-01');
  int get criado => numI(d['criado']) ?? 0;
  bool get doExtrato => d['ext'] != null && d['ext'] != false && d['ext'] != '';
  String? get conta => d['conta'] is String ? d['conta'] as String : null;
  String? get ativo => d['ativo'] is String ? d['ativo'] as String : null;
}

class ContaBancaria {
  final Doc d;
  ContaBancaria(this.d);
  String get id => str(d['id']);
  String get nome => str(d['nome'], 'Conta');
  double get saldo => numD(d['saldo']);
  String get data => str(d['data'], '1970-01-01');
  int get ts => numI(d['ts']) ?? 0;
}

class Limite {
  final Doc d;
  Limite(this.d);
  String get cat => str(d['cat']);
  double get limite => numD(d['limite']);
}

class Renda {
  final Doc d;
  Renda(this.d);
  String get id => str(d['id']);
  String get nome => str(d['nome'], 'Recebimento');
  double get valor => numD(d['valor']);
  String get regra => str(d['regra'], 'dia');
  int get dia => numI(d['dia']) ?? 1;
  bool get mesSeguinte => d['mesSeg'] == true;
}
