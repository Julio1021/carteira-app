// Pequenas animações usadas no app inteiro: entrada em sequência, toque que
// "afunda", números que contam e a confirmação de lançamento.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tema.dart';
import '../util/fmt.dart';

/// true quando o celular pede menos animação.
bool semAnimacao(BuildContext c) => MediaQuery.maybeOf(c)?.disableAnimations ?? false;

/// Faz o filho surgir subindo de leve; [ordem] atrasa um pouco cada item.
class Surge extends StatefulWidget {
  final Widget child;
  final int ordem;
  const Surge({super.key, required this.child, this.ordem = 0});
  @override
  State<Surge> createState() => _SurgeState();
}

class _SurgeState extends State<Surge> with SingleTickerProviderStateMixin {
  late final AnimationController c;
  late final Animation<double> a;

  @override
  void initState() {
    super.initState();
    final atraso = (widget.ordem.clamp(0, 8)) * 55;
    final total = 420 + atraso;
    c = AnimationController(vsync: this, duration: Duration(milliseconds: total));
    a = CurvedAnimation(parent: c, curve: Interval(atraso / total, 1, curve: Curves.easeOutCubic));
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
      builder: (_, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, 18 * (1 - a.value)), child: child),
      ),
    );
  }
}

/// Encolhe um pouco enquanto o dedo está em cima (resposta ao toque).
class Toque extends StatefulWidget {
  final Widget child;
  final double escala;
  const Toque({super.key, required this.child, this.escala = .97});
  @override
  State<Toque> createState() => _ToqueState();
}

class _ToqueState extends State<Toque> {
  bool baixo = false;
  void _set(bool v) {
    if (baixo != v) setState(() => baixo = v);
  }

  @override
  Widget build(BuildContext context) {
    // no computador, mostra a "mãozinha" ao passar o mouse
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: baixo ? widget.escala : 1,
        duration: Duration(milliseconds: baixo ? 90 : 220),
        curve: baixo ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    ),
    );
  }
}

/// Valor em reais que conta do número anterior até o novo.
class ValorAnimado extends StatelessWidget {
  final double valor;
  final TextStyle? estilo;
  final bool sinal;
  final String Function(double)? formato;
  const ValorAnimado(this.valor, {super.key, this.estilo, this.sinal = false, this.formato});
  @override
  Widget build(BuildContext context) {
    final f = formato ?? (double v) => brl(v, sinal: sinal);
    if (semAnimacao(context)) return Text(f(valor), style: estilo, maxLines: 1);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: valor),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(f(v), style: estilo?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]), maxLines: 1),
    );
  }
}

/// Mostra um "check" animado no meio da tela (depois de lançar algo).
void mostrarConfirmacao(BuildContext context, {Color? cor, IconData icone = Icons.check_rounded}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  HapticFeedback.mediumImpact();
  late OverlayEntry e;
  e = OverlayEntry(builder: (_) => _Check(cor: cor ?? G.pos, icone: icone, onFim: () => e.remove()));
  overlay.insert(e);
}

class _Check extends StatefulWidget {
  final Color cor;
  final IconData icone;
  final VoidCallback onFim;
  const _Check({required this.cor, required this.icone, required this.onFim});
  @override
  State<_Check> createState() => _CheckState();
}

class _CheckState extends State<_Check> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  @override
  void initState() {
    super.initState();
    c.forward().whenComplete(widget.onFim);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: c,
        builder: (_, __) {
          final t = c.value;
          final entra = Curves.elasticOut.transform((t / .45).clamp(0.0, 1.0));
          final sai = Curves.easeIn.transform(((t - .7) / .3).clamp(0.0, 1.0));
          final anel = Curves.easeOut.transform((t / .6).clamp(0.0, 1.0));
          return Center(
            child: Opacity(
              opacity: 1 - sai,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 96 + 70 * anel,
                  height: 96 + 70 * anel,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.cor.withValues(alpha: .45 * (1 - anel)), width: 4)),
                ),
                Transform.scale(
                  scale: .3 + .7 * entra,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.cor,
                      boxShadow: [BoxShadow(color: widget.cor.withValues(alpha: .45), blurRadius: 30, spreadRadius: -6)],
                    ),
                    child: Icon(widget.icone, color: Colors.white, size: 54),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Faz os itens de uma lista surgirem em sequência (espaçadores ficam como estão).
List<Widget> emSequencia(List<Widget> itens) {
  var o = 0;
  return [for (final w in itens) w is SizedBox || w is Divider ? w : Surge(ordem: o++, child: w)];
}
