// Aba "Análise" do Patrimônio, no visual do site: números do período,
// comparação com CDI/poupança/inflação, renda passiva mês a mês, desempenho
// por ativo, diversificação e destaques — tudo empilhado, sem carrossel.
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../dados/analise_inv.dart';
import '../dados/indices.dart';
import '../dados/patrimonio.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/rosca.dart';
import '../widgets/site.dart';
import 'patrimonio_site.dart' show EvolucaoAtivoSite, amostrarDias;

String _mesAno(String ym) => '${_abr(ym)}/${ym.substring(2, 4)}';
String _abr(String ym) => mesesLongos[int.parse(ym.substring(5, 7)) - 1].substring(0, 3).toLowerCase();
String _pct1(double v, {bool sinal = true}) {
  final s = (v * 100).abs().toStringAsFixed(2).replaceAll('.', ',');
  return '${sinal ? (v < 0 ? '−' : '+') : (v < 0 ? '−' : '')}$s%';
}

/// Passo "redondo" para o eixo (1, 2, 2,5, 5 × 10ⁿ).
double _passo(double bruto) {
  if (bruto <= 0) return 1;
  final mag = math.pow(10, (math.log(bruto) / math.ln10).floor()).toDouble();
  for (final m in [1, 2, 2.5, 5, 10]) {
    if (bruto <= m * mag) return m * mag;
  }
  return 10 * mag;
}

/// Espaços não separáveis: "R$ 1.234,56" nunca quebra no meio.
String _nb(String t) => t.replaceAll(' ', '\u00A0');

TextStyle _tit() => TextStyle(fontFamily: S.fonteNum, fontSize: 17, fontWeight: FontWeight.w700, color: S.ink, height: 1.3);
TextStyle _sub() => TextStyle(fontSize: 13, color: S.muted, height: 1.4);

class AnaliseInvest extends StatefulWidget {
  final Carteira c;
  const AnaliseInvest({super.key, required this.c});
  @override
  State<AnaliseInvest> createState() => _AnaliseInvestState();
}

class _AnaliseInvestState extends State<AnaliseInvest> {
  String periodo = '12m';
  bool porClasse = false;

