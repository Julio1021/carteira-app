import 'package:flutter/material.dart';

import '../dados/analise.dart';
import '../dados/categorias.dart';
import '../dados/patrimonio.dart' show pct;
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/painel.dart';
import '../widgets/graficos.dart';
import 'analise_extras.dart';

Color get corEntrada => G.pos;
Color get corSaida => G.saida;
Color get corInvest => G.lavanda;
const corAnterior = Color(0xFF8C90A6);

/// Aba "Análise" do Extrato: gráficos que contam a história do mês.
class AnaliseExtrato extends StatefulWidget {
  final String ym;
  final ValueChanged<String> onMes;
  final ValueChanged<String> verCategoria;
  const AnaliseExtrato({super.key, required this.ym, required this.onMes, required this.verCategoria});
  @override
  State<AnaliseExtrato> createState() => _AnaliseExtratoState();
}

class _AnaliseExtratoState extends State<AnaliseExtrato> {
  int nMeses = 6;

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final r = ResumoMes.de(repo, widget.ym);
    final hist = historicoMeses(repo, widget.ym, nMeses);
    final rit = ritmoDoMes(repo, widget.ym);
    final comp = comparativoCategorias(repo, widget.ym);
    final mesNome = mesesLongos[int.parse(widget.ym.substring(5)) - 1].toLowerCase();
    // números que o cabeçalho do mês ainda não mostra
    final dias = rit.diaHoje > 0 ? rit.diaHoje : diasNoMes(widget.ym);
    final totGastos = r.gastos.fold<double>(0, (a, g) => a + g.valor);
    final maior = r.gastos.isEmpty ? null : r.gastos.reduce((a, b) => b.valor > a.valor ? b : a);
    final cats = r.porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCat = cats.isEmpty ? null : cats.first;
    final base = rit.media.isNotEmpty ? rit.mediaMesmoDia : rit.anteriorMesmoDia;
    final varRit = base > 0 ? rit.gastoAteHoje / base - 1 : null;
    final assuntos = <(String, Widget)>[
      ('Resumo', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DestaquesMes(ym: widget.ym),
        _RitmoCard(rit: rit, mesNome: mesNome),
      ])),
      ('Entrou × Saiu', _EntrouSaiu(hist: hist, ym: widget.ym, nMeses: nMeses, onN: (n) => setState(() => nMeses = n), onMes: widget.onMes)),
      ('Fluxo', FluxoDinheiro(r: r)),
      ('Calendário', CalendarioCalor(ym: widget.ym)),
      ('Categorias', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _OndeFoi(r: r, verCategoria: widget.verCategoria),
        const SizedBox(height: 12),
        _Comparativo(comp: comp, verCategoria: widget.verCategoria, atual: widget.ym == ymDe(hojeIso())),
      ])),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GradeKpi([
        Kpi(icone: Icons.calendar_today_rounded, rotulo: 'Gasto por dia', valor: totGastos / dias, formato: brl, sub: 'média de $dias dia${dias == 1 ? '' : 's'}', cor: corSaida),
        Kpi(
          icone: Icons.speed_rounded,
          rotulo: 'Ritmo',
          texto: varRit == null ? '—' : '${varRit >= 0 ? '+' : '−'}${(varRit.abs() * 100).round()}%',
          sub: rit.media.isNotEmpty ? 'vs. sua média' : 'vs. mês anterior',
          cor: varRit == null ? G.texto : (varRit > .08 ? G.neg : (varRit < -.08 ? G.pos : G.texto)),
        ),
        Kpi(icone: Icons.arrow_upward_rounded, rotulo: 'Maior gasto', valor: maior?.valor ?? 0, formato: (v) => maior == null ? '—' : brl(v), sub: maior?.desc ?? 'nenhum gasto'),
        Kpi(
          icone: Icons.donut_small_rounded,
          rotulo: 'Mais gastou em',
          texto: topCat == null ? '—' : catGasto(topCat.key).nome,
          sub: topCat == null ? '' : '${brl(topCat.value)} · ${r.saiu > 0 ? (topCat.value / r.saiu * 100).round() : 0}%',
          onTap: topCat == null ? null : () => widget.verCategoria(topCat.key),
        ),
      ]),
      const SizedBox(height: 16),
      ChipsAssunto(nomes: [for (final a in assuntos) a.$1], construir: (_, i) => assuntos[i].$2),
    ]);
  }
}

