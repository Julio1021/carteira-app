// Objetivos: metas de valor (reserva, viagem, carro…) acompanhadas pelo
// patrimônio investido, por um ativo ou por um valor informado à mão.
import '../util/fmt.dart';
import 'modelos.dart';
import 'patrimonio.dart';
import 'repo.dart';

class Objetivo {
  final Doc d;
  Objetivo(this.d);
  String get id => str(d['id']);
  String get nome => str(d['nome'], 'Objetivo');
  double get alvo => numD(d['valor']);

  /// 'total' (tudo o que está investido), 'ativo' (um ativo) ou 'manual'.
  String get fonte => str(d['fonte'], 'total');
  String? get ativo => d['ativo'] is String ? d['ativo'] as String : null;
  double get guardado => numD(d['guardado']);

  /// Mês desejado (aaaa-mm), opcional.
  String? get prazo => d['prazo'] is String && (d['prazo'] as String).length == 7 ? d['prazo'] as String : null;
  int get icone => numI(d['icone']) ?? 0;
  int get criado => numI(d['criado']) ?? 0;
}

class Progresso {
  final Objetivo o;
  final double atual;

  /// Quanto o valor tem crescido por mês (aportes + rendimento), ou null se não dá para saber.
  final double? ritmo;
  const Progresso(this.o, this.atual, this.ritmo);

  double get frac => o.alvo > 0 ? (atual / o.alvo).clamp(0, 1).toDouble() : 0;
  double get falta => (o.alvo - atual) < 0 ? 0 : o.alvo - atual;
  bool get concluido => o.alvo > 0 && atual >= o.alvo;

  /// Em quantos meses chega lá, no ritmo atual.
  int? get mesesNoRitmo {
    if (concluido) return 0;
    final r = ritmo;
    if (r == null || r <= 0) return null;
    final m = (falta / r).ceil();
    return m > 600 ? null : m;
  }

  /// Mês previsto (aaaa-mm) no ritmo atual.
  String? previsao(String hoje) {
    final m = mesesNoRitmo;
    return m == null ? null : ymAdd(ymDe(hoje), m);
  }

  /// Quanto precisa crescer por mês para chegar no prazo.
  double? porMesParaPrazo(String hoje) {
    final p = o.prazo;
    if (p == null || concluido) return null;
    final a = ymDe(hoje);
    final meses = (int.parse(p.substring(0, 4)) - int.parse(a.substring(0, 4))) * 12 + int.parse(p.substring(5, 7)) - int.parse(a.substring(5, 7));
    if (meses <= 0) return falta;
    return falta / meses;
  }

  /// true quando há prazo e o ritmo atual não chega a tempo.
  bool atrasado(String hoje) {
    final p = o.prazo, prev = previsao(hoje);
    if (p == null || concluido) return false;
    if (prev == null) return o.fonte != 'manual';
    return prev.compareTo(p) > 0;
  }
}

List<Objetivo> objetivosDe(Repo repo) => repo.doTipo('objetivo').map(Objetivo.new).toList()..sort((a, b) => a.criado.compareTo(b.criado));

Progresso progressoDe(Objetivo o, Carteira c, {String? hoje}) {
  if (o.fonte == 'manual') return Progresso(o, o.guardado, null);
  final h = hoje ?? hojeIso();
  double valorEm(LinhaDia d) => o.fonte == 'ativo' ? _doAtivo(c, o.ativo, d) : d.total;
  if (c.dias.isEmpty) return Progresso(o, 0, null);
  final atual = valorEm(c.dias.last);
  // ritmo: quanto cresceu nos últimos ~6 meses
  final corte = addDias(h, -183);
  LinhaDia? base;
  for (final d in c.dias) {
    if (d.data.compareTo(corte) >= 0) {
      base = d;
      break;
    }
  }
  base ??= c.dias.first;
  final dias = dataDe(c.dias.last.data).difference(dataDe(base.data)).inDays;
  final ritmo = dias >= 28 ? (atual - valorEm(base)) / (dias / 30.44) : null;
  return Progresso(o, atual, ritmo);
}

double _doAtivo(Carteira c, String? id, LinhaDia d) {
  if (id == null) return 0;
  final filhos = c.ativos.where((a) => a.pai == id).map((a) => a.id).toList();
  if (filhos.isEmpty) return d.porAtivo[id] ?? 0;
  return filhos.fold<double>(0, (t, f) => t + (d.porAtivo[f] ?? 0));
}

Doc docObjetivo({String? id, required String nome, required double valor, required String fonte, String? ativo, double guardado = 0, String? prazo, int icone = 0, int? criado}) => {
      'kind': 'objetivo',
      'id': id ?? novoId('ob'),
      'nome': nome,
      'valor': (valor * 100).round() / 100,
      'fonte': fonte,
      if (ativo != null) 'ativo': ativo,
      if (fonte == 'manual') 'guardado': (guardado * 100).round() / 100,
      if (prazo != null) 'prazo': prazo,
      'icone': icone,
      'criado': criado ?? DateTime.now().millisecondsSinceEpoch,
    };