  @override
  void initState() {
    super.initState();
    if (!indicesAtuais.value.exemplo) carregarIndices();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    if (c.vazia) {
      return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 120), children: [
        CartaoSite(
          padding: const EdgeInsets.all(18),
          child: Text('Lance o saldo dos seus investimentos (aba Lançar valores) para ver a análise da evolução.', style: TextStyle(color: S.ink2, fontSize: 14, height: 1.45)),
        ),
      ]);
    }
    return ValueListenableBuilder<Indices>(
      valueListenable: indicesAtuais,
      builder: (context, idx, _) {
        final repo = RepoScope.of(context);
        final meses = mesesDoPeriodo(c, periodo);
        final cmp = compararComIndices(c, idx, meses);
        final ativos = desempenhoPorAtivo(c, idx, meses);
        final rp = rendaPassiva(repo, c);
        final (inst, cls) = diversificacao(c);
        final dest = destaquesInvest(c, cmp);
        final porYm = {for (final m in c.meses) m.ym: m};
        final noPer = [for (final ym in meses) if (porYm[ym] != null) porYm[ym]!];
        final rendeu = noPer.fold<double>(0, (a, m) => a + m.ganho);
        final melhor = noPer.isEmpty ? null : noPer.reduce((a, b) => a.rent >= b.rent ? a : b);
        final p = cmp?.pctCdi;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 130),
          children: [
            _SeletorPer(valor: periodo, aoMudar: (v) => setState(() => periodo = v)),
            const SizedBox(height: 12),
            _Grade([
              _Num(
                rotulo: 'Rendeu',
                valor: brl(rendeu, sinal: true),
                sub: cmp == null ? 'no período' : '${_pct1(cmp.carteira)} no período',
                cor: rendeu >= 0 ? S.pos : S.neg,
              ),
              _Num(
                rotulo: 'Comparado ao CDI',
                valor: p == null ? 'Sem dados' : '${(p * 100).round()}%',
                sub: p == null ? 'índice ainda não carregado' : (p >= 1 ? 'do CDI · acima' : 'do CDI · abaixo'),
                cor: p == null ? S.muted : (p >= 1 ? S.pos : (p >= .85 ? S.second : S.neg)),
              ),
              _Num(
                rotulo: 'Renda passiva',
                valor: rp == null ? 'Sem dados' : brl(rp.media),
                sub: rp == null ? 'falta 1 mês fechado' : 'em média por mês',
                cor: rp == null ? S.muted : S.ink,
              ),
              if (cmp?.real != null)
                _Num(
                  rotulo: 'Acima da inflação',
                  valor: _pct1(cmp!.real!),
                  sub: 'ganho real no período',
                  cor: cmp.real! >= 0 ? S.pos : S.neg,
                )
              else
                _Num(
                  rotulo: 'Melhor mês',
                  valor: melhor == null ? 'Sem dados' : _pct1(melhor.rent),
                  sub: melhor == null ? '' : mesesLongos[int.parse(melhor.ym.substring(5)) - 1],
                  cor: melhor == null ? S.muted : S.pos,
                ),
            ]),
            const SizedBox(height: 14),
            _CardIndices(cmp: cmp, idx: idx),
            if (rp != null) ...[const SizedBox(height: 14), _CardRenda(rp: rp)],
            if (ativos.isNotEmpty) ...[const SizedBox(height: 14), _CardAtivos(lista: ativos)],
            if (c.dias.length >= 2 && c.posicoes.where((p) => p.valor > 0.005).length > 1) ...[
              const SizedBox(height: 14),
              EvolucaoAtivoSite(amostra: amostrarDias(c.dias, 90), posicoes: c.posicoes.where((p) => p.valor > 0.005).toList()),
            ],
            if (inst.isNotEmpty) ...[
              const SizedBox(height: 14),
              _CardDiversificacao(fatias: porClasse ? cls : inst, porClasse: porClasse, onTrocar: (v) => setState(() => porClasse = v)),
            ],
            if (dest.isNotEmpty) ...[const SizedBox(height: 14), _CardDestaques(lista: dest)],
          ],
        );
      },
    );
  }
}

// ───────────────────────── período e números ─────────────────────────

class _SeletorPer extends StatelessWidget {
  final String valor;
  final ValueChanged<String> aoMudar;
  const _SeletorPer({required this.valor, required this.aoMudar});
  @override
  Widget build(BuildContext context) {
    const ops = [('12m', '12 meses'), ('ano', 'Este ano'), ('tudo', 'Tudo')];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: S.c('tabs-bg'), borderRadius: BorderRadius.circular(99), border: Border.all(color: S.line)),
      child: Row(children: [
        for (final (v, t) in ops)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => aoMudar(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: v == valor ? S.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: v == valor ? [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 6, offset: const Offset(0, 2))] : null,
                ),
                child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: v == valor ? S.ink : S.muted)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Num {
  final String rotulo, valor, sub;
  final Color cor;
  const _Num({required this.rotulo, required this.valor, required this.sub, required this.cor});
}

/// Grade 2×2 de números, com altura igual em cada linha e textos sem corte.
class _Grade extends StatelessWidget {
  final List<_Num> itens;
  const _Grade(this.itens);
  @override
  Widget build(BuildContext context) {
    Widget caixa(_Num n) => CartaoSite(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.rotulo, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: S.muted)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(n.valor, style: TextStyle(fontFamily: S.fonteNum, fontSize: 21, fontWeight: FontWeight.w800, color: n.cor)),
            ),
            const SizedBox(height: 2),
            Text(n.sub, style: TextStyle(fontSize: 12, color: S.muted, height: 1.3)),
          ]),
        );
    return Column(children: [
      for (var i = 0; i < itens.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: caixa(itens[i])),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < itens.length ? caixa(itens[i + 1]) : const SizedBox()),
          ]),
        ),
      ],
    ]);
  }
}

// ───────────────────────── comparação com índices ─────────────────────────

class _Serie {
  final String nome;
  final List<double> pontos; // em % acumulado (0 = começo)
  final Color cor;
  final bool tracejada, principal;
  final double? total;
  const _Serie(this.nome, this.pontos, this.cor, {this.tracejada = false, this.principal = false, this.total});
}

