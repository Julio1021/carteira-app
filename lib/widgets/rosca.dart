// Gráfico de rosca moderno: fatias com pontas arredondadas e um respiro entre
// elas (fatias pequenas viram "pílulas"), entrada animada e toque por fatia.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'site.dart';

class RoscaModerna extends StatefulWidget {
  final List<double> valores;
  final List<Color> cores;
  final double tam;

  /// Espessura do anel, em fração do raio (0,2 = 20%).
  final double espessura;

  /// Fatia em destaque controlada por fora (opcional).
  final int? selecionado;
  final ValueChanged<int?>? onToque;

  /// true: a fatia destacada vem só de [selecionado] (quem usa guarda o estado).
  final bool controlado;

  /// Conteúdo do meio; recebe a fatia tocada (ou null).
  final Widget Function(int? sel)? centro;

  const RoscaModerna({
    super.key,
    required this.valores,
    required this.cores,
    this.tam = 200,
    this.espessura = .19,
    this.selecionado,
    this.onToque,
    this.controlado = false,
    this.centro,
  });

  @override
  State<RoscaModerna> createState() => _RoscaModernaState();
}

class _RoscaModernaState extends State<RoscaModerna> with SingleTickerProviderStateMixin {
  late final AnimationController an = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int? toque;
  List<(double ini, double fim)> faixas = const [];

  int? get sel => widget.controlado ? widget.selecionado : toque;

  @override
  void initState() {
    super.initState();
    final semAnim = WidgetsBinding.instance.runtimeType.toString().contains('Test') || WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (semAnim) {
      an.value = 1;
    } else {
      an.forward();
    }
  }

  @override
  void didUpdateWidget(RoscaModerna old) {
    super.didUpdateWidget(old);
    if (old.valores.length != widget.valores.length) toque = null;
  }

  @override
  void dispose() {
    an.dispose();
    super.dispose();
  }

  void _tocar(Offset p) {
    final r = widget.tam / 2;
    final c = Offset(r, r);
    final d = (p - c).distance;
    final esp = r * widget.espessura;
    int? achou;
    if (d >= r - esp * 2.2 && d <= r + 6) {
      var ang = math.atan2(p.dy - c.dy, p.dx - c.dx) + math.pi / 2;
      if (ang < 0) ang += 2 * math.pi;
      for (var i = 0; i < faixas.length; i++) {
        final (a, b) = faixas[i];
        if (ang >= a && ang <= b) achou = i;
      }
      // toque no respiro entre duas fatias: pega a mais próxima
      if (achou == null && faixas.isNotEmpty) {
        var melhor = 9.0;
        for (var i = 0; i < faixas.length; i++) {
          final (a, b) = faixas[i];
          final m = (ang - (a + b) / 2).abs();
          if (m < melhor) {
            melhor = m;
            achou = i;
          }
        }
      }
    }
    final novo = achou == sel ? null : achou;
    setState(() => toque = novo);
    widget.onToque?.call(novo);
  }

