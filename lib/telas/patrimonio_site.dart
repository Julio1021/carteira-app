// Cartões da Visão geral do Patrimônio que vêm do site: alocação por classe,
// rentabilidade mensal, evolução por ativo e posição atual.
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../dados/patrimonio.dart';
import '../util/fmt.dart';
import '../widgets/graficos.dart';
import '../widgets/site.dart';
import 'analise_site.dart' show BarraSite;

/// Valor de um ativo do topo (grupo = soma dos filhos) num dia.
double _valorNoDia(PosAtivo p, LinhaDia d) {
  if (p.filhos == null || p.filhos!.isEmpty) return d.porAtivo[p.a.id] ?? 0;
  return p.filhos!.fold<double>(0, (t, f) => t + (d.porAtivo[f.a.id] ?? 0));
}

class AlocacaoClasseSite extends StatelessWidget {
  final Carteira c;
  const AlocacaoClasseSite({super.key, required this.c});
  @override
  Widget build(BuildContext context) {
    final por = <String, double>{};
    for (final p in c.posicoes) {
      if (p.valor <= 0.005) continue;
      por[p.a.classe] = (por[p.a.classe] ?? 0) + p.valor;
    }
    final lista = por.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final tot = lista.fold<double>(0, (a, e) => a + e.value);
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CabecalhoSite('Alocação por classe', sub: 'Distribuição do patrimônio atual'),
        for (final e in lista)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(e.key, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: S.ink))),
                Text(pct(tot > 0 ? e.value / tot : 0), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: S.ink)),
              ]),
              const SizedBox(height: 6),
              BarraSite(tot > 0 ? e.value / tot : 0, S.accent, altura: 8),
              const SizedBox(height: 4),
              Text(brl(e.value), style: TextStyle(fontSize: 12.5, color: S.muted)),
            ]),
          ),
      ]),
    );
  }
}

class RentMensalSite extends StatelessWidget {
  final List<MesPat> meses; // últimos 12
  const RentMensalSite({super.key, required this.meses});
  @override
  Widget build(BuildContext context) {
    final vs = [for (final m in meses) m.rent.isFinite ? m.rent * 100 : 0.0];
    var maxV = vs.fold<double>(0, math.max);
    var minV = vs.fold<double>(0, math.min);
    final passo = maxV - minV <= 0 ? .2 : ((maxV - minV) / 6 * 5).ceil() / 5;
    maxV = (maxV / passo).ceil() * passo;
    minV = (minV / passo).floor() * passo;
    if (maxV == minV) maxV = minV + passo;
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CabecalhoSite('Rentabilidade mensal', sub: 'Últimos 12 meses, descontando aportes e resgates'),
        SizedBox(
          height: 220,
          child: BarChart(BarChartData(
            minY: minV,
            maxY: maxV,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(drawVerticalLine: false, horizontalInterval: passo, getDrawingHorizontalLine: (_) => FlLine(color: S.line, strokeWidth: 1)),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => S.ink,
                getTooltipItem: (g, _, r, __) => BarTooltipItem(
                  '${mesesAbr[int.parse(meses[g.x].ym.substring(5)) - 1]}/${meses[g.x].ym.substring(2, 4)}\n${pct(meses[g.x].rent, sinal: true)}',
                  TextStyle(color: S.surface, fontWeight: FontWeight.w700, fontSize: 12, fontFamily: 'Manrope'),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: passo,
                  reservedSize: 46,
                  getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(2).replaceAll('.', ',')}%', style: TextStyle(fontSize: 10, color: S.muted)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= meses.length || i.isOdd) return const SizedBox();
                    final ym = meses[i].ym;
                    return Padding(padding: const EdgeInsets.only(top: 4), child: Text('${mesesAbr[int.parse(ym.substring(5)) - 1]}/${ym.substring(2, 4)}', style: TextStyle(fontSize: 10.5, color: S.muted)));
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < vs.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: vs[i], width: 14, color: vs[i] >= 0 ? S.pos : S.neg, borderRadius: BorderRadius.circular(3)),
                ]),
            ],
          )),
        ),
      ]),
    );
  }
}

