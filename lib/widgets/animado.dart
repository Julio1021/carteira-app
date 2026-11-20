// Animações do Início: números que contam, lançamento novo entrando,
// tanque do limite com ondinha, troca de mês arrastando e confete.
// Tudo respeita "reduzir animações" do celular e dura menos de 1 segundo
// (a ondinha do tanque é contínua, mas lenta e discreta).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'site.dart';

/// false quando o celular pede menos animação (ou nos testes).
bool animacoesLigadas(BuildContext context) {
  if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) return false;
  return !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
}

// ───────────────────────── números que contam ─────────────────────────

/// Número que "rola" até o valor (como um placar). Na primeira vez conta a
/// partir de zero; depois, do valor antigo para o novo.
class NumeroAnimado extends StatelessWidget {
  final double valor;
  final String Function(double) formato;
  final TextStyle? style;
  final Duration duracao;
  const NumeroAnimado(this.valor, {super.key, required this.formato, this.style, this.duracao = const Duration(milliseconds: 900)});
  @override
  Widget build(BuildContext context) {
    if (!animacoesLigadas(context)) return Text(formato(valor), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valor),
      duration: duracao,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(formato(v), style: style),
    );
  }
}

// ───────────────────────── lançamento novo entrando ─────────────────────────

/// Ids já mostrados nesta abertura do app (o que aparecer depois é "novo").
final Set<String> _idsVistos = {};
bool _primeiraLista = true;

/// Marca os ids de uma lista; devolve os que são novos desde a última vez.
Set<String> idsNovos(Iterable<String> ids) {
  if (_primeiraLista) {
    _primeiraLista = false;
    _idsVistos.addAll(ids);
    return const {};
  }
  final novos = ids.where((i) => !_idsVistos.contains(i)).toSet();
  _idsVistos.addAll(novos);
  return novos;
}

/// Faz o filho entrar deslizando e crescendo (para o lançamento recém-criado).
class EntradaNova extends StatefulWidget {
  final bool novo;
  final Widget child;
  const EntradaNova({super.key, required this.novo, required this.child});
  @override
  State<EntradaNova> createState() => _EntradaNovaState();
}

