import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/modelos.dart';
import '../dados/patrimonio.dart';
import '../dados/invest_pat.dart';
import 'analise_inv.dart';
import '../dados/categorias.dart';
import '../dados/repo.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import 'inicio_site.dart';
import '../widgets/site.dart';
import '../widgets/movimento.dart';
import '../widgets/largo.dart';
import '../widgets/painel.dart';
import 'objetivos.dart';
import 'patrimonio_site.dart';
import 'lancar_valores.dart';
import '../widgets/formulario.dart';
import '../widgets/graficos.dart';

class TelaPatrimonio extends StatefulWidget {
  final int subInicial;
  const TelaPatrimonio({super.key, this.subInicial = 0});
  @override
  State<TelaPatrimonio> createState() => _TelaPatrimonioState();
}

class _TelaPatrimonioState extends State<TelaPatrimonio> {
  // "Lançar valores" (1) abre numa tela própria, com a data e o Salvar fixos
  late int sub = widget.subInicial == 1 ? 0 : widget.subInicial;

  @override
  void initState() {
    super.initState();
    if (widget.subInicial == 1) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? abrirLancarValores(context) : null);
  }

  void _ir(int i) => i == 1 ? abrirLancarValores(context) : setState(() => sub = i);
  // abas visíveis: Visão geral, Análise e Ativos. Lançar (1) e Relatórios (3)
  // abrem pelos botões da Visão geral, com "Voltar".

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final c = calcularCarteira(repo);
    final corpo = switch (sub) {
      0 => _Resumo(c: c, ir: _ir),
      2 => _Ativos(c: c),
      4 => AnaliseInvest(c: c),
      _ => _Relatorios(c: c),
    };
    final largo = telaLarga(context);
    const pilulas = [(0, 'Visão geral'), (1, 'Lançar valores'), (2, 'Ativos'), (3, 'Relatórios'), (4, 'Análise')];
    return Column(children: [
      Padding(
        padding: largo ? const EdgeInsets.fromLTRB(28, 14, 28, 14) : const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (i, t) in pilulas)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: sub == i ? S.ink : S.surface,
                  shape: StadiumBorder(side: BorderSide(color: sub == i ? S.ink : S.line)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _ir(i);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(t, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: sub == i ? S.bg : S.ink2)),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
      Expanded(child: largo && sub != 0 ? Centralizar(max: sub == 4 ? 1180 : 900, child: corpo) : corpo),
    ]);
  }
}

// =====================================================================
// Resumo
// =====================================================================

