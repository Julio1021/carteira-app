// Campo de lançamento rápido: escreva "mercado 45,90 débito" e pronto.
import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/rapido.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';

class CampoRapido extends StatefulWidget {
  /// Chamado depois de salvar (para fechar o menu).
  final VoidCallback aoSalvar;
  final String inicial;
  const CampoRapido({super.key, required this.aoSalvar, this.inicial = ''});
  @override
  State<CampoRapido> createState() => _CampoRapidoState();
}

class _CampoRapidoState extends State<CampoRapido> {
  late final c = TextEditingController(text: widget.inicial);
  final foco = FocusNode();
  bool salvando = false;

  @override
  void dispose() {
    c.dispose();
    foco.dispose();
    super.dispose();
  }

  Future<void> _salvar(Rapido r) async {
    if (!r.pronto || salvando) return;
    salvando = true;
    final repo = RepoScope.ler(context);
    final cat = r.entrada ? catEntrada(r.cat) : catGasto(r.cat);
    await repo.salvar(r.doc(descPadrao: cat.nome));
    if (!mounted) return;
    mostrarConfirmacao(context, cor: G.pos);
    final msg = r.entrada ? 'Entrada lançada.' : 'Gasto lançado em ${cat.nome}.';
    final ms = ScaffoldMessenger.maybeOf(context);
    widget.aoSalvar();
    ms
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final r = lerRapido(c.text, repo.gastos);
    final cat = r == null ? null : (r.entrada ? catEntrada(r.cat) : catGasto(r.cat));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      TextField(
        controller: c,
        focusNode: foco,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.none,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (r != null && r.pronto) {
            _salvar(r);
          } else {
            foco.requestFocus();
          }
        },
        decoration: InputDecoration(
          hintText: 'Escreva: mercado 45,90 débito',
          prefixIcon: Icon(Icons.bolt_rounded, color: G.lavanda),
          suffixIcon: r != null && r.pronto
              ? Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IconButton.filled(
                    tooltip: 'Lançar',
                    onPressed: () => _salvar(r),
                    style: IconButton.styleFrom(backgroundColor: G.branco, foregroundColor: G.tinta),
                    icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                  ),
                )
              : null,
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: r == null || cat == null
            ? Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text('A categoria é escolhida sozinha. Use “+” na frente para entrada e “ontem” para a data.', style: TextStyle(color: G.apagado, fontSize: 12)),
              )
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
                  decoration: BoxDecoration(color: G.v(0x0A), borderRadius: BorderRadius.circular(14), border: Border.all(color: G.borda)),
                  child: Row(children: [
                    IconeCategoria(cat, tam: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.desc.isEmpty ? cat.nome : r.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          [cat.nome, if (!r.entrada) r.pag, rotuloDia(r.data)].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: G.apagado, fontSize: 12),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.pronto ? '${r.entrada ? '+ ' : '− '}${brlSempre(r.valor!)}' : 'falta o valor',
                      style: TextStyle(fontWeight: r.pronto ? FontWeight.w800 : FontWeight.w500, fontSize: r.pronto ? 15 : 12.5, color: r.pronto ? (r.entrada ? G.pos : G.texto) : G.alerta),
                    ),
                  ]),
                ),
              ),
      ),
    ]);
  }
}
