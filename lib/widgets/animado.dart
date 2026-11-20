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