class _EntrouSaiu extends StatelessWidget {
  final List<MesValores> hist;
  final String ym;
  final int nMeses;
  final ValueChanged<int> onN;
  final ValueChanged<String> onMes;
  const _EntrouSaiu({required this.hist, required this.ym, required this.nMeses, required this.onN, required this.onMes});
  @override
  Widget build(BuildContext context) {
    final comDados = hist.where((m) => m.entrou > 0 || m.saiu > 0).toList();
    final mediaSobra = comDados.isEmpty ? 0.0 : comDados.fold<double>(0, (a, m) => a + m.sobra) / comDados.length;
    final melhor = comDados.isEmpty ? null : comDados.reduce((a, b) => b.sobra > a.sobra ? b : a);
    final temInv = hist.any((m) => m.investiu > 0);
    final comEntrada = hist.where((m) => m.entrou > 0 && m.investiu != 0).toList();
    final pctMedio = comEntrada.isEmpty ? null : comEntrada.fold<double>(0, (a, m) => a + m.investiu / m.entrou) / comEntrada.length;
    String abr(String m) => mesesAbr[int.parse(m.substring(5)) - 1];
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(temInv ? 'Entrou × Saiu × Investiu' : 'Entrou × Saiu', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          SegmentedButton<int>(
            segments: const [ButtonSegment(value: 6, label: Text('6m')), ButtonSegment(value: 12, label: Text('12m'))],
            selected: {nMeses},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: G.branco,
              selectedForegroundColor: G.tinta,
              foregroundColor: G.texto2,
              side: BorderSide(color: G.borda),
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            onSelectionChanged: (s) => onN(s.first),
          ),
        ]),
        const SizedBox(height: 12),
        GraficoBarras(
          titulo: temInv ? 'Entrou × Saiu × Investiu' : 'Entrou × Saiu',
          rotulos: [for (final m in hist) abr(m.ym)],
          valores: [for (final m in hist) [m.entrou, m.saiu, if (temInv) (m.investiu > 0 ? m.investiu : 0.0)]],
          cores: [corEntrada, corSaida, if (temInv) corInvest],
          nomes: ['Entrou', 'Saiu', if (temInv) 'Investiu'],
          formatoY: curto,
          selecionado: hist.indexWhere((m) => m.ym == ym),
          onToque: (i) => onMes(hist[i].ym),
          rodape: [for (final m in hist) m.entrou == 0 && m.saiu == 0 ? '' : (m.sobra >= 0 ? '+' : '−') + curto(m.sobra.abs())],
          coresRodape: [for (final m in hist) m.sobra >= 0 ? G.pos : corSaida],
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 6, children: [Legenda(corEntrada, 'Entrou'), Legenda(corSaida, 'Saiu'), if (temInv) Legenda(corInvest, 'Investiu')]),
        if (comDados.length >= 2)
          FaixaNumeros([
            ('Sobra média', brl(mediaSobra), mediaSobra >= 0 ? G.pos : corSaida),
            if (melhor != null) ('Melhor mês · ${abr(melhor.ym)}', brl(melhor.sobra), null),
            if (pctMedio != null) ('Investe', '${(pctMedio * 100).round()}% da renda', corInvest),
          ]),
      ]),
    );
  }
}

