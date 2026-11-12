import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/repo.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import 'movimento.dart';

/// Dá acesso ao repositório em qualquer tela e redesenha quando os dados mudam.
class RepoScope extends InheritedNotifier<Repo> {
  const RepoScope({super.key, required Repo repo, required super.child}) : super(notifier: repo);
  static Repo of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<RepoScope>()!.notifier!;
  static Repo ler(BuildContext c) => (c.getElementForInheritedWidgetOfExactType<RepoScope>()!.widget as RepoScope).notifier!;
}

/// Cartão com efeito de vidro.
class Cartao extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradiente;
  final double raio;
  final VoidCallback? onTap;
  const Cartao({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.gradiente, this.raio = 20, this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(raio);
    final caixa = DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradiente ?? G.gradCartao,
        borderRadius: r,
        border: Border.all(color: G.borda),
        boxShadow: [BoxShadow(color: G.sombra(0x55), blurRadius: 20, offset: Offset(0, 8), spreadRadius: -14)],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: r, onTap: onTap, child: Padding(padding: padding, child: _DentroDeCartao(child: child))),
      ),
    );
    return onTap == null ? caixa : Toque(escala: .985, child: caixa);
  }
}

/// Cabeçalho de seção dentro de um cartão: título, subtítulo e ação à direita.
class CabecalhoCartao extends StatelessWidget {
  final String titulo;
  final String? sub;
  final String? acao;
  final VoidCallback? onAcao;
  const CabecalhoCartao(this.titulo, {super.key, this.sub, this.acao, this.onAcao});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -.2)),
            if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: TextStyle(color: G.apagado, fontSize: 12.5))),
          ]),
        ),
        if (acao != null)
          OutlinedButton(
            onPressed: onAcao,
            style: OutlinedButton.styleFrom(minimumSize: const Size(10, 32), padding: const EdgeInsets.symmetric(horizontal: 10), visualDensity: VisualDensity.compact),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Text(acao!, style: const TextStyle(fontSize: 13)), const SizedBox(width: 2), const Icon(Icons.chevron_right_rounded, size: 18)]),
          ),
      ]),
    );
  }
}

/// Quadrado colorido com o ícone da categoria.
class IconeCategoria extends StatelessWidget {
  final Categoria cat;
  final double tam;
  const IconeCategoria(this.cat, {super.key, this.tam = 36});
  @override
  Widget build(BuildContext context) {
    final c = cat.cor;
    // ícone colorido sobre um fundo clarinho da mesma cor: a categoria continua
    // fácil de reconhecer sem pesar na lista
    final escuro = !G.claro;
    final cor = escuro ? Color.lerp(c, Colors.white, .25)! : Color.lerp(c, Colors.black, .08)!;
    return Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tam * .32),
        color: c.withValues(alpha: escuro ? .20 : .13),
      ),
      child: Icon(cat.icone, color: cor, size: tam * .52),
    );
  }
}

/// Uma linha de lançamento (gasto, entrada ou investido).
class LinhaLanc extends StatelessWidget {
  final Lanc l;
  final VoidCallback? onTap;
  final bool selecionado;
  const LinhaLanc(this.l, {super.key, this.onTap, this.selecionado = false});
  @override
  Widget build(BuildContext context) {
    final inv = l.i;
    final cat = inv != null ? (inv.resgate ? catResgate : catInvestido) : (l.ehEntrada ? catEntrada(l.e!.cat) : catGasto(l.g!.cat));
    final sub = inv != null
        ? (inv.resgate ? 'Resgate · voltou para a conta' : 'Investido · não conta como gasto')
        : (l.ehEntrada ? cat.nome : '${cat.nome} · ${l.g!.pag}');
    final entreContas = l.ehEntrada && l.e!.entreContas;
    return Material(
      color: selecionado ? G.lavandaFundo : Colors.transparent,
      child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _DentroDeCartao.dentro(context) ? 2 : 12, vertical: 9),
        child: Row(children: [
          IconeCategoria(cat),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: G.apagado, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(width: 10),
          Text(
            inv != null ? '${inv.resgate ? '←' : '→'} ${brl(l.valor)}' : (l.ehEntrada ? brl(l.valor, sinal: true) : brl(-l.valor)),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: inv != null ? G.lavanda : (entreContas ? G.apagado : (l.ehEntrada ? G.pos : G.texto)),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ]),
      ),
    ),
    );
  }
}

