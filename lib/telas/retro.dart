// Retrospectiva do mês: o resumo contado em telas cheias, como "stories".
// Toque à direita para avançar, à esquerda para voltar; segure para pausar.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/analise.dart';
import '../dados/categorias.dart';
import '../dados/modelos.dart';
import '../dados/patrimonio.dart';
import '../dados/repo.dart';
import '../dados/resumo.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';
import 'objetivos.dart' show Anel;

void abrirRetro(BuildContext context, String ym, {int inicial = 0, bool parado = false}) {
  Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => TelaRetro(ym: ym, inicial: inicial, parado: parado),
    transitionsBuilder: (_, a, __, child) {
      final v = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: v, child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(v), child: child));
    },
  ));
}

/// Mês que faz mais sentido mostrar: o próprio mês se já acabou; senão o
/// anterior (quando tem dados), ou o atual mesmo.
String mesDaRetro(Repo repo, String ym) {
  final atual = ymDe(hojeIso());
  if (ym.compareTo(atual) < 0) return ym;
  final ant = ymAdd(atual, -1);
  return repo.gastos.any((g) => g.data.startsWith(ant)) ? ant : atual;
}

class _Dados {
  final String ym;
  final ResumoMes r, ant;
  final List<MapEntry<String, double>> cats;
  final Gasto? maior;
  final int? diaCaro;
  final double valorDiaCaro;
  final int diasSemGasto, diasContados;
  final MesPat? pat;
  _Dados(this.ym, this.r, this.ant, this.cats, this.maior, this.diaCaro, this.valorDiaCaro, this.diasSemGasto, this.diasContados, this.pat);

  factory _Dados.de(Repo repo, String ym) {
    final r = ResumoMes.de(repo, ym), ant = ResumoMes.de(repo, ymAdd(ym, -1));
    final cats = r.porCategoria.entries.where((e) => e.key != 'cartao').toList()..sort((a, b) => b.value.compareTo(a.value));
    Gasto? maior;
    for (final g in r.gastos) {
      if (g.cat == 'cartao') continue;
      if (maior == null || g.valor > maior.valor) maior = g;
    }
    final porDia = gastosPorDia(repo, ym);
    int? dia;
    var vDia = 0.0;
    porDia.forEach((d, v) {
      if (v > vDia) {
        vDia = v;
        dia = d;
      }
    });
    final h = hojeIso();
    final ate = ymDe(h) == ym ? int.parse(h.substring(8, 10)) : diasNoMes(ym);
    var sem = 0;
    for (var d = 1; d <= ate; d++) {
      if ((porDia[d] ?? 0) <= 0) sem++;
    }
    MesPat? pat;
    for (final m in calcularCarteira(repo).meses) {
      if (m.ym == ym) pat = m;
    }
    return _Dados(ym, r, ant, cats, maior, dia, vDia, sem, ate, pat);
  }

  String get mes => mesesLongos[int.parse(ym.substring(5, 7)) - 1];
  String get mesAnt => mesesLongos[int.parse(ymAdd(ym, -1).substring(5, 7)) - 1];
}

class TelaRetro extends StatefulWidget {
  final String ym;
  final int inicial;
  final bool parado;
  const TelaRetro({super.key, required this.ym, this.inicial = 0, this.parado = false});
  @override
  State<TelaRetro> createState() => _TelaRetroState();
}

class _TelaRetroState extends State<TelaRetro> with TickerProviderStateMixin {
  late final AnimationController tempo = AnimationController(vsync: this, duration: const Duration(seconds: 7));
  late final AnimationController fundo = AnimationController(vsync: this, duration: const Duration(seconds: 24));
  _Dados? dados;
  List<int> slides = const [0];
  int i = 0;

  static const _paletas = <List<Color>>[
    [Color(0xFF16226A), Color(0xFF3B6BE8)],
    [Color(0xFF0B3A2D), Color(0xFF16A37B)],
    [Color(0xFF3F1A57), Color(0xFFB5489A)],
    [Color(0xFF55260B), Color(0xFFE08336)],
    [Color(0xFF1B2163), Color(0xFF6C72E6)],
    [Color(0xFF0F1630), Color(0xFF2F4FBF)],
    [Color(0xFF101119), Color(0xFF3A3F5C)],
  ];

