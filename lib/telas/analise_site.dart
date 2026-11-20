// Aba Análise do Extrato no formato do site: "Como o mês está indo",
// "Para onde foi o dinheiro" (distribuição, onde mais gastou, forma de
// pagamento, gastos por categoria) e "Ao longo do tempo".
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../dados/analise.dart';
import '../dados/categorias.dart';
import '../dados/modelos.dart';
import '../dados/resumo.dart';
import '../util/fmt.dart';
import '../widgets/rosca.dart';
import '../widgets/site.dart';

/// Título de seção do site (.gx-sec): nome, período e uma linha até a borda.
class SecaoSite extends StatelessWidget {
  final String titulo, sub;
  final bool primeira;
  const SecaoSite(this.titulo, this.sub, {super.key, this.primeira = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(0, primeira ? 2 : 24, 0, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text(titulo, style: TextStyle(fontFamily: S.fonteNum, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -.19, color: S.ink)),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: S.line)),
          ]),
          if (sub.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: S.muted)),
            ),
        ]),
      );
}

String _reais(double v) {
  if (valoresOcultos) return 'R\$ •••';
  final a = v.abs();
  final s = v < 0 ? '-' : '';
  if (a >= 1e6) return '${s}R\$ ${(a / 1e6).toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '')} mi';
  if (a >= 1e3) return '${s}R\$ ${(a / 1e3).toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '')} mil';
  return '${s}R\$ ${a.toStringAsFixed(0)}';
}

String _pct(double p) => '${(p * 100).toStringAsFixed(2).replaceAll('.', ',')}%';

/// Barrinha do site (.gbar): trilho claro e preenchimento arredondado.
class BarraSite extends StatelessWidget {
  final double frac;
  final Color cor;
  final double altura;
  const BarraSite(this.frac, this.cor, {super.key, this.altura = 7});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: altura,
          color: S.surface2,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: frac.clamp(0, 1).toDouble(),
            child: Container(decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(4))),
          ),
        ),
      );
}

/// Categorias do mês, da maior para a menor.
List<MapEntry<String, double>> _cats(ResumoMes r) => r.porCategoria.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));

// ───────────────────────── Distribuição (carrossel) ─────────────────────────

class DistribuicaoSite extends StatefulWidget {
  final ResumoMes r;
  final List<ResumoMes> meses; // últimos meses, do mais antigo ao atual
  const DistribuicaoSite({super.key, required this.r, required this.meses});
  @override
  State<DistribuicaoSite> createState() => _DistribuicaoSiteState();
}

class _DistribuicaoSiteState extends State<DistribuicaoSite> {
  static const _subs = [
    'Participação de cada categoria · deslize para ver mais',
    'Ranking das categorias por valor',
    'Cada bloco tem o tamanho do gasto da categoria',
    'Composição dos gastos em cada mês',
  ];
  final pc = PageController();
  int pag = 0;

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  void ir(int i) {
    final n = (i % 4 + 4) % 4;
    pc.animateToPage(n, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final cats = _cats(r);
    final total = cats.fold<double>(0, (a, e) => a + e.value);
    return CartaoSite(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Distribuição', style: TextStyle(fontFamily: S.fonteNum, fontSize: 16.5, fontWeight: FontWeight.w700, color: S.ink, height: 1.5)),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: mesLongo(r.ym), style: TextStyle(fontWeight: FontWeight.w600, color: S.ink2)),
            TextSpan(text: ' · ${_subs[pag]}'),
          ]),
          style: TextStyle(fontSize: 12.5, color: S.muted, height: 1.5),
        ),
        if (total <= 0)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text('Os gráficos aparecem após o primeiro gasto.', style: TextStyle(fontSize: 12.5, color: S.muted)))
        else ...[
          const SizedBox(height: 10),
          Row(children: [
            _seta(Icons.chevron_left_rounded, () => ir(pag - 1), 'Gráfico anterior'),
            const SizedBox(width: 4),
            for (var k = 0; k < 4; k++)
              GestureDetector(
                onTap: () => ir(k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: k == pag ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(color: k == pag ? S.accent : S.line, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            const SizedBox(width: 4),
            _seta(Icons.chevron_right_rounded, () => ir(pag + 1), 'Próximo gráfico'),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 300,
            child: PageView(
              controller: pc,
              onPageChanged: (i) => setState(() => pag = i),
              children: [
                _Anel(cats: cats, total: total),
                _Barras(cats: cats),
                _Blocos(cats: cats, total: total),
                _MesAMes(meses: widget.meses),
              ],
            ),
          ),
        ],
      ]),
    );
  }

  Widget _seta(IconData i, VoidCallback f, String dica) => Semantics(
        button: true,
        label: dica,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: f,
          child: Padding(padding: const EdgeInsets.all(5), child: Icon(i, size: 20, color: S.ink2)),
        ),
      );
}