/// Lista de lançamentos dentro de uma caixa com divisórias.
class CaixaLista extends StatelessWidget {
  final List<Widget> filhos;
  const CaixaLista(this.filhos, {super.key});
  @override
  Widget build(BuildContext context) {
    // Dentro de um cartão vira lista simples (sem caixa dentro de caixa).
    final plana = _DentroDeCartao.dentro(context);
    final col = Column(children: [
      for (var i = 0; i < filhos.length; i++) ...[
        if (i > 0) Divider(indent: plana ? 0 : 12, endIndent: plana ? 0 : 12, height: 1),
        filhos[i],
      ],
    ]);
    if (plana) return col;
    return Container(
      decoration: BoxDecoration(color: G.v(0x07), borderRadius: BorderRadius.circular(16), border: Border.all(color: G.borda)),
      clipBehavior: Clip.antiAlias,
      child: col,
    );
  }
}

/// Seletor de mês: ‹ Novembro 2026 ›
class SeletorMes extends StatelessWidget {
  final String ym;
  final ValueChanged<String> onMudar;
  final bool escuro;
  const SeletorMes({super.key, required this.ym, required this.onMudar, this.escuro = false});
  @override
  Widget build(BuildContext context) {
    Widget seta(IconData i, int n, String rotulo) => IconButton(
          tooltip: rotulo,
          onPressed: () => onMudar(ymAdd(ym, n)),
          style: IconButton.styleFrom(backgroundColor: escuro ? const Color(0x14FFFFFF) : G.v(0x14), side: BorderSide(color: escuro ? GE.borda : G.borda)),
          icon: Icon(i, size: 20),
        );
    return Row(children: [
      seta(Icons.chevron_left_rounded, -1, 'Mês anterior'),
      Expanded(
        child: GestureDetector(
          onTap: ym == ymDe(hojeIso()) ? null : () => onMudar(ymDe(hojeIso())),
          child: Column(children: [
            Text(mesLongo(ym), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            if (ym != ymDe(hojeIso())) Text('toque para voltar ao mês atual', style: TextStyle(fontSize: 11, color: escuro ? GE.apagado : G.apagado)),
          ]),
        ),
      ),
      seta(Icons.chevron_right_rounded, 1, 'Próximo mês'),
    ]);
  }
}

/// Barra de progresso fininha.
class Barra extends StatelessWidget {
  final double valor; // 0..1 (pode passar de 1)
  final Color? _cor;
  final Color? _trilho;
  final double altura;
  const Barra(this.valor, {super.key, Color? cor, Color? trilho, this.altura = 7})
      : _cor = cor,
        _trilho = trilho;
  Color get cor => _cor ?? G.branco;
  Color get trilho => _trilho ?? G.v(0x1F);
  @override
  Widget build(BuildContext context) {
    final f = valor.isNaN ? 0.0 : valor.clamp(0, 1).toDouble();
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : 200.0;
      return Container(
        height: altura,
        width: w,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: trilho, borderRadius: BorderRadius.circular(altura)),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: f),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: w * v,
            height: altura,
            decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(altura)),
          ),
        ),
      );
    });
  }
}

void avisar(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}


/// Força o visual escuro (grafite) num trecho da tela, como o cartão principal.
class Escuro extends StatelessWidget {
  final Widget child;
  const Escuro({super.key, required this.child});
  static ThemeData? _t;
  @override
  Widget build(BuildContext context) {
    final t = _t ??= temaDe(false);
    return Theme(
      data: t,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: GE.texto),
        child: IconTheme.merge(data: const IconThemeData(color: GE.texto), child: child),
      ),
    );
  }
}


/// true quando o widget está dentro de um [Cartao].
bool dentroDeCartao(BuildContext c) => _DentroDeCartao.dentro(c);

/// Marca o conteúdo de um [Cartao] (listas lá dentro ficam sem caixa própria).
class _DentroDeCartao extends InheritedWidget {
  const _DentroDeCartao({required super.child});
  static bool dentro(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_DentroDeCartao>() != null;
  @override
  bool updateShouldNotify(covariant InheritedWidget old) => false;
}
