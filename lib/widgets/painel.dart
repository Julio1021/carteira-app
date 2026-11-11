// Peças da organização "combinada": quadradinhos de números (2 por linha),
// chips que mostram um assunto por vez (com deslize) e o botão de período.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tema.dart';
import 'comum.dart';
import 'movimento.dart';

/// Um quadradinho de número.
class Kpi {
  final IconData icone;
  final String rotulo;
  final double? valor; // anima de um número para outro
  final String Function(double)? formato;
  final String? texto; // use quando não for número
  final String sub;
  final Color? cor;
  final VoidCallback? onTap;
  const Kpi({required this.icone, required this.rotulo, this.valor, this.formato, this.texto, this.sub = '', this.cor, this.onTap});
}

class KpiTile extends StatelessWidget {
  final Kpi k;
  const KpiTile(this.k, {super.key});
  @override
  Widget build(BuildContext context) {
    final cor = k.cor ?? G.texto;
    final estilo = TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.5, color: cor);
    return Cartao(
      onTap: k.onTap,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      raio: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(k.icone, size: 15, color: cor),
          const SizedBox(width: 5),
          Expanded(child: Text(k.rotulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: G.apagado, fontSize: 12, fontWeight: FontWeight.w600))),
          if (k.onTap != null) Icon(Icons.chevron_right_rounded, size: 16, color: G.apagado),
        ]),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: k.valor != null ? ValorAnimado(k.valor!, formato: k.formato, estilo: estilo) : Text(k.texto ?? '—', style: estilo),
        ),
        if (k.sub.isNotEmpty) Text(k.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: G.apagado, fontSize: 11.5)),
      ]),
    );
  }
}

/// Quadradinhos de 2 em 2.
class GradeKpi extends StatelessWidget {
  final List<Kpi> itens;
  const GradeKpi(this.itens, {super.key});
  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[];
    for (var i = 0; i < itens.length; i += 2) {
      if (i > 0) linhas.add(const SizedBox(height: 8));
      linhas.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: KpiTile(itens[i])),
          const SizedBox(width: 8),
          Expanded(child: i + 1 < itens.length ? KpiTile(itens[i + 1]) : const SizedBox()),
        ]),
      ));
    }
    return Column(children: linhas);
  }
}

/// Barra de abas simples (ex.: Lançamentos | Contas | Gastos).
class Segmentos extends StatelessWidget {
  final List<String> nomes;
  final List<String?>? marcas; // número pequeno ao lado do nome (ex.: atrasadas)
  final int sel;
  final ValueChanged<int> onSel;
  const Segmentos({super.key, required this.nomes, required this.sel, required this.onSel, this.marcas});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: G.abasFundo, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (var i = 0; i < nomes.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onSel(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(color: sel == i ? G.branco : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(child: Text(nomes[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: sel == i ? G.tinta : G.texto2))),
                  if (marcas != null && i < marcas!.length && marcas![i] != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: G.neg, borderRadius: BorderRadius.circular(99)),
                      child: Text(marcas![i]!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Chips de assunto: mostra um assunto por vez; dá para tocar ou deslizar.
class ChipsAssunto extends StatefulWidget {
  final List<String> nomes;
  final Widget Function(BuildContext, int) construir;
  final int inicial;
  const ChipsAssunto({super.key, required this.nomes, required this.construir, this.inicial = 0});
  @override
  State<ChipsAssunto> createState() => _ChipsAssuntoState();
}

class _ChipsAssuntoState extends State<ChipsAssunto> {
  late int sel = widget.inicial;
  int dir = 1;
  final rolagem = ScrollController();
  final chaves = <int, GlobalKey>{};

  void _ir(int i) {
    if (i < 0 || i >= widget.nomes.length || i == sel) return;
    HapticFeedback.selectionClick();
    setState(() {
      dir = i > sel ? 1 : -1;
      sel = i;
    });
    // mantém o chip escolhido visível
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = chaves[i]?.currentContext;
      if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250), alignment: .5);
    });
  }

  @override
  void dispose() {
    rolagem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (sel >= widget.nomes.length) sel = widget.nomes.length - 1;
    if (sel < 0) sel = 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SingleChildScrollView(
        controller: rolagem,
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < widget.nomes.length; i++)
            Padding(
              key: chaves.putIfAbsent(i, GlobalKey.new),
              padding: EdgeInsets.only(right: i < widget.nomes.length - 1 ? 6 : 0),
              child: Toque(
                escala: .93,
                child: GestureDetector(
                  onTap: () => _ir(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: i == sel ? G.texto : G.fundo2,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: i == sel ? G.texto : G.borda),
                    ),
                    child: Text(widget.nomes[i], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: i == sel ? G.fundo : G.texto2)),
                  ),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -250) _ir(sel + 1);
          if (v > 250) _ir(sel - 1);
        },
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: semAnimacao(context) ? 0 : 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (atual, antigos) => Stack(alignment: Alignment.topCenter, children: [...antigos, if (atual != null) atual]),
          transitionBuilder: (child, a) {
            final entrando = child.key == ValueKey(sel);
            final de = Offset(entrando ? .12 * dir : -.12 * dir, 0);
            return FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: de, end: Offset.zero).animate(a), child: child));
          },
          child: KeyedSubtree(key: ValueKey(sel), child: widget.construir(context, sel)),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < widget.nomes.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: i == sel ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == sel ? G.lavanda : G.v(0x22), borderRadius: BorderRadius.circular(3)),
          ),
      ]),
    ]);
  }
}

/// Botão pequeno de período: "12 meses ▾".
class BotaoPeriodo extends StatelessWidget {
  final String valor;
  final List<(String, String)> opcoes; // (valor, nome)
  final ValueChanged<String> onMudar;
  const BotaoPeriodo({super.key, required this.valor, required this.opcoes, required this.onMudar});
  @override
  Widget build(BuildContext context) {
    final nome = opcoes.firstWhere((o) => o.$1 == valor, orElse: () => opcoes.first).$2;
    return PopupMenuButton<String>(
      initialValue: valor,
      onSelected: (v) {
        HapticFeedback.selectionClick();
        onMudar(v);
      },
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        for (final o in opcoes)
          PopupMenuItem(
            value: o.$1,
            child: Row(children: [
              Expanded(child: Text(o.$2, style: TextStyle(fontWeight: o.$1 == valor ? FontWeight.w700 : FontWeight.w500))),
              if (o.$1 == valor) Icon(Icons.check_rounded, size: 18, color: G.lavanda),
            ]),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 5, 7, 5),
        decoration: BoxDecoration(color: G.lavandaFundo, borderRadius: BorderRadius.circular(99), border: Border.all(color: G.lavanda.withValues(alpha: .3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(nome, style: TextStyle(color: G.lavanda, fontWeight: FontWeight.w700, fontSize: 12.5)),
          Icon(Icons.expand_more_rounded, size: 18, color: G.lavanda),
        ]),
      ),
    );
  }
}

/// Título de seção fora do cartão, em letra pequena.
class TituloSecao extends StatelessWidget {
  final String texto;
  final Widget? direita;
  const TituloSecao(this.texto, {super.key, this.direita});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 2, 8),
        child: Row(children: [
          Expanded(child: Text(texto.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: G.apagado))),
          if (direita != null) direita!,
        ]),
      );
}