class _CardIndices extends StatelessWidget {
  final Comparacao? cmp;
  final Indices idx;
  const _CardIndices({required this.cmp, required this.idx});
  @override
  Widget build(BuildContext context) {
    final m = cmp;
    if (m == null) {
      return CartaoSite(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Comparado com o CDI', style: _tit()),
          const SizedBox(height: 6),
          Text(idx.temDados ? 'Ainda não há meses com rendimento e índice publicados neste período.' : 'Assim que o app conseguir buscar os índices na internet, a comparação aparece aqui.',
              style: TextStyle(color: S.ink2, fontSize: 13.5, height: 1.45)),
        ]),
      );
    }
    List<double> pc(List<double> l) => [for (final v in l) v - 100];
    final series = <_Serie>[
      _Serie('Sua carteira', pc(m.curvaCart), S.accent, principal: true, total: m.carteira),
      _Serie('CDI', pc(m.curvaCdi), S.ink2, total: m.cdi),
      if (m.curvaPoup.isNotEmpty) _Serie('Poupança', pc(m.curvaPoup), S.second, tracejada: true, total: m.poup),
      if (m.curvaIpca.isNotEmpty) _Serie('Inflação (IPCA)', pc(m.curvaIpca), S.neg, tracejada: true, total: m.ipca),
    ];
    final p = m.pctCdi;
    final dif = m.cdi == null ? null : m.carteira - m.cdi!;
    return CartaoSite(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Sua carteira x índices', style: _tit()),
        Text('Rendimento acumulado de ${_mesAno(m.meses.first)} a ${_mesAno(m.meses.last)} (${m.meses.length} ${m.meses.length == 1 ? 'mês' : 'meses'}), sem contar aportes.', style: _sub()),
        const SizedBox(height: 12),
        if (p != null && dif != null)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(color: (dif >= 0 ? S.pos : S.neg).withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Sua carteira rendeu '),
                TextSpan(text: '${(p * 100).round()}% do CDI', style: TextStyle(fontWeight: FontWeight.w800, color: dif >= 0 ? S.pos : S.neg)),
                TextSpan(text: dif >= 0 ? ' — ${_pct1(dif, sinal: false)} a mais que o CDI no período.' : ' — ${_pct1(-dif, sinal: false)} a menos que o CDI no período.'),
              ]),
              style: TextStyle(fontSize: 13.5, color: S.ink, height: 1.4),
            ),
          ),
        const SizedBox(height: 14),
        _GraficoComparacao(meses: m.meses, series: series),
        const SizedBox(height: 12),
        for (final s in series)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              _Marca(s.cor, tracejada: s.tracejada, grossa: s.principal),
              const SizedBox(width: 10),
              Expanded(child: Text(s.nome, style: TextStyle(fontSize: 14, fontWeight: s.principal ? FontWeight.w700 : FontWeight.w500, color: S.ink))),
              Text(s.total == null ? '—' : _pct1(s.total!), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: s.principal ? s.cor : S.ink)),
            ]),
          ),
        const SizedBox(height: 6),
        Text(idx.exemplo ? 'Índices de exemplo (demonstração).' : 'Fonte dos índices: Banco Central${idx.ultimo(idx.cdi) == null ? '' : ', até ${_mesAno(idx.ultimo(idx.cdi)!)}'}.',
            style: TextStyle(fontSize: 12, color: S.muted)),
      ]),
    );
  }
}

/// Amostra da linha na legenda (cheia ou tracejada).
class _Marca extends StatelessWidget {
  final Color cor;
  final bool tracejada, grossa;
  const _Marca(this.cor, {this.tracejada = false, this.grossa = false});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 22,
        child: tracejada
            ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (var i = 0; i < 3; i++) Container(width: 5, height: 2.5, color: cor)])
            : Container(height: grossa ? 4 : 2.5, decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2))),
      );
}

