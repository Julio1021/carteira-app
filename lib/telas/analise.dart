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
import 'analise_site.dart';
import 'inicio_site.dart' show PrevisaoSite, previsaoMes;
import 'limites.dart';

Color get corEntrada => G.pos;
Color get corSaida => G.saida;
Color get corInvest => G.lavanda;
const corAnterior = Color(0xFF8C90A6);

/// Aba "Análise" do Extrato: gráficos que contam a história do mês.
class AnaliseExtrato extends StatefulWidget {
  final String ym;
  final ValueChanged<String> onMes;
  final ValueChanged<String> verCategoria;
  final VoidCallback? irLista, irLimites;
  final ValueChanged<String>? buscar;
  const AnaliseExtrato({super.key, required this.ym, required this.onMes, required this.verCategoria, this.irLista, this.irLimites, this.buscar});
  @override
  State<AnaliseExtrato> createState() => _AnaliseExtratoState();
}

class _AnaliseExtratoState extends State<AnaliseExtrato> {

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final r = ResumoMes.de(repo, widget.ym);
    final rit = ritmoDoMes(repo, widget.ym);
    final comp = comparativoCategorias(repo, widget.ym);
    final mesNome = mesesLongos[int.parse(widget.ym.substring(5)) - 1].toLowerCase();
    final hoje = hojeIso();
    final atual = ymDe(hoje) == widget.ym;
    final meses = [for (var i = 5; i >= 0; i--) i == 0 ? r : ResumoMes.de(repo, ymAdd(widget.ym, -i))];
    final hist12 = historicoMeses(repo, widget.ym, 12);
    final limites = widget.irLimites ?? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaLimites(ym: widget.ym)));
    final extras = <(String, Widget)>[
      ('Destaques', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DestaquesMes(ym: widget.ym),
        _RitmoCard(rit: rit, mesNome: mesNome),
      ])),
      ('Fluxo', FluxoDinheiro(r: r)),
      ('Calendário', CalendarioCalor(ym: widget.ym)),
      ('Comparar', _Comparativo(comp: comp, verCategoria: widget.verCategoria, atual: atual)),
    ];
    final per = mesLongo(widget.ym);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SecaoSite(atual ? 'Como o mês está indo' : 'Como foi o mês', per, primeira: true),
      PrevisaoSite(r: r, prev: previsaoMes(repo, widget.ym), irExtrato: widget.irLista ?? () {}, irLimites: limites),
      SecaoSite('Para onde foi o dinheiro', per),
      DistribuicaoSite(r: r, meses: meses),
      const SizedBox(height: 14),
      OndeMaisGastouSite(r: r, buscar: widget.buscar ?? (_) {}),
      const SizedBox(height: 14),
      FormaPagamentoSite(r: r),
      const SizedBox(height: 14),
      GastosCategoriaSite(r: r, verCategoria: widget.verCategoria, ajustarLimites: limites),
      SecaoSite('Ao longo do tempo', 'Últimos 12 meses'),
      EntradasGastosSite(hist: hist12, limite: r.limiteTotal, ymAtual: widget.ym, onMes: widget.onMes),
      SecaoSite('Mais detalhes', per),
      ChipsAssunto(nomes: [for (final a in extras) a.$1], construir: (_, i) => extras[i].$2),
    ]);
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
        const Text('Ritmo dos gastos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
        const Text('Este mês × sua média', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
                Text('${brl(c.atual)} agora · média ${brl(c.media)}', style: TextStyle(color: G.apagado, fontSize: 11)),
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
        child: Text('novo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: G.texto2)),
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
        Text('${(v.abs() * 100).round()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cor)),
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