class _Resumo extends StatelessWidget {
  final Carteira c;
  final ValueChanged<int> ir;
  const _Resumo({required this.c, required this.ir});

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    if (c.vazia) {
      return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 150), children: emSequencia([
        Cartao(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Comece pelos seus investimentos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Cadastre cada aplicação (CDB, Tesouro, caixinha…) e lance o saldo de cada uma de tempos em tempos. O app separa o que você aplicou do que rendeu.', style: TextStyle(color: G.texto2, height: 1.4)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: () => abrirFolha(context, const FormAtivo()), icon: const Icon(Icons.add_rounded), label: const Text('Cadastrar primeiro ativo')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/ajustes'), icon: const Icon(Icons.file_upload_outlined), label: const Text('Ou importar o backup do site')),
          ]),
        ),
      ]));
    }
    final emConta = repo.contas.isEmpty ? 0.0 : saldoEmConta(repo);
    final patrimonio = c.total + emConta;
    final pctInv = patrimonio > 0 ? c.total / patrimonio : 1.0;
    final ult = c.ultimo!;
    final posicoes = c.posicoes.where((p) => p.valor > 0.005).toList()..sort((a, b) => b.valor.compareTo(a.valor));
    final hojeYm = ymDe(hojeIso());
    final ultMeses = c.meses.where((m) => m.ym.compareTo(ymAdd(hojeYm, -11)) >= 0).toList();
    final amostra = _amostrar(c.dias, 90);
    final esquerda = <Widget>[
      _HeroPat(c: c, emConta: emConta, patrimonio: patrimonio, pctInv: pctInv, irLancar: () => ir(1)),
      const SizedBox(height: 14),
      BotaoSite('Lançar valores de hoje', icone: Ico.mais, onTap: () => ir(1)),
    ];
    final finais = <Widget>[_Pendencias(c: c), CartaoObjetivos(c: c)];
    // Visão geral = resumo. Os detalhes ficam em Relatórios (por ano) e Análise (comparações).
    final ns = ['Ativos', if (amostra.length >= 2) 'Evolução', 'Origem'];
    Widget assunto(String nome) => switch (nome) {
            'Ativos' => CartaoSite(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CabecalhoSite('Seus ativos', sub: 'Saldo de cada investimento no total de ${brl(c.total)}', acao: 'Gerenciar', onAcao: () => ir(2)),
          LayoutBuilder(builder: (context, cons) {
            final larg = cons.maxWidth >= 520; // computador: rosca à esquerda, lista à direita
            final rosca = Rosca(
              valores: [for (final p in posicoes) p.valor],
              cores: [for (final p in posicoes) p.cor],
              centro: brl(c.total),
              sub: 'Total',
              tam: larg ? 170 : 200,
            );
            final linhas = [for (final p in posicoes) _LinhaPos(p: p, total: c.total)];
            if (!larg) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Center(child: rosca), const SizedBox(height: 14), ...linhas]);
            return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              rosca,
              const SizedBox(width: 22),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: linhas)),
            ]);
          }),
        ]),
      ),
            'Origem' => CartaoSite(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CabecalhoSite('De onde vem seu patrimônio', sub: c.investido > 0 ? '${pct(c.rendeu / c.investido, sinal: true)} desde ${dataBr(c.dias.first.data)}' : null),
          Barra(c.total > 0 ? c.investido / c.total : 0, cor: G.neutroSerie, trilho: G.pos, altura: 10),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Mini('Você aplicou', brl(c.investido), G.neutroSerie)),
            Expanded(child: _Mini('O dinheiro rendeu', brl(c.rendeu, sinal: true), G.pos)),
          ]),
        ]),
      ),
            'Alocação' => AlocacaoClasseSite(c: c),
            'Rentabilidade' => RentMensalSite(meses: ultMeses),
            'Por ativo' => EvolucaoAtivoSite(amostra: amostra, posicoes: posicoes),
            'Posição' => PosicaoAtualSite(c: c, posicoes: posicoes, verRelatorios: () => ir(3)),
            'Evolução' => CartaoSite(
        padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const CabecalhoSite('Evolução do patrimônio', sub: 'Patrimônio comparado ao total que você aplicou'),
            GraficoLinha(
              titulo: 'Evolução do patrimônio',
              series: [amostra.map((d) => d.total).toList(), amostra.map((d) => d.investido).toList()],
              cores: [S.accent, S.second],
              tracejada: const [false, true],
              formatoY: curto,
              rotulosX: [dataCurta(amostra.first.data), dataCurta(amostra[amostra.length ~/ 2].data), dataCurta(amostra.last.data)],
              nomes: const ['Saldo', 'Aplicado'],
              rotuloToque: (i) => dataBr(amostra[i.clamp(0, amostra.length - 1).toInt()].data),
            ),
            const SizedBox(height: 8),
            Row(children: [
              _Legenda(S.accent, 'Patrimônio'),
              SizedBox(width: 14),
              _Legenda(S.second, 'Valor aplicado'),
            ]),
          ]),
        ),
            _ => CartaoSite(
        padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CabecalhoSite('Rentabilidade mês a mês', sub: 'ganho em % sobre o saldo, sem contar aportes', acao: 'Relatório', onAcao: () => ir(3)),
            Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: S.neg, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text('perda', style: TextStyle(fontSize: 12, color: S.muted)),
              const SizedBox(width: 14),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: S.pos, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text('ganho · em %', style: TextStyle(fontSize: 12, color: S.muted)),
            ]),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, cons) {
              const gap = 6.0;
              final w = (cons.maxWidth - gap * 5) / 6;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                for (final m in ultMeses)
                  Container(
                    width: w,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Color.lerp(S.surface, m.rent >= 0 ? S.pos : S.neg, (.45 + m.rent.abs() * 40).clamp(.45, .95).toDouble()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(children: [
                      Text(mesesAbr[int.parse(m.ym.substring(5)) - 1][0].toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .85), fontWeight: FontWeight.w600)),
                      Text(pct(m.rent, casas: 1).replaceAll('%', '').replaceAll('+', ''), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
              ]);
            }),
          ]),
        ),
        };
    final chips = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final n in ns) ...[const SizedBox(height: 18), assunto(n)],
      const SizedBox(height: 18),
      ...finais,
    ]);
    return LayoutBuilder(builder: (context, cons) {
      if (cons.maxWidth >= 860) {
        // computador: cartão principal + atalhos/pendências em cima; embaixo,
        // todos os assuntos lado a lado (sem chips)
        return ListView(padding: const EdgeInsets.fromLTRB(28, 4, 28, 40), children: [
          Centralizar(
            max: 1180,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 11, child: esquerda.first),
                const SizedBox(width: 20),
                Expanded(flex: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: esquerda.sublist(2))),
              ]),
              const SizedBox(height: 20),
              chips,
            ]),
          ),
        ]);
      }
      return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 104), children: [...esquerda, chips]);
    });
  }

  static List<LinhaDia> _amostrar(List<LinhaDia> d, int max) {
    if (d.length <= max) return d;
    final out = <LinhaDia>[];
    for (var i = 0; i < max; i++) {
      out.add(d[(i * (d.length - 1) / (max - 1)).round()]);
    }
    return out;
  }

  Widget _at(BuildContext context, IconData i, String t, VoidCallback f, {bool destaque = false}) => Expanded(
        child: Column(children: [
          Material(
            color: destaque ? G.branco : G.v(0x10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: destaque ? G.branco : G.borda)),
            child: InkWell(borderRadius: BorderRadius.circular(18), onTap: f, child: SizedBox(width: 54, height: 54, child: Icon(i, color: destaque ? G.tinta : G.texto, size: 22))),
          ),
          const SizedBox(height: 7),
          Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: G.texto2)),
        ]),
      );
}

class _Legenda extends StatelessWidget {
  final Color cor;
  final String t;
  const _Legenda(this.cor, this.t);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(color: G.apagado, fontSize: 12.5)),
      ]);
}

class _Mini extends StatelessWidget {
  final String t, v;
  final Color cor;
  const _Mini(this.t, this.v, this.cor);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Legenda(cor, t),
        const SizedBox(height: 4),
        Text(v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: cor == G.pos ? G.pos : G.texto)),
      ]);
}

