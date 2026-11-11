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

/// Chips de assunto: mostra um assunto por vez. Toque no chip ou deslize
/// para o lado (a página acompanha o dedo).
class ChipsAssunto extends StatefulWidget {
  final List<String> nomes;
  final Widget Function(BuildContext, int) construir;
  final int inicial;
  const ChipsAssunto({super.key, required this.nomes, required this.construir, this.inicial = 0});
  @override
  State<ChipsAssunto> createState() => _ChipsAssuntoState();
}

class _ChipsAssuntoState extends State<ChipsAssunto> with SingleTickerProviderStateMixin {
  late int sel = widget.inicial;
  int? alvo; // página que entra durante o deslize/animação
  double dx = 0; // quanto a página atual andou para o lado
  double larg = 1;
  late final AnimationController ac = AnimationController(vsync: this);
  final chaves = <int, GlobalKey>{};
  final paginas = <int, GlobalKey>{}; // mantém a página viva ao trocar de lugar
  static const _gap = 12.0;

  int get n => widget.nomes.length;

  void _animar(double ate, {VoidCallback? fim}) {
    final de = dx;
    ac.stop();
    ac.value = 0;
    final dist = (ate - de).abs();
    final ms = semAnimacao(context) ? 1 : (dist / (larg + _gap) * 380).clamp(140, 380).round();
    void tick() => setState(() => dx = de + (ate - de) * Curves.easeOutCubic.transform(ac.value));
    ac.addListener(tick);
    ac.animateTo(1, duration: Duration(milliseconds: ms)).whenComplete(() {
      ac.removeListener(tick);
      if (mounted) fim?.call();
    });
  }

  void _concluir(int i) {
    setState(() {
      sel = i;
      alvo = null;
      dx = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = chaves[i]?.currentContext;
      if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250), alignment: .5);
    });
  }

  void _irPara(int i) {
    if (i < 0 || i >= n || i == sel || ac.isAnimating) return;
    HapticFeedback.selectionClick();
    setState(() => alvo = i);
    _animar(i > sel ? -(larg + _gap) : (larg + _gap), fim: () => _concluir(i));
  }

  void _arrastou(DragUpdateDetails d) {
    if (ac.isAnimating) return;
    final temProx = sel + 1 < n, temAnt = sel > 0;
    var novo = dx + d.delta.dx;
    // resistência nas pontas
    if ((novo < 0 && !temProx) || (novo > 0 && !temAnt)) novo = dx + d.delta.dx * .3;
    setState(() {
      dx = novo.clamp(-(larg + _gap), larg + _gap).toDouble();
      alvo = dx < 0 ? (temProx ? sel + 1 : null) : (dx > 0 ? (temAnt ? sel - 1 : null) : null);
    });
  }

  void _soltou(DragEndDetails d) {
    if (ac.isAnimating) return;
    final v = d.primaryVelocity ?? 0;
    final a = alvo;
    final passou = dx.abs() > larg * .25 || v.abs() > 450;
    final sentidoOk = a != null && ((a > sel && dx < 0 && v <= 250) || (a < sel && dx > 0 && v >= -250));
    if (passou && sentidoOk) {
      HapticFeedback.selectionClick();
      _animar(a > sel ? -(larg + _gap) : (larg + _gap), fim: () => _concluir(a));
    } else {
      _animar(0, fim: () => setState(() => alvo = null));
    }
  }

  @override
  void didUpdateWidget(ChipsAssunto old) {
    super.didUpdateWidget(old);
    if (sel >= n) sel = n - 1;
    if (alvo != null && alvo! >= n) alvo = null;
    if (old.nomes.join('|') != widget.nomes.join('|')) paginas.clear();
  }

  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = alvo;
    // o chip e os pontinhos acompanham o deslize
    final mostrado = a != null && dx.abs() > (larg + _gap) / 2 ? a : sel;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(children: [
          for (var i = 0; i < n; i++)
            Padding(
              key: chaves.putIfAbsent(i, GlobalKey.new),
              padding: EdgeInsets.only(right: i < n - 1 ? 6 : 0),
              child: Toque(
                escala: .93,
                child: GestureDetector(
                  onTap: () => _irPara(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: i == mostrado ? G.texto : G.fundo2,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: i == mostrado ? G.texto : G.borda),
                    ),
                    child: Text(widget.nomes[i], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: i == mostrado ? G.fundo : G.texto2)),
                  ),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, cons) {
        larg = cons.maxWidth;
        final passo = larg + _gap;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: _arrastou,
          onHorizontalDragEnd: _soltou,
          // A altura é a da página atual (sem medir nada); a vizinha entra pelo
          // lado, alinhada no topo. Ao trocar, a altura se ajusta suavemente.
          child: AnimatedSize(
            duration: Duration(milliseconds: semAnimacao(context) ? 0 : 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none, // nunca corta o cartão enquanto ajusta a altura
            child: Stack(clipBehavior: Clip.none, children: [
              Transform.translate(offset: Offset(dx, 0), child: KeyedSubtree(key: paginas.putIfAbsent(sel, GlobalKey.new), child: widget.construir(context, sel))),
              if (a != null && a != sel)
                Positioned(
                  top: 0,
                  left: (a > sel ? passo : -passo) + dx,
                  width: larg,
                  child: IgnorePointer(child: KeyedSubtree(key: paginas.putIfAbsent(a, GlobalKey.new), child: widget.construir(context, a))),
                ),
            ]),
          ),
        );
      }),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < n; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: i == mostrado ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == mostrado ? G.lavanda : G.v(0x22), borderRadius: BorderRadius.circular(3)),
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

/// Faixa de 2–3 números no rodapé de um cartão: rótulo pequeno em cima,
/// valor embaixo, separados por uma linha fina.
class FaixaNumeros extends StatelessWidget {
  final List<(String, String, Color?)> itens;
  const FaixaNumeros(this.itens, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: G.borda))),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < itens.length; i++) ...[
            if (i > 0) VerticalDivider(width: 20, thickness: 1, color: G.borda),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(itens[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: G.apagado, fontSize: 11.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(itens[i].$2, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: itens[i].$3 ?? G.texto)),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Dica curta numa pílula colorida (uma ou duas linhas, no máximo).
class Dica extends StatelessWidget {
  final IconData icone;
  final String texto;
  final Color? cor;
  const Dica(this.texto, {super.key, this.icone = Icons.lightbulb_outline_rounded, this.cor});
  @override
  Widget build(BuildContext context) {
    final c = cor ?? G.alerta;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(color: c.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icone, size: 17, color: c),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: G.texto2, fontSize: 12.5, height: 1.3))),
      ]),
    );
  }
}

/// Nota de rodapé (fonte dos dados etc.).
class Rodape extends StatelessWidget {
  final String texto;
  const Rodape(this.texto, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(texto, style: TextStyle(color: G.apagado, fontSize: 11)),
      );
}