class EvolucaoAtivoSite extends StatefulWidget {
  final List<LinhaDia> amostra;
  final List<PosAtivo> posicoes;
  const EvolucaoAtivoSite({super.key, required this.amostra, required this.posicoes});
  @override
  State<EvolucaoAtivoSite> createState() => _EvolucaoAtivoSiteState();
}

class _EvolucaoAtivoSiteState extends State<EvolucaoAtivoSite> {
  bool rent = false;
  @override
  Widget build(BuildContext context) {
    final am = widget.amostra;
    final ps = widget.posicoes;
    final series = <List<double>>[];
    for (final p in ps) {
      final vals = [for (final d in am) _valorNoDia(p, d)];
      if (!rent) {
        series.add(vals);
      } else {
        final base = vals.firstWhere((v) => v > 0, orElse: () => 0);
        series.add([for (final v in vals) base > 0 && v > 0 ? (v / base - 1) * 100 : 0]);
      }
    }
    Widget pilula(String t, bool on, VoidCallback f) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: on ? S.cta : S.surface,
            shape: StadiumBorder(side: BorderSide(color: on ? S.cta : S.line)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: f,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? S.ctaInk : S.ink2)),
              ),
            ),
          ),
        );
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoSite('Evolução por ativo', sub: rent ? 'Quanto cada ativo cresceu desde o começo do período' : 'Saldo de cada ativo no período'),
        Row(children: [
          pilula('Saldo', !rent, () => setState(() => rent = false)),
          pilula('Rentabilidade', rent, () => setState(() => rent = true)),
        ]),
        const SizedBox(height: 12),
        GraficoLinha(
          key: ValueKey(rent),
          titulo: 'Evolução por ativo',
          series: series,
          cores: [for (final p in ps) p.cor],
          nomes: [for (final p in ps) p.a.nome],
          preencherPrimeira: false,
          formatoY: rent ? (v) => '${v.toStringAsFixed(1).replaceAll('.', ',')}%' : curto,
          rotulosX: [dataCurta(am.first.data), dataCurta(am[am.length ~/ 2].data), dataCurta(am.last.data)],
          rotuloToque: (i) => dataBr(am[i.clamp(0, am.length - 1).toInt()].data),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: [
          for (final p in ps)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 14, height: 3, decoration: BoxDecoration(color: p.cor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text(p.a.nome, style: TextStyle(fontSize: 12.5, color: S.ink2)),
            ]),
        ]),
      ]),
    );
  }
}

class PosicaoAtualSite extends StatelessWidget {
  final Carteira c;
  final List<PosAtivo> posicoes;
  final VoidCallback? verRelatorios;
  final ValueChanged<PosAtivo>? abrir;
  const PosicaoAtualSite({super.key, required this.c, required this.posicoes, this.verRelatorios, this.abrir});