class _EntradaNovaState extends State<EntradaNova> with SingleTickerProviderStateMixin {
  late final AnimationController an = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  bool iniciou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (iniciou) return;
    iniciou = true;
    if (widget.novo && animacoesLigadas(context)) {
      an.forward();
    } else {
      an.value = 1;
    }
  }

  @override
  void dispose() {
    an.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CurvedAnimation(parent: an, curve: Curves.easeOutCubic);
    return SizeTransition(
      sizeFactor: c,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: c,
        child: SlideTransition(
          position: Tween(begin: const Offset(.25, 0), end: Offset.zero).animate(c),
          child: AnimatedBuilder(
            animation: an,
            child: widget.child,
            // um brilho rápido de destaque enquanto entra
            builder: (_, ch) => DecoratedBox(
              decoration: BoxDecoration(
                color: S.accent.withValues(alpha: widget.novo ? .12 * (1 - an.value) : 0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ch,
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── tanque do limite ─────────────────────────

/// Reservatório com água: o nível é quanto do limite já foi gasto; a linha
/// tracejada mostra onde você "deveria" estar hoje.
class TanqueLimite extends StatefulWidget {
  final double uso; // 0..1+ (passa de 1 quando estoura)
  final double? hoje; // 0..1 (fração do mês)
  final Color cor;
  final double largura, altura;
  const TanqueLimite({super.key, required this.uso, required this.hoje, required this.cor, this.largura = 86, this.altura = 128});
  @override
  State<TanqueLimite> createState() => _TanqueLimiteState();
}

class _TanqueLimiteState extends State<TanqueLimite> with TickerProviderStateMixin {
  late final AnimationController onda = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  late final AnimationController enche = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool iniciou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (iniciou) return;
    iniciou = true;
    if (animacoesLigadas(context)) {
      onda.repeat();
      enche.forward();
    } else {
      enche.value = 1;
    }
  }

  @override
  void dispose() {
    onda.dispose();
    enche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.uso.clamp(0, 1.08).toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, nivel, __) => AnimatedBuilder(
        animation: Listenable.merge([onda, enche]),
        builder: (_, __) => CustomPaint(
          size: Size(widget.largura, widget.altura),
          painter: _TanquePainter(
            nivel: nivel * Curves.easeOutBack.transform(enche.value).clamp(0, 1.05),
            fase: onda.value * 2 * math.pi,
            hoje: widget.hoje,
            cor: widget.cor,
            vidro: S.surface2,
            borda: S.line,
            texto: S.ink2,
          ),
        ),
      ),
    );
  }
}

class _TanquePainter extends CustomPainter {
  final double nivel, fase;
  final double? hoje;
  final Color cor, vidro, borda, texto;
  _TanquePainter({required this.nivel, required this.fase, required this.hoje, required this.cor, required this.vidro, required this.borda, required this.texto});

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * .28));
    canvas.drawRRect(r, Paint()..color = vidro);
    canvas.save();
    canvas.clipRRect(r);
    final h = size.height;
    final y0 = h * (1 - nivel.clamp(0, 1));
    // duas ondas sobrepostas, a de trás mais clara
    for (final (amp, desloc, alfa) in [(4.5, 1.6, .45), (3.5, 0.0, 1.0)]) {
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= size.width; x += 2) {
        final y = y0 + math.sin(x / size.width * 2 * math.pi + fase + desloc) * (nivel <= 0.001 ? 0 : amp);
        p.lineTo(x, y);
      }
      p
        ..lineTo(size.width, h)
        ..close();
      canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
            Color.lerp(cor, Colors.white, .25)!.withValues(alpha: alfa),
            cor.withValues(alpha: alfa),
          ]).createShader(Rect.fromLTWH(0, y0, size.width, h - y0)),
      );
    }
    // brilho do vidro
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .12, h * .08, size.width * .1, h * .7), const Radius.circular(8)),
      Paint()..color = Colors.white.withValues(alpha: .22),
    );
    canvas.restore();
    canvas.drawRRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = borda);
    // marca de "hoje": onde o gasto deveria estar
    final hj = hoje;
    if (hj != null) {
      final y = h * (1 - hj.clamp(0, 1));
      final tinta = Paint()
        ..color = texto
        ..strokeWidth = 1.6;
      for (var x = -6.0; x < size.width + 6; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width + 6), y), tinta);
      }
      final tp = TextPainter(
        text: TextSpan(text: 'hoje', style: TextStyle(fontFamily: 'Manrope', fontSize: 10, fontWeight: FontWeight.w800, color: texto)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width + 8, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_TanquePainter o) => o.nivel != nivel || o.fase != fase || o.hoje != hoje || o.cor != cor;
}

// ───────────────────────── troca de mês arrastando ─────────────────────────

/// Arrastar para o lado troca o mês; o conteúdo desliza na direção certa.
class TrocaMesArrastando extends StatefulWidget {
  final String ym;
  final void Function(int direcao) aoTrocar; // -1 = mês anterior, +1 = próximo
  final Widget child;
  const TrocaMesArrastando({super.key, required this.ym, required this.aoTrocar, required this.child});
  @override
  State<TrocaMesArrastando> createState() => _TrocaMesArrastandoState();
}

class _TrocaMesArrastandoState extends State<TrocaMesArrastando> {
  double arrasto = 0;
  int direcao = 1;
  late String ymAnt = widget.ym;

  @override
  void didUpdateWidget(TrocaMesArrastando old) {
    super.didUpdateWidget(old);
    if (old.ym != widget.ym) {
      direcao = widget.ym.compareTo(old.ym) > 0 ? 1 : -1;
      ymAnt = old.ym;
    }
  }

  @override
  Widget build(BuildContext context) {
    final anima = animacoesLigadas(context);
    return GestureDetector(
      onHorizontalDragUpdate: (d) => setState(() => arrasto = (arrasto + d.delta.dx).clamp(-80, 80)),
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        final dir = (arrasto < -45 || v < -350) ? 1 : ((arrasto > 45 || v > 350) ? -1 : 0);
        setState(() => arrasto = 0);
        if (dir != 0) {
          HapticFeedback.selectionClick();
          widget.aoTrocar(dir);
        }
      },
      onHorizontalDragCancel: () => setState(() => arrasto = 0),
      child: AnimatedSlide(
        offset: Offset(arrasto / 900, 0),
        duration: Duration(milliseconds: arrasto == 0 ? 220 : 0),
        curve: Curves.easeOutCubic,
        child: !anima
            ? widget.child
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (atual, anteriores) => Stack(alignment: Alignment.topCenter, children: [...anteriores, if (atual != null) atual]),
                transitionBuilder: (ch, a) {
                  final entrando = ch.key == ValueKey(widget.ym);
                  final de = Offset(entrando ? .35 * direcao : -.35 * direcao, 0);
                  return FadeTransition(
                    opacity: a,
                    child: SlideTransition(position: Tween(begin: de, end: Offset.zero).animate(a), child: ch),
                  );
                },
                child: KeyedSubtree(key: ValueKey(widget.ym), child: widget.child),
              ),
      ),
    );
  }
}