class _Anel extends StatefulWidget {
  final List<MapEntry<String, double>> cats;
  final double total;
  const _Anel({required this.cats, required this.total});
  @override
  State<_Anel> createState() => _AnelState();
}

class _AnelState extends State<_Anel> {
  @override
  Widget build(BuildContext context) {
    final cats = widget.cats;
    return LayoutBuilder(builder: (context, c) {
      final tam = math.min(c.maxWidth, c.maxHeight);
      return Center(
        child: RoscaModerna(
          tam: tam,
          valores: [for (final e in cats) e.value],
          cores: [for (final e in cats) catGasto(e.key).cor],
          centro: (sel) => sel == null || sel >= cats.length
              ? CentroRosca(rotulo: 'Total', valor: brl(widget.total))
              : CentroRosca(rotulo: catGasto(cats[sel].key).nome, valor: brl(cats[sel].value), sub: _pct(cats[sel].value / widget.total), cor: catGasto(cats[sel].key).cor),
        ),
      );
    });
  }
}

class _Barras extends StatelessWidget {
  final List<MapEntry<String, double>> cats;
  const _Barras({required this.cats});
  @override
  Widget build(BuildContext context) {
    final lista = cats.take(8).toList();
    final max = lista.isEmpty ? 1.0 : lista.first.value;
    return Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      for (final e in lista)
        Row(children: [
          SizedBox(
            width: 112,
            child: Text(catGasto(e.key).nome, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: S.ink2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => Row(children: [
                Container(
                  width: math.max(4, (c.maxWidth - 70) * e.value / max),
                  height: 15,
                  decoration: BoxDecoration(color: catGasto(e.key).cor, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(_reais(e.value), maxLines: 1, style: TextStyle(fontSize: 11.5, color: S.muted))),
              ]),
            ),
          ),
        ]),
    ]);
  }
}

/// Mapa de blocos: divide o retângulo ao meio (por valor) sempre no lado maior.
class _Blocos extends StatelessWidget {
  final List<MapEntry<String, double>> cats;
  final double total;
  const _Blocos({required this.cats, required this.total});

  void _dividir(List<MapEntry<String, double>> itens, Rect r, List<(MapEntry<String, double>, Rect)> saida) {
    if (itens.isEmpty) return;
    if (itens.length == 1) {
      saida.add((itens.first, r));
      return;
    }
    final soma = itens.fold<double>(0, (a, e) => a + e.value);
    var acc = 0.0;
    var k = 0;
    while (k < itens.length - 1 && (acc + itens[k].value) <= soma / 2) {
      acc += itens[k].value;
      k++;
    }
    if (k == 0) {
      acc = itens[0].value;
      k = 1;
    }
    final f = acc / soma;
    if (r.width >= r.height) {
      final w = r.width * f;
      _dividir(itens.sublist(0, k), Rect.fromLTWH(r.left, r.top, w, r.height), saida);
      _dividir(itens.sublist(k), Rect.fromLTWH(r.left + w, r.top, r.width - w, r.height), saida);
    } else {
      final h = r.height * f;
      _dividir(itens.sublist(0, k), Rect.fromLTWH(r.left, r.top, r.width, h), saida);
      _dividir(itens.sublist(k), Rect.fromLTWH(r.left, r.top + h, r.width, r.height - h), saida);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final blocos = <(MapEntry<String, double>, Rect)>[];
        _dividir(cats, Offset.zero & Size(c.maxWidth, c.maxHeight), blocos);
        return Stack(children: [
          for (final (e, r) in blocos)
            Positioned.fromRect(
              rect: r.deflate(2),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 6, 4),
                decoration: BoxDecoration(color: catGasto(e.key).cor, borderRadius: BorderRadius.circular(5)),
                child: r.width < 34 || r.height < 26
                    ? null
                    : DefaultTextStyle(
                        style: const TextStyle(color: Colors.white, fontFamily: 'Manrope'),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (r.height > 70) Text(catGasto(e.key).nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(_pct(e.value / total), maxLines: 1, overflow: TextOverflow.clip, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                          if (r.height > 90) Text(_reais(e.value), maxLines: 1, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .85))),
                        ]),
                      ),
              ),
            ),
        ]);
      });
}