/// 2. Ritmo dos gastos no mês.
class _RitmoCard extends StatelessWidget {
  final Ritmo rit;
  final String mesNome;
  const _RitmoCard({required this.rit, required this.mesNome});
  @override
  Widget build(BuildContext context) {
    final temMedia = rit.media.isNotEmpty;
    final ant = mesesLongos[int.parse(ymAdd(rit.ym, -1).substring(5)) - 1].toLowerCase();
    final atual = rit.gastoAteHoje, med = rit.mediaMesmoDia;
    final projecao = rit.diaHoje > 0 && rit.diaHoje >= 3 ? atual / rit.diaHoje * rit.dias : null;
    String frase;
    if (rit.diaHoje > 0 && temMedia && med > 0) {
      final v = atual / med - 1;
      frase = v.abs() < .08 ? 'Você está no seu ritmo normal de gastos.' : 'Você está gastando ${(v.abs() * 100).round()}% ${v > 0 ? 'mais rápido' : 'mais devagar'} que a sua média.';
    } else {
      frase = 'Quanto já tinha saído até cada dia do mês.';
    }
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Ritmo dos gastos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(frase, style: TextStyle(color: G.texto2, fontSize: 12.5)),
        const SizedBox(height: 14),
        GraficoLinha(
          titulo: 'Ritmo dos gastos',
          series: [rit.atual, rit.anterior, if (temMedia) rit.media],
          cores: [corSaida, corAnterior, if (temMedia) G.lavanda],
          tracejada: [false, true, true],
          nomes: [mesNome, ant, if (temMedia) 'média'],
          pontosX: rit.dias,
          rotulosX: const ['1', '10', '20', 'fim'],
          rotuloToque: (i) => 'Dia ${i + 1}',
          formatoY: curto,
          linhaH: rit.limite > 0 ? rit.limite : null,
          nomeLinhaH: rit.limite > 0 ? 'limite' : null,
          altura: 240,
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: [
          Legenda(corSaida, mesNome),
          Legenda(corAnterior, ant, tracejada: true),
          if (temMedia) Legenda(G.lavanda, 'sua média', tracejada: true),
          if (rit.limite > 0) Legenda(G.neg, 'limite', tracejada: true),
        ]),
        if (rit.diaHoje > 0)
          FaixaNumeros([
            ('Até hoje', brl(atual), corSaida),
            if (projecao != null) ('Previsão do mês', brl(projecao), rit.limite > 0 && projecao > rit.limite ? G.neg : null),
            if (rit.limite > 0) ('Limite', brl(rit.limite), null),
          ]),
      ]),
    );
  }
}

/// 3. Para onde foi o dinheiro (rosca por categoria).
class _OndeFoi extends StatefulWidget {
  final ResumoMes r;
  final ValueChanged<String> verCategoria;
  const _OndeFoi({required this.r, required this.verCategoria});
  @override
  State<_OndeFoi> createState() => _OndeFoiState();
}