// ───────────────────────── confete ─────────────────────────

/// Solta um confete rápido por cima da tela (uma vez).
void soltarConfete(BuildContext context) {
  if (!animacoesLigadas(context)) return;
  final ov = Overlay.maybeOf(context);
  if (ov == null) return;
  late OverlayEntry e;
  e = OverlayEntry(builder: (_) => _Confete(aoFim: () => e.remove()));
  ov.insert(e);
  HapticFeedback.mediumImpact();
}

class _Confete extends StatefulWidget {
  final VoidCallback aoFim;
  const _Confete({required this.aoFim});
  @override
  State<_Confete> createState() => _ConfeteState();
}

class _ConfeteState extends State<_Confete> with SingleTickerProviderStateMixin {
  late final AnimationController an = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..forward().whenComplete(widget.aoFim);
  final rnd = math.Random();
  late final pecas = [
    for (var i = 0; i < 90; i++)
      (
        x: rnd.nextDouble(),
        vx: (rnd.nextDouble() - .5) * .5,
        vy: -(.9 + rnd.nextDouble() * .9),
        giro: rnd.nextDouble() * 12,
        tam: 6 + rnd.nextDouble() * 6,
        cor: [const Color(0xFFF2C94C), const Color(0xFF34C47A), const Color(0xFF4F7BF2), const Color(0xFFE8664F), const Color(0xFFB56CF0), const Color(0xFF2BB3C0)][i % 6],
        atraso: rnd.nextDouble() * .15,
      ),
  ];

  @override
  void dispose() {
    an.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: an,
          builder: (_, __) => CustomPaint(size: MediaQuery.sizeOf(context), painter: _ConfetePainter(pecas, an.value)),
        ),
      );
}

class _ConfetePainter extends CustomPainter {
  final List<({double x, double vx, double vy, double giro, double tam, Color cor, double atraso})> pecas;
  final double t;
  _ConfetePainter(this.pecas, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pecas) {
      final tt = ((t - p.atraso) / (1 - p.atraso)).clamp(0.0, 1.0);
      if (tt <= 0) continue;
      // sobe a partir de baixo e cai com gravidade
      final x = (p.x + p.vx * tt) * size.width;
      final y = size.height * (1.02 + p.vy * tt * 1.1 + 1.25 * tt * tt);
      final alfa = tt > .8 ? (1 - tt) / .2 : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.giro * tt);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.tam, height: p.tam * .55), const Radius.circular(1.5)),
        Paint()..color = p.cor.withValues(alpha: alfa),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfetePainter o) => o.t != t;
}

// ───────────────────────── velocímetro do ritmo ─────────────────────────

/// Cor da faixa do velocímetro: até 90% do ritmo verde, até 115% amarelo, depois vermelho.
Color corRitmo(double r) => r <= .9 ? const Color(0xFF1D9E75) : (r <= 1.15 ? const Color(0xFFEF9F27) : const Color(0xFFE24B4A));
Color corRitmoEscura(double r) => r <= .9 ? const Color(0xFF0F6E56) : (r <= 1.15 ? const Color(0xFF854F0B) : const Color(0xFFA32D2D));

/// Velocímetro clássico: três faixas sólidas e ponteiro grosso. [ritmo] = gasto até
/// hoje ÷ o que caberia gastar até hoje (1 = exatamente no ritmo).
class VelocimetroRitmo extends StatefulWidget {
  final double ritmo;
  final String titulo, sub;
  const VelocimetroRitmo({super.key, required this.ritmo, required this.titulo, required this.sub});
  @override
  State<VelocimetroRitmo> createState() => _VelocimetroRitmoState();
}