class _LinhaPos extends StatelessWidget {
  final PosAtivo p;
  final double total;
  const _LinhaPos({required this.p, required this.total});
  @override
  Widget build(BuildContext context) {
    final frac = total > 0 ? p.valor / total : 0.0;
    final destaque = p.indice == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: destaque ? S.surface2 : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: destaque ? S.line : Colors.transparent),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: p.cor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.a.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: S.ink, height: 1.4)),
              Text('${pct(frac, casas: 1)} da carteira', style: TextStyle(fontSize: 12, color: S.muted, height: 1.4)),
            ]),
          ),
          Text(brl(p.valor), style: TextStyle(fontFamily: S.fonteNum, fontSize: 16, fontWeight: FontWeight.w700, color: S.ink)),
        ]),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (_, c) => Container(
            height: 5,
            decoration: BoxDecoration(color: S.surface2, borderRadius: BorderRadius.circular(99)),
            alignment: Alignment.centerLeft,
            child: Container(width: c.maxWidth * frac.clamp(0, 1), decoration: BoxDecoration(color: p.cor, borderRadius: BorderRadius.circular(99))),
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(TextSpan(children: [
          TextSpan(text: '${brl(p.lucro, sinal: true)} (${pct(p.rent, sinal: true)})', style: TextStyle(fontWeight: FontWeight.w700, color: p.lucro >= 0 ? S.pos : S.neg)),
          if (p.ultima != null) TextSpan(text: ' · atualizado ${dataCurta(p.ultima!.data)}', style: TextStyle(color: S.muted)),
        ]), style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}

// =====================================================================
// Lançar saldos do dia
// =====================================================================

// =====================================================================
// Ativos
// =====================================================================

class _Ativos extends StatelessWidget {
  final Carteira c;
  const _Ativos({required this.c});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ocultos = repo.doTipo('ativo').where((d) => d['oculto'] == true).map(Ativo.new).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 150), children: [
      Row(children: [
        Expanded(child: Text('${c.posicoes.length} ativo(s) · ${brl(c.total)}', style: TextStyle(color: G.texto2, fontWeight: FontWeight.w600))),
        FilledButton.icon(
          onPressed: () => abrirFolha(context, const FormAtivo()),
          style: FilledButton.styleFrom(minimumSize: const Size(10, 38)),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Novo ativo'),
        ),
      ]),
      const SizedBox(height: 12),
      for (final p in c.posicoes) ...[
        Cartao(
          padding: const EdgeInsets.all(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaAtivo(id: p.a.id))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: p.cor, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 10),
              Expanded(child: Text(p.a.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: G.v(0x14), borderRadius: BorderRadius.circular(8)),
                child: Text(p.a.classe.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: G.texto2, letterSpacing: .5)),
              ),
            ]),
            const SizedBox(height: 8),
            ValorBrl(p.valor, estilo: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: G.texto)),
            Text(
              [if (p.a.inst.isNotEmpty) p.a.inst, '${p.n} lançamento(s)', if (p.investido > 0) pct(p.rent, sinal: true)].join(' · '),
              style: TextStyle(color: G.apagado, fontSize: 12.5),
            ),
            if (p.filhos != null) ...[
              const SizedBox(height: 8),
              for (final f in p.filhos!)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const SizedBox(width: 22),
                    Expanded(child: Text(f.a.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: G.texto2, fontSize: 12.5))),
                    Text(brl(f.valor), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ],
          ]),
        ),
        const SizedBox(height: 10),
      ],
      if (ocultos.isNotEmpty) ...[
        const Rotulo('Ocultos'),
        CaixaLista([
          for (final a in ocultos)
            ListTile(
              title: Text(a.nome),
              subtitle: Text('Não entra nos totais', style: TextStyle(color: G.apagado)),
              trailing: TextButton(onPressed: () => repo.salvar({...a.d, 'oculto': false}), child: const Text('Mostrar')),
            ),
        ]),
      ],
    ]);
  }
}

/// Tela de um ativo: saldo, gráfico da evolução e histórico agrupado por mês.
class TelaAtivo extends StatefulWidget {
  final String id;
  const TelaAtivo({super.key, required this.id});
  @override
  State<TelaAtivo> createState() => _TelaAtivoState();
}

class _PontoAtivo {
  final String data;
  final double saldo, aplicado;
  const _PontoAtivo(this.data, this.saldo, this.aplicado);
}

class _TelaAtivoState extends State<TelaAtivo> {
  String periodo = '6m';
  int vista = 0; // 0 = saldo, 1 = rendimento por mês
  int mostrar = 40; // linhas do histórico
  int? mesSel;

  static const _opcoes = [('1m', '1 mês'), ('3m', '3 meses'), ('6m', '6 meses'), ('12m', '12 meses'), ('tudo', 'Tudo')];