class _GraficoComparacao extends StatelessWidget {
  final List<String> meses;
  final List<_Serie> series;
  const _GraficoComparacao({required this.meses, required this.series});
  @override
  Widget build(BuildContext context) {
    final n = series.first.pontos.length; // meses + 1 (ponto de partida)
    var maxV = 0.0, minV = 0.0;
    for (final s in series) {
      for (final v in s.pontos) {
        maxV = math.max(maxV, v);
        minV = math.min(minV, v);
      }
    }
    final passo = _passo((maxV - minV) / 4);
    final topo = maxV + (maxV - minV) * .08;
    final base = minV < 0 ? minV - (maxV - minV) * .08 : 0.0;
    // rótulo do eixo X: o fim de cada mês; mostra no máximo ~6 para não embolar
    final cada = math.max(1, (meses.length / 6).ceil());
    String rot(int i) => i == 0 ? 'início' : _abr(meses[i - 1]);
    // série principal desenhada por último (fica por cima)
    final ordem = [...series.where((s) => !s.principal), ...series.where((s) => s.principal)];
    return SizedBox(
      height: 230,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (n - 1).toDouble(),
          minY: base,
          maxY: topo <= base ? base + passo : topo,
          clipData: const FlClipData.all(),
          borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: S.line))),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: passo,
            getDrawingHorizontalLine: (v) => FlLine(color: v == 0 ? S.muted.withValues(alpha: .5) : S.line, strokeWidth: 1, dashArray: v == 0 ? null : [3, 4]),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: passo,
                reservedSize: 44,
                getTitlesWidget: (v, meta) => (v == meta.max || v == meta.min && v != 0)
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('${v.toStringAsFixed(passo < 1 ? 1 : 0).replaceAll('.', ',')}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: S.muted)),
                      ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 26,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if ((v - i).abs() > .01 || i < 0 || i >= n) return const SizedBox();
                  final ultimo = i == n - 1;
                  if (!ultimo && (n - 1 - i) % cada != 0) return const SizedBox();
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(rot(i), style: TextStyle(fontSize: 11, color: S.muted)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            getTouchedSpotIndicator: (bar, ids) => [
              for (final _ in ids)
                TouchedSpotIndicatorData(
                  FlLine(color: S.muted.withValues(alpha: .5), strokeWidth: 1, dashArray: [3, 3]),
                  FlDotData(getDotPainter: (s, _, b, __) => FlDotCirclePainter(radius: 4, color: b.color ?? S.ink, strokeWidth: 2, strokeColor: S.surface)),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => S.ink,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipPadding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              getTooltipItems: (spots) {
                final ord = [...spots]..sort((a, b) => a.barIndex.compareTo(b.barIndex));
                return [
                  for (final s in spots)
                    s == ord.first
                        ? LineTooltipItem(
                            '${s.x.round() == 0 ? 'Início' : _mesAno(meses[s.x.round() - 1])}\n',
                            TextStyle(color: S.surface, fontWeight: FontWeight.w700, fontSize: 12, fontFamily: 'Manrope'),
                            textAlign: TextAlign.left,
                            children: [
                              for (final t in ord)
                                TextSpan(
                                  text: '${ordem[t.barIndex].nome}: ${_pct1(t.y / 100)}${t == ord.last ? '' : '\n'}',
                                  style: TextStyle(color: S.surface.withValues(alpha: .92), fontWeight: FontWeight.w500, fontSize: 12, fontFamily: 'Manrope'),
                                ),
                            ],
                          )
                        : null,
                ];
              },
            ),
          ),
          lineBarsData: [
            for (final s in ordem)
              LineChartBarData(
                spots: [for (var i = 0; i < s.pontos.length; i++) FlSpot(i.toDouble(), s.pontos[i])],
                color: s.cor,
                barWidth: s.principal ? 3.2 : (s.tracejada ? 1.8 : 2.2),
                isCurved: true,
                curveSmoothness: .2,
                preventCurveOverShooting: true,
                isStrokeCapRound: true,
                dashArray: s.tracejada ? [5, 4] : null,
                dotData: FlDotData(
                  checkToShowDot: (spot, _) => spot.x == (n - 1).toDouble(),
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: s.principal ? 4.5 : 3.2, color: s.cor, strokeWidth: 2, strokeColor: S.surface),
                ),
                belowBarData: BarAreaData(
                  show: s.principal,
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [s.cor.withValues(alpha: .16), s.cor.withValues(alpha: 0)]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── renda passiva ─────────────────────────

class _CardRenda extends StatefulWidget {
  final RendaPassiva rp;
  const _CardRenda({required this.rp});
  @override
  State<_CardRenda> createState() => _CardRendaState();
}

class _CardRendaState extends State<_CardRenda> {
  int? sel;
  @override
  Widget build(BuildContext context) {
    final rp = widget.rp;
    final s = sel != null && sel! < rp.meses.length ? sel : null;
    final maxV = rp.ganhos.fold<double>(0, math.max);
    final minV = rp.ganhos.fold<double>(0, math.min);
    final passo = _passo((maxV - minV) / 4);
    final topo = math.max(passo, (maxV / passo).ceil() * passo);
    final base = (minV / passo).floor() * passo;
    final cada = math.max(1, (rp.meses.length / 6).ceil());
    return CartaoSite(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Renda passiva', style: _tit()),
        Text('Quanto os investimentos renderam em cada mês, sem contar aportes. Toque numa barra para ver o valor.', style: _sub()),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s == null ? 'Média por mês' : 'Em ${mesesLongos[int.parse(rp.meses[s].substring(5)) - 1].toLowerCase()} de ${rp.meses[s].substring(0, 4)}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: S.muted)),
              Text(brl(s == null ? rp.media : rp.ganhos[s], sinal: s != null),
                  style: TextStyle(fontFamily: S.fonteNum, fontSize: 24, fontWeight: FontWeight.w800, color: s != null && rp.ganhos[s] < 0 ? S.neg : S.pos)),
            ]),
          ),
          if (s != null) TextButton(onPressed: () => setState(() => sel = null), child: const Text('Ver média')),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(BarChartData(
            minY: base,
            maxY: topo,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: S.line))),
            gridData: FlGridData(drawVerticalLine: false, horizontalInterval: passo, getDrawingHorizontalLine: (_) => FlLine(color: S.line, strokeWidth: 1, dashArray: [3, 4])),
            extraLinesData: ExtraLinesData(horizontalLines: [
              if (rp.media > 0)
                HorizontalLine(
                  y: rp.media,
                  color: S.ink2.withValues(alpha: .7),
                  strokeWidth: 1.2,
                  dashArray: [5, 4],
                ),
            ]),
            barTouchData: BarTouchData(
              enabled: true,
              handleBuiltInTouches: false,
              touchCallback: (ev, resp) {
                if (ev is! FlTapUpEvent) return;
                final i = resp?.spot?.touchedBarGroupIndex;
                if (i == null) return;
                setState(() => sel = i == sel ? null : i);
              },
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: passo,
                  reservedSize: 52,
                  getTitlesWidget: (v, meta) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(_curtoR(v), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: S.muted)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= rp.meses.length) return const SizedBox();
                    if (i != sel && (rp.meses.length - 1 - i) % cada != 0) return const SizedBox();
                    return SideTitleWidget(
                      meta: meta,
                      space: 6,
                      child: Text(_abr(rp.meses[i]), style: TextStyle(fontSize: 11, color: i == sel ? S.ink : S.muted, fontWeight: i == sel ? FontWeight.w700 : FontWeight.w400)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < rp.ganhos.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: rp.ganhos[i],
                    width: rp.ganhos.length > 10 ? 12 : 18,
                    color: (rp.ganhos[i] < 0 ? S.neg : S.pos).withValues(alpha: s == null || s == i ? 1 : .35),
                    borderRadius: rp.ganhos[i] < 0 ? const BorderRadius.vertical(bottom: Radius.circular(4)) : const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]),
            ],
          )),
        ),
        if (rp.media > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              _Marca(S.ink2, tracejada: true),
              const SizedBox(width: 8),
              Text('Linha tracejada: média de ${brl(rp.media)} por mês', style: TextStyle(fontSize: 12.5, color: S.muted)),
            ]),
          ),
        if (rp.pctSalario != null || rp.pagaConta != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(color: S.surface2, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (rp.pctSalario != null)
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'A média equivale a '),
                    TextSpan(text: '${(rp.pctSalario! * 100).toStringAsFixed(1).replaceAll('.', ',')}% da sua renda', style: TextStyle(fontWeight: FontWeight.w800, color: S.ink)),
                    const TextSpan(text: ' mensal.'),
                  ]),
                  style: TextStyle(fontSize: 13.5, color: S.ink2, height: 1.4),
                ),
              if (rp.pagaConta != null) ...[
                if (rp.pctSalario != null) const SizedBox(height: 4),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Já paga sozinha a conta '),
                    TextSpan(text: rp.pagaConta!, style: TextStyle(fontWeight: FontWeight.w800, color: S.ink)),
                    const TextSpan(text: '.'),
                  ]),
                  style: TextStyle(fontSize: 13.5, color: S.ink2, height: 1.4),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

