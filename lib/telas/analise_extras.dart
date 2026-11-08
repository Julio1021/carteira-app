// Extras visuais da Análise: destaques em frases, fluxo do dinheiro e
// calendário de calor dos gastos.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dados/analise.dart';
import '../dados/categorias.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';

// =====================================================================
// Destaques
// =====================================================================

class DestaquesMes extends StatelessWidget {
  final String ym;
  const DestaquesMes({super.key, required this.ym});
  @override
  Widget build(BuildContext context) {
    final ds = destaquesDoMes(RepoScope.of(context), ym);
    if (ds.isEmpty) return const SizedBox.shrink();
    IconData ic(String t) => switch (t) {
          'maior' => Icons.shopping_bag_outlined,
          'sobe' => Icons.trending_up_rounded,
          'desce' => Icons.trending_down_rounded,
          'semgasto' => Icons.event_available_rounded,
          'semana' => Icons.calendar_view_week_rounded,
          'invest' => Icons.savings_outlined,
          _ => Icons.auto_awesome_rounded,
        };
    Color cor(int tom) => tom > 0 ? G.pos : (tom < 0 ? G.alerta : G.lavanda);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Cartao(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CabecalhoCartao('Destaques do mês'),
          for (var i = 0; i < ds.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: cor(ds[i].tom).withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
                  child: Icon(ic(ds[i].tipo), size: 18, color: cor(ds[i].tom)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: ds[i].antes),
                        TextSpan(text: ds[i].forte, style: TextStyle(fontWeight: FontWeight.w700, color: ds[i].tom == 0 ? G.texto : cor(ds[i].tom))),
                        TextSpan(text: ds[i].depois),
                      ]),
                      style: TextStyle(color: G.texto2, fontSize: 14, height: 1.35),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// =====================================================================
// Fluxo do dinheiro
// =====================================================================

class _No {
  final String nome;
  final double valor;
  final Color cor;
  _No(this.nome, this.valor, this.cor);
}

class FluxoDinheiro extends StatelessWidget {
  final ResumoMes r;
  const FluxoDinheiro({super.key, required this.r});
  @override
  Widget build(BuildContext context) {
    final cats = r.porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final destinos = <_No>[];
    final top = cats.take(4).toList();
    for (final e in top) {
      final c = catGasto(e.key);
      destinos.add(_No(c.nome, e.value, c.cor));
    }
    final resto = cats.skip(4).fold<double>(0, (t, e) => t + e.value);
    if (resto > 0) destinos.add(_No('Outros gastos', resto, G.apagado));
    if (r.investiu > 0) destinos.add(_No('Investido', r.investiu, G.lavanda));
    final ficou = r.entrou - r.saiu - (r.investiu > 0 ? r.investiu : 0);
    if (ficou > 0) destinos.add(_No('Ficou em conta', ficou, G.pos));
    final saidas = destinos.fold<double>(0, (t, n) => t + n.valor);
    if (saidas <= 0 || r.entrou <= 0) return const SizedBox.shrink();
    final origens = <_No>[_No('Entrou', r.entrou, G.pos)];
    if (saidas > r.entrou + .5) origens.add(_No('Do saldo', saidas - r.entrou, G.alerta));
    final altura = math.max(190.0, destinos.length * 40.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Cartao(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CabecalhoCartao('Para onde foi o que entrou', sub: 'Cada faixa tem a largura do valor'),
          SizedBox(
            height: altura,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, t, __) => CustomPaint(
                size: Size.infinite,
                painter: _PintorFluxo(origens: origens, destinos: destinos, t: t, texto: G.texto, apagado: G.apagado),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PintorFluxo extends CustomPainter {
  final List<_No> origens, destinos;
  final double t;
  final Color texto, apagado;
  _PintorFluxo({required this.origens, required this.destinos, required this.t, required this.texto, required this.apagado});

  void _rotulo(Canvas c, String a, String b, Offset pos, {bool direita = false, double maxW = 120}) {
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(text: '$a\n', style: TextStyle(color: texto, fontSize: 11.5, fontWeight: FontWeight.w600)),
        TextSpan(text: b, style: TextStyle(color: apagado, fontSize: 10.5)),
      ]),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
      textAlign: direita ? TextAlign.right : TextAlign.left,
    )..layout(maxWidth: maxW);
    tp.paint(c, Offset(direita ? pos.dx - tp.width : pos.dx, pos.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final total = destinos.fold<double>(0, (s, n) => s + n.valor);
    const gap = 6.0, barW = 10.0, rotE = 74.0, rotD = 118.0;
    final hD = size.height - gap * (destinos.length - 1);
    final hO = size.height - gap * (origens.length - 1);
    final xE = rotE, xD = size.width - rotD;
    // colunas da esquerda (origens)
    var y = 0.0;
    final origemY = <double>[];
    for (final o in origens) {
      final h = hO * o.valor / total;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(xE - barW, y, barW, h), const Radius.circular(4)), Paint()..color = o.cor);
      _rotulo(canvas, o.nome, brl(o.valor), Offset(xE - barW - 6, y + h / 2), direita: true, maxW: rotE - barW - 8);
      origemY.add(y);
      y += h + gap;
    }
    // faixas: preenchem as origens em ordem
    var oi = 0;
    var ocupado = 0.0; // quanto da origem atual já foi usado (em valor)
    var yd = 0.0;
    for (final d in destinos) {
      final hd = hD * d.valor / total;
      var resta = d.valor, yDest = yd;
      while (resta > .001 && oi < origens.length) {
        final livre = origens[oi].valor - ocupado;
        final usa = math.min(livre, resta);
        final yO = origemY[oi] + hO * ocupado / total;
        final hFaixaO = hO * usa / total, hFaixaD = hD * usa / total;
        final x0 = xE, x1 = xE + (xD - barW - xE) * t;
        final cx = (x0 + x1) / 2;
        final path = Path()
          ..moveTo(x0, yO)
          ..cubicTo(cx, yO, cx, yDest, x1, yDest)
          ..lineTo(x1, yDest + hFaixaD)
          ..cubicTo(cx, yDest + hFaixaD, cx, yO + hFaixaO, x0, yO + hFaixaO)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(colors: [origens[oi].cor.withValues(alpha: .28), d.cor.withValues(alpha: .45)]).createShader(Rect.fromLTRB(x0, 0, xD, size.height)),
        );
        ocupado += usa;
        resta -= usa;
        yDest += hFaixaD;
        if (origens[oi].valor - ocupado < .001) {
          oi++;
          ocupado = 0;
        }
      }
      if (t > .7) {
        final op = ((t - .7) / .3).clamp(0.0, 1.0);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(xD - barW, yd, barW, math.max(hd, 2)), const Radius.circular(4)), Paint()..color = d.cor.withValues(alpha: op));
        if (op > .5) _rotulo(canvas, d.nome, '${brl(d.valor)} · ${(d.valor / total * 100).round()}%', Offset(xD + 6, yd + hd / 2), maxW: rotD - 8);
      }
      yd += hd + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _PintorFluxo o) => o.t != t || o.destinos != destinos;
}

// =====================================================================
// Calendário de calor
// =====================================================================

class CalendarioCalor extends StatefulWidget {
  final String ym;
  const CalendarioCalor({super.key, required this.ym});
  @override
  State<CalendarioCalor> createState() => _CalendarioCalorState();
}

class _CalendarioCalorState extends State<CalendarioCalor> {
  int? sel;

  @override
  void didUpdateWidget(covariant CalendarioCalor old) {
    super.didUpdateWidget(old);
    if (old.ym != widget.ym) sel = null;
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final por = gastosPorDia(repo, widget.ym);
    if (por.isEmpty) return const SizedBox.shrink();
    final n = diasNoMes(widget.ym);
    final primeiro = DateTime.parse('${widget.ym}-01').weekday - 1; // seg = 0
    final hoje = hojeIso();
    final valores = por.values.toList()..sort();
    final ref = valores[(valores.length * .9).floor().clamp(0, valores.length - 1)];
    final maxV = ref <= 0 ? 1.0 : ref;
    final corBase = G.saida;
    final dSel = sel;
    final gastosDia = dSel == null ? const [] : repo.gastos.where((g) => g.data == '${widget.ym}-${doisDig(dSel)}').toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Cartao(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CabecalhoCartao('Calendário de gastos', sub: 'Quanto mais forte a cor, mais você gastou no dia'),
          Row(children: [
            for (final d in const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'])
              Expanded(child: Center(child: Text(d, style: TextStyle(color: G.apagado, fontSize: 11, fontWeight: FontWeight.w600)))),
          ]),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, k) {
            final lado = (k.maxWidth - 6 * 6) / 7;
            final celulas = primeiro + n;
            final linhas = (celulas / 7).ceil();
            return Column(children: [
              for (var l = 0; l < linhas; l++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    for (var c = 0; c < 7; c++)
                      Builder(builder: (_) {
                        final i = l * 7 + c - primeiro + 1;
                        final w = Padding(padding: EdgeInsets.only(right: c < 6 ? 6 : 0), child: SizedBox(width: lado, height: lado * .82));
                        if (i < 1 || i > n) return w;
                        final v = por[i] ?? 0;
                        final iso = '${widget.ym}-${doisDig(i)}';
                        final futuro = iso.compareTo(hoje) > 0;
                        final f = v <= 0 ? 0.0 : (.18 + .82 * (v / maxV).clamp(0.0, 1.0));
                        final marcado = sel == i;
                        return Padding(
                          padding: EdgeInsets.only(right: c < 6 ? 6 : 0),
                          child: GestureDetector(
                            onTap: () => setState(() => sel = marcado ? null : i),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: f),
                              duration: Duration(milliseconds: 500 + i * 12),
                              curve: Curves.easeOut,
                              builder: (_, a, __) => Container(
                                width: lado,
                                height: lado * .82,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: v > 0 ? corBase.withValues(alpha: a) : G.v(futuro ? 0x05 : 0x0B),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: marcado ? G.texto : (iso == hoje ? G.lavanda : Colors.transparent), width: marcado ? 2 : 1.4),
                                ),
                                child: Text('$i', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: a > .55 ? Colors.white : (futuro ? G.apagado.withValues(alpha: .6) : G.texto2))),
                              ),
                            ),
                          ),
                        );
                      }),
                  ]),
                ),
            ]);
          }),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: dSel == null
                ? Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Toque num dia para ver os gastos.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('${rotuloDia('${widget.ym}-${doisDig(dSel)}')} · ${brl(por[dSel] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      if (gastosDia.isEmpty) Text('Nenhum gasto neste dia.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
                      for (final g in gastosDia.take(6))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Icon(catGasto(g.cat).icone, size: 16, color: catGasto(g.cat).cor),
                            const SizedBox(width: 8),
                            Expanded(child: Text(g.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: G.texto2, fontSize: 13))),
                            Text(brl(g.valor), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ]),
                        ),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }
}
