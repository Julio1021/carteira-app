// Aba "Análise" do Patrimônio.
import 'package:flutter/material.dart';

import '../dados/analise_inv.dart';
import '../dados/indices.dart';
import '../dados/patrimonio.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/graficos.dart';
import '../widgets/movimento.dart';
import '../widgets/painel.dart';

String _mesAno(String ym) => '${_abr(ym)}/${ym.substring(2, 4)}';
String _abr(String ym) => mesesLongos[int.parse(ym.substring(5, 7)) - 1].substring(0, 3).toLowerCase();

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
        Cartao(child: Text('Lance o saldo dos seus investimentos (aba Lançar) para ver a análise da evolução.', style: TextStyle(color: G.texto2))),
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
        final rendeu = meses.fold<double>(0, (a, ym) => a + (porYm[ym]?.ganho ?? 0));
        final p = cmp?.pctCdi;
        final assuntos = <(String, Widget)>[
          ('Comparação', _CardIndices(cmp: cmp, idx: idx)),
          if (ativos.isNotEmpty) ('Por ativo', _CardAtivos(lista: ativos)),
          if (rp != null) ('Renda passiva', _CardRenda(rp: rp)),
          if (inst.isNotEmpty) ('Diversificação', _CardDiversificacao(fatias: porClasse ? cls : inst, porClasse: porClasse, onTrocar: (v) => setState(() => porClasse = v))),
          if (dest.isNotEmpty) ('Destaques', _CardDestaques(lista: dest)),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
          children: emSequencia([
            TituloSecao(
              'Seus números',
              direita: BotaoPeriodo(
                valor: periodo,
                opcoes: const [('12m', '12 meses'), ('ano', 'Este ano'), ('tudo', 'Desde o início')],
                onMudar: (v) => setState(() => periodo = v),
              ),
            ),
            GradeKpi([
              Kpi(
                icone: Icons.speed_rounded,
                rotulo: '% do CDI',
                valor: p ?? 0,
                formato: (v) => p == null ? '—' : '${(v * 100).round()}%',
                sub: cmp == null ? 'sem índice ainda' : (p! >= 1 ? 'acima do CDI' : 'abaixo do CDI'),
                cor: p == null ? G.texto : (p >= 1 ? G.pos : (p >= .85 ? G.alerta : G.neg)),
              ),
              Kpi(icone: Icons.trending_up_rounded, rotulo: 'Rendeu', valor: rendeu, formato: (v) => brl(v, sinal: true), sub: cmp == null ? 'no período' : '${pct(cmp.carteira, sinal: true)} no período', cor: rendeu >= 0 ? G.pos : G.neg),
              Kpi(icone: Icons.payments_outlined, rotulo: 'Renda passiva', valor: rp?.media ?? 0, formato: (v) => rp == null ? '—' : brl(v), sub: rp == null ? 'falta 1 mês fechado' : 'média por mês', cor: G.lavanda),
              Kpi(
                icone: Icons.shield_outlined,
                rotulo: 'Acima da inflação',
                valor: cmp?.real ?? 0,
                formato: (v) => cmp?.real == null ? '—' : pct(v, sinal: true),
                sub: cmp?.real == null ? 'sem IPCA ainda' : 'ganho real',
                cor: (cmp?.real ?? 0) >= 0 ? G.pos : G.neg,
              ),
            ]),
            const SizedBox(height: 16),
            ChipsAssunto(nomes: [for (final a in assuntos) a.$1], construir: (_, i) => assuntos[i].$2),
          ]),
        );
      },
    );
  }
}