class _OndeFoiState extends State<_OndeFoi> {
  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final itens = r.porCategoria.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (itens.isEmpty) return const SizedBox.shrink();
    final top = itens.take(7).toList();
    final resto = itens.skip(7).fold<double>(0, (a, e) => a + e.value);
    final valores = [...top.map((e) => e.value), if (resto > 0) resto];
    final cores = [...top.map((e) => catGasto(e.key).cor), if (resto > 0) const Color(0xFF7A7F92)];
    final nomes = [...top.map((e) => catGasto(e.key).nome), if (resto > 0) 'Outras ${itens.length - 7}'];
    final cats = [...top.map((e) => e.key), if (resto > 0) null];
    final maior = valores.first;
    // Com várias categorias, barras ordenadas comparam melhor do que uma rosca:
    // a faixa de cima mostra a divisão do total e a lista, o tamanho de cada uma.
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoCartao('Para onde foi o dinheiro', sub: '${brl(r.saiu)} em ${itens.length} categoria${itens.length == 1 ? '' : 's'}'),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(children: [
              for (var i = 0; i < valores.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(flex: (valores[i] / r.saiu * 1000).round().clamp(8, 1000).toInt(), child: ColoredBox(color: cores[i])),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < valores.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: cats[i] == null ? null : () => widget.verCategoria(cats[i]!),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              child: Column(children: [
                Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: cores[i], borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 9),
                  Expanded(child: Text(nomes[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(pct(valores[i] / r.saiu, casas: 0), style: TextStyle(color: G.apagado, fontSize: 12.5)),
                  const SizedBox(width: 10),
                  SizedBox(width: 92, child: Text(brl(valores[i]), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (cats[i] != null) Icon(Icons.chevron_right_rounded, size: 18, color: G.apagado) else const SizedBox(width: 18),
                ]),
                const SizedBox(height: 6),
                Padding(padding: const EdgeInsets.only(left: 19, right: 18), child: Barra(valores[i] / maior, cor: cores[i], altura: 5)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// 4. Este mês × sua média, por categoria.
class _Comparativo extends StatelessWidget {
  final ({List<CompCategoria> itens, int ateDia, int nMeses}) comp;
  final ValueChanged<String> verCategoria;
  final bool atual;
  const _Comparativo({required this.comp, required this.verCategoria, required this.atual});
  @override
  Widget build(BuildContext context) {
    if (comp.nMeses == 0 || comp.itens.isEmpty) return const SizedBox.shrink();
    final itens = comp.itens.take(8).toList();
    final mx = itens.fold<double>(1, (a, c) => [a, c.atual, c.media].reduce((x, y) => x > y ? x : y));
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Este mês × sua média', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          atual ? 'Do dia 1 ao dia ${comp.ateDia}, comparado ao mesmo trecho ${comp.nMeses == 1 ? 'do mês anterior' : 'dos ${comp.nMeses} meses anteriores'}.' : 'Comparado ${comp.nMeses == 1 ? 'ao mês anterior' : 'à média dos ${comp.nMeses} meses anteriores'}.',
          style: TextStyle(color: G.apagado, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        for (final c in itens)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => verCategoria(c.cat),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(catGasto(c.cat).icone, size: 16, color: catGasto(c.cat).cor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(catGasto(c.cat).nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                  _Seta(c),
                ]),
                const SizedBox(height: 6),
                _BarraDupla(atual: c.atual / mx, media: c.media / mx, cor: catGasto(c.cat).cor),
                const SizedBox(height: 4),
                Text('${brl(c.atual)} agora · média ${brl(c.media)}', style: TextStyle(color: G.apagado, fontSize: 11.5)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Seta extends StatelessWidget {
  final CompCategoria c;
  const _Seta(this.c);
  @override
  Widget build(BuildContext context) {
    final v = c.var_;
    if (v == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: G.v(0x14), borderRadius: BorderRadius.circular(99)),
        child: Text('novo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: G.texto2)),
      );
    }
    final sobe = v > .03, desce = v < -.03;
    final cor = sobe ? corSaida : (desce ? G.pos : G.apagado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: cor.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(sobe ? Icons.arrow_upward_rounded : (desce ? Icons.arrow_downward_rounded : Icons.remove_rounded), size: 13, color: cor),
        const SizedBox(width: 2),
        Text('${(v.abs() * 100).round()}%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: cor)),
      ]),
    );
  }
}

class _BarraDupla extends StatelessWidget {
  final double atual, media;
  final Color cor;
  const _BarraDupla({required this.atual, required this.media, required this.cor});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => SizedBox(
          height: 14,
          child: Stack(children: [
            Positioned(left: 0, top: 0, child: Container(width: w * atual.clamp(0, 1) * t, height: 8, decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(4)))),
            Positioned(left: 0, top: 10, child: Container(width: w * media.clamp(0, 1) * t, height: 4, decoration: BoxDecoration(color: corAnterior.withValues(alpha: .7), borderRadius: BorderRadius.circular(2)))),
          ]),
        ),
      );
    });
  }
}
