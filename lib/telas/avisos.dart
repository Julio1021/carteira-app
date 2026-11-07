import 'package:flutter/material.dart';

import '../dados/avisos.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import 'busca.dart';

/// Botão do sininho com o número de avisos novos.
class BotaoAvisos extends StatelessWidget {
  final void Function(String cat) verCategoria;
  const BotaoAvisos({super.key, required this.verCategoria});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final l = avisosDoMes(repo);
    if (l.isEmpty) return const SizedBox(width: 42);
    final vistos = repo.lista('av.vistos').toSet();
    final novos = l.where((a) => !vistos.contains(a.k)).toList();
    final grave = novos.any((a) => a.sev >= 3);
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(
        tooltip: 'Avisos do mês',
        onPressed: () async {
          await repo.guardarLista('av.vistos', {...vistos, ...l.map((a) => a.k)}.toList().reversed.take(300).toList());
          if (context.mounted) abrirAvisos(context, verCategoria);
        },
        style: IconButton.styleFrom(
          backgroundColor: const Color(0x10FFFFFF),
          side: const BorderSide(color: G.borda),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          fixedSize: const Size(42, 42),
        ),
        icon: Icon(Icons.notifications_none_rounded, color: grave ? const Color(0xFFFF8DA0) : G.texto),
      ),
      if (novos.isNotEmpty)
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: grave ? G.neg : G.branco, borderRadius: BorderRadius.circular(99), border: Border.all(color: G.fundo, width: 2)),
            child: Text('${novos.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: grave ? Colors.white : G.tinta)),
          ),
        ),
    ]);
  }
}

Future<void> abrirAvisos(BuildContext context, void Function(String cat) verCategoria) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => _FolhaAvisos(verCategoria: verCategoria),
  );
}

class _FolhaAvisos extends StatelessWidget {
  final void Function(String cat) verCategoria;
  const _FolhaAvisos({required this.verCategoria});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final l = avisosDoMes(repo);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Avisos do mês', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        Text(l.isEmpty ? 'Nada pedindo atenção agora.' : '${l.length} ${l.length > 1 ? 'coisas merecem' : 'coisa merece'} sua atenção', style: const TextStyle(color: G.apagado)),
        const SizedBox(height: 12),
        Flexible(
          child: ListView(shrinkWrap: true, children: [
            for (final a in l) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0x0BFFFFFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: G.borda)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: _cor(a.sev).withValues(alpha: .18), borderRadius: BorderRadius.circular(11)),
                    child: Icon(_ico(a.sev), size: 18, color: _cor(a.sev)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.texto, style: const TextStyle(height: 1.35)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, children: [
                        if (a.fixos)
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(10, 34)),
                            onPressed: () async {
                              final docs = docsLancarFixos(repo, ymDe(hojeIso()));
                              await repo.salvarVarios(docs);
                              if (context.mounted) avisar(context, '${docs.length} gasto(s) fixo(s) lançado(s).');
                            },
                            child: const Text('Lançar fixos'),
                          ),
                        if (a.cat != null)
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              verCategoria(a.cat!);
                            },
                            child: const Text('ver gastos'),
                          ),
                        if (a.busca != null)
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaBusca(inicial: a.busca!)));
                            },
                            child: const Text('ver'),
                          ),
                      ]),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Dispensar aviso',
                    icon: const Icon(Icons.close_rounded, size: 18, color: G.apagado),
                    onPressed: () => repo.guardarLista('av.ocultos', [...repo.lista('av.ocultos'), a.k].reversed.take(300).toList()),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ],
          ]),
        ),
      ]),
    );
  }

  static Color _cor(int s) => switch (s) { 3 => G.neg, 2 => G.alerta, 0 => G.pos, _ => G.lavanda };
  static IconData _ico(int s) => switch (s) { 3 => Icons.warning_amber_rounded, 2 => Icons.trending_up_rounded, 0 => Icons.check_rounded, _ => Icons.info_outline_rounded };
}
