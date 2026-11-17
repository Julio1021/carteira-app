import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/modelos.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/painel.dart';
import '../widgets/movimento.dart';
import 'analise.dart';
import 'busca.dart';
import 'lancar.dart';
import 'limites.dart';
import 'importar.dart';
import 'cartoes.dart';
import 'inicio_site.dart';
import '../widgets/site.dart';

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
  String? origem; // conta ou cartão escolhido nas pílulas

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

  Future<void> _filtros(BuildContext context, List<String> cats) async {
    final todas = {...cats, for (final c in categoriasGasto) c.id}.toList();
    final r = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: S.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(14, 14, 14, 20), children: [
          Text('Filtrar por categoria', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: S.ink)),
          const SizedBox(height: 10),
          ListaTxSite([
            InkWell(onTap: () => Navigator.pop(c, ''), child: Padding(padding: const EdgeInsets.all(14), child: Text('Todas as categorias', style: TextStyle(fontWeight: FontWeight.w600, color: cat == null ? S.accent : S.ink)))),
            for (final id in todas)
              LinhaTxSite(cat: catGasto(id), titulo: catGasto(id).nome, sub: cats.contains(id) ? 'Tem gastos neste mês' : 'Sem gastos neste mês', valor: cat == id ? '✓' : '', corValor: S.accent, onTap: () => Navigator.pop(c, id)),
          ]),
        ]),
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      cat = r.isEmpty ? null : r;
      if (cat != null && filtro != 'saidas') filtro = 'saidas';
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
      if (origem != null) {
        final d = l.doc;
        if (d['cartao'] != origem && d['conta'] != origem) {
          // sem conta marcada: conta como da conta principal
          final principal = repo.contas.isEmpty ? null : (repo.contas..sort((a, b) => b.saldo.compareTo(a.saldo))).first.id;
          if (!(d['cartao'] == null && d['conta'] == null && origem == principal)) return false;
        }
      }
      return true;
    }).toList();

    // agrupa por dia
    final grupos = <String, List<Lanc>>{};
    for (final l in lista) {
      (grupos[l.data] ??= []).add(l);
    }
    final totalFiltro = filtro == 'investido' ? lista.fold<double>(0, (a, l) => a + l.i!.liquido) : lista.fold<double>(0, (a, l) => a + l.efeito);
    final catsDoMes = r.porCategoria.keys.toList()..sort((a, b) => (r.porCategoria[b] ?? 0).compareTo(r.porCategoria[a] ?? 0));

    Widget aba(bool v, String t) => Expanded(
          child: InkWell(
            onTap: () => setState(() => analise = v),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: analise == v ? S.ink : S.ink2)),
            ),
          ),
        );
    Widget pilula(String t, bool on, VoidCallback onTap, {Color? ponto, bool origem = false}) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Material(
            color: on ? S.accentSoft : S.surface,
            shape: StadiumBorder(side: BorderSide(color: on ? (origem ? S.accent : S.accent.withValues(alpha: .35)) : S.line)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (ponto != null) ...[Container(width: 9, height: 9, decoration: BoxDecoration(color: ponto, shape: BoxShape.circle)), const SizedBox(width: 6)],
                  Text(t, style: TextStyle(fontSize: 13, fontWeight: origem ? FontWeight.w600 : FontWeight.w700, color: on ? (origem ? S.ink : S.accent) : S.ink2)),
                ]),
              ),
            ),
          ),
        );
    // contas e cartões, como no site (Todas · Banco Inter · Nubank)
    final origens = <(String, String, Color?)>[
      for (final c in repo.contas) (c.id, c.nome, null),
      for (final c in repo.doTipo('cartao')) (str(c['id']), str(c['nome'], 'Cartão'), corDeTexto(c['cor'])),
    ];
    final m = MediaQuery.paddingOf(context);
    return CustomScrollView(slivers: [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(12, 14 + (doisPaineis ? 0 : 0) + m.top * 0, 12, 0),
        sliver: SliverList.list(children: [
          HeroSite(r: r, ym: widget.ym, onMes: widget.onMes, prev: (aReceber: 0, faltaPagar: 0), mini: true, irEntradas: () => setState(() {
                analise = false;
                filtro = 'entradas';
              }), irSaidas: () => setState(() {
                analise = false;
                filtro = 'saidas';
              })),
          const SizedBox(height: 18),
          AtalhosSite(itens: [
            (Ico.mais, 'Gasto', () => abrirFormLanc(context)),
            (Ico.cima, 'Entrada', () => abrirFormLanc(context, entrada: true)),
            (Ico.cartao, 'Cartão', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaCartoes()))),
            (Ico.importar, 'Importar', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaImportarExtrato()))),
            (Ico.buscar, 'Buscar', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaBusca(inicial: buscaC.text)))),
            (Ico.ajustes, 'Limites', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaLimites(ym: widget.ym)))),
          ]),
          const SizedBox(height: 18),
          // abas com o tracinho embaixo da escolhida
          Container(
            color: S.bg.withValues(alpha: .82),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(children: [
              Row(children: [aba(false, 'Lançamentos'), const SizedBox(width: 2), aba(true, 'Análise')]),
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: analise ? Alignment.centerRight : Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: .5,
                  child: Container(height: 3, decoration: BoxDecoration(color: S.accent, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in [['tudo', 'Tudo'], ['saidas', 'Saídas'], ['entradas', 'Entradas'], if (r.investimentos.isNotEmpty || filtro == 'investido') ['investido', 'Investido']])
                  pilula(f[1], filtro == f[0], () => setState(() {
                        filtro = f[0];
                        if (filtro == 'entradas' || filtro == 'investido') cat = null;
                      })),
              ]),
            ),
            if (origens.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  pilula('Todas', origem == null, () => setState(() => origem = null), origem: true),
                  for (final (id, nome, cor) in origens) pilula(nome, origem == id, () => setState(() => origem = origem == id ? null : id), ponto: cor, origem: true),
                ]),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: S.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: S.line)),
                  child: Row(children: [
                    IconeSite(Ico.buscar, tam: 18, cor: S.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: buscaC,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(fontSize: 16, color: S.ink),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Buscar no mês',
                          hintStyle: TextStyle(color: S.muted, fontSize: 16),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    if (buscaC.text.isNotEmpty) GestureDetector(onTap: () => setState(() => buscaC.clear()), child: Icon(Icons.close_rounded, size: 18, color: S.muted)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: cat != null ? S.accentSoft : S.surface2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cat != null ? S.accent : S.line)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _filtros(context, catsDoMes),
                  child: SizedBox(
                    height: 46,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(children: [
                        IconeSite('<path d="M3 6h18M7 12h10M10 18h4"/>', tam: 18, cor: cat != null ? S.accent : S.ink),
                        const SizedBox(width: 7),
                        Text(cat != null ? catGasto(cat).nome : 'Filtros', style: TextStyle(fontWeight: FontWeight.w700, color: cat != null ? S.accent : S.ink)),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
            if (q.isNotEmpty || cat != null || filtro != 'tudo' || origem != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                child: Row(children: [
                  Expanded(child: Text('${lista.length} lançamento${lista.length == 1 ? '' : 's'}', style: TextStyle(color: S.muted, fontSize: 12.5))),
                  Text(filtro == 'investido' ? 'Investiu ${brl(totalFiltro)}' : brl(totalFiltro, sinal: true),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: filtro == 'investido' ? S.accent : (totalFiltro < 0 ? S.ink : S.pos))),
                ]),
              ),
            const SizedBox(height: 10),
          ],
        ]),
      ),
      if (analise)
        const SliverToBoxAdapter(child: SizedBox(height: 130))
      else if (lista.isEmpty)
        SliverToBoxAdapter(
          child: q.isNotEmpty || cat != null || filtro != 'tudo'
              ? Vazio(icone: Icons.search_off_rounded, titulo: 'Nada encontrado', texto: q.isNotEmpty ? 'Nenhum lançamento com “${buscaC.text}” neste mês.' : 'Nenhum lançamento com esse filtro neste mês.')
              : Vazio(
                  icone: Icons.receipt_long_rounded,
                  titulo: 'Nada lançado em ${mesLongo(widget.ym).toLowerCase()}',
                  texto: 'Seus gastos e entradas do mês aparecem aqui.',
                  acao: 'Lançar gasto',
                  onAcao: () => abrirFormLanc(context),
                ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
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
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                    child: Row(children: [
                      Expanded(child: Text(rotuloDia(dia), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: S.ink2))),
                      Text(_totDia(ls), style: TextStyle(color: S.muted, fontWeight: FontWeight.w600, fontSize: 12)),
                    ]),
                  ),
                  ListaTxSite([for (final l in ls) linhaLancSite(context, repo, l, onTap: () => abrir(l))]),
                ]),
              ));
            },
          ),
        ),
    ]);
  }
}

/// Total do dia como no site: "+ R$ 150,00 · − R$ 189,60" quando há os dois.
String _totDia(List<Lanc> ls) {
  final ent = ls.where((l) => l.ehEntrada && !l.e!.entreContas).fold<double>(0, (a, l) => a + l.valor);
  final sai = ls.where((l) => l.ehGasto).fold<double>(0, (a, l) => a + l.valor);
  final p = <String>[if (ent > 0) '+ ${brl(ent)}', if (sai > 0) '− ${brl(sai)}'];
  return p.isEmpty ? '' : p.join(' · ');
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
      FittedBox(fit: BoxFit.scaleDown, child: Text(brl(v), style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 14))),
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
                      Expanded(child: Text(catGasto(e.key).nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                      Text(brl(e.value), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
        Text('Clique num lançamento para ver e editar aqui.', textAlign: TextAlign.center, style: TextStyle(color: G.apagado, fontSize: 12.5)),
      ]),
    );
  }
}
