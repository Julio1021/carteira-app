// Peças da organização "combinada": quadradinhos de números (2 por linha),
// chips que mostram um assunto por vez (com deslize) e o botão de período.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    // a cor fica no ícone; o número só ganha cor quando pede atenção
    final alerta = k.cor == G.neg || k.cor == G.alerta;
    final estilo = TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.5, color: alerta ? cor : G.texto);
    return Cartao(
      onTap: k.onTap,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      raio: 20,
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

/// Quadradinhos de 2 em 2 (de 4 em 4 quando há espaço, no computador).
class GradeKpi extends StatelessWidget {
  final List<Kpi> itens;
  const GradeKpi(this.itens, {super.key});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final porLinha = cons.maxWidth >= 640 ? 4 : 2;
      final linhas = <Widget>[];
      for (var i = 0; i < itens.length; i += porLinha) {
        if (i > 0) linhas.add(const SizedBox(height: 8));
        linhas.add(IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var j = 0; j < porLinha; j++) ...[
              if (j > 0) const SizedBox(width: 8),
              Expanded(child: i + j < itens.length ? KpiTile(itens[i + j]) : const SizedBox()),
            ],
          ]),
        ));
      }
      return Column(children: linhas);
    });
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
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
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
  /// Quanto a página atual andou para o lado. Fica num ValueNotifier para o
  /// arrastar redesenhar só a posição, sem reconstruir as páginas (e os gráficos).
  final dx = ValueNotifier<double>(0);
  double larg = 1;
  late final AnimationController ac = AnimationController(vsync: this);
  final chaves = <int, GlobalKey>{};
  final paginas = <int, GlobalKey>{}; // cada página fica viva: não "recresce" a cada deslize
  final alturas = <int, double>{};
  final vistas = <int>{}; // páginas já montadas
  static const _gap = 12.0;

  int get n => widget.nomes.length;
  bool get _movendo => alvo != null || dx.value != 0;

  void _animar(double ate, {VoidCallback? fim}) {
    final de = dx.value;
    ac.stop();
    ac.value = 0;
    final dist = (ate - de).abs();
    final ms = semAnimacao(context) ? 1 : (dist / (larg + _gap) * 360).clamp(140, 360).round();
    void tick() => dx.value = de + (ate - de) * Curves.easeOutCubic.transform(ac.value);
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
    });
    dx.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = chaves[i]?.currentContext;
      if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250), alignment: .5);
    });
  }

  void _irPara(int i) {
    if (i < 0 || i >= n || i == sel || ac.isAnimating) return;
    HapticFeedback.selectionClick();
    setState(() {
      alvo = i;
      vistas.add(i);
    });
    _animar(i > sel ? -(larg + _gap) : (larg + _gap), fim: () => _concluir(i));
  }

  void _comecou(DragStartDetails _) {
    if (ac.isAnimating) return;
    // monta as vizinhas já no começo, para medir a altura antes de aparecerem
    final antes = vistas.length;
    if (sel + 1 < n) vistas.add(sel + 1);
    if (sel > 0) vistas.add(sel - 1);
    if (vistas.length != antes) setState(() {});
  }

  void _arrastou(DragUpdateDetails d) {
    if (ac.isAnimating) return;
    final temProx = sel + 1 < n, temAnt = sel > 0;
    var novo = dx.value + d.delta.dx;
    // resistência nas pontas
    if ((novo < 0 && !temProx) || (novo > 0 && !temAnt)) novo = dx.value + d.delta.dx * .3;
    novo = novo.clamp(-(larg + _gap), larg + _gap).toDouble();
    final novoAlvo = novo < 0 ? (temProx ? sel + 1 : null) : (novo > 0 ? (temAnt ? sel - 1 : null) : null);
    if (novoAlvo != alvo) setState(() => alvo = novoAlvo);
    dx.value = novo;
  }

  void _soltou(DragEndDetails d) {
    if (ac.isAnimating) return;
    final v = d.primaryVelocity ?? 0;
    final a = alvo, x = dx.value;
    final passou = x.abs() > larg * .25 || v.abs() > 450;
    final sentidoOk = a != null && ((a > sel && x < 0 && v <= 250) || (a < sel && x > 0 && v >= -250));
    if (passou && sentidoOk) {
      HapticFeedback.selectionClick();
      _animar(a > sel ? -(larg + _gap) : (larg + _gap), fim: () => _concluir(a));
    } else {
      _animar(0, fim: () => setState(() => alvo = null));
    }
  }

  void _mediu(int i, double h) {
    if (alturas[i] == h) return;
    alturas[i] = h;
    // só precisa redesenhar se estiver no meio de um deslize
    if (_movendo && mounted) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() {}) : null);
  }

  @override
  void didUpdateWidget(ChipsAssunto old) {
    super.didUpdateWidget(old);
    if (sel >= n) sel = n - 1;
    if (alvo != null && alvo! >= n) alvo = null;
    if (old.nomes.join('|') != widget.nomes.join('|')) {
      paginas.clear();
      alturas.clear();
      vistas.clear();
    }
  }

  @override
  void dispose() {
    ac.dispose();
    dx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      if (cons.maxWidth >= 900) return _grade(context);
      return _umPorVez(context);
    });
  }

  /// Computador: todos os assuntos de uma vez, em duas colunas.
  Widget _grade(BuildContext context) {
    final col = [<Widget>[], <Widget>[]];
    for (var i = 0; i < n; i++) {
      final lado = col[i % 2];
      if (lado.isNotEmpty) lado.add(const SizedBox(height: 16));
      lado.add(widget.construir(context, i));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: col[0])),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: col[1])),
    ]);
  }

  Widget _umPorVez(BuildContext context) {
    vistas.add(sel);
    // páginas montadas uma vez só; quem não aparece fica escondida e parada
    final montadas = vistas.where((i) => i < n).toList()..sort();
    final pagina = <int, Widget>{
      for (final i in montadas)
        i: KeyedSubtree(
          key: paginas.putIfAbsent(i, GlobalKey.new),
          child: RepaintBoundary(child: _Medir(aoMedir: (h) => _mediu(i, h), child: widget.construir(context, i))),
        ),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ValueListenableBuilder<double>(
        valueListenable: dx,
        builder: (context, x, _) {
          final a = alvo;
          final mostrado = a != null && x.abs() > (larg + _gap) / 2 ? a : sel;
          return SingleChildScrollView(
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
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: i == mostrado ? _chipSel : G.fundo2,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: i == mostrado ? _chipSel : G.borda),
                        ),
                        child: Text(widget.nomes[i], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: i == mostrado ? _chipTexto : G.texto2)),
                      ),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, cons) {
        larg = cons.maxWidth;
        final passo = larg + _gap;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _comecou,
          onHorizontalDragUpdate: _arrastou,
          onHorizontalDragEnd: _soltou,
          onHorizontalDragCancel: () {
            if (!ac.isAnimating && dx.value != 0) _animar(0, fim: () => setState(() => alvo = null));
          },
          child: ValueListenableBuilder<double>(
            valueListenable: dx,
            builder: (context, x, _) {
              final a = alvo;
              final movendo = a != null || x != 0;
              Widget escondida(int i) => Positioned(
                    top: 0,
                    left: 0,
                    width: larg,
                    child: Offstage(child: TickerMode(enabled: false, child: pagina[i]!)),
                  );
              if (!movendo) {
                // parado: a página atual dá a altura (sem medir nada)
                return Stack(clipBehavior: Clip.none, children: [
                  for (final i in montadas)
                    if (i == sel) pagina[i]! else escondida(i),
                ]);
              }
              // deslizando: a altura vai da atual para a próxima junto com o dedo,
              // e o que passa da altura é cortado (nada fica por cima do resto da tela)
              final p = (x.abs() / passo).clamp(0.0, 1.0);
              final hSel = alturas[sel] ?? 0, hAlvo = a == null ? hSel : (alturas[a] ?? hSel);
              final h = hSel + (hAlvo - hSel) * p;
              return SizedBox(
                height: h,
                child: ClipRect(
                  clipper: _CorteLateral(),
                  child: Stack(clipBehavior: Clip.none, children: [
                    for (final i in montadas)
                      if (i == sel)
                        Positioned(top: 0, left: x, width: larg, child: pagina[i]!)
                      else if (i == a)
                        Positioned(top: 0, left: (a! > sel ? passo : -passo) + x, width: larg, child: IgnorePointer(child: pagina[i]!))
                      else
                        escondida(i),
                  ]),
                ),
              );
            },
          ),
        );
      }),
      const SizedBox(height: 10),
      ValueListenableBuilder<double>(
        valueListenable: dx,
        builder: (context, x, _) {
          final a = alvo;
          final mostrado = a != null && x.abs() > (larg + _gap) / 2 ? a : sel;
          return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < n; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: i == mostrado ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(color: i == mostrado ? G.lavanda : G.v(0x22), borderRadius: BorderRadius.circular(3)),
              ),
          ]);
        },
      ),
    ]);
  }
}