  @override
  void initState() {
    super.initState();
    tempo.addStatusListener((s) {
      if (s == AnimationStatus.completed) _ir(1, automatico: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (dados != null) return;
    final d = _Dados.de(RepoScope.ler(context), widget.ym);
    dados = d;
    slides = [
      0,
      1,
      if (d.cats.isNotEmpty) 2,
      if (d.maior != null) 3,
      if (d.r.investiu != 0 || d.pat != null) 4,
      if (d.ant.saiu > 0 && d.r.saiu > 0) 5,
      6,
    ];
    i = widget.inicial.clamp(0, slides.length - 1).toInt();
    if (!widget.parado && !semAnimacao(context)) {
      tempo.forward();
      fundo.repeat();
    }
  }

  @override
  void dispose() {
    tempo.dispose();
    fundo.dispose();
    super.dispose();
  }

  void _ir(int passo, {bool automatico = false}) {
    final n = i + passo;
    if (n < 0) {
      tempo.forward(from: 0);
      return;
    }
    if (n >= slides.length) {
      if (automatico) return; // fica na última tela
      Navigator.of(context).maybePop();
      return;
    }
    if (!automatico) HapticFeedback.selectionClick();
    setState(() => i = n);
    if (!widget.parado) tempo.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final d = dados!;
    final tipo = slides[i];
    final cores = _paletas[tipo];
    return Escuro(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LayoutBuilder(builder: (context, cons) {
              final largo = MediaQuery.sizeOf(context).width > 520;
              return ClipRRect(
                borderRadius: BorderRadius.circular(largo ? 28 : 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (t) => _ir(t.localPosition.dx < cons.maxWidth * .3 ? -1 : 1),
                  onLongPressStart: (_) => tempo.stop(),
                  onLongPressEnd: (_) {
                    if (!widget.parado) tempo.forward();
                  },
                  child: Stack(fit: StackFit.expand, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: cores)),
                    ),
                    AnimatedBuilder(animation: fundo, builder: (_, __) => CustomPaint(painter: _Bolhas(fundo.value, cores.last))),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          // barrinhas de progresso
                          AnimatedBuilder(
                            animation: tempo,
                            builder: (_, __) => Row(children: [
                              for (var k = 0; k < slides.length; k++)
                                Expanded(
                                  child: Container(
                                    height: 3.5,
                                    margin: EdgeInsets.only(right: k < slides.length - 1 ? 4 : 0),
                                    decoration: BoxDecoration(color: const Color(0x40FFFFFF), borderRadius: BorderRadius.circular(2)),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: k < i ? 1.0 : (k == i ? (widget.parado ? 1.0 : tempo.value) : 0.0),
                                      child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Retrospectiva · ${d.mes}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5))),
                            IconButton(
                              tooltip: 'Fechar',
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                            ),
                          ]),
                          Expanded(child: KeyedSubtree(key: ValueKey(tipo), child: _slide(tipo, d))),
                        ]),
                      ),
                    ),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ---------- estilos ----------
  static const _rot = TextStyle(color: Color(0xCCFFFFFF), fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2);
  static const _grande = TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1.6, height: 1.05);
  static const _medio = TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.6, height: 1.15);
  static const _texto = TextStyle(color: Color(0xE6FFFFFF), fontSize: 17, height: 1.35, fontWeight: FontWeight.w500);

  Widget _coluna(List<Widget> filhos, {MainAxisAlignment eixo = MainAxisAlignment.center}) => Column(
        mainAxisAlignment: eixo,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (var k = 0; k < filhos.length; k++) _Sobe(atraso: 90 + k * 130, child: filhos[k])],
      );

