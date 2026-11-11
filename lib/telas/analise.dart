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
    final ant = rit.anteriorMesmoDia, atual = rit.gastoAteHoje;
    final varAnt = ant > 0 ? atual / ant - 1 : null;
    final txa = r.entrou > 0 ? r.sobra / r.entrou : null;
    final assuntos = <(String, Widget)>[
      ('Resumo', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Destaque(r: r, rit: rit, mesNome: mesNome),
        const SizedBox(height: 12),
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
        Kpi(icone: Icons.south_west_rounded, rotulo: 'Entrou', valor: r.entrou, formato: brl, sub: mesNome, cor: corEntrada),
        Kpi(icone: Icons.north_east_rounded, rotulo: 'Saiu', valor: r.saiu, formato: brl, sub: r.investiu > 0 ? 'investiu ${brl(r.investiu)}' : mesNome, cor: corSaida),
        Kpi(icone: Icons.account_balance_wallet_outlined, rotulo: r.sobra >= 0 ? 'Sobrou' : 'Faltou', valor: r.sobra.abs(), formato: brl, sub: txa != null && r.sobra >= 0 ? '${(txa * 100).round()}% do que entrou' : '', cor: r.sobra >= 0 ? G.pos : G.neg),
        Kpi(
          icone: Icons.speed_rounded,
          rotulo: rit.diaHoje > 0 ? 'Gasto até hoje' : 'Ritmo',
          texto: varAnt == null ? '—' : '${varAnt >= 0 ? '+' : '−'}${(varAnt.abs() * 100).round()}%',
          sub: 'vs. mês anterior',
          cor: varAnt == null ? G.texto : (varAnt > .05 ? G.neg : G.pos),
        ),
      ]),
      const SizedBox(height: 16),
      ChipsAssunto(nomes: [for (final a in assuntos) a.$1], construir: (_, i) => assuntos[i].$2),
    ]);
  }
}

