// Formatação de dinheiro e datas no padrão brasileiro, sem depender de dados de localidade.

const mesesLongos = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];
const mesesAbr = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
const diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

/// R$ 1.234,56 (com sinal de menos quando negativo).
String brl(num v, {bool sinal = false}) {
  final neg = v < 0;
  final cent = (v.abs() * 100).round();
  final inteiro = cent ~/ 100;
  final dec = (cent % 100).toString().padLeft(2, '0');
  final s = inteiro.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  final pre = neg ? '− ' : (sinal ? '+ ' : '');
  return '${pre}R\$ $b,$dec';
}

/// Lê "1.234,56", "1234.56", "R$ 10" etc. Devolve null se não for número.
double? lerValor(String? t) {
  if (t == null) return null;
  var s = t.replaceAll(RegExp(r'[^0-9,.\-]'), '').trim();
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'\.\d{3}$').hasMatch(s) && !RegExp(r'\.\d{1,2}$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}

/// Valor para mostrar num campo de edição: 1234.5 -> "1.234,50".
String valorCampo(double v) => brl(v).replaceFirst('R\$ ', '').replaceFirst('− ', '-');

String doisDig(int n) => n.toString().padLeft(2, '0');

/// Data ISO (aaaa-mm-dd) de hoje, no horário local.
String hojeIso() => isoDe(DateTime.now());
String isoDe(DateTime d) => '${d.year}-${doisDig(d.month)}-${doisDig(d.day)}';
DateTime dataDe(String iso) => DateTime(int.parse(iso.substring(0, 4)), int.parse(iso.substring(5, 7)), int.parse(iso.substring(8, 10)), 12);

/// Mês no formato aaaa-mm.
String ymDe(String iso) => iso.substring(0, 7);
String ymAdd(String ym, int n) {
  var y = int.parse(ym.substring(0, 4));
  var m = int.parse(ym.substring(5, 7)) + n;
  while (m < 1) { m += 12; y--; }
  while (m > 12) { m -= 12; y++; }
  return '$y-${doisDig(m)}';
}
int diasNoMes(String ym) {
  final y = int.parse(ym.substring(0, 4)), m = int.parse(ym.substring(5, 7));
  return DateTime(y, m + 1, 0).day;
}
String addDias(String iso, int n) => isoDe(dataDe(iso).add(Duration(days: n)));

String mesLongo(String ym) => '${mesesLongos[int.parse(ym.substring(5, 7)) - 1]} ${ym.substring(0, 4)}';
String dataCurta(String iso) => '${iso.substring(8, 10)}/${iso.substring(5, 7)}';
String dataBr(String iso) => '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';

/// "Hoje", "Ontem" ou "Sex, 20 de nov".
String rotuloDia(String iso) {
  final h = hojeIso();
  if (iso == h) return 'Hoje';
  if (iso == addDias(h, -1)) return 'Ontem';
  final d = dataDe(iso);
  return '${diasSemana[d.weekday - 1]}, ${d.day} de ${mesesAbr[d.month - 1]}';
}

// ---------- dias úteis e feriados nacionais (mesma regra do site) ----------
String _pascoa(int y) {
  final a = y % 19, b = y ~/ 100, c = y % 100, d = b ~/ 4, e = b % 4, f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30, i = c ~/ 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = (a + 11 * h + 22 * l) ~/ 451;
  final mes = (h + l - 7 * m + 114) ~/ 31, dia = ((h + l - 7 * m + 114) % 31) + 1;
  return '$y-${doisDig(mes)}-${doisDig(dia)}';
}

bool feriado(String iso) {
  final md = iso.substring(5);
  const fixos = ['01-01', '04-21', '05-01', '09-07', '10-12', '11-02', '11-15', '11-20', '12-25'];
  if (fixos.contains(md)) return true;
  final p = _pascoa(int.parse(iso.substring(0, 4)));
  return [-48, -47, -2, 60].any((n) => addDias(p, n) == iso);
}

bool diaUtil(String iso) {
  final w = dataDe(iso).weekday;
  return w != DateTime.saturday && w != DateTime.sunday && !feriado(iso);
}

String ultimoDiaUtil(String ym) {
  var d = '$ym-${doisDig(diasNoMes(ym))}';
  while (!diaUtil(d)) {
    d = addDias(d, -1);
  }
  return d;
}

String novoId(String prefixo) {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = (DateTime.now().microsecond * 7919 % 1679616).toRadixString(36).padLeft(4, '0');
  return '${prefixo}_$t$r';
}