/// Barras empilhadas por mês: as 5 maiores categorias do mês e "Demais".
class _MesAMes extends StatelessWidget {
  final List<ResumoMes> meses;
  const _MesAMes({required this.meses});
  @override
  Widget build(BuildContext context) {
    final soma = <String, double>{};
    for (final m in meses) {
      m.porCategoria.forEach((k, v) => soma[k] = (soma[k] ?? 0) + v);
    }
    final top = (soma.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).map((e) => e.key).toList();
    final demais = S.muted;
    double tot(ResumoMes m) => m.porCategoria.values.fold<double>(0, (a, b) => a + b);
    final maxV = meses.fold<double>(0, (a, m) => math.max(a, tot(m)));
    return Column(children: [
      Expanded(
        child: BarChart(BarChartData(
          maxY: maxV <= 0 ? 1 : maxV * 1.08,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: S.line, strokeWidth: 1)),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 58,
                getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox() : Text(_reais(v), style: TextStyle(fontSize: 10.5, color: S.muted)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= meses.length) return const SizedBox();
                  final ym = meses[i].ym;
                  return Padding(padding: const EdgeInsets.only(top: 4), child: Text('${mesesAbr[int.parse(ym.substring(5)) - 1]}/${ym.substring(2, 4)}', style: TextStyle(fontSize: 10.5, color: S.muted)));
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < meses.length; i++)
              () {
                final m = meses[i];
                var y = 0.0;
                final itens = <BarChartRodStackItem>[];
                for (final k in top) {
                  final v = m.porCategoria[k] ?? 0;
                  if (v <= 0) continue;
                  itens.add(BarChartRodStackItem(y, y + v, catGasto(k).cor));
                  y += v;
                }
                final resto = tot(m) - y;
                if (resto > 0.005) itens.add(BarChartRodStackItem(y, y + resto, demais));
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: tot(m), width: 16, rodStackItems: itens, color: Colors.transparent, borderRadius: BorderRadius.circular(3)),
                ]);
              }(),
          ],
        )),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 10, runSpacing: 4, alignment: WrapAlignment.center, children: [
        for (final k in top) _leg(catGasto(k).cor, catGasto(k).nome),
        _leg(demais, 'Demais'),
      ]),
    ]);
  }

  Widget _leg(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, color: c),
        const SizedBox(width: 5),
        Text(t, style: TextStyle(fontSize: 11.5, color: S.ink2)),
      ]);
}

// ───────────────────────── Onde você mais gastou ─────────────────────────

class OndeMaisGastouSite extends StatelessWidget {
  final ResumoMes r;
  final ValueChanged<String> buscar;
  const OndeMaisGastouSite({super.key, required this.r, required this.buscar});
  @override
  Widget build(BuildContext context) {
    final grupos = <String, ({String desc, String cat, int n, double v})>{};
    for (final Gasto g in r.gastos) {
      final k = g.desc.trim().toLowerCase();
      final a = grupos[k];
      grupos[k] = a == null ? (desc: g.desc.trim(), cat: g.cat, n: 1, v: g.valor) : (desc: a.desc, cat: a.cat, n: a.n + 1, v: a.v + g.valor);
    }
    final top = (grupos.values.toList()..sort((a, b) => b.v.compareTo(a.v))).take(6).toList();
    return CartaoSite(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CabecalhoSite('Onde você mais gastou', sub: 'Maiores destinos de dinheiro no período · toque para ver os gastos'),
        if (top.isEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Sem gastos no período.', style: TextStyle(fontSize: 12.5, color: S.muted)))
        else
          for (var k = 0; k < top.length; k++)
            InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => buscar(top[k].desc),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(children: [
                  SizedBox(width: 22, child: Text('${k + 1}', style: TextStyle(fontSize: 11, color: S.muted))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(top[k].desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: S.ink)),
                            Text('${top[k].n}× · ${catGasto(top[k].cat).nome}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: S.muted)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Text(brl(top[k].v), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: S.ink)),
                      ]),
                      const SizedBox(height: 5),
                      BarraSite(top[k].v / top.first.v, catGasto(top[k].cat).cor, altura: 5),
                    ]),
                  ),
                ]),
              ),
            ),
      ]),
    );
  }
}