String _curtoR(double v) {
  final a = v.abs();
  final s = v < 0 ? '−' : '';
  if (a >= 1000) return '${s}R\$ ${(a / 1000).toStringAsFixed(a >= 10000 ? 0 : 1).replaceAll('.', ',').replaceAll(',0', '')} mil';
  return '${s}R\$ ${a.toStringAsFixed(0)}';
}

// ───────────────────────── por ativo ─────────────────────────

class _CardAtivos extends StatelessWidget {
  final List<DesempenhoAtivo> lista;
  const _CardAtivos({required this.lista});
  @override
  Widget build(BuildContext context) {
    final fracos = lista.where((d) => d.pctCdi != null && d.pctCdi! < .7 && d.saldo > 100).toList();
    final maxR = lista.fold<double>(0, (a, d) => math.max(a, d.rent.abs()));
    return CartaoSite(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Por investimento', style: _tit()),
        Text('Quanto cada um rendeu no período, sem contar aportes.', style: _sub()),
        const SizedBox(height: 6),
        for (var i = 0; i < lista.length; i++) ...[
          if (i > 0) Divider(height: 1, color: S.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(margin: const EdgeInsets.only(top: 5), width: 10, height: 10, decoration: BoxDecoration(color: lista[i].a.cor(lista[i].indice), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lista[i].a.nome, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: S.ink)),
                    Text('Saldo ${_nb(brl(lista[i].saldo))}', style: TextStyle(color: S.muted, fontSize: 12.5, height: 1.35)),
                    Text('Rendeu ${_nb(brl(lista[i].ganho, sinal: true))}', style: TextStyle(color: lista[i].ganho >= 0 ? S.pos : S.neg, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35)),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_pct1(lista[i].rent), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: lista[i].rent >= 0 ? S.pos : S.neg)),
                  if (lista[i].pctCdi != null)
                    Builder(builder: (_) {
                      final q = lista[i].pctCdi!;
                      final cor = q >= 1 ? S.pos : (q >= .7 ? S.second : S.neg);
                      return Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: cor.withValues(alpha: .13), borderRadius: BorderRadius.circular(99)),
                        child: Text('${(q * 100).round()}% do CDI', style: TextStyle(color: cor, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      );
                    }),
                ]),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  color: S.surface2,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: maxR <= 0 ? 0 : (lista[i].rent.abs() / maxR).clamp(0, 1).toDouble(),
                    child: Container(decoration: BoxDecoration(color: lista[i].rent >= 0 ? S.pos : S.neg, borderRadius: BorderRadius.circular(4))),
                  ),
                ),
              ),
            ]),
          ),
        ],
        if (fracos.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(color: S.second.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
            child: Text('${fracos.map((d) => d.a.nome).join(', ')} ${fracos.length > 1 ? 'renderam' : 'rendeu'} menos de 70% do CDI no período.',
                style: TextStyle(fontSize: 13, color: S.ink, height: 1.4)),
          ),
      ]),
    );
  }
}

