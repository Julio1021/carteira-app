// Animação de abertura: a carteira surge, moedas caem dentro dela, o gráfico do
// seu patrimônio cresce acima e tudo vira o ícone do cabeçalho.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dados/patrimonio.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';

/// Preferências da abertura (Ajustes → Abertura).
final aberturaLigada = ValueNotifier<bool>(true);
final aberturaValor = ValueNotifier<bool>(false);

Future<void> carregarAbertura() async {
  try {
    final sp = await SharedPreferences.getInstance();
    aberturaLigada.value = sp.getBool('abertura') ?? true;
    aberturaValor.value = sp.getBool('aberturaValor') ?? false;
  } catch (_) {}
}

Future<void> definirAbertura({bool? ligada, bool? valor}) async {
  if (ligada != null) aberturaLigada.value = ligada;
  if (valor != null) aberturaValor.value = valor;
  try {
    final sp = await SharedPreferences.getInstance();
    if (ligada != null) await sp.setBool('abertura', ligada);
    if (valor != null) await sp.setBool('aberturaValor', valor);
  } catch (_) {}
}

/// Pontos do gráfico (0..1) a partir da evolução do patrimônio; null sem dados.
List<double>? curvaDoPatrimonio(Carteira c) {
  final ts = c.dias.map((d) => d.total).where((v) => v.isFinite).toList();
  if (ts.length < 3) return null;
  const n = 14;
  final amostra = [for (var i = 0; i < n; i++) ts[(i * (ts.length - 1) / (n - 1)).round()]];
  final mn = amostra.reduce(math.min), mx = amostra.reduce(math.max);
  if (mx - mn < 1) return null;
  return [for (final v in amostra) (v - mn) / (mx - mn)];
}

class Abertura extends StatefulWidget {
  final VoidCallback onFim;
  /// Só para prints: para a animação neste ponto (0..1).
  final double? congelar;
  const Abertura({super.key, required this.onFim, this.congelar});
  @override
  State<Abertura> createState() => _AberturaState();
}