// ───────────────────────── Forma de pagamento ─────────────────────────

class FormaPagamentoSite extends StatelessWidget {
  final ResumoMes r;
  const FormaPagamentoSite({super.key, required this.r});
  @override
  Widget build(BuildContext context) {
    final por = <String, double>{};
    for (final g in r.gastos) {
      por[g.pag] = (por[g.pag] ?? 0) + g.valor;
    }
    final lista = por.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = lista.isEmpty ? 1.0 : lista.first.value;
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CabecalhoSite('Forma de pagamento', sub: 'Como você pagou no período'),
        if (lista.isEmpty)
          Text('Sem dados no período.', style: TextStyle(fontSize: 12.5, color: S.muted))
        else
          for (final e in lista)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 74, child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: S.ink))),
                const SizedBox(width: 10),
                Expanded(child: BarraSite(e.value / max, S.second)),
                const SizedBox(width: 10),
                Text(brl(e.value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: S.ink)),
              ]),
            ),
      ]),
    );
  }
}

// ───────────────────────── Gastos por categoria ─────────────────────────

class GastosCategoriaSite extends StatelessWidget {
  final ResumoMes r;
  final ValueChanged<String> verCategoria;
  final VoidCallback ajustarLimites;
  const GastosCategoriaSite({super.key, required this.r, required this.verCategoria, required this.ajustarLimites});
  @override
  Widget build(BuildContext context) {
    final cats = _cats(r);
    final total = cats.fold<double>(0, (a, e) => a + e.value);
    final lims = r.lim.cat;
    final temLim = lims.values.any((v) => v > 0) || r.temLimiteGeral;
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Gastos por categoria', style: TextStyle(fontFamily: S.fonteNum, fontSize: 16.5, fontWeight: FontWeight.w700, color: S.ink, height: 1.5)),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 12),
          child: Text('${lims.isNotEmpty ? 'Valor gasto e limite definido para cada categoria' : 'Onde o dinheiro foi no período'} · toque para filtrar',
              style: TextStyle(fontSize: 12.5, color: S.muted, height: 1.5)),
        ),
        Align(alignment: Alignment.centerLeft, child: BotaoSm(temLim ? 'Ajustar limites' : 'Definir limites', onTap: ajustarLimites, seta: false)),
        const SizedBox(height: 12),
        if (cats.isEmpty)
          Text('Nenhum gasto em ${mesLongo(r.ym).toLowerCase()}.', style: TextStyle(fontSize: 12.5, color: S.muted))
        else
          for (final e in cats) _linha(e.key, e.value, lims[e.key], total),
      ]),
    );
  }

  Widget _linha(String c, double v, double? l, double total) {
    final cat = catGasto(c);
    final temL = l != null && l > 0;
    final u = temL ? v / l : 0.0;
    final part = total > 0 ? v / total : 0.0;
    final cor = !temL ? cat.cor : (u > 1 ? S.neg : (u > .85 ? S.second : S.pos));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => verCategoria(c),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(border: Border.all(color: S.line), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: cat.cor, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                Expanded(child: Text(cat.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: S.ink))),
                Text.rich(TextSpan(children: [
                  TextSpan(text: brl(v), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: S.ink)),
                  TextSpan(text: temL ? ' de ${brl(l)}' : ' · ${_pct(part)}', style: TextStyle(fontSize: 11.7, fontWeight: FontWeight.w500, color: S.muted)),
                ])),
              ]),
              const SizedBox(height: 8),
              BarraSite(temL ? u : part, cor),
              if (temL && u > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Passou ${brl(v - l)} do limite', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: S.neg)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Entradas e gastos (12 meses) ─────────────────────────

class EntradasGastosSite extends StatelessWidget {
  final List<MesValores> hist;
  final double limite;
  final String ymAtual;
  final ValueChanged<String>? onMes;
  const EntradasGastosSite({super.key, required this.hist, required this.limite, required this.ymAtual, this.onMes});
  @override
  Widget build(BuildContext context) {
    final temEntradas = hist.any((m) => m.entrou > 0);
    final vals = [for (final m in hist) ...[m.entrou, m.saiu, m.sobra], if (limite > 0) limite];
    var maxV = vals.fold<double>(0, math.max);
    var minV = vals.fold<double>(0, math.min);
    if (maxV <= 0) maxV = 1;
    final passo = _passo((maxV - minV) / 6);
    maxV = (maxV / passo).ceil() * passo;
    minV = (minV / passo).floor() * passo;
    String rot(String ym) => '${mesesAbr[int.parse(ym.substring(5)) - 1]}/${ym.substring(2, 4)}';
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoSite(temEntradas ? 'Entradas e gastos' : 'Evolução dos gastos',
            sub: '${temEntradas ? 'Quanto entrou, quanto saiu e quanto sobrou em cada mês' : 'Total gasto por mês'}${limite > 0 ? ' · linha tracejada: orçamento' : ''}'),
        SizedBox(
          height: 240,
          child: Stack(children: [
            BarChart(BarChartData(
              minY: minV,
              maxY: maxV,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(drawVerticalLine: false, horizontalInterval: passo, getDrawingHorizontalLine: (_) => FlLine(color: S.line, strokeWidth: 1)),
              extraLinesData: ExtraLinesData(horizontalLines: [
                if (limite > 0) HorizontalLine(y: limite, color: S.ink2, strokeWidth: 1.4, dashArray: [6, 5]),
              ]),
              barTouchData: BarTouchData(
                handleBuiltInTouches: false,
                touchCallback: (ev, resp) {
                  if (ev is! FlTapUpEvent || onMes == null) return;
                  final i = resp?.spot?.touchedBarGroupIndex;
                  if (i != null && i >= 0 && i < hist.length) onMes!(hist[i].ym);
                },
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: passo,
                    reservedSize: 58,
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(_reais(v), textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, color: S.muted)),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= hist.length || (hist.length - 1 - i).isOdd) return const SizedBox();
                      return Padding(padding: const EdgeInsets.only(top: 4), child: Text(rot(hist[i].ym), style: TextStyle(fontSize: 10.5, color: S.muted)));
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < hist.length; i++)
                  BarChartGroupData(x: i, barsSpace: 2, barRods: [
                    if (temEntradas) BarChartRodData(toY: hist[i].entrou, width: 6, color: S.pos.withValues(alpha: hist[i].ym == ymAtual ? 1 : .8), borderRadius: BorderRadius.circular(3)),
                    BarChartRodData(toY: hist[i].saiu, width: 6, color: S.neg.withValues(alpha: hist[i].ym == ymAtual ? 1 : .8), borderRadius: BorderRadius.circular(3)),
                  ]),
              ],
            )),
            // linha da sobra por cima das barras (mesma escala)
            if (temEntradas)
              IgnorePointer(
                child: LineChart(LineChartData(
                  minY: minV,
                  maxY: maxV,
                  minX: -.5,
                  maxX: hist.length - .5,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 58, getTitlesWidget: (_, __) => const SizedBox())),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (_, __) => const SizedBox())),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < hist.length; i++) FlSpot(i.toDouble(), hist[i].sobra)],
                      color: S.accent,
                      barWidth: 2.2,
                      dotData: FlDotData(getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3.6, color: S.accent, strokeWidth: 0)),
                    ),
                  ],
                )),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 4, children: [
          if (temEntradas) _leg(S.pos, 'Entrou'),
          _leg(S.neg, 'Saiu'),
          if (temEntradas) _leg(S.accent, 'Sobra'),
          if (limite > 0) _leg(S.ink2, 'Orçamento', tracejada: true),
        ]),
      ]),
    );
  }

  static double _passo(double bruto) {
    if (bruto <= 0) return 1;
    final mag = math.pow(10, (math.log(bruto) / math.ln10).floor()).toDouble();
    for (final m in [1, 2, 2.5, 5, 10]) {
      if (bruto <= m * mag) return m * mag;
    }
    return 10 * mag;
  }

  Widget _leg(Color c, String t, {bool tracejada = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
        tracejada
            ? Row(children: [Container(width: 5, height: 2, color: c), const SizedBox(width: 3), Container(width: 5, height: 2, color: c)])
            : Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(fontSize: 12, color: S.muted)),
      ]);
}