class _VelocimetroRitmoState extends State<VelocimetroRitmo> with TickerProviderStateMixin {
  late final AnimationController treme = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  bool liga = false, iniciou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (iniciou) return;
    iniciou = true;
    liga = animacoesLigadas(context);
    if (liga) treme.repeat();
  }

  @override
  void dispose() {
    treme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alvo = widget.ritmo.isFinite ? widget.ritmo.clamp(0.0, 2.0).toDouble() : 0.0;
    return LayoutBuilder(builder: (context, c) {
      final w = math.min(c.maxWidth, 400.0);
      // arco em cima, textos embaixo (o ponteiro nunca passa por cima do número)
      final h = 8 + w * .40 + w * .075 / 2 + 22;
      return Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: liga ? 0 : alvo, end: alvo),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutBack,
          builder: (_, r, __) => AnimatedBuilder(
            animation: treme,
            builder: (_, __) {
              final t = treme.value * 6;
              final tremor = liga ? math.sin(t * 9) * .01 + math.sin(t * 2.3) * .015 : 0.0;
              return SizedBox(
                width: w,
                child: Column(children: [
                  CustomPaint(size: Size(w, h), painter: _VelPainter(r: r, tremor: tremor, marca: S.surface, texto: S.muted, ponteiro: S.escuro ? const Color(0xFFE8E6DF) : const Color(0xFF2C2C2A))),
                  const SizedBox(height: 4),
                  Text(widget.titulo, style: TextStyle(fontFamily: S.fonteNum, fontSize: 26, fontWeight: FontWeight.w800, color: S.escuro ? corRitmo(widget.ritmo) : corRitmoEscura(widget.ritmo), height: 1.15)),
                  const SizedBox(height: 2),
                  Text(widget.sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: S.muted, height: 1.35)),
                ]),
              );
            },
          ),
        ),
      );
    });
  }
}

class _VelPainter extends CustomPainter {
  final double r, tremor;
  final Color marca, texto, ponteiro;
  _VelPainter({required this.r, required this.tremor, required this.marca, required this.texto, required this.ponteiro});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final R = w * .40;
    final esp = w * .075;
    final cx = w / 2, cy = 8 + R + esp / 2;
    double ang(double v) => math.pi + v.clamp(0, 2) / 2 * math.pi;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: R);
    for (final (a, b, cor) in [(0.0, .9, corRitmo(0)), (.9, 1.15, corRitmo(1)), (1.15, 2.0, corRitmo(2))]) {
      canvas.drawArc(rect, ang(a), ang(b) - ang(a), false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = esp
        ..color = cor);
    }
    // separadores das faixas
    final sep = Paint()
      ..color = marca
      ..strokeWidth = 3;
    for (final v in [.9, 1.15]) {
      final a = ang(v);
      canvas.drawLine(Offset(cx + math.cos(a) * (R - esp / 2 - 1), cy + math.sin(a) * (R - esp / 2 - 1)), Offset(cx + math.cos(a) * (R + esp / 2 + 1), cy + math.sin(a) * (R + esp / 2 + 1)), sep);
    }
    // tracinhos
    final tr = Paint()
      ..color = texto
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= 10; i++) {
      final a = math.pi + i / 10 * math.pi;
      final r1 = R - esp / 2 - 6, r2 = R - esp / 2 - (i % 5 == 0 ? 18 : 12);
      tr.strokeWidth = i % 5 == 0 ? 3 : 2;
      canvas.drawLine(Offset(cx + math.cos(a) * r1, cy + math.sin(a) * r1), Offset(cx + math.cos(a) * r2, cy + math.sin(a) * r2), tr);
    }
    // "devagar" e "rápido" nas pontas
    void rot(String t, double x) {
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontFamily: 'Manrope', fontSize: 11.5, color: texto, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, cy + 6));
    }

    rot('devagar', cx - R);
    rot('rápido', cx + R);
    // ponteiro grosso
    final a = ang(r) + tremor;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(a);
    final larg = w * .022;
    final comp = R - esp / 2 - 4;
    final p = Path()
      ..moveTo(0, -larg)
      ..lineTo(comp, -1.5)
      ..lineTo(comp, 1.5)
      ..lineTo(0, larg)
      ..close();
    canvas.drawPath(p, Paint()..color = ponteiro);
    canvas.restore();
    canvas.drawCircle(Offset(cx, cy), larg + 7, Paint()..color = ponteiro);
    canvas.drawCircle(Offset(cx, cy), larg - 1, Paint()..color = marca);
  }

  @override
  bool shouldRepaint(_VelPainter o) => o.r != r || o.tremor != tremor || o.marca != marca || o.ponteiro != ponteiro;
}