  Widget _lin(String r, Widget v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(r, style: TextStyle(fontSize: 12.5, color: S.muted))),
          v,
        ]),
      );

  Widget _txt(String t, {bool forte = false, Color? cor}) => Text(t, style: TextStyle(fontSize: 13.5, fontWeight: forte ? FontWeight.w700 : FontWeight.w500, color: cor ?? S.ink));

  @override
  Widget build(BuildContext context) {
    final tot = c.total;
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CabecalhoSite('Posição atual', sub: 'Saldo, valor aplicado e resultado de cada ativo'),
        if (verRelatorios != null) ...[
          Align(alignment: Alignment.centerLeft, child: BotaoSm('Ver relatórios', onTap: verRelatorios!, seta: false)),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < posicoes.length; i++) ...[
          if (i > 0) Divider(color: S.line, height: 18),
          InkWell(
            onTap: abrir == null ? null : () => abrir!(posicoes[i]),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: () {
                final p = posicoes[i];
                final r = p.rent;
                final corR = p.lucro >= 0 ? S.pos : S.neg;
                return [
                  Row(children: [
                    Container(width: 11, height: 11, decoration: BoxDecoration(color: p.cor, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.a.nome, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: S.ink))),
                  ]),
                  const SizedBox(height: 6),
                  _lin('Classe', _txt(p.a.classe)),
                  _lin('Saldo atual', _txt(brl(p.valor), forte: true)),
                  _lin('Aplicado', _txt(brl(p.investido))),
                  _lin('Resultado', _txt(brl(p.lucro, sinal: true), cor: corR)),
                  _lin(
                    'Rent.',
                    r.isFinite
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: (r >= 0 ? S.posSoft : S.negSoft), borderRadius: BorderRadius.circular(99)),
                            child: Text(pct(r, sinal: true), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: corR)),
                          )
                        : _txt('—'),
                  ),
                  _lin('Part.', _txt(pct(tot > 0 ? p.valor / tot : 0))),
                  if (p.ultima != null) _lin('Último lanç.', _txt(dataBr(p.ultima!.data))),
                ];
              }()),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: S.surface2, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Total', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: S.ink)),
            const SizedBox(height: 4),
            _lin('Saldo atual', _txt(brl(tot), forte: true)),
            _lin('Aplicado', _txt(brl(c.investido), forte: true)),
            _lin('Resultado', _txt(brl(c.rendeu, sinal: true), forte: true, cor: c.rendeu >= 0 ? S.pos : S.neg)),
            if (c.investido > 0) _lin('Rent.', _txt(pct(c.rendeu / c.investido, sinal: true), forte: true)),
            _lin('Part.', _txt('100%', forte: true)),
          ]),
        ),
      ]),
    );
  }
}


/// Reduz a lista de dias para no máximo [max] pontos (gráficos leves).
List<LinhaDia> amostrarDias(List<LinhaDia> d, int max) {
  if (d.length <= max) return d;
  return [for (var i = 0; i < max; i++) d[(i * (d.length - 1) / (max - 1)).round()]];
}

/// Rentabilidade de cada mês do ano numa grade colorida (verde ganho, vermelho perda).
class GradeRentMeses extends StatelessWidget {
  final List<MesPat> meses; // do ano, em ordem
  final String titulo, sub;
  const GradeRentMeses({super.key, required this.meses, this.titulo = 'Rentabilidade de cada mês', this.sub = 'Descontando aportes e resgates'});
  @override
  Widget build(BuildContext context) {
    final maxA = meses.fold<double>(0, (a, m) => math.max(a, m.rent.isFinite ? m.rent.abs() : 0));
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoSite(titulo, sub: sub),
        LayoutBuilder(builder: (context, cons) {
          const gap = 8.0;
          final col = cons.maxWidth >= 520 ? 6 : 4;
          final w = (cons.maxWidth - gap * (col - 1)) / col;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final m in meses)
              Builder(builder: (_) {
                final r = m.rent.isFinite ? m.rent : 0.0;
                final base = r >= 0 ? S.pos : S.neg;
                final forca = maxA <= 0 ? .3 : (.18 + .62 * (r.abs() / maxA));
                final fundo = Color.lerp(S.surface, base, forca)!;
                final escuroTxt = forca < .45;
                final corTxt = escuroTxt ? (r >= 0 ? S.pos : S.neg) : Colors.white;
                return Container(
                  width: w,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    Text(mesesAbr[int.parse(m.ym.substring(5)) - 1], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: escuroTxt ? S.ink2 : Colors.white.withValues(alpha: .9))),
                    const SizedBox(height: 2),
                    Text(pct(r, sinal: true), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: corTxt)),
                  ]),
                );
              }),
          ]);
        }),
      ]),
    );
  }
}