  String _inicio(String hoje) {
    final meses = switch (periodo) { '1m' => 1, '3m' => 3, '6m' => 6, '12m' => 12, _ => 0 };
    if (meses == 0) return '0000-00-00';
    final d = DateTime.parse(hoje);
    final ini = DateTime(d.year, d.month - meses, d.day);
    return '${ini.year.toString().padLeft(4, '0')}-${ini.month.toString().padLeft(2, '0')}-${ini.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final d = repo.porId(widget.id);
    if (d == null) return const Scaffold(body: Center(child: Text('Ativo excluído.')));
    final a = Ativo(d);
    final c = calcularCarteira(repo);
    final filhos = c.ativos.where((x) => x.pai == widget.id).map((x) => x.id).toSet();
    final ids = filhos.isEmpty ? {widget.id} : filhos;
    final nomes = {for (final x in c.ativos) x.id: x.nome};
    final lancs = repo.doTipo('lanc').map(Lancamento.new).where((l) => ids.contains(l.ativo)).toList()..sort((x, y) => x.data.compareTo(y.data));

    // variação de cada lançamento em relação ao anterior do mesmo ativo (sem o aporte)
    final variacao = <String, double?>{};
    final ultimoDe = <String, Lancamento>{};
    for (final l in lancs) {
      final ant = ultimoDe[l.ativo];
      variacao[l.id] = ant == null ? null : l.saldo - ant.saldo - l.aporte;
      ultimoDe[l.ativo] = l;
    }

    // série diária do ativo (soma dos filhos, se for um grupo)
    final serie = <_PontoAtivo>[];
    for (final dia in c.dias) {
      final s = ids.fold<double>(0, (t, i) => t + (dia.porAtivo[i] ?? 0));
      final ap = ids.fold<double>(0, (t, i) => t + (dia.investidoPorAtivo[i] ?? 0));
      if (serie.isEmpty && s == 0 && ap == 0) continue;
      serie.add(_PontoAtivo(dia.data, s, ap));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(a.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(tooltip: 'Editar', onPressed: () => abrirFolha(context, FormAtivo(doc: d)), icon: const Icon(Icons.edit_outlined))],
      ),
      body: lancs.isEmpty
          ? Center(child: Vazio(icone: Icons.show_chart_rounded, titulo: 'Nenhum saldo lançado', texto: 'Lance o saldo deste ativo para ver a evolução aqui.'))
          : ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 40), children: [
              _resumo(serie),
              const SizedBox(height: 14),
              if (serie.length >= 2) ...[_grafico(serie), const SizedBox(height: 18)],
              ..._historico(context, repo, lancs.reversed.toList(), variacao, filhos.isEmpty ? null : nomes),
            ]),
    );
  }

  // --- saldo de hoje e o que rendeu desde o começo
  Widget _resumo(List<_PontoAtivo> serie) {
    final ult = serie.isEmpty ? null : serie.last;
    final saldo = ult?.saldo ?? 0, aplicado = ult?.aplicado ?? 0;
    final rendeu = saldo - aplicado;
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Saldo', style: TextStyle(color: G.apagado, fontWeight: FontWeight.w600, fontSize: 12.5)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: ValorBrl(saldo, estilo: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, color: G.texto)),
        ),
        if (ult != null) Text('em ${dataBr(ult.data)}', style: TextStyle(color: G.apagado, fontSize: 12.5)),
        FaixaNumeros([
          ('Você aplicou', brl(aplicado), null),
          ('Rendeu', brl(rendeu, sinal: true), rendeu >= 0 ? G.pos : G.neg),
          ('Rentabilidade', aplicado > 0 ? pct(rendeu / aplicado, sinal: true) : '—', rendeu >= 0 ? G.pos : G.neg),
        ]),
      ]),
    );
  }

  // --- gráfico: saldo × aplicado, ou rendimento de cada mês
  Widget _grafico(List<_PontoAtivo> tudo) {
    final hoje = tudo.last.data;
    final ini = _inicio(hoje);
    var pts = tudo.where((p) => p.data.compareTo(ini) >= 0).toList();
    // começa no último ponto antes do período, para a linha não "pular"
    final antes = tudo.lastIndexWhere((p) => p.data.compareTo(ini) < 0);
    if (antes >= 0) pts = [tudo[antes], ...pts];
    if (pts.length < 2) pts = tudo.length >= 2 ? tudo.sublist(tudo.length - 2) : tudo;
    final amostra = _Resumo._amostrar([for (final p in pts) LinhaDia(p.data, p.saldo, 0, p.aplicado, 0, 0, 0, const {}, const {})], 90);

    // rendimento por mês = variação do saldo − o que foi aplicado no mês
    final meses = <String>[], ganhos = <double>[];
    _PontoAtivo? fimAnt;
    String? ymAtual;
    _PontoAtivo? fimAtual;
    void fechar() {
      if (ymAtual != null && fimAtual != null && fimAnt != null) {
        meses.add(ymAtual!);
        ganhos.add((fimAtual!.saldo - fimAnt!.saldo) - (fimAtual!.aplicado - fimAnt!.aplicado));
      }
    }
    for (final p in tudo) {
      final ym = p.data.substring(0, 7);
      if (ym != ymAtual) {
        fechar();
        if (fimAtual != null) fimAnt = fimAtual;
        ymAtual = ym;
      }
      fimAtual = p;
    }
    fechar();
    final nMeses = switch (periodo) { '1m' => 3, '3m' => 3, '6m' => 6, '12m' => 12, _ => meses.length };
    final ms = meses.length > nMeses ? meses.sublist(meses.length - nMeses) : meses;
    final gs = ganhos.length > nMeses ? ganhos.sublist(ganhos.length - nMeses) : ganhos;

    final p0 = pts.first, p1 = pts.last;
    final aportes = p1.aplicado - p0.aplicado;
    final rendeuPer = (p1.saldo - p0.saldo) - aportes;
    final sel = mesSel != null && mesSel! < ms.length ? mesSel : null;

    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Evolução', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          BotaoPeriodo(valor: periodo, opcoes: _opcoes, onMudar: (v) => setState(() {
                periodo = v;
                mesSel = null;
              })),
        ]),
        const SizedBox(height: 12),
        Segmentos(nomes: const ['Saldo', 'Rendimento por mês'], sel: vista, onSel: (i) => setState(() => vista = i)),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: vista == 0
              ? Column(key: const ValueKey('saldo'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  GraficoLinha(
                    titulo: 'Evolução do saldo',
                    series: [amostra.map((d) => d.total).toList(), amostra.map((d) => d.investido).toList()],
                    cores: [G.pos, G.neutroSerie],
                    tracejada: const [false, true],
                    formatoY: curto,
                    rotulosX: [dataCurta(amostra.first.data), dataCurta(amostra[amostra.length ~/ 2].data), dataCurta(amostra.last.data)],
                    nomes: const ['Saldo', 'Aplicado'],
                    rotuloToque: (i) => dataBr(amostra[i.clamp(0, amostra.length - 1).toInt()].data),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [Legenda(G.pos, 'Saldo'), const SizedBox(width: 14), Legenda(G.neutroSerie, 'Quanto você aplicou')]),
                ])
              : ms.isEmpty
                  ? Padding(
                      key: const ValueKey('vazio'),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('Precisa de pelo menos 2 meses de lançamentos.', textAlign: TextAlign.center, style: TextStyle(color: G.apagado)),
                    )
                  : GraficoBarras(
                      key: const ValueKey('mes'),
                      titulo: 'Rendimento por mês',
                      rotulos: [for (final m in ms) mesesAbr[int.parse(m.substring(5)) - 1]],
                      valores: [for (final g in gs) [g]],
                      cores: [G.pos],
                      nomes: const ['Rendeu'],
                      formatoY: curto,
                      selecionado: sel,
                      onToque: (i) => setState(() => mesSel = mesSel == i ? null : i),
                    ),
        ),
        FaixaNumeros(vista == 1 && sel != null
            ? [
                ('Rendeu em ${mesesAbr[int.parse(ms[sel].substring(5)) - 1]}', brl(gs[sel], sinal: true), gs[sel] >= 0 ? G.pos : G.neg),
                ('Média por mês', brl(gs.fold<double>(0, (a, b) => a + b) / gs.length), null),
              ]
            : [
                ('Rendeu', brl(rendeuPer, sinal: true), rendeuPer >= 0 ? G.pos : G.neg),
                ('Aportes', brl(aportes, sinal: true), null),
                if (vista == 1 && gs.isNotEmpty)
                  ('Média por mês', brl(gs.fold<double>(0, (a, b) => a + b) / gs.length), null)
                else
                  // rendimento sem contar o dinheiro novo
                  ('Rentabilidade', p0.saldo > 0 ? pct(rendeuPer / p0.saldo, sinal: true) : '—', rendeuPer >= 0 ? G.pos : G.neg),
              ]),
      ]),
    );
  }

  // --- histórico agrupado por mês; tocar numa linha mostra os detalhes
  List<Widget> _historico(BuildContext context, Repo repo, List<Lancamento> lancs, Map<String, double?> variacao, Map<String, String>? nomes) {
    final vis = lancs.take(mostrar).toList();
    final porMes = <String, List<Lancamento>>{};
    for (final l in vis) {
      porMes.putIfAbsent(l.data.substring(0, 7), () => []).add(l);
    }
    final out = <Widget>[TituloSecao('Histórico · ${lancs.length} lançamento${lancs.length == 1 ? '' : 's'}')];
    for (final e in porMes.entries) {
      final ganhoMes = lancs.where((l) => l.data.startsWith(e.key)).fold<double>(0, (t, l) => t + (variacao[l.id] ?? 0));
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        child: Row(children: [
          Expanded(child: Text(mesLongo(e.key), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
          Text('${ganhoMes >= 0 ? 'rendeu' : 'variou'} ${brl(ganhoMes, sinal: true)}', style: TextStyle(color: ganhoMes >= 0 ? G.pos : G.neg, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      ));
      out.add(CaixaLista([
        for (final l in e.value)
          InkWell(
            onTap: () => _detalhe(context, repo, l, variacao[l.id], nomes?[l.ativo]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(children: [
                SizedBox(
                  width: 44,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.data.substring(8, 10), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    Text(_semana(l.data), style: TextStyle(color: G.apagado, fontSize: 11)),
                  ]),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(brl(l.saldo), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    if (nomes != null || l.aporte != 0)
                      Text(
                        [if (nomes != null) nomes[l.ativo] ?? '', if (l.aporte != 0) '${l.aporte > 0 ? 'aporte' : 'resgate'} ${brl(l.aporte.abs())}'].where((s) => s.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: l.aporte > 0 ? G.lavanda : G.apagado, fontSize: 12.5),
                      ),
                  ]),
                ),
                Builder(builder: (_) {
                  final v = variacao[l.id];
                  if (v == null) return Text('início', style: TextStyle(color: G.apagado, fontSize: 12.5));
                  return Text(brl(v, sinal: true), style: TextStyle(color: v >= 0 ? G.texto2 : G.neg, fontWeight: FontWeight.w600, fontSize: 14));
                }),
              ]),
            ),
          ),
      ]));
      out.add(const SizedBox(height: 8));
    }
    if (lancs.length > mostrar) {
      out.add(Center(child: TextButton(onPressed: () => setState(() => mostrar += 60), child: Text('Mostrar mais (${lancs.length - mostrar})'))));
    }
    return out;
  }

  static String _semana(String iso) => const ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'][DateTime.parse(iso).weekday - 1];

  void _detalhe(BuildContext context, Repo repo, Lancamento l, double? v, String? nomeFilho) {
    abrirFolha(
      context,
      CorpoFolha([
        TituloFolha(dataBr(l.data)),
        if (nomeFilho != null) Text(nomeFilho, style: TextStyle(color: G.texto2)),
        FaixaNumeros([
          ('Saldo', brl(l.saldo), null),
          ('Rendeu no dia', v == null ? '—' : brl(v, sinal: true), v == null ? null : (v >= 0 ? G.pos : G.neg)),
          ('Aporte', l.aporte == 0 ? '—' : brl(l.aporte, sinal: true), null),
        ]),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            final nav = Navigator.of(context);
            if (await confirmar(context, 'Excluir lançamento?', 'Saldo de ${brl(l.saldo)} em ${dataBr(l.data)}.')) {
              await repo.apagar(l.id);
              nav.pop();
            }
          },
          style: OutlinedButton.styleFrom(foregroundColor: G.neg, side: BorderSide(color: G.neg.withValues(alpha: .4)), padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Excluir lançamento'),
        ),
      ]),
    );
  }
}

