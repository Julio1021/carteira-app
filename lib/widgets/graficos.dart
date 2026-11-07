import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema.dart';

/// Gráfico de linhas simples, desenhado à mão (sem bibliotecas).
class GraficoLinha extends StatelessWidget {
  final List<List<double>> series;
  final List<Color> cores;
  final List<bool> tracejada;
  final List<String> rotulosX; // poucos rótulos espalhados pelo eixo
  final String Function(double) formatoY;
  final double altura;
  final bool preencherPrimeira;
  const GraficoLinha({
    super.key,
    required this.series,
    required this.cores,
    required this.formatoY,
    this.tracejada = const [],
    this.rotulosX = const [],
    this.altura = 190,
    this.preencherPrimeira = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altura,
      child: CustomPaint(painter: _PintorLinha(series, cores, tracejada, rotulosX, formatoY, preencherPrimeira), size: Size.infinite),
    );
  }
}

class _PintorLinha extends CustomPainter {
  final List<List<double>> series;
  final List<Color> cores;
  final List<bool> tracejada;
  final List<String> rotulosX;
  final String Function(double) fy;
  final bool preencher;
  _PintorLinha(this.series, this.cores, this.tracejada, this.rotulosX, this.fy, this.preencher);

  @override
  void paint(Canvas canvas, Size size) {
    final todos = series.expand((s) => s).where((v) => v.isFinite).toList();
    if (todos.isEmpty) return;
    var mn = todos.reduce(math.min), mx = todos.reduce(math.max);
    if (mx - mn < 1e-9) {
      mx += 1;
      mn -= 1;
    }
    final pad = (mx - mn) * .08;
    mn -= pad;
    mx += pad;
    const esq = 56.0, baixo = 20.0, topo = 6.0;
    final w = size.width - esq - 4, h = size.height - baixo - topo;
    final grade = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var k = 0; k <= 3; k++) {
      final v = mn + (mx - mn) * k / 3;
      final y = topo + h - h * k / 3;
      canvas.drawLine(Offset(esq, y), Offset(esq + w, y), grade);
      tp.text = TextSpan(text: fy(v), style: const TextStyle(color: G.apagado, fontSize: 10));
      tp.layout(maxWidth: esq - 6);
      tp.paint(canvas, Offset(esq - 6 - tp.width, y - tp.height / 2));
    }
    for (var i = 0; i < rotulosX.length; i++) {
      final x = rotulosX.length == 1 ? esq + w / 2 : esq + w * i / (rotulosX.length - 1);
      tp.text = TextSpan(text: rotulosX[i], style: const TextStyle(color: G.apagado, fontSize: 10));
      tp.layout();
      final dx = (x - tp.width / 2).clamp(esq, esq + w - tp.width).toDouble();
      tp.paint(canvas, Offset(dx, topo + h + 5));
    }
    for (var s = series.length - 1; s >= 0; s--) {
      final pts = series[s];
      if (pts.length < 2) continue;
      final path = Path();
      for (var i = 0; i < pts.length; i++) {
        final x = esq + w * i / (pts.length - 1);
        final y = topo + h - (pts[i] - mn) / (mx - mn) * h;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final cor = cores[s % cores.length];
      if (s == 0 && preencher) {
        final area = Path.from(path)
          ..lineTo(esq + w, topo + h)
          ..lineTo(esq, topo + h)
          ..close();
        canvas.drawPath(
          area,
          Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [cor.withValues(alpha: .28), cor.withValues(alpha: 0)]).createShader(Rect.fromLTWH(esq, topo, w, h)),
        );
      }
      final p = Paint()
        ..color = cor
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      if (s < tracejada.length && tracejada[s]) {
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 9) {
            canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), p..strokeWidth = 1.8);
          }
        }
      } else {
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PintorLinha o) => o.series != series;
}

/// Rosca (donut) com o total no meio.
class Rosca extends StatelessWidget {
  final List<double> valores;
  final List<Color> cores;
  final String centro, sub;
  final double tam;
  const Rosca({super.key, required this.valores, required this.cores, required this.centro, this.sub = '', this.tam = 170});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tam,
      height: tam,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: Size(tam, tam), painter: _PintorRosca(valores, cores)),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(centro, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (sub.isNotEmpty) Text(sub, style: const TextStyle(color: G.apagado, fontSize: 11.5)),
        ]),
      ]),
    );
  }
}

class _PintorRosca extends CustomPainter {
  final List<double> v;
  final List<Color> c;
  _PintorRosca(this.v, this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final tot = v.fold<double>(0, (a, b) => a + (b > 0 ? b : 0));
    final r = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 12);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.butt;
    if (tot <= 0) {
      canvas.drawArc(r, 0, math.pi * 2, false, p..color = const Color(0x1FFFFFFF));
      return;
    }
    var ini = -math.pi / 2;
    const folga = .035;
    for (var i = 0; i < v.length; i++) {
      if (v[i] <= 0) continue;
      final ang = v[i] / tot * math.pi * 2;
      canvas.drawArc(r, ini + folga / 2, math.max(.001, ang - folga), false, p..color = c[i % c.length]);
      ini += ang;
    }
  }

  @override
  bool shouldRepaint(covariant _PintorRosca o) => o.v != v;
}

/// Valor curto para eixos: 1,2 mil · 3,4 mi.
String curto(double v) {
  final a = v.abs();
  String f(double x) => x.toStringAsFixed(x >= 100 ? 0 : 1).replaceAll('.', ',');
  if (a >= 1e6) return '${v < 0 ? '-' : ''}${f(a / 1e6)} mi';
  if (a >= 1e3) return '${v < 0 ? '-' : ''}${f(a / 1e3)} mil';
  return v.toStringAsFixed(0);
}