class _AberturaState extends State<Abertura> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));
  bool vibrou = false;

  @override
  void initState() {
    super.initState();
    if (widget.congelar != null) {
      c.value = widget.congelar!;
      return;
    }
    c.addListener(() {
      if (!vibrou && c.value > .6) {
        vibrou = true;
        HapticFeedback.lightImpact();
      }
    });
    c.forward().whenComplete(widget.onFim);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _pular() {
    if (widget.congelar != null) return;
    if (c.value < .76) {
      c.animateTo(1, duration: const Duration(milliseconds: 380), curve: Curves.easeIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final cart = calcularCarteira(repo);
    final curva = curvaDoPatrimonio(cart);
    final total = cart.total;
    final mostrarValor = aberturaValor.value && total > 0;
    final mq = MediaQuery.of(context);
    // onde está o ícone do cabeçalho
    final alvo = Rect.fromLTWH(12, mq.padding.top + 6, 38, 38);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pular,
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final t = c.value;
          double fase(double a, double b, [Curve cv = Curves.linear]) => cv.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
          final saida = fase(.76, 1, Curves.easeInOutCubic);
          final lado = math.min(mq.size.width * .46, 190.0);
          final centro = Rect.fromCenter(center: Offset(mq.size.width / 2, mq.size.height * .42), width: lado, height: lado);
          final r = Rect.lerp(centro, alvo, saida)!;
          final surgir = fase(0, .2, Curves.easeOutBack);
          final textoOp = fase(.5, .64) * (1 - fase(.76, .86));
          return Stack(children: [
            Positioned.fill(child: ColoredBox(color: G.fundo.withValues(alpha: 1 - fase(.82, 1)))),
            Positioned.fromRect(
              rect: r,
              child: Opacity(
                opacity: fase(0, .08),
                child: Transform.scale(
                  scale: .4 + .6 * surgir,
                  child: CustomPaint(painter: _Carteira(t: t, curva: curva)),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: centro.bottom + 18,
              child: Opacity(
                opacity: textoOp,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - fase(.5, .64, Curves.easeOut))),
                  child: Column(children: [
                    Text('Diário da Carteira', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: G.texto, letterSpacing: -.3)),
                    const SizedBox(height: 4),
                    if (mostrarValor)
                      Text(brl(total * fase(.5, .72, Curves.easeOutCubic)), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: G.pos, fontFeatures: const [FontFeature.tabularFigures()]))
                    else
                      Text('seu patrimônio em evolução', style: TextStyle(fontSize: 13.5, color: G.apagado, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// Desenha o ícone (mesmo desenho do assets/icone.png) em quadros.
class _Carteira extends CustomPainter {
  final double t;
  final List<double>? curva;
  _Carteira({required this.t, required this.curva});

  double _f(double a, double b, [Curve cv = Curves.linear]) => cv.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 512;
    canvas.save();
    canvas.scale(s);
    final fundo = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 512, 512), const Radius.circular(116));
    canvas.drawRRect(
      fundo,
      Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4A66EA), Color(0xFF121852)]).createShader(const Rect.fromLTWH(0, 0, 512, 512)),
    );

    // moedas caindo de cima da tela para dentro da carteira (somem atrás dela)
    const moedas = [(x: 190.0, ini: .08), (x: 268.0, ini: .17), (x: 228.0, ini: .26)];
    var tranco = 0.0;
    for (final m in moedas) {
      final p = _f(m.ini, m.ini + .14, Curves.easeInQuad);
      if (p <= 0 || p >= 1) {
        if (p >= 1) tranco = math.max(tranco, 1 - _f(m.ini + .14, m.ini + .2));
        continue;
      }
      final y = -420 + (290 - -420) * p;
      final giro = math.cos(p * math.pi * 2).abs() * .45 + .55;
      final op = (1 - _f(m.ini + .12, m.ini + .14)).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(m.x, y);
      canvas.scale(giro, 1);
      canvas.drawCircle(Offset.zero, 46, Paint()..color = const Color(0xFFD69A2D).withValues(alpha: op));
      canvas.drawCircle(Offset.zero, 36, Paint()..color = const Color(0xFFF5C26B).withValues(alpha: op));
      final tp = TextPainter(
        text: const TextSpan(text: r'$', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Color(0xFFB07A1E))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    canvas.clipRRect(fundo);
    // carteira (dá um pulinho quando a moeda cai)
    final dy = -10 * math.sin(tranco * math.pi);
    canvas.save();
    canvas.translate(0, dy);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(113, 220, 286, 174), const Radius.circular(38)), Paint()..color = const Color(0xFFDEE4FF));
    canvas.drawRRect(
      RRect.fromRectAndCorners(const Rect.fromLTWH(113, 259, 286, 135), bottomLeft: const Radius.circular(38), bottomRight: const Radius.circular(38)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(297, 284, 113, 56), const Radius.circular(26)), Paint()..color = const Color(0xFFCBD4FF));
    canvas.drawCircle(const Offset(335, 312), 11, Paint()..color = const Color(0xFF182068));
    canvas.restore();

    // gráfico crescendo acima da carteira
    final pts = <Offset>[];
    final c = curva;
    if (c != null) {
      for (var i = 0; i < c.length; i++) {
        pts.add(Offset(130 + (348 - 130) * i / (c.length - 1), 190 - 92 * c[i]));
      }
    } else {
      pts.addAll(const [Offset(144, 182), Offset(212, 134), Offset(264, 168), Offset(348, 106)]);
    }
    final linha = _f(.42, .64, Curves.easeOutCubic);
    if (linha > 0) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      final m = path.computeMetrics().first;
      final parcial = m.extractPath(0, m.length * linha);
      canvas.drawPath(
        parcial,
        Paint()
          ..color = const Color(0xFF5EE6A8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      // ponto verde no topo
      final pop = _f(.62, .7, Curves.elasticOut);
      if (pop > 0) {
        final fim = pts.last + const Offset(10, -6);
        canvas.drawCircle(fim, 23 * pop, Paint()..color = const Color(0xFF5EE6A8));
        canvas.drawCircle(fim, 10 * pop, Paint()..color = Colors.white);
        final halo = _f(.64, .8);
        if (halo > 0 && halo < 1) {
          canvas.drawCircle(
            fim,
            22 + 40 * halo,
            Paint()
              ..color = const Color(0xFF5EE6A8).withValues(alpha: .5 * (1 - halo))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Carteira old) => old.t != t || old.curva != curva;
}