class FormAtivo extends StatefulWidget {
  final Doc? doc;
  const FormAtivo({super.key, this.doc});
  @override
  State<FormAtivo> createState() => _FormAtivoState();
}

class _FormAtivoState extends State<FormAtivo> {
  late final Ativo? base = widget.doc == null ? null : Ativo(widget.doc!);
  late final nomeC = TextEditingController(text: base?.nome ?? '');
  late final instC = TextEditingController(text: base?.inst ?? '');
  late String classe = classesAtivo.contains(base?.classe) ? base!.classe : 'Renda Fixa';
  late int cor = base?.d['cor'] is num ? (base!.d['cor'] as num).toInt() % 8 : (base == null ? 0 : -1);

  @override
  void dispose() {
    nomeC.dispose();
    instC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CorpoFolha([
      TituloFolha(base != null ? 'Editar ativo' : 'Novo ativo', onExcluir: base != null ? _excluir : null),
      const SizedBox(height: 12),
      TextField(controller: nomeC, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: CDB Inter, Caixinha Nubank')),
      const SizedBox(height: 12),
      TextField(controller: instC, decoration: const InputDecoration(labelText: 'Banco ou corretora (opcional)')),
      const Rotulo('Tipo'),
      Opcoes<String>(itens: [for (final c in classesAtivo) (c, c)], valor: classe, onMudar: (v) => setState(() => classe = v)),
      const Rotulo('Cor'),
      Wrap(spacing: 10, children: [
        for (var i = 0; i < coresSerie.length; i++)
          GestureDetector(
            onTap: () => setState(() => cor = i),
            child: Container(width: 34, height: 34, decoration: BoxDecoration(color: coresSerie[i], shape: BoxShape.circle, border: Border.all(color: i == cor ? G.branco : Colors.transparent, width: 3))),
          ),
      ]),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: () async {
          final nome = nomeC.text.trim();
          if (nome.isEmpty) return avisar(context, 'Dê um nome ao ativo.');
          await RepoScope.ler(context).salvar({
            ...?widget.doc,
            'kind': 'ativo',
            'id': base?.id ?? novoId('a'),
            'nome': nome,
            'classe': classe,
            'inst': instC.text.trim(),
            if (cor >= 0) 'cor': cor,
            'ordem': widget.doc?['ordem'] ?? DateTime.now().millisecondsSinceEpoch,
          });
          if (!context.mounted) return;
          Navigator.pop(context);
          avisar(context, base != null ? 'Ativo atualizado.' : '$nome cadastrado. Agora lance o saldo dele.');
        },
        child: Text(base != null ? 'Salvar alterações' : 'Cadastrar ativo'),
      ),
      if (base != null) ...[
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            await RepoScope.ler(context).salvar({...base!.d, 'oculto': true});
            if (!context.mounted) return;
            Navigator.pop(context);
            avisar(context, '${base!.nome} oculto: não entra mais nos totais.');
          },
          child: const Text('Ocultar (vendi ou não uso mais)'),
        ),
      ],
    ]);
  }

  Future<void> _excluir() async {
    final b = base!;
    if (!await confirmar(context, 'Excluir ${b.nome}?', 'O ativo e todos os lançamentos de saldo dele serão apagados. Se só não usa mais, prefira ocultar.')) return;
    if (!mounted) return;
    final repo = RepoScope.ler(context);
    final filhos = repo.doTipo('ativo').where((x) => x['pai'] == b.id).map((x) => str(x['id'])).toSet();
    final ids = {b.id, ...filhos};
    await repo.apagarVarios([...ids, ...repo.doTipo('lanc').where((l) => ids.contains(l['ativo'])).map((l) => str(l['id']))]);
    if (!mounted) return;
    Navigator.pop(context);
    avisar(context, 'Ativo excluído.');
  }
}

