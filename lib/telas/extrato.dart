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
import 'lancar.dart';
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

  Widget _chipAtivo(String t, Color cor, VoidCallback tirar) => Material(
        color: S.accentSoft,
        shape: StadiumBorder(side: BorderSide(color: S.accent.withValues(alpha: .5))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: tirar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: S.ink)),
              const SizedBox(width: 4),
              Icon(Icons.close_rounded, size: 16, color: S.ink2),
            ]),
          ),
        ),
      );

  /// Folha de filtros: conta/cartão e categoria, aplicados juntos.
  Future<void> _filtros(BuildContext context, List<String> cats, List<(String, String, Color?)> origens) async {
    final todas = [...cats, for (final c in categoriasGasto) if (!cats.contains(c.id)) c.id];
    String? c0 = cat, o0 = origem;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: S.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Widget chip(String t, bool on, VoidCallback f, {Color? ponto}) => Material(
                color: on ? S.accentSoft : S.surface,
                shape: StadiumBorder(side: BorderSide(color: on ? S.accent : S.line, width: on ? 1.5 : 1)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: f,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (ponto != null) ...[Container(width: 9, height: 9, decoration: BoxDecoration(color: ponto, shape: BoxShape.circle)), const SizedBox(width: 7)],
                      Text(t, style: TextStyle(fontSize: 13.5, fontWeight: on ? FontWeight.w700 : FontWeight.w600, color: on ? S.accent : S.ink)),
                    ]),
                  ),
                ),
              );
          Widget titulo(String t) => Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 10),
                child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: S.ink)),
              );
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .85),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: S.line, borderRadius: BorderRadius.circular(2)))),
                Flexible(
                  child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 14, 18, 8), children: [
                    Text('Filtros', style: TextStyle(fontFamily: S.fonteNum, fontSize: 20, fontWeight: FontWeight.w700, color: S.ink)),
                    if (origens.isNotEmpty) ...[
                      titulo('Conta ou cartão'),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        chip('Todas', o0 == null, () => set(() => o0 = null)),
                        for (final (id, nome, cor) in origens) chip(nome, o0 == id, () => set(() => o0 = o0 == id ? null : id), ponto: cor ?? S.ink2),
                      ]),
                    ],
                    titulo('Categoria'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      chip('Todas', c0 == null, () => set(() => c0 = null)),
                      for (final id in todas) chip(catGasto(id).nome, c0 == id, () => set(() => c0 = c0 == id ? null : id), ponto: catGasto(id).cor),
                    ]),
                    const SizedBox(height: 6),
                    Text('As categorias com gastos neste mês aparecem primeiro.', style: TextStyle(fontSize: 12.5, color: S.muted)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => set(() {
                          c0 = null;
                          o0 = null;
                        }),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                        child: const Text('Limpar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                        child: const Text('Aplicar filtros'),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      cat = c0;
      origem = o0;
      if (cat != null && filtro != 'saidas') filtro = 'saidas';
    });
  }

  Widget _lista(BuildContext context, bool doisPaineis) {
    final repo = RepoScope.of(context);
    final r = ResumoMes.de(repo, widget.ym);
    void abrir(Lanc l) => abreClassificar(l)
        ? abrirLancamento(context, l)
        : (doisPaineis ? setState(() => aberto = aberto?['id'] == l.doc['id'] ? null : l.doc) : abrirFormLanc(context, doc: l.doc));
    final q = buscaC.text.trim().toLowerCase();
    var lista = r.lancamentos.where((l) {
      // transferência para outra conta sua aparece em Saídas; a que chegou, em Entradas
      final saidaProp = l.ehEntrada && l.e!.valor < 0;
      if (filtro == 'saidas' && !l.ehGasto && !saidaProp) return false;
      if (filtro == 'entradas' && (!l.ehEntrada || saidaProp)) return false;
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
    final gruposTodos = <String, List<Lanc>>{};
    for (final l in lista) {
      (gruposTodos[l.data] ??= []).add(l);
    }
    // os dias que já passaram primeiro (do mais novo ao mais velho); os
    // agendados (data depois de hoje) vão para o fim, do mais próximo ao mais longe
    final hojeX = hojeIso();
    final passados = gruposTodos.keys.where((d) => d.compareTo(hojeX) <= 0);
    final futuros = gruposTodos.keys.where((d) => d.compareTo(hojeX) > 0).toList()..sort();
    final grupos = <String, List<Lanc>>{for (final d in [...passados, ...futuros]) d: gruposTodos[d]!};
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
    final nFiltros = (cat != null ? 1 : 0) + (origem != null ? 1 : 0);
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
              irLista: () => setState(() => analise = false),
              buscar: (d) => setState(() {
                analise = false;
                filtro = 'tudo';
                cat = null;
                buscaC.text = d;
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
                color: nFiltros > 0 ? S.accentSoft : S.surface2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: nFiltros > 0 ? S.accent : S.line)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _filtros(context, catsDoMes, origens),
                  child: SizedBox(
                    height: 46,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(children: [
                        IconeSite('<path d="M3 6h18M7 12h10M10 18h4"/>', tam: 18, cor: nFiltros > 0 ? S.accent : S.ink),
                        const SizedBox(width: 7),
                        Text('Filtros', style: TextStyle(fontWeight: FontWeight.w700, color: nFiltros > 0 ? S.accent : S.ink)),
                        if (nFiltros > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: S.accent, shape: BoxShape.circle),
                            child: Text('$nFiltros', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: S.ctaInk)),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
            if (nFiltros > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  if (cat != null) _chipAtivo(catGasto(cat).nome, catGasto(cat).cor, () => setState(() => cat = null)),
                  if (origem != null)
                    for (final (id, nome, cor) in origens)
                      if (id == origem) _chipAtivo(nome, cor ?? S.ink2, () => setState(() => origem = null)),
                ]),
              ),
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
                      Expanded(
                        child: Text(dia.compareTo(hojeIso()) > 0 ? 'Agendado · ${rotuloDia(dia)}' : rotuloDia(dia),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: dia.compareTo(hojeIso()) > 0 ? S.accent : S.ink2)),
                      ),
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