// ───────────────────────── tubo deitado ─────────────────────────

/// Tubo de vidro deitado com líquido: quanto do limite já foi usado, a marca de
/// "hoje" (onde o gasto deveria estar) e a escala em reais embaixo.
class TuboLimite extends StatefulWidget {
  final double uso; // 0..1+
  final double? hoje; // 0..1
  final double limite;
  final String? rotuloHoje;
  const TuboLimite({super.key, required this.uso, required this.limite, this.hoje, this.rotuloHoje});
  @override
  State<TuboLimite> createState() => _TuboLimiteState();
}

class _TuboLimiteState extends State<TuboLimite> with SingleTickerProviderStateMixin {
  late final AnimationController onda = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
  bool liga = false, iniciou = false;
  final bolhas = [for (var i = 0; i < 12; i++) (x: (i * 37 % 100) / 100, y: (i * 53 % 100) / 100, r: 1.5 + (i % 4), v: .5 + (i % 3) * .3)];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (iniciou) return;
    iniciou = true;
    liga = animacoesLigadas(context);
    if (liga) onda.repeat();
  }

  @override
  void dispose() {
    onda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hj = widget.hoje;
    final cor = widget.uso > 1 ? const Color(0xFFE24B4A) : (hj == null || widget.uso <= hj + .02 ? const Color(0xFF1D9E75) : const Color(0xFFBA7517));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: liga ? 0 : widget.uso, end: widget.uso),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (_, u, __) => AnimatedBuilder(
        animation: onda,
        builder: (_, __) => SizedBox(
          height: 92,
          child: CustomPaint(
            size: const Size(double.infinity, 92),
            painter: _TuboPainter(
              uso: u,
              hoje: hj,
              limite: widget.limite,
              fase: onda.value * 2 * math.pi,
              cor: cor,
              vidro: S.surface2,
              borda: S.line,
              texto: S.muted,
              tinta: S.ink,
              selo: S.surface,
              rotuloHoje: widget.rotuloHoje ?? 'hoje',
              bolhas: bolhas,
            ),
          ),
        ),
      ),
    );
  }
}

class _TuboPainter extends CustomPainter {
  final double uso, limite, fase;
  final double? hoje;
  final Color cor, vidro, borda, texto, tinta, selo;
  final String rotuloHoje;
  final List<({double x, double y, double r, double v})> bolhas;
  _TuboPainter({required this.uso, required this.hoje, required this.limite, required this.fase, required this.cor, required this.vidro, required this.borda, required this.texto, required this.tinta, required this.selo, required this.rotuloHoje, required this.bolhas});