// =====================================================================
// Relatórios e projeção
// =====================================================================

class _Relatorios extends StatefulWidget {
  final Carteira c;
  const _Relatorios({required this.c});
  @override
  State<_Relatorios> createState() => _RelatoriosState();
}

class _RelatoriosState extends State<_Relatorios> {
  late String ano = widget.c.anos.isEmpty ? hojeIso().substring(0, 4) : widget.c.anos.last;
  final aporteC = TextEditingController();
  final metaC = TextEditingController(text: '1.000.000,00');
  String taxa = 'mod';
  int anos = 10;

  @override
  void initState() {
    super.initState();
    final h = historico(widget.c);
    aporteC.text = valorCampo(h.aporteMedio > 0 ? (h.aporteMedio / 50).round() * 50.0 : 500);
    if (h.taxaMedia != null) taxa = 'hist';
  }

  @override
  void dispose() {
    aporteC.dispose();
    metaC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final h = historico(c);
    final taxas = <(String, String, double)>[
      if (h.taxaMedia != null) ('hist', 'Sua média ${pct(h.taxaMedia!, casas: 1)}', h.taxaMedia!),
      ('cons', 'Conservador 8%', .08),
      ('mod', 'Moderado 10%', .10),
      ('arr', 'Arrojado 12%', .12),
    ];
    final tx = taxas.firstWhere((t) => t.$1 == taxa, orElse: () => taxas.firstWhere((t) => t.$1 == 'mod')).$3;
    final ap = lerValor(aporteC.text) ?? 0;
    final proj = projetar(c.total, ap, tx, anos * 12);
    final fim = proj.last;
    final meta = lerValor(metaC.text) ?? 0;
    final mm = meta > 0 ? mesesAteMeta(c.total, ap, tx, meta) : null;
    final meses = c.meses.where((m) => m.ym.startsWith(ano)).toList().reversed.toList();
    final amostra = [for (var i = 0; i < proj.length; i += (proj.length / 60).ceil().clamp(1, 1000).toInt()) proj[i], proj.last];

    final posicoes = c.posicoes.where((p) => p.valor > 0.005).toList()..sort((a, b) => b.valor.compareTo(a.valor));
    Widget kpi(String t, String v, Color cor) => Expanded(
          child: CartaoSite(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: S.muted)),
              const SizedBox(height: 3),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: TextStyle(fontFamily: S.fonteNum, fontSize: 17, fontWeight: FontWeight.w800, color: cor))),
            ]),
          ),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 150), children: [
      if (!c.vazia) ...[
        if (posicoes.isNotEmpty) ...[
          PosicaoAtualSite(c: c, posicoes: posicoes, abrir: (p) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaAtivo(id: p.a.id)))),
          const SizedBox(height: 22),
        ],
        Text('Relatório do ano', style: TextStyle(fontFamily: S.fonteNum, fontSize: 19, fontWeight: FontWeight.w700, color: S.ink)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final a in c.anos.reversed)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: a == ano ? S.ink : S.surface,
                  shape: StadiumBorder(side: BorderSide(color: a == ano ? S.ink : S.line)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => setState(() => ano = a),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(a, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: a == ano ? S.bg : S.ink2)),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          kpi('Rentabilidade', pct(c.rentAno(ano), sinal: true), c.rentAno(ano) >= 0 ? S.pos : S.neg),
          const SizedBox(width: 8),
          kpi('Rendeu', brl(c.rendimentoAno(ano), sinal: true), c.rendimentoAno(ano) >= 0 ? S.pos : S.neg),
          const SizedBox(width: 8),
          kpi('Aportes', brl(c.aportesAno(ano), sinal: true), S.accent),
        ]),
        const SizedBox(height: 12),
        if (meses.isNotEmpty) ...[
          GradeRentMeses(meses: meses.reversed.toList(), sub: 'Em $ano, descontando aportes e resgates'),
          const SizedBox(height: 12),
        ],
        // tabela: um mês por linha (antes era um cartão de 4 linhas por mês)
        Cartao(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Builder(builder: (context) {
            String n(double v, {bool sinal = false}) => brl(v, sinal: sinal).replaceFirst('R\$\u00A0', '');
            final cab = TextStyle(color: G.apagado, fontSize: 11, fontWeight: FontWeight.w600);
            Widget cel(String t, {int flex = 3, TextStyle? estilo}) => Expanded(
                  flex: flex,
                  child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(t, maxLines: 1, style: estilo ?? const TextStyle(fontSize: 12.5))),
                );
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const CabecalhoCartao('Mês a mês', sub: 'Valores em reais'),
              Row(children: [
                Expanded(flex: 3, child: Text('Mês', style: cab)),
                cel('Aportes', estilo: cab),
                cel('Rendeu', estilo: cab),
                cel('Saldo final', flex: 4, estilo: cab),
              ]),
              const SizedBox(height: 4),
              for (final m in meses)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: G.borda))),
                  child: Row(children: [
                    Expanded(
                      flex: 3,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(mesesLongos[int.parse(m.ym.substring(5, 7)) - 1].substring(0, 3), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(pct(m.rent, sinal: true), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: m.rent >= 0 ? G.pos : G.neg)),
                      ]),
                    ),
                    cel(m.aportes == 0 ? '—' : n(m.aportes, sinal: true), estilo: TextStyle(fontSize: 12.5, color: G.texto2)),
                    cel(n(m.ganho, sinal: true), estilo: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: m.ganho >= 0 ? G.texto : G.neg)),
                    cel(n(m.fim), flex: 4, estilo: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]);
          }),
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 8),
      ],
      Cartao(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CabecalhoCartao('Projeção dos investimentos', sub: 'Simule quanto seu patrimônio vai valer com o tempo, com juros compostos'),
          CampoValor(aporteC, rotulo: 'Aporte por mês'),
          const SizedBox(height: 4),
          if (h.aporteMedio > 0) Text('Sua média dos últimos meses: ${brl(h.aporteMedio)}', style: TextStyle(color: G.apagado, fontSize: 12.5)),
          const Rotulo('Rentabilidade por ano'),
          Opcoes<String>(itens: [for (final t in taxas) (t.$1, t.$2)], valor: taxa, onMudar: (v) => setState(() => taxa = v)),
          const Rotulo('Prazo'),
          Opcoes<int>(itens: const [(5, '5 anos'), (10, '10 anos'), (20, '20 anos'), (30, '30 anos')], valor: anos, onMudar: (v) => setState(() => anos = v)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: G.gradHero, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Em $anos anos (${mesLongo(ymAdd(ymDe(hojeIso()), anos * 12)).toLowerCase()})', style: TextStyle(color: G.texto2)),
              FittedBox(fit: BoxFit.scaleDown, child: ValorBrl(fim.saldo, estilo: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: G.texto))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _Mini('Você investiu', brl(fim.investido), G.neutroSerie)),
                Expanded(child: _Mini('Juros trabalharam', brl(fim.saldo - fim.investido), G.pos)),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          GraficoLinha(
            titulo: 'Projeção',
            series: [amostra.map((p) => p.saldo).toList(), amostra.map((p) => p.investido).toList()],
            cores: [G.pos, G.neutroSerie],
            tracejada: const [false, true],
            formatoY: curto,
            rotulosX: ['hoje', '${anos ~/ 2} anos', '$anos anos'],
            nomes: const ['Saldo', 'Investido'],
            rotuloToque: (i) => mesLongo(ymAdd(ymDe(hojeIso()), amostra[i.clamp(0, amostra.length - 1).toInt()].m)),
          ),
          const Rotulo('Quanto tempo até chegar em…'),
          CampoValor(metaC, rotulo: 'Meta'),
          const SizedBox(height: 8),
          Text(
            meta <= 0
                ? 'Informe uma meta.'
                : mm == null
                    ? 'Com esse aporte e essa taxa, a meta passa de 100 anos.'
                    : mm == 0
                        ? 'Você já chegou lá! 🎉'
                        : 'Em ${tempoTexto(mm)} (${mesLongo(ymAdd(ymDe(hojeIso()), mm)).toLowerCase()}).',
            style: TextStyle(fontWeight: FontWeight.w700, color: G.lavanda),
          ),
          const SizedBox(height: 6),
          Text('Estimativa com juros compostos mensais e aportes no fim de cada mês. Não considera impostos nem taxas, e não é garantia de rendimento.', style: TextStyle(color: G.apagado, fontSize: 11)),
          TextButton(onPressed: () => setState(() {}), child: const Text('Recalcular')),
        ]),
      ),
    ]);
  }
}