// ───────────────────────── diversificação ─────────────────────────

class _CardDiversificacao extends StatefulWidget {
  final List<Fatia> fatias;
  final bool porClasse;
  final ValueChanged<bool> onTrocar;
  const _CardDiversificacao({required this.fatias, required this.porClasse, required this.onTrocar});
  @override
  State<_CardDiversificacao> createState() => _CardDiversificacaoState();
}

class _CardDiversificacaoState extends State<_CardDiversificacao> {
  int? toque;
  @override
  Widget build(BuildContext context) {
    final fatias = widget.fatias;
    final tot = fatias.fold<double>(0, (t, f) => t + f.valor);
    final paleta = G.coresSerie;
    final cores = [for (var i = 0; i < fatias.length; i++) paleta[i % paleta.length]];
    final maior = fatias.isEmpty ? null : fatias.first;
    final conc = maior != null && tot > 0 && maior.valor / tot > .6 && fatias.length > 1;
    final t = toque != null && toque! < fatias.length ? toque : null;
    return CartaoSite(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Diversificação', style: _tit()),
        Text(widget.porClasse ? 'Como o patrimônio está dividido por tipo de investimento.' : 'Como o patrimônio está dividido por instituição.', style: _sub()),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: S.c('tabs-bg'), borderRadius: BorderRadius.circular(99), border: Border.all(color: S.line)),
          child: Row(children: [
            for (final (v, txt) in const [(false, 'Instituição'), (true, 'Tipo')])
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => toque = null);
                    widget.onTrocar(v);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: widget.porClasse == v ? S.surface : Colors.transparent, borderRadius: BorderRadius.circular(99)),
                    child: Text(txt, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: widget.porClasse == v ? S.ink : S.muted)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Center(
          child: RoscaModerna(
            key: ValueKey(widget.porClasse),
            tam: 210,
            valores: [for (final f in fatias) f.valor],
            cores: cores,
            selecionado: t,
            controlado: true,
            onToque: (i) => setState(() => toque = i),
            centro: (sel) => sel == null
                ? CentroRosca(rotulo: 'Total', valor: brl(tot))
                : CentroRosca(rotulo: fatias[sel].nome, valor: '${(fatias[sel].valor / tot * 100).toStringAsFixed(1).replaceAll('.', ',')}%', sub: brl(fatias[sel].valor), cor: cores[sel]),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < fatias.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => toque = toque == i ? null : i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: cores[i], borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(fatias[i].nome, style: TextStyle(fontWeight: t == i ? FontWeight.w800 : FontWeight.w600, fontSize: 14, color: S.ink))),
                  Text(brl(fatias[i].valor), style: TextStyle(fontSize: 13, color: S.muted)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 50,
                    child: Text('${(fatias[i].valor / tot * 100).toStringAsFixed(1).replaceAll('.', ',')}%', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: S.ink)),
                  ),
                ]),
              ]),
            ),
          ),
        if (conc)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(color: S.second.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
            child: Text('${(maior.valor / tot * 100).round()}% do patrimônio está em ${maior.nome}. Espalhar entre mais lugares diminui o risco.', style: TextStyle(fontSize: 13, color: S.ink, height: 1.4)),
          ),
        if (!widget.porClasse && fatias.any((f) => f.nome == 'Outras'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Preencha a instituição de cada investimento (aba Ativos) para a divisão ficar exata.', style: TextStyle(fontSize: 12, color: S.muted, height: 1.4)),
          ),
      ]),
    );
  }
}

