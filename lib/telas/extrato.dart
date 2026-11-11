import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/modelos.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';
import 'analise.dart';
import 'busca.dart';
import 'lancar.dart';

class TelaExtrato extends StatefulWidget {
  final String ym;
  final ValueChanged<String> onMes;
  final String filtroInicial;
  final String? catInicial;
  final bool analiseInicial;
  const TelaExtrato({super.key, required this.ym, required this.onMes, this.filtroInicial = 'tudo', this.catInicial, this.analiseInicial = false});
  @override
  State<TelaExtrato> createState() => _TelaExtratoState();
}

class _TelaExtratoState extends State<TelaExtrato> {
  late String filtro = widget.filtroInicial; // tudo | saidas | entradas
  late String? cat = widget.catInicial;
  final buscaC = TextEditingController();
  late bool analise = widget.analiseInicial;
  Doc? aberto; // lançamento aberto no painel da direita (computador)

  @override
  void didUpdateWidget(covariant TelaExtrato old) {
    super.didUpdateWidget(old);
    if (old.filtroInicial != widget.filtroInicial || old.catInicial != widget.catInicial) {
      filtro = widget.filtroInicial;
      cat = widget.catInicial;
    }
  }

  @override
  void dispose() {
    buscaC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final doisPaineis = cons.maxWidth >= 1000 && !analise;
      final lista = _lista(context, doisPaineis);
      if (!doisPaineis) return lista;
      // computador: lista à esquerda, painel fixo à direita
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: lista),
        SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 14, 20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              layoutBuilder: (atual, antigos) => Stack(alignment: Alignment.topCenter, children: [...antigos, if (atual != null) atual]),
              child: aberto == null
                  ? _PainelMes(key: const ValueKey('mes'), ym: widget.ym, cat: cat, onCat: (c) => setState(() {
                        filtro = 'saidas';
                        cat = cat == c ? null : c;
                      }))
                  : Cartao(
                      key: ValueKey(aberto!['id']),
                      padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(tooltip: 'Fechar', onPressed: () => setState(() => aberto = null), icon: Icon(Icons.close_rounded, color: G.apagado)),
                        ),
                        Flexible(child: FormLanc(tipo: tipoDoDoc(aberto!), doc: aberto, aoFechar: () => setState(() => aberto = null))),
                      ]),
                    ),
            ),
          ),
        ),
      ]);
    });
  }

  Widget _lista(BuildContext context, bool doisPaineis) {
    final repo = RepoScope.of(context);
    final r = ResumoMes.de(repo, widget.ym);
    void abrir(Lanc l) => doisPaineis ? setState(() => aberto = aberto?['id'] == l.doc['id'] ? null : l.doc) : abrirFormLanc(context, doc: l.doc);
    final q = buscaC.text.trim().toLowerCase();
    var lista = r.lancamentos.where((l) {
      if (filtro == 'saidas' && !l.ehGasto) return false;
      if (filtro == 'entradas' && !l.ehEntrada) return false;
      if (filtro == 'investido' && !l.ehInvest) return false;
      if (cat != null && (!l.ehGasto || l.g!.cat != cat)) return false;
      if (q.isNotEmpty && !l.desc.toLowerCase().contains(q)) return false;
      return true;
    }).toList();

    // agrupa por dia
    final grupos = <String, List<Lanc>>{};
    for (final l in lista) {
      (grupos[l.data] ??= []).add(l);
    }
    final totalFiltro = filtro == 'investido' ? lista.fold<double>(0, (a, l) => a + l.i!.liquido) : lista.fold<double>(0, (a, l) => a + l.efeito);
    final catsDoMes = r.porCategoria.keys.toList()..sort((a, b) => (r.porCategoria[b] ?? 0).compareTo(r.porCategoria[a] ?? 0));

    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        sliver: SliverList.list(children: [
          Cartao(
            gradiente: G.gradHero,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(children: [
              SeletorMes(ym: widget.ym, onMudar: widget.onMes),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Resumo('Entrou', r.entrou, G.pos)),
                Expanded(child: _Resumo('Saiu', r.saiu, G.neg)),
                Expanded(child: _Resumo('Sobra', r.sobra, r.sobra < 0 ? G.neg : G.texto)),
              ]),
              if (r.investimentos.isNotEmpty) ...[
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    analise = false;
                    filtro = 'investido';
                    cat = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: G.lavandaFundo, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(Icons.savings_rounded, size: 18, color: G.lavanda),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.investiu >= 0 ? 'Investiu no mês' : 'Resgatou no mês', style: TextStyle(color: G.texto2, fontWeight: FontWeight.w600, fontSize: 13))),
                      Text(brl(r.investiu.abs()), style: TextStyle(color: G.lavanda, fontWeight: FontWeight.w700)),
                      if (r.pctInvestido != null && r.investiu > 0) Text('  ·  ${(r.pctInvestido! * 100).round()}%', style: TextStyle(color: G.apagado, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Lançamentos'), icon: Icon(Icons.receipt_long_rounded, size: 18)),
              ButtonSegment(value: true, label: Text('Análise'), icon: Icon(Icons.insights_rounded, size: 18)),
            ],
            selected: {analise},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: G.branco,
              selectedForegroundColor: G.tinta,
              foregroundColor: G.texto2,
              side: BorderSide(color: G.borda),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onSelectionChanged: (s) => setState(() => analise = s.first),
          ),
          const SizedBox(height: 12),
          if (analise)
            AnaliseExtrato(
              ym: widget.ym,
              onMes: widget.onMes,
              verCategoria: (c) => setState(() {
                analise = false;
                filtro = 'saidas';
                cat = c;
              }),
            ),
          if (!analise) ...[
          TextField(
            controller: buscaC,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar no mês',
              prefixIcon: Icon(Icons.search_rounded, color: G.apagado),
              suffixIcon: buscaC.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => buscaC.clear()),
                    ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaBusca(inicial: buscaC.text))),
              icon: const Icon(Icons.manage_search_rounded, size: 18),
              label: const Text('Buscar em todos os meses'),
            ),
          ),
          Builder(builder: (context) {
            final chips = <Widget>[
              for (final f in [['tudo', 'Tudo'], ['saidas', 'Saídas'], ['entradas', 'Entradas'], if (r.investimentos.isNotEmpty || filtro == 'investido') ['investido', 'Investido']])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: filtro == f[0],
                    label: Text(f[1]),
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, color: filtro == f[0] ? G.tinta : G.texto2),
                    onSelected: (_) => setState(() {
                      filtro = f[0];
                      if (filtro == 'entradas' || filtro == 'investido') cat = null;
                    }),
                  ),
                ),
              if (filtro != 'entradas' && filtro != 'investido')
                for (final c in catsDoMes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: cat == c,
                      avatar: Icon(catGasto(c).icone, size: 16, color: cat == c ? G.tinta : catGasto(c).cor),
                      label: Text(catGasto(c).nome),
                      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: cat == c ? G.tinta : G.texto2),
                      onSelected: (v) => setState(() => cat = v ? c : null),
                    ),
                  ),
            ];
            // computador: os filtros quebram em linhas, sem rolar para o lado
            if (doisPaineis) return Wrap(runSpacing: 6, children: chips);
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, .9, 1]).createShader(r),
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(right: 28), child: Row(children: chips)),
            );
          }),
          const SizedBox(height: 12),
          if (q.isNotEmpty || cat != null || filtro != 'tudo')
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
              child: Row(children: [
                Expanded(child: Text('${lista.length} lançamento${lista.length == 1 ? '' : 's'}', style: TextStyle(color: G.apagado))),
                Text(filtro == 'investido' ? 'Investiu ${brl(totalFiltro)}' : brl(totalFiltro, sinal: true),
                    style: TextStyle(fontWeight: FontWeight.w700, color: filtro == 'investido' ? G.lavanda : (totalFiltro < 0 ? G.texto : G.pos))),
              ]),
            ),
          ],
        ]),
      ),
      if (analise)
        const SliverToBoxAdapter(child: SizedBox(height: 130))
      else if (lista.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(children: [
              Icon(Icons.receipt_long_rounded, size: 40, color: G.apagado),
              const SizedBox(height: 10),
              Text(q.isNotEmpty ? 'Nada encontrado para “${buscaC.text}”.' : 'Nenhum lançamento em ${mesLongo(widget.ym).toLowerCase()}.', textAlign: TextAlign.center, style: TextStyle(color: G.apagado)),
            ]),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
          sliver: SliverList.builder(
            itemCount: grupos.length,
            itemBuilder: (c, i) {
              final dia = grupos.keys.elementAt(i);
              final ls = grupos[dia]!;
              final tot = ls.fold<double>(0, (a, l) => a + l.efeito);
              return Surge(
                key: ValueKey('$dia$filtro${cat ?? ''}'),
                ordem: i < 6 ? i : 0,
                child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Row(children: [
                      Expanded(child: Text(rotuloDia(dia), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text(brl(tot, sinal: true), style: TextStyle(color: tot < 0 ? G.apagado : G.pos, fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ),
                  CaixaLista([for (final l in ls) LinhaLanc(l, selecionado: aberto?['id'] == l.doc['id'], onTap: () => abrir(l))]),
                ]),
              ));
            },
          ),
        ),
    ]);
  }
}

