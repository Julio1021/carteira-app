import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import 'lancar.dart';

/// Busca em todo o histórico de gastos e entradas.
class TelaBusca extends StatefulWidget {
  final String inicial;
  const TelaBusca({super.key, this.inicial = ''});
  @override
  State<TelaBusca> createState() => _TelaBuscaState();
}

class _TelaBuscaState extends State<TelaBusca> {
  late final c = TextEditingController(text: widget.inicial);
  String tipo = 'tudo';
  String? cat;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final q = c.text.trim().toLowerCase();
    final v = lerValor(q);
    final todos = <Lanc>[
      if (tipo != 'entradas') ...repo.gastos.map(Lanc.gasto),
      if (tipo != 'saidas') ...repo.entradas.map(Lanc.entrada),
    ];
    final ativo = q.isNotEmpty || cat != null;
    final res = ativo
        ? (todos.where((l) {
            if (cat != null && (l.ehEntrada || l.g!.cat != cat)) return false;
            if (q.isEmpty) return true;
            if (l.desc.toLowerCase().contains(q)) return true;
            final nomeCat = l.ehEntrada ? catEntrada(l.e!.cat).nome : catGasto(l.g!.cat).nome;
            if (nomeCat.toLowerCase().contains(q)) return true;
            return v != null && (l.valor - v).abs() < .005;
          }).toList()
          ..sort(ordemLanc))
        : <Lanc>[];
    final meses = <String, List<Lanc>>{};
    for (final l in res) {
      (meses[ymDe(l.data)] ??= []).add(l);
    }
    final totG = res.where((l) => !l.ehEntrada).fold<double>(0, (a, l) => a + l.valor);
    final totE = res.where((l) => l.ehEntrada && !l.e!.entreContas).fold<double>(0, (a, l) => a + l.valor);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: c,
          autofocus: widget.inicial.isEmpty,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar em todo o histórico',
            prefixIcon: Icon(Icons.search_rounded, color: G.apagado),
            suffixIcon: c.text.isEmpty ? null : IconButton(tooltip: 'Limpar', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => c.clear())),
          ),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 40), children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in const [['tudo', 'Tudo'], ['saidas', 'Saídas'], ['entradas', 'Entradas']])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: tipo == f[0],
                  label: Text(f[1]),
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, color: tipo == f[0] ? G.tinta : G.texto2),
                  onSelected: (_) => setState(() => tipo = f[0]),
                ),
              ),
            if (tipo != 'entradas')
              for (final cg in categoriasGasto)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: cat == cg.id,
                    avatar: Icon(cg.icone, size: 16, color: cat == cg.id ? G.tinta : cg.cor),
                    label: Text(cg.nome),
                    labelStyle: TextStyle(fontWeight: FontWeight.w700, color: cat == cg.id ? G.tinta : G.texto2),
                    onSelected: (s) => setState(() => cat = s ? cg.id : null),
                  ),
                ),
          ]),
        ),
        const SizedBox(height: 12),
        if (!ativo)
          Padding(
            padding: EdgeInsets.all(24),
            child: Text('Digite uma descrição (ex.: "ifood"), uma categoria ou um valor (ex.: 120,00). A busca olha todos os meses.', textAlign: TextAlign.center, style: TextStyle(color: G.apagado, height: 1.4)),
          )
        else if (res.isEmpty)
          Padding(padding: EdgeInsets.all(24), child: Text('Nada encontrado.', textAlign: TextAlign.center, style: TextStyle(color: G.apagado)))
        else ...[
          Cartao(
            gradiente: G.gradHero,
            child: Row(children: [
              Expanded(child: Column(children: [Text('${res.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), Text('lançamentos', style: TextStyle(color: G.texto2, fontSize: 12))])),
              Expanded(child: Column(children: [FittedBox(child: Text(brl(totG), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: G.neg))), Text('em gastos', style: TextStyle(color: G.texto2, fontSize: 12))])),
              Expanded(child: Column(children: [FittedBox(child: Text(brl(totE), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: G.pos))), Text('em entradas', style: TextStyle(color: G.texto2, fontSize: 12))])),
            ]),
          ),
          const SizedBox(height: 12),
          for (final e in meses.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Row(children: [
                Expanded(child: Text(mesLongo(e.key), style: const TextStyle(fontWeight: FontWeight.w800))),
                Text('${e.value.length} · ${brl(e.value.where((l) => !l.ehEntrada).fold<double>(0, (a, l) => a + l.valor))}', style: TextStyle(color: G.apagado, fontSize: 12.5)),
              ]),
            ),
            CaixaLista([for (final l in e.value) LinhaLanc(l, onTap: () => abrirFormLanc(context, doc: l.doc))]),
            const SizedBox(height: 12),
          ],
        ],
      ]),
    );
  }
}