  Widget _valor(double v, {TextStyle estilo = _grande, bool sinal = false}) =>
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: ValorAnimado(v, estilo: estilo, sinal: sinal));

  Widget _slide(int tipo, _Dados d) {
    final r = d.r;
    switch (tipo) {
      case 0:
        final n = r.gastos.length + r.entradas.length + r.investimentos.length;
        return _coluna([
          const Text('SEU MÊS EM NÚMEROS', style: _rot),
          const SizedBox(height: 10),
          Text(d.mes, style: _grande.copyWith(fontSize: 58)),
          Text(d.ym.substring(0, 4), style: _grande.copyWith(fontSize: 58, color: const Color(0x8CFFFFFF))),
          const SizedBox(height: 22),
          Text(n == 0 ? 'Ainda não há lançamentos neste mês.' : '$n lançamento${n == 1 ? '' : 's'} contam a história deste mês.', style: _texto),
          const SizedBox(height: 28),
          const Row(children: [
            Icon(Icons.touch_app_rounded, size: 16, color: Color(0xB3FFFFFF)),
            SizedBox(width: 6),
            Text('Toque para avançar', style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 13)),
          ]),
        ]);
      case 1:
        final taxa = r.entrou > 0 ? r.sobra / r.entrou : null;
        return _coluna([
          const Text('ENTROU', style: _rot),
          _valor(r.entrou, estilo: _medio.copyWith(fontSize: 32)),
          const SizedBox(height: 18),
          const Text('SAIU', style: _rot),
          _valor(r.saiu, estilo: _medio.copyWith(fontSize: 32)),
          const SizedBox(height: 26),
          Container(height: 1, color: const Color(0x33FFFFFF)),
          const SizedBox(height: 26),
          Text(r.sobra >= 0 ? 'SOBROU' : 'FALTOU', style: _rot),
          const SizedBox(height: 4),
          _valor(r.sobra.abs()),
          const SizedBox(height: 14),
          Text(
            taxa == null
                ? 'Sem entradas registradas no mês.'
                : (r.sobra >= 0 ? 'Você ficou com ${(taxa * 100).round()}% de tudo o que entrou.' : 'Os gastos passaram das entradas em ${(-taxa * 100).round()}%.'),
            style: _texto,
          ),
        ]);
      case 2:
        final total = d.cats.fold<double>(0, (a, e) => a + e.value);
        final top = d.cats.first;
        final cat = catGasto(top.key);
        final frac = total > 0 ? top.value / total : 0.0;
        return _coluna([
          const Text('PARA ONDE MAIS FOI', style: _rot),
          const SizedBox(height: 16),
          Row(children: [
            Anel(
              frac: frac,
              cor: Colors.white,
              trilho: const Color(0x33FFFFFF),
              tam: 124,
              espessura: 13,
              centro: Text('${(frac * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1)),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(cat.icone, color: Colors.white, size: 26),
                const SizedBox(height: 6),
                Text(cat.nome, style: _medio),
                const SizedBox(height: 2),
                _valor(top.value, estilo: _texto.copyWith(fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 30),
          for (final e in d.cats.skip(1).take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _BarraRetro(nome: catGasto(e.key).nome, valor: e.value, frac: top.value > 0 ? e.value / top.value : 0.0),
            ),
        ]);
      case 3:
        final g = d.maior!;
        final dia = d.diaCaro;
        return _coluna([
          const Text('MAIOR GASTO', style: _rot),
          const SizedBox(height: 6),
          Text(g.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: _medio),
          _valor(g.valor),
          const SizedBox(height: 4),
          Text('${catGasto(g.cat).nome} · ${rotuloDia(g.data)}', style: _texto.copyWith(fontSize: 15)),
          const SizedBox(height: 30),
          if (dia != null)
            _Fato(
              icone: Icons.local_fire_department_rounded,
              titulo: 'Dia mais caro: ${diasSemana[dataDe('${d.ym}-${doisDig(dia)}').weekday - 1].toLowerCase()}, $dia',
              texto: '${brl(d.valorDiaCaro)} num dia só',
            ),
          const SizedBox(height: 10),
          _Fato(
            icone: Icons.spa_rounded,
            titulo: '${d.diasSemGasto} dia${d.diasSemGasto == 1 ? '' : 's'} sem gastar nada',
            texto: 'de ${d.diasContados} dia${d.diasContados == 1 ? '' : 's'} do mês',
          ),
        ]);
      case 4:
        final pct = r.pctInvestido;
        final p = d.pat;
        return _coluna([
          const Text('INVESTIMENTOS', style: _rot),
          const SizedBox(height: 8),
          Text(r.investiu >= 0 ? 'Você investiu' : 'Você resgatou', style: _medio),
          _valor(r.investiu.abs()),
          if (pct != null && r.investiu > 0) ...[
            const SizedBox(height: 8),
            Text('${(pct * 100).round()}% de tudo o que entrou foi para o seu futuro.', style: _texto),
          ],
          if (p != null) ...[
            const SizedBox(height: 28),
            _Fato(
              icone: Icons.trending_up_rounded,
              titulo: 'Seus investimentos renderam ${brl(p.ganho, sinal: true)}',
              texto: '${pct_(p.rent)} no mês · patrimônio em ${brl(p.fim)}',
            ),
          ],
        ]);
      case 5:
        final v = r.saiu / d.ant.saiu - 1;
        final menos = v < 0;
        final mx = math.max(r.saiu, d.ant.saiu);
        return _coluna([
          Text('CONTRA ${d.mesAnt.toUpperCase()}', style: _rot),
          const SizedBox(height: 8),
          Text('Você gastou', style: _medio),
          Text('${(v.abs() * 100).round()}% ${menos ? 'menos' : 'a mais'}', style: _grande),
          const SizedBox(height: 30),
          SizedBox(
            height: 170,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: _Coluna(nome: d.mesAnt, valor: d.ant.saiu, frac: d.ant.saiu / mx, forte: false)),
              const SizedBox(width: 16),
              Expanded(child: _Coluna(nome: d.mes, valor: r.saiu, frac: r.saiu / mx, forte: true)),
            ]),
          ),
          const SizedBox(height: 18),
          Text(menos ? 'São ${brl(d.ant.saiu - r.saiu)} que ficaram com você.' : 'Foram ${brl(r.saiu - d.ant.saiu)} a mais que no mês anterior.', style: _texto),
        ]);
      default:
        final bom = r.sobra >= 0;
        return _coluna([
          Icon(bom ? Icons.emoji_events_rounded : Icons.flag_rounded, color: Colors.white, size: 46),
          const SizedBox(height: 16),
          Text(bom ? 'Mês fechado\nno azul.' : 'Mês apertado.\nO próximo é seu.', style: _grande.copyWith(fontSize: 40)),
          const SizedBox(height: 16),
          Text(
            bom
                ? (r.investiu > 0 ? 'Sobrou ${brl(r.sobra)} e ${brl(r.investiu)} foram investidos. Continue assim.' : 'Sobrou ${brl(r.sobra)}. Que tal investir uma parte?')
                : 'Faltaram ${brl(r.sobra.abs())}. Dê uma olhada nos limites por categoria para o próximo mês.',
            style: _texto,
          ),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF12131C), padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14)),
            child: const Text('Fechar', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]);
    }
  }
}