class _Kpi extends StatelessWidget {
  final String t, v;
  final Color cor;
  const _Kpi(this.t, this.v, this.cor);
  @override
  Widget build(BuildContext context) => Cartao(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: TextStyle(color: G.apagado, fontSize: 12.5)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cor))),
        ]),
      );
}

/// Aviso: investimentos registrados que ainda não foram para nenhum ativo.
/// "Para conferir": junta, num cartão só, o que precisa de atenção.
class _Pendencias extends StatelessWidget {
  final Carteira c;
  const _Pendencias({required this.c});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final sem = c.ativos.isEmpty ? const <Investido>[] : investidosSemAtivo(repo);
    final semTot = sem.fold<double>(0, (t, i) => t + i.liquido);
    final conf = repo.investidos.isEmpty ? const <Conferencia>[] : conferenciaMeses(repo, c);
    final dif = conf.where((m) => !m.bate).toList();
    if (sem.isEmpty && dif.isEmpty) return const SizedBox.shrink();
    Widget linha(IconData ic, String t, String v, VoidCallback f) => InkWell(
          onTap: f,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Icon(ic, size: 19, color: G.alerta),
              const SizedBox(width: 10),
              Expanded(child: Text(t, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(v, style: TextStyle(fontWeight: FontWeight.w700, color: G.texto2)),
              Icon(Icons.chevron_right_rounded, color: G.apagado),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TituloSecao('Para conferir'),
        Cartao(
          padding: EdgeInsets.zero,
          child: Column(children: [
            if (sem.isNotEmpty) linha(Icons.link_off_rounded, '${sem.length} investimento${sem.length > 1 ? 's' : ''} sem ativo', brl(semTot), () => abrirFolha(context, const _FolhaSemAtivo())),
            if (sem.isNotEmpty && dif.isNotEmpty) Divider(height: 1, color: G.borda),
            if (dif.isNotEmpty) linha(Icons.rule_rounded, '${dif.length} ${dif.length > 1 ? 'meses' : 'mês'} com aporte diferente', '', () => abrirFolha(context, _FolhaConferencia(c: c))),
          ]),
        ),
      ]),
    );
  }
}

/// Conferência: o que saiu da conta para investir × aportes lançados.
class _FolhaConferencia extends StatelessWidget {
  final Carteira c;
  const _FolhaConferencia({required this.c});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ms = conferenciaMeses(repo, c);
    TextStyle cab = TextStyle(color: G.apagado, fontSize: 11, fontWeight: FontWeight.w600);
    return CorpoFolha([
      const TituloFolha('Conferência dos aportes'),
      Text('Compara o que saiu da conta para investir com os aportes lançados no Patrimônio.', style: TextStyle(color: G.texto2, fontSize: 12.5)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(flex: 3, child: Text('Mês', style: cab)),
        Expanded(flex: 4, child: Text('Saiu p/ investir', textAlign: TextAlign.right, style: cab)),
        Expanded(flex: 4, child: Text('Aportes', textAlign: TextAlign.right, style: cab)),
        Expanded(flex: 4, child: Text('Diferença', textAlign: TextAlign.right, style: cab)),
      ]),
      const SizedBox(height: 4),
      for (final m in ms)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: G.borda))),
          child: Row(children: [
            Expanded(flex: 3, child: Text(mesLongo(m.ym).split(' ').first, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(flex: 4, child: Text(brl(m.saiuParaInvestir), textAlign: TextAlign.right)),
            Expanded(flex: 4, child: Text(brl(m.aportes), textAlign: TextAlign.right)),
            Expanded(
              flex: 4,
              child: Text(m.bate ? 'ok' : brl(m.diferenca, sinal: true), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, color: m.bate ? G.pos : G.alerta)),
            ),
          ]),
        ),
      const SizedBox(height: 12),
      Dica('Diferença positiva: falta lançar um aporte. Negativa: falta registrar um Investido (ou veio de outra conta).', icone: Icons.info_outline_rounded, cor: G.lavanda),
    ]);
  }
}