class _CardIndices extends StatelessWidget {
  final Comparacao? cmp;
  final Indices idx;
  const _CardIndices({required this.cmp, required this.idx});
  @override
  Widget build(BuildContext context) {
    final cCart = G.lavanda, cCdi = G.pos, cPoup = G.alerta, cIpca = G.saida;
    final m = cmp;
    if (m == null) {
      return Cartao(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CabecalhoCartao('Comparado com o CDI'),
          Text(idx.temDados ? 'Ainda não há meses com rendimento e índice publicados neste período.' : 'Assim que o app conseguir buscar os índices na internet, a comparação aparece aqui.', style: TextStyle(color: G.texto2)),
        ]),
      );
    }
    final rot = [for (final ym in ['', ...m.meses]) ym.isEmpty ? '' : _abr(ym)];
    final series = <List<double>>[m.curvaCart, m.curvaCdi, if (m.curvaPoup.isNotEmpty) m.curvaPoup, if (m.curvaIpca.isNotEmpty) m.curvaIpca];
    final cores = [cCart, cCdi, if (m.curvaPoup.isNotEmpty) cPoup, if (m.curvaIpca.isNotEmpty) cIpca];
    final nomes = ['Sua carteira', 'CDI', if (m.curvaPoup.isNotEmpty) 'Poupança', if (m.curvaIpca.isNotEmpty) 'Inflação'];
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoCartao('Rendimento acumulado', sub: '${_mesAno(m.meses.first)} a ${_mesAno(m.meses.last)} · ${m.meses.length} ${m.meses.length == 1 ? 'mês' : 'meses'}'),
        GraficoLinha(
          titulo: 'Rendimento acumulado',
          series: [for (final l in series) [for (final v in l) v - 100]],
          cores: cores,
          nomes: nomes,
          tracejada: [false, false, true, true],
          rotulosX: rot,
          formatoY: (v) => '${v.round()}%',
          preencherPrimeira: true,
          altura: 220,
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 4),
        Builder(builder: (_) {
          final vals = [m.carteira, m.cdi, if (m.curvaPoup.isNotEmpty) m.poup, if (m.curvaIpca.isNotEmpty) m.ipca];
          Widget item(int i) => Row(children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: cores[i], borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 7),
                Expanded(child: Text(nomes[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: G.texto2, fontSize: 12.5))),
                Text(vals[i] == null ? '—' : pct(vals[i]!, sinal: true), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: i == 0 ? cores[0] : G.texto)),
              ]);
          return Column(children: [
            for (var i = 0; i < nomes.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Expanded(child: item(i)),
                  const SizedBox(width: 16),
                  Expanded(child: i + 1 < nomes.length ? item(i + 1) : const SizedBox()),
                ]),
              ),
          ]);
        }),
        Rodape(idx.exemplo ? 'Índices de exemplo (demonstração).' : 'CDI, poupança e IPCA: Banco Central${idx.ultimo(idx.cdi) == null ? '' : ', até ${_mesAno(idx.ultimo(idx.cdi)!)}'}.'),
      ]),
    );
  }
}

class _CardAtivos extends StatelessWidget {
  final List<DesempenhoAtivo> lista;
  const _CardAtivos({required this.lista});
  @override
  Widget build(BuildContext context) {
    final fracos = lista.where((d) => d.pctCdi != null && d.pctCdi! < .7 && d.saldo > 100).toList();
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CabecalhoCartao('Por ativo', sub: 'Rendimento no período, sem contar aportes'),
        CaixaLista([
          for (var i = 0; i < lista.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
              child: Row(children: [
                SizedBox(width: 20, child: Text('${i + 1}', style: TextStyle(color: G.apagado, fontWeight: FontWeight.w700, fontSize: 12.5))),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: lista[i].a.cor(lista[i].indice), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lista[i].a.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${brl(lista[i].saldo)} · ${brl(lista[i].ganho, sinal: true)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: G.apagado, fontSize: 12)),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(pct(lista[i].rent, sinal: true), style: TextStyle(fontWeight: FontWeight.w700, color: lista[i].rent >= 0 ? G.texto : G.neg)),
                  if (lista[i].pctCdi != null)
                    Builder(builder: (_) {
                      final q = lista[i].pctCdi!;
                      final cor = q >= 1 ? G.pos : (q >= .7 ? G.alerta : G.neg);
                      return Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: cor.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
                        child: Text('${(q * 100).round()}% CDI', style: TextStyle(color: cor, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      );
                    }),
                ]),
              ]),
            ),
        ]),
        if (fracos.isNotEmpty)
          Dica('${fracos.map((d) => d.a.nome).join(', ')} ${fracos.length > 1 ? 'renderam' : 'rendeu'} menos de 70% do CDI.'),
      ]),
    );
  }
}

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
    final s = sel;
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CabecalhoCartao('Renda passiva', sub: 'Quanto os investimentos renderam em cada mês'),
        GraficoBarras(
          titulo: 'Rendimento mês a mês',
          rotulos: [for (final ym in rp.meses) _abr(ym)],
          valores: [for (final g in rp.ganhos) [g < 0 ? 0.0 : g]],
          cores: [G.pos],
          nomes: const ['Rendeu'],
          formatoY: curto,
          altura: 190,
          selecionado: s,
          onToque: (i) => setState(() => sel = i == sel ? null : i),
        ),
        FaixaNumeros([
          if (s != null && s < rp.meses.length) ('Em ${_abr(rp.meses[s])}', brl(rp.ganhos[s], sinal: true), G.pos) else ('Média por mês', brl(rp.media), G.pos),
          if (rp.pctSalario != null) ('Da sua renda', '${(rp.pctSalario! * 100).toStringAsFixed(1).replaceAll('.', ',')}%', null),
          if (rp.pagaConta != null) ('Já paga', rp.pagaConta!, null),
        ]),
      ]),
    );
  }
}