String pct_(double v) => '${v >= 0 ? '+' : '−'}${(v.abs() * 100).toStringAsFixed(2).replaceAll('.', ',')}%';

/// Sobe e aparece depois de [atraso] ms.
class _Sobe extends StatefulWidget {
  final int atraso;
  final Widget child;
  const _Sobe({required this.atraso, required this.child});
  @override
  State<_Sobe> createState() => _SobeState();
}

class _SobeState extends State<_Sobe> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: Duration(milliseconds: 520 + widget.atraso));
  late final Animation<double> a = CurvedAnimation(parent: c, curve: Interval(widget.atraso / (520 + widget.atraso), 1, curve: Curves.easeOutCubic));
  @override
  void initState() {
    super.initState();
    c.forward();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (semAnimacao(context)) return widget.child;
    return AnimatedBuilder(
      animation: a,
      child: widget.child,
      builder: (_, child) => Opacity(opacity: a.value, child: Transform.translate(offset: Offset(0, 26 * (1 - a.value)), child: child)),
    );
  }
}

class _Fato extends StatelessWidget {
  final IconData icone;
  final String titulo, texto;
  const _Fato({required this.icone, required this.titulo, required this.texto});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x33FFFFFF))),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(13)),
            child: Icon(icone, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              Text(texto, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
            ]),
          ),
        ]),
      );
}

class _BarraRetro extends StatelessWidget {
  final String nome;
  final double valor, frac;
  const _BarraRetro({required this.nome, required this.valor, required this.frac});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))),
          Text(brl(valor), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 6),
        Container(
          height: 7,
          decoration: BoxDecoration(color: const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(4)),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: frac.clamp(0.0, 1.0).toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            ),
          ),
        ),
      ]);
}

class _Coluna extends StatelessWidget {
  final String nome;
  final double valor, frac;
  final bool forte;
  const _Coluna({required this.nome, required this.valor, required this.frac, required this.forte});
  @override
  Widget build(BuildContext context) => Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(brl(valor), style: TextStyle(color: Colors.white, fontWeight: forte ? FontWeight.w800 : FontWeight.w600, fontSize: 15))),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: frac.clamp(0.05, 1.0).toDouble()),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Container(
            height: 110 * v,
            decoration: BoxDecoration(color: forte ? Colors.white : const Color(0x59FFFFFF), borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 8),
        Text(nome, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xE6FFFFFF), fontWeight: FontWeight.w600, fontSize: 13.5)),
      ]);
}

/// Bolhas de luz que se movem devagar no fundo.
class _Bolhas extends CustomPainter {
  final double t;
  final Color cor;
  _Bolhas(this.t, this.cor);
  @override
  void paint(Canvas canvas, Size s) {
    void bolha(double fx, double fy, double raio, double fase, Color c) {
      final a = (t + fase) * math.pi * 2;
      final centro = Offset(s.width * fx + math.cos(a) * 26, s.height * fy + math.sin(a) * 34);
      final r = s.width * raio;
      canvas.drawCircle(centro, r, Paint()..shader = RadialGradient(colors: [c, c.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: centro, radius: r)));
    }

    bolha(.92, .10, .62, 0, Colors.white.withValues(alpha: .20));
    bolha(.02, .78, .70, .37, Color.lerp(cor, Colors.white, .35)!.withValues(alpha: .34));
    bolha(.80, .98, .42, .71, Colors.black.withValues(alpha: .22));
  }

  @override
  bool shouldRepaint(_Bolhas o) => o.t != t || o.cor != cor;
}