  @override
  Widget build(BuildContext context) {
    final tam = widget.tam;
    return SizedBox(
      width: tam,
      height: tam,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _tocar(d.localPosition),
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: an,
            builder: (_, __) => CustomPaint(
              size: Size(tam, tam),
              painter: _RoscaPainter(
                valores: widget.valores,
                cores: widget.cores,
                espessura: widget.espessura,
                progresso: Curves.easeOutCubic.transform(an.value),
                sel: sel,
                vazio: S.line,
                aoMedir: (f) => faixas = f,
              ),
            ),
          ),
          if (widget.centro != null)
            Padding(
              padding: EdgeInsets.all(tam * (widget.espessura + .12)),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .9, end: 1.0).animate(a), child: c)),
                child: KeyedSubtree(key: ValueKey(sel), child: widget.centro!(sel)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _RoscaPainter extends CustomPainter {
  final List<double> valores;
  final List<Color> cores;
  final double espessura, progresso;
  final int? sel;
  final Color vazio;
  final void Function(List<(double, double)>) aoMedir;
  _RoscaPainter({required this.valores, required this.cores, required this.espessura, required this.progresso, required this.sel, required this.vazio, required this.aoMedir});

  @override
  void paint(Canvas canvas, Size size) {
    final r0 = size.width / 2;
    final esp = r0 * espessura;
    final r = r0 - esp / 2 - 3; // folga para a fatia destacada crescer
    final c = Offset(r0, r0);
    final idx = [for (var i = 0; i < valores.length; i++) if (valores[i] > 0) i];
    final tot = idx.fold<double>(0, (a, i) => a + valores[i]);
    final rect = Rect.fromCircle(center: c, radius: r);
    if (tot <= 0) {
      canvas.drawCircle(c, r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = esp
        ..color = vazio);
      aoMedir(const []);
      return;
    }
    final circ = 2 * math.pi * r;
    // respiro visível entre fatias (as pontas arredondadas ocupam esp/2 de cada lado)
    final gap = math.max(4.0, esp * .35);
    final n = idx.length;
    final util = circ - n * gap;
    final minL = esp * 1.05; // fatia minúscula ainda aparece como uma pílula
    // comprimento de cada fatia, garantindo o mínimo e redistribuindo o resto
    final fr = [for (final i in idx) valores[i] / tot];
    final comp = List<double>.filled(n, 0);
    var restante = util;
    var somaFr = 1.0;
    final fixos = <int>{};
    for (var it = 0; it < 3; it++) {
      for (var k = 0; k < n; k++) {
        if (fixos.contains(k)) continue;
        final l = restante * fr[k] / somaFr;
        if (l < minL) {
          fixos.add(k);
          comp[k] = minL;
        }
      }
      restante = util - fixos.length * minL;
      somaFr = [for (var k = 0; k < n; k++) if (!fixos.contains(k)) fr[k]].fold<double>(0, (a, b) => a + b);
      if (somaFr <= 0) break;
    }
    for (var k = 0; k < n; k++) {
      if (!fixos.contains(k)) comp[k] = restante * fr[k] / somaFr;
    }
    if (n == 1) comp[0] = circ; // uma fatia só: anel inteiro
    final limite = 2 * math.pi * progresso;
    var ang = 0.0; // a partir do topo
    final faixas = <(double, double)>[];
    for (var k = 0; k < n; k++) {
      final i = idx[k];
      final sweepTot = comp[k] / r;
      final ini = ang + (n == 1 ? 0 : gap / 2 / r);
      faixas.add((ang, ang + sweepTot + (n == 1 ? 0 : gap / r)));
      // tira das pontas o raio do arredondamento, para o respiro ficar visível
      final capAng = n == 1 ? 0.0 : (esp / 2) / r;
      var a0 = ini + capAng;
      var sweep = math.max(0.0001, sweepTot - 2 * capAng);
      if (a0 > limite) {
        ang += sweepTot + (n == 1 ? 0 : gap / r);
        continue;
      }
      sweep = math.min(sweep, math.max(0.0001, limite - a0));
      final destaque = sel == i;
      final apagada = sel != null && !destaque;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = n == 1 ? StrokeCap.butt : StrokeCap.round
        ..strokeWidth = destaque ? esp + 6 : esp
        ..color = cores[i % cores.length].withValues(alpha: apagada ? .28 : 1);
      if (n == 1) {
        canvas.drawArc(rect, -math.pi / 2, sweep, false, p);
      } else {
        canvas.drawArc(rect, -math.pi / 2 + a0, sweep, false, p);
      }
      ang += sweepTot + (n == 1 ? 0 : gap / r);
    }
    aoMedir(faixas);
  }

  @override
  bool shouldRepaint(_RoscaPainter o) => o.progresso != progresso || o.sel != sel || o.valores != valores || o.cores != cores || o.vazio != vazio;
}

/// Centro padrão: rótulo pequeno em cima e valor grande embaixo (encolhe para caber).
class CentroRosca extends StatelessWidget {
  final String rotulo, valor;
  final String? sub;
  final Color? cor;
  const CentroRosca({super.key, required this.rotulo, required this.valor, this.sub, this.cor});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(rotulo, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: S.muted, height: 1.2)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(valor, style: TextStyle(fontFamily: S.fonteNum, fontSize: 22, fontWeight: FontWeight.w800, color: cor ?? S.ink)),
        ),
        if (sub != null) Text(sub!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: S.muted)),
      ]);
}