class _CardDiversificacao extends StatelessWidget {
  final List<Fatia> fatias;
  final bool porClasse;
  final ValueChanged<bool> onTrocar;
  const _CardDiversificacao({required this.fatias, required this.porClasse, required this.onTrocar});
  @override
  Widget build(BuildContext context) {
    final tot = fatias.fold<double>(0, (t, f) => t + f.valor);
    final cores = [for (var i = 0; i < fatias.length; i++) G.coresSerie[i % G.coresSerie.length]];
    final maior = fatias.isEmpty ? null : fatias.first;
    final conc = maior != null && tot > 0 && maior.valor / tot > .6 && fatias.length > 1;
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoCartao('Diversificação', sub: porClasse ? 'Por tipo de investimento' : 'Por instituição'),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: G.abasFundo, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            for (final (v, t) in const [(false, 'Instituição'), (true, 'Tipo')])
              Expanded(
                child: GestureDetector(
                  onTap: () => onTrocar(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(color: porClasse == v ? G.branco : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                    child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: porClasse == v ? G.tinta : G.texto2)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Rosca(key: ValueKey(porClasse), valores: [for (final f in fatias) f.valor], cores: cores, centro: '${fatias.length}', sub: porClasse ? 'tipos' : 'instituições', tam: 132),
          const SizedBox(width: 14),
          Expanded(
            child: Column(children: [
              for (var i = 0; i < fatias.length && i < 7; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: cores[i], borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(fatias[i].nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    Text('${(fatias[i].valor / tot * 100).toStringAsFixed(0)}%', style: TextStyle(color: G.texto2, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
            ]),
          ),
        ]),
        if (conc) Dica('${(maior.valor / tot * 100).round()}% está em ${maior.nome}. Espalhar diminui o risco.', icone: Icons.pie_chart_outline_rounded),
        if (!porClasse && fatias.any((f) => f.nome == 'Outras')) const Rodape('Preencha a instituição de cada ativo (aba Ativos) para a divisão ficar exata.'),
      ]),
    );
  }
}

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
    Color cor(int tom) => tom > 0 ? G.pos : (tom < 0 ? G.alerta : G.lavanda);
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CabecalhoCartao('Destaques'),
        for (var i = 0; i < lista.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: cor(lista[i].tom).withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
                child: Icon(ic(lista[i].tipo), size: 18, color: cor(lista[i].tom)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: lista[i].antes),
                      TextSpan(text: lista[i].forte, style: TextStyle(fontWeight: FontWeight.w700, color: lista[i].tom == 0 ? G.texto : cor(lista[i].tom))),
                      TextSpan(text: lista[i].depois),
                    ]),
                    style: TextStyle(color: G.texto2, fontSize: 14, height: 1.35),
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
