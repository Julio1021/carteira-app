import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../tema.dart';
import '../util/fmt.dart';
import 'comum.dart';

/// Faz os gráficos "crescerem" ao aparecer.
class _Entrada extends StatelessWidget {
  final Widget Function(double t) builder;
  const _Entrada({required this.builder});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => builder(t),
      );
}

/// Passo "redondo" para o eixo (1, 2, 2,5 ou 5 × potência de 10), ~3 marcas.
double passoRedondo(double faixa) {
  if (!(faixa > 0) || !faixa.isFinite) return 1;
  final bruto = faixa / 3;
  final mag = math.pow(10, (math.log(bruto) / math.ln10).floor()).toDouble();
  for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (m * mag >= bruto) return m * mag;
  }
  return 10 * mag;
}

TextStyle get _estiloEixo => TextStyle(color: G.apagado, fontSize: 9.5, fontWeight: FontWeight.w600);

FlGridData _grade(double intervalo) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: intervalo > 0 && intervalo.isFinite ? intervalo : null,
      getDrawingHorizontalLine: (_) => FlLine(color: G.v(0x10), strokeWidth: 1, dashArray: [3, 4]),
    );

/// Dá ao gráfico a largura toda do cartão (passa por cima do recuo interno) e
/// coloca o botão de tela cheia.
class _Moldura extends StatelessWidget {
  final double altura;
  final Widget grafico;
  final VoidCallback? onExpandir;
  const _Moldura({required this.altura, required this.grafico, this.onExpandir});
  @override
  Widget build(BuildContext context) {
    final s = dentroDeCartao(context) ? 10.0 : 0.0;
    return LayoutBuilder(builder: (context, k) {
      final w = k.maxWidth.isFinite ? k.maxWidth : 320.0;
      return SizedBox(
        height: altura,
        width: w,
        child: OverflowBox(
          minWidth: w + 2 * s,
          maxWidth: w + 2 * s,
          child: Stack(children: [
            Positioned.fill(child: grafico),
            if (onExpandir != null)
              Positioned(
                top: 0,
                right: s,
                child: Material(
                  color: G.v(0x0C),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onExpandir,
                    child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.open_in_full_rounded, size: 15, color: G.apagado, semanticLabel: 'Tela cheia')),
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }
}

/// Abre um gráfico ocupando a tela inteira (deitando o celular, fica mais largo).
void abrirGraficoCheio(BuildContext context, String titulo, Widget Function(double altura) construir) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (c) => Scaffold(
      appBar: AppBar(title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
          child: LayoutBuilder(builder: (c, k) => construir(k.maxHeight)),
        ),
      ),
    ),
  ));
}



/// Gráfico de linhas com toque mostrando os valores.
class GraficoLinha extends StatelessWidget {
  final List<List<double>> series;
  final List<Color> cores;
  final List<bool> tracejada;
  final List<String> nomes;
  final List<String> rotulosX; // espalhados pelo eixo
  final String Function(int i)? rotuloToque;
  final String Function(double) formatoY;
  final double altura;
  final bool preencherPrimeira;
  final double? linhaH; // linha horizontal tracejada (ex.: limite)
  final String? nomeLinhaH;
  final int? pontosX; // total de pontos no eixo x (para séries mais curtas, como o mês em andamento)
  final String? titulo; // com título, ganha o botão de tela cheia
  const GraficoLinha({
    super.key,
    required this.series,
    required this.cores,
    required this.formatoY,
    this.tracejada = const [],
    this.nomes = const [],
    this.rotulosX = const [],
    this.rotuloToque,
    this.altura = 230,
    this.preencherPrimeira = true,
    this.linhaH,
    this.nomeLinhaH,
    this.pontosX,
    this.titulo,
  });

  GraficoLinha _com(double h) => GraficoLinha(
        series: series,
        cores: cores,
        formatoY: formatoY,
        tracejada: tracejada,
        nomes: nomes,
        rotulosX: rotulosX,
        rotuloToque: rotuloToque,
        altura: h,
        preencherPrimeira: preencherPrimeira,
        linhaH: linhaH,
        nomeLinhaH: nomeLinhaH,
        pontosX: pontosX,
      );

  @override
  Widget build(BuildContext context) {
    final todos = [...series.expand((s) => s), if (linhaH != null) linhaH!].where((v) => v.isFinite).toList();
    if (todos.isEmpty) return SizedBox(height: altura);
    var mn = todos.reduce(math.min), mx = todos.reduce(math.max);
    if (mn > 0 && mn < mx * .35) mn = 0;
    if (mx - mn < 1e-9) {
      mx += 1;
      mn = mn > 1 ? mn - 1 : 0;
    }
    final pad = (mx - mn) * .08;
    final n = pontosX ?? series.map((s) => s.length).fold<int>(0, math.max);
    final posRotulos = <int, String>{};
    for (var i = 0; i < rotulosX.length; i++) {
      final x = rotulosX.length == 1 ? 0 : (i * (n - 1) / (rotulosX.length - 1)).round();
      posRotulos[x] = rotulosX[i];
    }
    final topo = mx + pad, base = mn - (mn == 0 ? 0 : pad);
    return _Moldura(
      altura: altura,
      onExpandir: titulo == null ? null : () => abrirGraficoCheio(context, titulo!, _com),
      grafico: _Entrada(
        builder: (t) => LineChart(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          LineChartData(
            minX: 0,
            maxX: math.max(1, n - 1).toDouble(),
            minY: base,
            maxY: topo,
            // a borda direita não corta o último ponto nem o último rótulo
            clipData: const FlClipData(top: true, bottom: true, left: true, right: false),
            gridData: _grade(passoRedondo(topo - base)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 16, getTitlesWidget: (_, __) => const SizedBox.shrink())),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: passoRedondo(topo - base),
                  getTitlesWidget: (v, meta) => (v == meta.min || v == meta.max)
                      ? const SizedBox.shrink()
                      : Padding(padding: const EdgeInsets.only(right: 6), child: Text(formatoY(v), style: _estiloEixo, textAlign: TextAlign.right, maxLines: 1, softWrap: false)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    final s = posRotulos[v.round()];
                    if (s == null || (v - v.round()).abs() > .01) return const SizedBox.shrink();
                    return Padding(padding: const EdgeInsets.only(top: 6), child: Text(s, style: _estiloEixo));
                  },
                ),
              ),
            ),
            extraLinesData: linhaH == null
                ? null
                : ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: linhaH!,
                      color: G.neg.withValues(alpha: .7),
                      strokeWidth: 1.4,
                      dashArray: [6, 5],
                      label: HorizontalLineLabel(
                        show: nomeLinhaH != null,
                        alignment: Alignment.bottomRight,
                        style: TextStyle(color: G.neg, fontSize: 10, fontWeight: FontWeight.w600),
                        labelResolver: (_) => nomeLinhaH ?? '',
                      ),
                    ),
                  ]),
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchSpotThreshold: 40,
              getTouchedSpotIndicator: (bar, idx) => [
                for (final _ in idx)
                  TouchedSpotIndicatorData(
                    FlLine(color: G.v(0x55), strokeWidth: 1.2, dashArray: [4, 4]),
                    FlDotData(getDotPainter: (_, __, b, ___) => FlDotCirclePainter(radius: 5, color: b.color ?? G.lavanda, strokeWidth: 2.5, strokeColor: G.fundo)),
                  ),
              ],
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => G.dica,
                tooltipBorderRadius: BorderRadius.circular(12),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (spots) => [
                  for (var k = 0; k < spots.length; k++)
                    LineTooltipItem(
                      '${k == 0 && rotuloToque != null ? '${rotuloToque!(spots[k].x.round())}\n' : ''}${spots[k].barIndex < nomes.length ? '${nomes[spots[k].barIndex]}: ' : ''}${brl(spots[k].y)}',
                      TextStyle(color: cores[spots[k].barIndex % cores.length], fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              for (var s = 0; s < series.length; s++)
                LineChartBarData(
                  spots: [for (var i = 0; i < series[s].length; i++) FlSpot(i.toDouble(), mn + (series[s][i] - mn) * t)],
                  isCurved: true,
                  curveSmoothness: .22,
                  preventCurveOverShooting: true,
                  color: cores[s % cores.length],
                  barWidth: s == 0 ? 3 : 2,
                  isStrokeCapRound: true,
                  dashArray: s < tracejada.length && tracejada[s] ? [6, 5] : null,
                  dotData: FlDotData(
                    show: t > .98,
                    // ponto no fim de cada linha (o da principal com um anel)
                    checkToShowDot: (spot, bar) => spot.x == bar.spots.last.x,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: s == 0 ? 5 : 3.2,
                      color: cores[s % cores.length],
                      strokeWidth: s == 0 ? 3 : 2,
                      strokeColor: G.fundo2,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: s == 0 && preencherPrimeira,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [cores[0].withValues(alpha: .30), cores[0].withValues(alpha: .08), cores[0].withValues(alpha: 0)],
                      stops: const [0, .6, 1],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barras agrupadas (ex.: entradas e saídas de cada mês).
class GraficoBarras extends StatelessWidget {
  final List<String> rotulos;
  final List<List<double>> valores; // valores[grupo][série]
  final List<Color> cores;
  final List<String> nomes;
  final String Function(double) formatoY;
  final int? selecionado;
  final ValueChanged<int>? onToque;
  final double altura;
  final List<String>? rodape; // texto curto embaixo de cada grupo (ex.: sobra)
  final List<Color>? coresRodape;
  const GraficoBarras({
    super.key,
    required this.rotulos,
    required this.valores,
    required this.cores,
    required this.formatoY,
    this.nomes = const [],
    this.selecionado,
    this.onToque,
    this.altura = 240,
    this.rodape,
    this.coresRodape,
    this.titulo,
  });
  final String? titulo;

  GraficoBarras _com(double h) => GraficoBarras(
        rotulos: rotulos,
        valores: valores,
        cores: cores,
        formatoY: formatoY,
        nomes: nomes,
        altura: h,
        rodape: rodape,
        coresRodape: coresRodape,
      );

  @override
  Widget build(BuildContext context) {
    final mx = valores.expand((g) => g).fold<double>(0, math.max);
    final mn = valores.expand((g) => g).fold<double>(0, math.min); // barras negativas (ex.: mês que rendeu menos)
    final largura = valores.isEmpty ? 10.0 : (valores.length <= 6 ? 14.0 : 8.0);
    final topo = mx <= 0 ? 1.0 : mx * 1.12;
    final poucosRotulos = rotulos.length > 8 && altura < 400;
    return _Moldura(
      altura: altura,
      onExpandir: titulo == null ? null : () => abrirGraficoCheio(context, titulo!, _com),
      grafico: _Entrada(
        builder: (t) => BarChart(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          BarChartData(
            maxY: topo,
            minY: mn < 0 ? mn * 1.12 : 0,
            gridData: _grade(passoRedondo(topo)),
            borderData: FlBorderData(show: false),
            alignment: BarChartAlignment.spaceAround,
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: passoRedondo(topo),
                  getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(right: 6), child: Text(formatoY(v), style: _estiloEixo, textAlign: TextAlign.right, maxLines: 1, softWrap: false)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: rodape == null ? 24 : 40,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= rotulos.length) return const SizedBox.shrink();
                    final sel = i == selecionado;
                    if (poucosRotulos && !sel && i != rotulos.length - 1 && (rotulos.length - 1 - i) % 2 == 1) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(rotulos[i], style: _estiloEixo.copyWith(color: sel ? G.branco : G.apagado, fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
                        if (rodape != null)
                          Text(rodape![i], style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: coresRodape?[i] ?? G.apagado)),
                      ]),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchCallback: (ev, resp) {
                if (onToque != null && ev is FlTapUpEvent && resp?.spot != null) onToque!(resp!.spot!.touchedBarGroupIndex);
              },
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => G.dica,
                tooltipBorderRadius: BorderRadius.circular(12),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                  '${ri == 0 ? '${rotulos[gi]}\n' : ''}${ri < nomes.length ? '${nomes[ri]}: ' : ''}${brl(valores[gi][ri])}',
                  TextStyle(color: cores[ri % cores.length], fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ),
            barGroups: [
              for (var g = 0; g < valores.length; g++)
                BarChartGroupData(
                  x: g,
                  barsSpace: 4,
                  barRods: [
                    for (var s = 0; s < valores[g].length; s++)
                      BarChartRodData(
                        toY: valores[g][s] * t,
                        width: largura,
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: selecionado == null || selecionado == g
                              ? [cores[s % cores.length].withValues(alpha: .75), cores[s % cores.length]]
                              : [cores[s % cores.length].withValues(alpha: .22), cores[s % cores.length].withValues(alpha: .38)],
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(largura / 2)),
                        // trilho de fundo: mostra a escala até o topo
                        backDrawRodData: BackgroundBarChartRodData(show: valores[g].length == 1, toY: topo, color: G.v(0x07)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rosca (donut) com o total no meio; toque numa fatia para destacar.
class Rosca extends StatefulWidget {
  final List<double> valores;
  final List<Color> cores;
  final String centro, sub;
  final double tam;
  final ValueChanged<int?>? onToque;
  const Rosca({super.key, required this.valores, required this.cores, required this.centro, this.sub = '', this.tam = 180, this.onToque});
  @override
  State<Rosca> createState() => _RoscaState();
}

class _RoscaState extends State<Rosca> {
  int? toc;
  @override
  Widget build(BuildContext context) {
    final tot = widget.valores.fold<double>(0, (a, b) => a + (b > 0 ? b : 0));
    final raio = widget.tam / 2;
    return SizedBox(
      width: widget.tam,
      height: widget.tam,
      child: Stack(alignment: Alignment.center, children: [
        _Entrada(
          builder: (t) => PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 2.5,
              centerSpaceRadius: raio * .62,
              pieTouchData: PieTouchData(touchCallback: (ev, resp) {
                if (ev is! FlTapUpEvent) return;
                final i = resp?.touchedSection?.touchedSectionIndex;
                final novo = (i == null || i < 0 || i == toc) ? null : i;
                setState(() => toc = novo);
                widget.onToque?.call(novo);
              }),
              sections: tot <= 0
                  ? [PieChartSectionData(value: 1, color: G.v(0x1F), radius: raio * .3, showTitle: false)]
                  : [
                      for (var i = 0; i < widget.valores.length; i++)
                        if (widget.valores[i] > 0)
                          PieChartSectionData(
                            value: widget.valores[i] * t + (t < 1 ? 0.0001 : 0),
                            color: toc == null || toc == i ? widget.cores[i % widget.cores.length] : widget.cores[i % widget.cores.length].withValues(alpha: .3),
                            radius: raio * (toc == i ? .36 : .3),
                            showTitle: false,
                          ),
                    ],
            ),
          ),
        ),
        // centro: o total, ou a fatia tocada (em %)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (c, an) => FadeTransition(opacity: an, child: ScaleTransition(scale: Tween(begin: .85, end: 1.0).animate(an), child: c)),
          child: toc != null && tot > 0 && toc! < widget.valores.length
              ? Column(key: ValueKey(toc), mainAxisSize: MainAxisSize.min, children: [
                  Text('${(widget.valores[toc!] / tot * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: widget.cores[toc! % widget.cores.length])),
                  Text('do total', style: TextStyle(color: G.apagado, fontSize: 11.5)),
                ])
              : Column(key: const ValueKey('c'), mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.centro, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  if (widget.sub.isNotEmpty) Text(widget.sub, textAlign: TextAlign.center, style: TextStyle(color: G.apagado, fontSize: 11.5)),
                ]),
        ),
      ]),
    );
  }
}

/// Valor curto para eixos: 1,2 mil · 3,4 mi.
String curto(double v) {
  final a = v.abs();
  String f(double x) => x.toStringAsFixed(x >= 100 ? 0 : 1).replaceAll('.', ',').replaceAll(',0', '');
  if (a >= 1e6) return '${v < 0 ? '-' : ''}${f(a / 1e6)} mi';
  if (a >= 1e3) return '${v < 0 ? '-' : ''}${f(a / 1e3)} mil';
  return v.toStringAsFixed(0);
}

/// Legenda pequena: quadradinho colorido + texto.
class Legenda extends StatelessWidget {
  final Color cor;
  final String t;
  final bool tracejada;
  const Legenda(this.cor, this.t, {super.key, this.tracejada = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        tracejada
            ? SizedBox(width: 14, height: 3, child: Row(children: [Container(width: 5, color: cor), const SizedBox(width: 3), Container(width: 5, color: cor)]))
            : Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(color: G.apagado, fontSize: 12)),
      ]);
}