class _Resumo extends StatelessWidget {
  final String t;
  final double v;
  final Color cor;
  const _Resumo(this.t, this.v, this.cor);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(t, style: TextStyle(color: G.texto2, fontSize: 12.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, child: Text(brl(v), style: TextStyle(color: cor, fontWeight: FontWeight.w800, fontSize: 15))),
    ]);
  }
}

/// Painel da direita no computador, quando nenhum lançamento está aberto.
class _PainelMes extends StatelessWidget {
  final String ym;
  final String? cat;
  final ValueChanged<String> onCat;
  const _PainelMes({super.key, required this.ym, required this.cat, required this.onCat});
  @override
  Widget build(BuildContext context) {
    final r = ResumoMes.de(RepoScope.of(context), ym);
    final cats = r.porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final tot = cats.fold<double>(0, (a, e) => a + e.value);
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        CabecalhoCartao('Para onde foi', sub: cats.isEmpty ? 'Nenhum gasto no mês' : '${cats.length} categoria${cats.length == 1 ? '' : 's'} · toque para filtrar'),
        for (final e in cats.take(8))
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onCat(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              decoration: BoxDecoration(color: cat == e.key ? G.lavandaFundo : null, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(catGasto(e.key).icone, size: 18, color: catGasto(e.key).cor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(catGasto(e.key).nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
                      Text(brl(e.value), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ]),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: tot > 0 ? e.value / tot : 0, minHeight: 5, color: catGasto(e.key).cor, backgroundColor: G.v(0x12)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Text('Clique num lançamento para ver e editar aqui.', textAlign: TextAlign.center, style: TextStyle(color: G.apagado, fontSize: 12)),
      ]),
    );
  }
}