  String _mil(double v) {
    if (v <= 0) return 'R\$ 0';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1).replaceAll('.', ',').replaceAll(',0', '')} mil';
    return 'R\$ ${v.round()}';
  }

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    const y0 = 22.0, y1 = 56.0;
    const x0 = 2.0;
    final x1 = w - 2;
    final rr = RRect.fromLTRBR(x0, y0, x1, y1, const Radius.circular(17));
    canvas.drawRRect(rr, Paint()..color = vidro);
    canvas.save();
    canvas.clipRRect(rr);
    final fr = uso.clamp(0.0, 1.0);
    final xe = x0 + (x1 - x0) * fr;
    final cheio = uso >= 1;
    final hj = hoje;
    if (hj != null && !cheio) {
      final xh = x0 + (x1 - x0) * hj.clamp(0, 1);
      if (xe < xh) canvas.drawRect(Rect.fromLTRB(xe, y0, xh, y1), Paint()..color = const Color(0xFF1D9E75).withValues(alpha: .10));
      if (xe > xh) canvas.drawRect(Rect.fromLTRB(xh, y0, xe, y1), Paint()..color = const Color(0xFFBA7517).withValues(alpha: .14));
    }
    final claro = Color.lerp(cor, Colors.white, .3)!;
    final escuro = Color.lerp(cor, Colors.black, .25)!;
    for (final (amp, desl, alfa) in [(4.5, 1.8, .5), (3.2, 0.0, 1.0)]) {
      final p = Path()..moveTo(x0 - 4, y0);
      for (var y = y0; y <= y1; y += 2) {
        final wv = cheio || fr <= 0 ? 0.0 : math.sin((y - y0) / (y1 - y0) * 2 * math.pi + fase + desl) * amp;
        p.lineTo(xe + wv, y);
      }
      p
        ..lineTo(x0 - 4, y1)
        ..close();
      canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [claro.withValues(alpha: alfa), (alfa < 1 ? claro : escuro).withValues(alpha: alfa)])
              .createShader(Rect.fromLTRB(0, y0, w, y1)),
      );
    }
    // bolhas indo para trás
    final pb = Paint()..color = Colors.white.withValues(alpha: .5);
    for (final b in bolhas) {
      final x = x0 + 10 + ((b.x - fase / (2 * math.pi) * b.v * .3) % 1) * (xe - x0 - 22);
      final y = y0 + 6 + b.y * (y1 - y0 - 12) + math.sin(fase * 2 + b.x * 9) * 1.5;
      if (x < xe - 8 && x > x0 + 6) canvas.drawCircle(Offset(x, y), b.r, pb);
    }
    // reflexo do vidro
    canvas.drawRRect(RRect.fromLTRBR(x0 + 14, y0 + 5, x1 - 14, y0 + 9, const Radius.circular(3)), Paint()..color = Colors.white.withValues(alpha: .35));
    if (uso > 1) canvas.drawRect(Rect.fromLTRB(x0, y0, x1, y1), Paint()..color = const Color(0xFFE24B4A).withValues(alpha: .10 + .08 * math.sin(fase * 2)));
    canvas.restore();
    canvas.drawRRect(rr, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = borda);
    // escala em reais
    for (final q in [0.0, .25, .5, .75, 1.0]) {
      final x = x0 + 17 + (x1 - x0 - 34) * q;
      canvas.drawLine(Offset(x, y1 + 4), Offset(x, y1 + (q == .5 || q == 0 || q == 1 ? 10 : 7)), Paint()
        ..color = texto
        ..strokeWidth = 1.5);
      final tp = TextPainter(text: TextSpan(text: _mil(limite * q), style: TextStyle(fontFamily: 'Manrope', fontSize: 10.5, color: texto)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset((x - tp.width / 2).clamp(0, w - tp.width), y1 + 13));
    }
    // marca de hoje
    if (hj != null) {
      final xh = x0 + (x1 - x0) * hj.clamp(0, 1);
      final dash = Paint()
        ..color = tinta
        ..strokeWidth = 2;
      for (var y = y0 - 2; y < y1 + 2; y += 6) {
        canvas.drawLine(Offset(xh, y), Offset(xh, math.min(y + 3.5, y1 + 2)), dash);
      }
      canvas.drawPath(Path()
        ..moveTo(xh - 5, y0 - 9)
        ..lineTo(xh + 5, y0 - 9)
        ..lineTo(xh, y0 - 2)
        ..close(), Paint()..color = tinta);
      final tp = TextPainter(text: TextSpan(text: rotuloHoje, style: TextStyle(fontFamily: 'Manrope', fontSize: 11, fontWeight: FontWeight.w800, color: tinta)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset((xh - tp.width / 2).clamp(0, w - tp.width), y0 - 22));
    }
    // selo com a % que acompanha a ponta da água
    final pct = '${(uso * 100).round()}%';
    final tp = TextPainter(text: TextSpan(text: pct, style: TextStyle(fontFamily: 'Bricolage', fontSize: 15, fontWeight: FontWeight.w800, color: escuro)), textDirection: TextDirection.ltr)..layout();
    final sw = tp.width + 16;
    var sx = (xe - sw - 10).clamp(x0 + 6, x1 - sw - 6).toDouble();
    if (xe - x0 < sw + 22) sx = (xe + 8).clamp(x0 + 6, x1 - sw - 6).toDouble();
    final sy = (y0 + y1) / 2 - 11;
    canvas.drawRRect(RRect.fromLTRBR(sx, sy, sx + sw, sy + 22, const Radius.circular(11)), Paint()..color = selo.withValues(alpha: .9));
    tp.paint(canvas, Offset(sx + 8, sy + 11 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_TuboPainter o) => o.uso != uso || o.fase != fase || o.cor != cor || o.hoje != hoje || o.vidro != vidro;
}