class _FolhaSemAtivo extends StatelessWidget {
  const _FolhaSemAtivo();
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final itens = investidosSemAtivo(repo);
    final c = calcularCarteira(repo);
    return CorpoFolha([
      const TituloFolha('Investimentos sem ativo'),
      Text('Toque no ativo onde o dinheiro foi aplicado. O valor entra como aporte no Patrimônio (se o mesmo aporte já estiver lançado, só liga os dois).', style: TextStyle(color: G.texto2, fontSize: 12.5)),
      const SizedBox(height: 12),
      if (itens.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('Tudo certo: nenhum investimento sem ativo.', style: TextStyle(color: G.apagado)))),
      for (final i in itens.take(30))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Cartao(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                IconeCategoria(i.resgate ? catResgate : catInvestido, tam: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${dataCurta(i.data)} · ${i.resgate ? 'resgate' : 'aplicação'}', style: TextStyle(color: G.apagado, fontSize: 12.5)),
                  ]),
                ),
                Text('${i.resgate ? '←' : '→'} ${brl(i.valor)}', style: TextStyle(fontWeight: FontWeight.w700, color: G.lavanda)),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final a in c.ativos)
                  ActionChip(
                    label: Text(a.nome),
                    onPressed: () async {
                      final m = Mudancas(repo);
                      final d = Map<String, dynamic>.from(i.d)..['ativo'] = a.id;
                      final msg = ligarAoPatrimonio(m, d, a.id);
                      m.poe(d);
                      await m.gravar();
                      if (context.mounted) avisar(context, msg);
                    },
                  ),
                ActionChip(
                  avatar: Icon(Icons.block_rounded, size: 16, color: G.apagado),
                  label: const Text('Não é do Patrimônio'),
                  onPressed: () => repo.salvar({...i.d, 'semPat': true}),
                ),
              ]),
            ]),
          ),
        ),
    ]);
  }
}



/// Cartão do topo do Patrimônio, como o do site (.pt-hx).
class _HeroPat extends StatelessWidget {
  final Carteira c;
  final double emConta, patrimonio, pctInv;
  final VoidCallback irLancar;
  const _HeroPat({required this.c, required this.emConta, required this.patrimonio, required this.pctInv, required this.irLancar});
  @override
  Widget build(BuildContext context) {
    const br = Colors.white;
    final cta = S.cta;
    final ult = c.ultimo!;
    final emDia = ult.data == hojeIso();
    Widget k(String rot, String v, String ic, Color cor) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(color: const Color(0x21FFFFFF), border: Border.all(color: const Color(0x38FFFFFF)), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(width: 28, height: 28, decoration: const BoxDecoration(color: br, shape: BoxShape.circle), alignment: Alignment.center, child: IconeSite(ic, tam: 15, cor: cor)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rot, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: br, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.5)),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: const TextStyle(color: br, fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.5))),
                ]),
              ),
            ]),
          ),
        );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(begin: const Alignment(-.55, -1), end: const Alignment(.55, 1), colors: [cta, Color.lerp(cta, Colors.black, .35)!]),
        boxShadow: [BoxShadow(color: cta.withValues(alpha: .55), blurRadius: 36, offset: const Offset(0, 18), spreadRadius: -18)],
      ),
      child: Stack(children: [
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(1, -1), radius: 1.1, colors: [S.accent.withValues(alpha: .7), S.accent.withValues(alpha: 0)], stops: const [0, .6])))),
        Positioned(right: -70, bottom: -110, child: Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .05)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Text('Investido', style: TextStyle(color: br, fontWeight: FontWeight.w600)),
              ValueListenableBuilder<bool>(
                valueListenable: privacidade,
                builder: (_, o, __) => GestureDetector(
                  onTap: () => definirPrivacidade(!o),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: IconeSite(o ? Ico.olhoFechado : Ico.olho, tam: 15, cor: br.withValues(alpha: .85))),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: irLancar,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: emDia ? const Color(0x29FFFFFF) : br, borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (emDia) ...[const IconeSite(Ico.certo, tam: 12, cor: br), const SizedBox(width: 5)],
                    Text(emDia ? 'Em dia' : 'Lançar hoje', style: TextStyle(color: emDia ? br : cta, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(brl(c.total), style: const TextStyle(fontFamily: S.fonteNum, color: br, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -.64, height: 1.5)),
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: (c.ganhoUltimo >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withValues(alpha: .35), borderRadius: BorderRadius.circular(99)),
                    child: Text('${brl(c.ganhoUltimo, sinal: true)} · ${pct(c.rUltimo, sinal: true)}', style: const TextStyle(color: br, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ),
                TextSpan(text: ' no último lançamento, em ${dataBr(ult.data)}'),
              ]),
              style: const TextStyle(color: br, fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 14),
            Row(children: [
              k('Patrimônio total', brl(patrimonio), '<path d="M3 21h18M5 21V10M19 21V10M9 21V10M15 21V10M2 10l10-7 10 7z"/>', const Color(0xFF11764A)),
              const SizedBox(width: 8),
              k('Em conta · ${pct(1 - pctInv)}', brl(emConta), Ico.cartao, const Color(0xFFC23B2A)),
            ]),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 6,
                child: Stack(children: [
                  const Positioned.fill(child: ColoredBox(color: Color(0x38FFFFFF))),
                  Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: pctInv.clamp(0, 1).toDouble(), heightFactor: 1, child: const ColoredBox(color: br))),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text('${pct(pctInv)} investido', style: const TextStyle(color: br, fontSize: 11.5))),
              Text('${pct(1 - pctInv)} em conta', style: const TextStyle(color: br, fontSize: 11.5)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
