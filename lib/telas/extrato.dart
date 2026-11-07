import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import 'lancar.dart';

class TelaExtrato extends StatefulWidget {
  final String ym;
  final ValueChanged<String> onMes;
  final String filtroInicial;
  const TelaExtrato({super.key, required this.ym, required this.onMes, this.filtroInicial = 'tudo'});
  @override
  State<TelaExtrato> createState() => _TelaExtratoState();
}

class _TelaExtratoState extends State<TelaExtrato> {
  late String filtro = widget.filtroInicial; // tudo | saidas | entradas
  String? cat;
  final buscaC = TextEditingController();

  @override
  void didUpdateWidget(covariant TelaExtrato old) {
    super.didUpdateWidget(old);
    if (old.filtroInicial != widget.filtroInicial) filtro = widget.filtroInicial;
  }

  @override
  void dispose() {
    buscaC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final r = ResumoMes.de(repo, widget.ym);
    final q = buscaC.text.trim().toLowerCase();
    var lista = r.lancamentos.where((l) {
      if (filtro == 'saidas' && l.ehEntrada) return false;
      if (filtro == 'entradas' && !l.ehEntrada) return false;
      if (cat != null && (l.ehEntrada || l.g!.cat != cat)) return false;
      if (q.isNotEmpty && !l.desc.toLowerCase().contains(q)) return false;
      return true;
    }).toList();

    // agrupa por dia
    final grupos = <String, List<Lanc>>{};
    for (final l in lista) {
      (grupos[l.data] ??= []).add(l);
    }
    final totalFiltro = lista.fold<double>(0, (a, l) => a + (l.ehEntrada ? (l.e!.entreContas ? 0 : l.valor) : -l.valor));
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
            ]),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: buscaC,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar no mês',
              prefixIcon: const Icon(Icons.search_rounded, color: G.apagado),
              suffixIcon: buscaC.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => buscaC.clear()),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in const [['tudo', 'Tudo'], ['saidas', 'Saídas'], ['entradas', 'Entradas']])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: filtro == f[0],
                    label: Text(f[1]),
                    labelStyle: TextStyle(fontWeight: FontWeight.w700, color: filtro == f[0] ? G.tinta : G.texto2),
                    onSelected: (_) => setState(() {
                      filtro = f[0];
                      if (filtro == 'entradas') cat = null;
                    }),
                  ),
                ),
              if (filtro != 'entradas')
                for (final c in catsDoMes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: cat == c,
                      avatar: Icon(catGasto(c).icone, size: 16, color: cat == c ? G.tinta : catGasto(c).cor),
                      label: Text(catGasto(c).nome),
                      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: cat == c ? G.tinta : G.texto2),
                      onSelected: (v) => setState(() => cat = v ? c : null),
                    ),
                  ),
            ]),
          ),
          const SizedBox(height: 12),
          if (q.isNotEmpty || cat != null || filtro != 'tudo')
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
              child: Row(children: [
                Text('${lista.length} lançamento${lista.length == 1 ? '' : 's'}', style: const TextStyle(color: G.apagado)),
                const Spacer(),
                Text(brl(totalFiltro, sinal: true), style: TextStyle(fontWeight: FontWeight.w800, color: totalFiltro < 0 ? G.texto : G.pos)),
              ]),
            ),
        ]),
      ),
      if (lista.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(children: [
              const Icon(Icons.receipt_long_rounded, size: 40, color: G.apagado),
              const SizedBox(height: 10),
              Text(q.isNotEmpty ? 'Nada encontrado para “${buscaC.text}”.' : 'Nenhum lançamento em ${mesLongo(widget.ym).toLowerCase()}.', textAlign: TextAlign.center, style: const TextStyle(color: G.apagado)),
            ]),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 130),
          sliver: SliverList.builder(
            itemCount: grupos.length,
            itemBuilder: (c, i) {
              final dia = grupos.keys.elementAt(i);
              final ls = grupos[dia]!;
              final tot = ls.fold<double>(0, (a, l) => a + (l.ehEntrada ? (l.e!.entreContas ? 0 : l.valor) : -l.valor));
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Row(children: [
                      Text(rotuloDia(dia), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text(brl(tot, sinal: true), style: TextStyle(color: tot < 0 ? G.apagado : G.pos, fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                  ),
                  CaixaLista([for (final l in ls) LinhaLanc(l, onTap: () => abrirFormLanc(context, doc: l.g?.d ?? l.e!.d))]),
                ]),
              );
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
      Text(t, style: const TextStyle(color: G.texto2, fontSize: 12.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, child: Text(brl(v), style: TextStyle(color: cor, fontWeight: FontWeight.w800, fontSize: 15))),
    ]);
  }
}