/// Frase de abertura, em linguagem simples.
class _Destaque extends StatelessWidget {
  final ResumoMes r;
  final Ritmo rit;
  final String mesNome;
  const _Destaque({required this.r, required this.rit, required this.mesNome});
  @override
  Widget build(BuildContext context) {
    final emAndamento = rit.diaHoje > 0;
    final txaSobra = r.entrou > 0 ? r.sobra / r.entrou : null;
    final ant = rit.anteriorMesmoDia, atual = rit.gastoAteHoje;
    final varAnt = ant > 0 ? atual / ant - 1 : null;
    return Cartao(
      gradiente: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [G.lavandaFundo, G.v(0x0A)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome_rounded, color: G.lavanda, size: 18),
          const SizedBox(width: 8),
          Text(emAndamento ? 'Resumo até hoje' : 'Resumo de $mesNome', style: TextStyle(color: G.lavanda, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(style: TextStyle(fontSize: 15.5, height: 1.45, color: G.texto), children: [
            TextSpan(text: emAndamento ? 'Até o dia ${rit.diaHoje}, entraram ' : 'Em $mesNome entraram '),
            TextSpan(text: brl(r.entrou), style: TextStyle(fontWeight: FontWeight.w700, color: corEntrada)),
            const TextSpan(text: ' e saíram '),
            TextSpan(text: brl(r.saiu), style: TextStyle(fontWeight: FontWeight.w700, color: corSaida)),
            const TextSpan(text: '. '),
            if (r.entrou > 0) ...[
              TextSpan(text: r.sobra >= 0 ? 'Sobraram ' : 'Faltaram '),
              TextSpan(text: brl(r.sobra.abs()), style: const TextStyle(fontWeight: FontWeight.w700)),
              if (txaSobra != null && r.sobra >= 0) TextSpan(text: ', ${(txaSobra * 100).round()}% do que entrou.'),
              if (r.sobra < 0) const TextSpan(text: '.'),
              if (r.investiu > 0) ...[
                const TextSpan(text: ' Você investiu '),
                TextSpan(text: brl(r.investiu), style: TextStyle(fontWeight: FontWeight.w700, color: corInvest)),
                TextSpan(text: ' (${((r.pctInvestido ?? 0) * 100).round()}% do que entrou)'),
                if (r.sobra >= 0) ...[
                  TextSpan(text: r.sobraEmConta >= 0 ? ' e ficaram ' : ' e usou '),
                  TextSpan(text: brl(r.sobraEmConta.abs()), style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: r.sobraEmConta >= 0 ? ' em conta.' : ' do que já tinha em conta.'),
                ] else
                  const TextSpan(text: '.'),
              ],
            ],
            if (r.entrou <= 0 && r.investiu > 0) ...[
              const TextSpan(text: 'Você investiu '),
              TextSpan(text: brl(r.investiu), style: TextStyle(fontWeight: FontWeight.w700, color: corInvest)),
              const TextSpan(text: '.'),
            ],
          ]),
        ),
        if (varAnt != null && emAndamento) ...[
          const SizedBox(height: 8),
          Text(
            varAnt.abs() < .05
                ? 'Você está gastando no mesmo ritmo do mês passado.'
                : 'Você gastou ${(varAnt.abs() * 100).round()}% ${varAnt > 0 ? 'a mais' : 'a menos'} que no mesmo dia do mês passado (${brl(ant)}).',
            style: TextStyle(color: varAnt > .05 ? G.negTexto : (varAnt < -.05 ? G.pos : G.texto2), fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ]),
    );
  }
}

/// 1. Entrou × Saiu mês a mês.
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
        const SizedBox(height: 2),
        Text('Toque num mês para ver os valores. Embaixo, quanto sobrou.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
        const SizedBox(height: 14),
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
        if (comDados.length >= 2) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _MiniInfo('Sobra média', brl(mediaSobra), mediaSobra >= 0 ? G.pos : corSaida)),
            if (melhor != null) Expanded(child: _MiniInfo('Melhor mês', '${mesLongo(melhor.ym)} · ${brl(melhor.sobra)}', G.texto)),
          ]),
        ],
        if (pctMedio != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _MiniInfo('Investe em média', '${(pctMedio * 100).round()}% do que entra', corInvest)),
            Expanded(child: _MiniInfo('Investido no período', brl(hist.fold<double>(0, (a, m) => a + m.investiu)), corInvest)),
          ]),
        ],
      ]),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String t, v;
  final Color cor;
  const _MiniInfo(this.t, this.v, this.cor);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: TextStyle(color: G.apagado, fontSize: 12)),
        const SizedBox(height: 2),
        Text(v, style: TextStyle(fontWeight: FontWeight.w700, color: cor, fontSize: 13.5)),
      ]);
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
      frase = 'Cada ponto é quanto já tinha saído até aquele dia.';
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
        if (projecao != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: G.v(0x0D), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(Icons.timeline_rounded, color: G.lavanda, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(style: TextStyle(fontSize: 13, color: G.texto2), children: [
                  const TextSpan(text: 'Nesse ritmo, o mês fecha perto de '),
                  TextSpan(text: brl(projecao), style: TextStyle(fontWeight: FontWeight.w700, color: rit.limite > 0 && projecao > rit.limite ? corSaida : G.texto)),
                  if (rit.limite > 0) TextSpan(text: projecao > rit.limite ? ', acima do limite de ${brl(rit.limite)}.' : ', dentro do limite de ${brl(rit.limite)}.'),
                ])),
              ),
            ]),
          ),
        ],
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
  int? sel;
  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final itens = r.porCategoria.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (itens.isEmpty) return const SizedBox.shrink();
    final top = itens.take(6).toList();
    final resto = itens.skip(6).fold<double>(0, (a, e) => a + e.value);
    final valores = [...top.map((e) => e.value), if (resto > 0) resto];
    final cores = [...top.map((e) => catGasto(e.key).cor), if (resto > 0) const Color(0xFF5A5E72)];
    final nomes = [...top.map((e) => catGasto(e.key).nome), if (resto > 0) 'Outras ${itens.length - 6}'];
    final cats = [...top.map((e) => e.key), if (resto > 0) null];
    final s = sel;
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Para onde foi o dinheiro', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('Toque numa fatia ou numa categoria para ver os gastos dela.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
        const SizedBox(height: 14),
        Center(
          child: Rosca(
            valores: valores,
            cores: cores,
            centro: s == null ? brl(r.saiu) : brl(valores[s]),
            sub: s == null ? 'em ${itens.length} categorias' : '${nomes[s]}\n${pct(valores[s] / r.saiu, casas: 1)}',
            tam: 200,
            onToque: (i) => setState(() => sel = i),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < valores.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: cats[i] == null ? null : () => widget.verCategoria(cats[i]!),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              child: Row(children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: cores[i], borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 10),
                Expanded(child: Text(nomes[i], style: TextStyle(fontWeight: sel == i ? FontWeight.w700 : FontWeight.w600))),
                Text(pct(valores[i] / r.saiu, casas: 0), style: TextStyle(color: G.apagado, fontSize: 12.5)),
                const SizedBox(width: 12),
                SizedBox(width: 92, child: Text(brl(valores[i]), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                if (cats[i] != null) Icon(Icons.chevron_right_rounded, size: 18, color: G.apagado),
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
