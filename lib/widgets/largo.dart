// Tela larga (computador/tablet deitado): menu lateral, conteúdo centralizado
// e telas que se abrem por cima ficam numa coluna confortável de ler.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/drive.dart';
import '../tema.dart';
import 'movimento.dart';

const larguraMinimaLarga = 900.0;

bool telaLarga(BuildContext context) => MediaQuery.sizeOf(context).width >= larguraMinimaLarga;

/// Limita a largura do conteúdo e centraliza (só tem efeito em telas largas).
class Centralizar extends StatelessWidget {
  final double max;
  final Widget child;
  const Centralizar({super.key, this.max = 860, required this.child});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: max), child: child),
      );
}

/// Para telas abertas por cima (Ajustes, Busca, Limites…): no computador elas
/// ficam numa coluna central, com o fundo do app dos lados.
class Estreito extends StatelessWidget {
  final Widget child;
  const Estreito({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < larguraMinimaLarga) return child;
    return ColoredBox(
      color: G.fundo,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: MediaQuery(data: MediaQuery.of(context).copyWith(size: Size(820, MediaQuery.sizeOf(context).height)), child: child),
        ),
      ),
    );
  }
}

/// Menu lateral do computador.
class MenuLateral extends StatelessWidget {
  final int aba;
  final ValueChanged<int> onAba;
  final VoidCallback onNovo, onAjustes;
  const MenuLateral({super.key, required this.aba, required this.onAba, required this.onNovo, required this.onAjustes});

  @override
  Widget build(BuildContext context) {
    Widget item(int i, IconData ic, IconData icOn, String t, String atalho) {
      final on = aba == i;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: on ? G.lavandaFundo : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onAba(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(children: [
                Icon(on ? icOn : ic, size: 21, color: on ? G.lavanda : G.texto2),
                const SizedBox(width: 12),
                Expanded(child: Text(t, style: TextStyle(fontSize: 14.5, fontWeight: on ? FontWeight.w700 : FontWeight.w600, color: on ? G.texto : G.texto2))),
                Text(atalho, style: TextStyle(fontSize: 11, color: G.apagado, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 236,
      decoration: BoxDecoration(color: G.fundo2, border: Border(right: BorderSide(color: G.borda))),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/icone.png', width: 34, height: 34, errorBuilder: (_, __, ___) => const SizedBox(width: 34, height: 34))),
          const SizedBox(width: 10),
          const Expanded(child: Text('Diário da Carteira', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -.2))),
        ]),
        const SizedBox(height: 22),
        Toque(
          escala: .97,
          child: FilledButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              onNovo();
            },
            style: FilledButton.styleFrom(
              backgroundColor: G.branco,
              foregroundColor: G.tinta,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo lançamento'),
          ),
        ),
        const SizedBox(height: 6),
        Center(child: Text('ou aperte N', style: TextStyle(color: G.apagado, fontSize: 11))),
        const SizedBox(height: 18),
        item(0, Icons.home_outlined, Icons.home_rounded, 'Início', '1'),
        item(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Extrato', '2'),
        item(2, Icons.event_note_outlined, Icons.event_note_rounded, 'Planejar', '3'),
        item(3, Icons.show_chart_rounded, Icons.show_chart_rounded, 'Patrimônio', '4'),
        const Spacer(),
        const _StatusDrive(),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onAjustes,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(children: [
                Icon(Icons.settings_outlined, size: 21, color: G.texto2),
                const SizedBox(width: 12),
                Text('Ajustes', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: G.texto2)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Situação da sincronização com o Drive, no pé do menu lateral.
class _StatusDrive extends StatelessWidget {
  const _StatusDrive();
  @override
  Widget build(BuildContext context) {
    final sd = syncDrive;
    if (sd == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: sd,
      builder: (context, _) {
        final (IconData ic, Color cor, String t, String sub) = switch (sd.estado) {
          EstadoDrive.desligado => (Icons.cloud_off_outlined, G.apagado, 'Drive desligado', 'ligar em Ajustes'),
          EstadoDrive.sincronizando => (Icons.cloud_sync_outlined, G.lavanda, 'Sincronizando…', ''),
          EstadoDrive.pendente => (Icons.cloud_upload_outlined, G.lavanda, 'Salvando no Drive…', ''),
          EstadoDrive.entrar => (Icons.cloud_off_outlined, G.alerta, 'Sincronizar', 'toque para entrar no Google'),
          EstadoDrive.erro => (Icons.cloud_off_outlined, G.neg, 'Drive com erro', 'toque para tentar de novo'),
          EstadoDrive.pronto => (Icons.cloud_done_outlined, G.pos, 'Drive em dia', sd.quando),
        };
        final clicavel = sd.estado == EstadoDrive.entrar || sd.estado == EstadoDrive.erro || sd.estado == EstadoDrive.pronto;
        return Material(
          color: sd.estado == EstadoDrive.entrar ? G.alerta.withValues(alpha: .12) : G.v(0x08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: clicavel ? () => sd.sincronizar(interativo: true) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Icon(ic, size: 20, color: cor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: G.apagado, fontSize: 11.5)),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