// ───────────────────────── destaques ─────────────────────────

class _CardDestaques extends StatelessWidget {
  final List<DestaqueInv> lista;
  const _CardDestaques({required this.lista});
  @override
  Widget build(BuildContext context) {
    IconData ic(String t) => switch (t) {
          'cdi' => Icons.speed_rounded,
          'melhor' => Icons.emoji_events_outlined,
          'aporte' => Icons.savings_outlined,
          'seq' => Icons.local_fire_department_outlined,
          'marco' => Icons.flag_outlined,
          _ => Icons.auto_awesome_rounded,
        };
    Color cor(int tom) => tom > 0 ? S.pos : (tom < 0 ? S.second : S.accent);
    return CartaoSite(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Destaques', style: _tit()),
        const SizedBox(height: 4),
        for (var i = 0; i < lista.length; i++) ...[
          if (i > 0) Divider(height: 1, color: S.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: cor(lista[i].tom).withValues(alpha: .13), borderRadius: BorderRadius.circular(10)),
                child: Icon(ic(lista[i].tipo), size: 18, color: cor(lista[i].tom)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: lista[i].antes),
                      TextSpan(text: lista[i].forte, style: TextStyle(fontWeight: FontWeight.w800, color: lista[i].tom == 0 ? S.ink : cor(lista[i].tom))),
                      TextSpan(text: lista[i].depois),
                    ]),
                    style: TextStyle(color: S.ink2, fontSize: 14, height: 1.4),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