/// Corta embaixo (para a página mais alta não passar por cima do resto) mas deixa
/// sobrar dos lados e em cima (sombra dos cartões e a página que entra).
/// Chip escolhido com a mesma cor da aba escolhida (Segmentos), para o tema
/// falar uma língua só. Nos temas Nuvem a aba é branca sobre trilho cinza, então
/// o chip fica na cor do texto.
Color get _chipSel => G.nuvem != null ? G.texto : G.branco;
Color get _chipTexto => G.nuvem != null ? G.fundo : G.tinta;

class _CorteLateral extends CustomClipper<Rect> {
  @override
  Rect getClip(Size s) => Rect.fromLTRB(-60, -24, s.width + 60, s.height + 2);
  @override
  bool shouldReclip(_CorteLateral o) => false;
}

/// Informa a altura do filho depois de cada layout.
class _Medir extends SingleChildRenderObjectWidget {
  final ValueChanged<double> aoMedir;
  const _Medir({required this.aoMedir, required Widget super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMedir(aoMedir);
  @override
  void updateRenderObject(BuildContext context, _RenderMedir r) => r.aoMedir = aoMedir;
}

class _RenderMedir extends RenderProxyBox {
  ValueChanged<double> aoMedir;
  _RenderMedir(this.aoMedir);
  @override
  void performLayout() {
    super.performLayout();
    aoMedir(size.height);
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
  // verde de "deu certo" vira neutro; vermelho/alerta continuam chamando atenção
  static Color _cor(Color? c) => (c == null || c == G.pos) ? G.texto : c;
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
                  child: Text(itens[i].$2, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: _cor(itens[i].$3))),
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

/// Tela/área vazia: um desenho simples, uma frase e (opcional) o botão que
/// leva direto à ação.
class Vazio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? texto;
  final String? acao;
  final VoidCallback? onAcao;
  const Vazio({super.key, required this.icone, required this.titulo, this.texto, this.acao, this.onAcao});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 86,
          height: 86,
          child: Stack(alignment: Alignment.center, children: [
            Container(decoration: BoxDecoration(shape: BoxShape.circle, color: G.lavanda.withValues(alpha: .10))),
            Positioned(right: 6, top: 8, child: Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: G.lavanda.withValues(alpha: .22)))),
            Positioned(left: 10, bottom: 12, child: Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: G.pos.withValues(alpha: .35)))),
            Icon(icone, size: 36, color: G.lavanda),
          ]),
        ),
        const SizedBox(height: 14),
        Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (texto != null) ...[
          const SizedBox(height: 4),
          Text(texto!, textAlign: TextAlign.center, style: TextStyle(color: G.apagado, fontSize: 13, height: 1.35)),
        ],
        if (acao != null && onAcao != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onAcao, icon: const Icon(Icons.add_rounded), label: Text(acao!)),
        ],
      ]),
    );
  }
}
