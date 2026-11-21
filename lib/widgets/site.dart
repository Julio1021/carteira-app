// Peças visuais copiadas do site Diário da Carteira (medidas e cores tiradas
// do próprio site, tema a tema). Use estas em vez de inventar estilos novos.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../dados/categorias.dart';
import '../tema.dart';
import '../tema_site.dart';
import 'animado.dart';

/// Cores do tema do site em uso (Linho & Safira se nenhum estiver ativo).
class S {
  static TemaSite get t => G.site ?? temasSite.first;
  static Color c(String k) => t.c[k] ?? t.c['ink']!;
  static Color get bg => c('bg');
  static Color get surface => c('surface');
  static Color get surface2 => c('surface-2');
  static Color get ink => c('ink');
  static Color get ink2 => c('ink-2');
  static Color get muted => c('muted');
  static Color get line => c('line');
  static Color get accent => c('accent');
  static Color get accentSoft => c('accent-soft');
  static Color get pos => c('pos');
  static Color get posSoft => c('pos-soft');
  static Color get neg => c('neg');
  static Color get negSoft => c('neg-soft');
  static Color get cta => c('cta');
  static Color get ctaInk => c('cta-ink');
  static Color get second => c('second');
  static bool get escuro => t.escuro;
  /// Borda dos cartões: a linha do tema um pouco mais clara (no site é a mistura com a superfície).
  static Color get bordaCartao => Color.lerp(line, surface, .25)!;
  static List<BoxShadow> get sombraCartao => [
        BoxShadow(color: ink.withValues(alpha: .04), blurRadius: 2, offset: const Offset(0, 1)),
        BoxShadow(color: ink.withValues(alpha: .12), blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -10),
      ];
  static const fonteNum = 'Bricolage';
}

/// Ícones do site (traço, como os SVG originais).
class Ico {
  static const casa = '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9v11h14V9"/><path d="M10 20v-6h4v6"/>';
  static const lista = '<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>';
  static const calendario = '<rect x="3" y="4" width="18" height="17" rx="2"/><path d="M3 9h18M8 2v4M16 2v4M8 14h3"/>';
  static const calendario2 = '<rect x="3" y="4" width="18" height="17" rx="2"/><path d="M3 9h18M8 2v4M16 2v4"/>';
  static const patrimonio = '<path d="M3 17l5-5 4 3 8-8"/><path d="M15 7h5v5"/><path d="M3 21h18"/>';
  static const esq = '<path d="M15 6l-6 6 6 6"/>';
  static const dir = '<path d="M9 6l6 6-6 6"/>';
  static const baixo = '<path d="M6 9l6 6 6-6"/>';
  static const olho = '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>';
  static const olhoFechado = '<path d="M3 3l18 18"/><path d="M10.6 5.1A10 10 0 0 1 12 5c6 0 10 7 10 7a17 17 0 0 1-3.2 3.9M6.6 6.6C3.9 8.4 2 12 2 12s4 7 10 7c1.7 0 3.2-.5 4.5-1.2"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>';
  static const entrou = '<path d="M17 7 7 17M7 9v8h8"/>';
  static const saiu = '<path d="M7 17 17 7M9 7h8v8"/>';
  static const mais = '<path d="M12 5v14M5 12h14"/>';
  static const cima = '<path d="M12 19V5M5 12l7-7 7 7"/>';
  static const desce = '<path d="M12 5v14M5 12l7 7 7-7"/>';
  static const cartao = '<rect x="2" y="5" width="20" height="14" rx="3"/><path d="M2 10h20M6 15h4"/>';
  static const importar = '<path d="M12 3v12M7 10l5 5 5-5M4 15v4a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-4"/>';
  static const buscar = '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>';
  static const ajustes = '<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/>';
  static const pizza = '<path d="M21 12a9 9 0 1 1-9-9v9z"/>';
  static const lixo = '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>';
  static const etiqueta = '<path d="M20 12l-8 8-9-9V3h8z"/><circle cx="7.5" cy="7.5" r="1.5"/>';
  static const lampada = '<path d="M9 18h6M10 22h4"/><path d="M12 2a7 7 0 0 0-4 12.7c.6.5 1 1.3 1 2.1V17h6v-.2c0-.8.4-1.6 1-2.1A7 7 0 0 0 12 2z"/>';
  static const certo = '<path d="M5 12l5 5L20 7"/>';
  static const cat = <String, String>{
  'g:moradia': r'''<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9v11h14V9"/>''',
  'g:contas': r'''<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>''',
  'g:mercado': r'''<circle cx="9" cy="20" r="1.5"/><circle cx="18" cy="20" r="1.5"/><path d="M2 3h3l2.6 12.4a2 2 0 0 0 2 1.6h7.7a2 2 0 0 0 2-1.6L21 7H6"/>''',
  'g:alimentacao': r'''<path d="M7 2v8a3 3 0 0 0 6 0V2M10 2v20M17 2c-1.7 1.3-3 3.6-3 7v4h3v9"/>''',
  'g:transporte': r'''<path d="M5 17h14v-5l-2-6H7l-2 6z"/><circle cx="8" cy="17" r="2"/><circle cx="16" cy="17" r="2"/>''',
  'g:saude': r'''<path d="M12 21s-8-5.2-8-11a4.5 4.5 0 0 1 8-2.8A4.5 4.5 0 0 1 20 10c0 5.8-8 11-8 11z"/>''',
  'g:educacao': r'''<path d="M2 8l10-5 10 5-10 5z"/><path d="M6 10v5c3 2.5 9 2.5 12 0v-5"/>''',
  'g:lazer': r'''<circle cx="12" cy="12" r="9"/><path d="M8.5 14.5a4.5 4.5 0 0 0 7 0M9 9.5h.01M15 9.5h.01"/>''',
  'g:compras': r'''<path d="M6 7h12l-1 14H7z"/><path d="M9 7a3 3 0 0 1 6 0"/>''',
  'g:internet': r'''<path d="M2 9a15 15 0 0 1 20 0M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0"/><path d="M12 19.5h.01"/>''',
  'g:recarga': r'''<rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/>''',
  'g:assinaturas': r'''<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M10 9l5 3-5 3z"/>''',
  'g:pets': r'''<circle cx="5" cy="10" r="2"/><circle cx="9" cy="5" r="2"/><circle cx="15" cy="5" r="2"/><circle cx="19" cy="10" r="2"/><path d="M12 12c-3 0-6 3.5-6 6.5 0 1.5 1.3 2.5 3 2l3-1 3 1c1.7.5 3-.5 3-2 0-3-3-6.5-6-6.5z"/>''',
  'g:cuidados': r'''<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>''',
  'g:impostos': r'''<path d="M3 21h18M5 21V10M19 21V10M9 21V10M15 21V10M2 10l10-7 10 7z"/>''',
  'g:cartao': r'''<rect x="2" y="5" width="20" height="14" rx="3"/><path d="M2 10h20"/>''',
  'g:transferencias': r'''<path d="M7 7h13l-3-3M17 17H4l3 3"/>''',
  'g:outros': r'''<circle cx="6" cy="12" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="18" cy="12" r="1.5"/>''',
  'e:salario': r'''<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>''',
  'e:beneficios': r'''<path d="M7 2v8a3 3 0 0 0 6 0V2M10 2v20M17 2c-1.7 1.3-3 3.6-3 7v4h3v9"/>''',
  'e:emprestimo': r'''<path d="M7 12l3 3 7-7"/><circle cx="12" cy="12" r="9"/>''',
  'e:proprias': r'''<path d="M7 7h13l-3-3M17 17H4l3 3"/>''',
  'e:pix': r'''<path d="M17 7 7 17M7 9v8h8"/>''',
  'e:reembolso': r'''<path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-2"/>''',
  'e:rendimentos': r'''<path d="M3 17l5-5 4 3 8-8"/><path d="M15 7h5v5"/>''',
  'e:vendas': r'''<path d="M20 12l-8 8-9-9V3h8z"/><circle cx="7.5" cy="7.5" r="1.5"/>''',
  'e:outros_e': r'''<path d="M12 5v14M5 12h14"/>''',
  };
  static String deCategoria(Categoria c, {bool entrada = false}) => cat['${entrada ? 'e' : 'g'}:${c.id}'] ?? cat['g:${c.id}'] ?? cat['e:${c.id}'] ?? cat['g:outros']!;
}

/// Desenha um ícone do site. [traco] é a espessura do traço (o site usa 2 ou 2,2).
class IconeSite extends StatelessWidget {
  final String d;
  final double tam;
  final Color? cor;
  final double traco;
  const IconeSite(this.d, {super.key, this.tam = 16, this.cor, this.traco = 2.2});
  @override
  Widget build(BuildContext context) {
    final c = cor ?? IconTheme.of(context).color ?? S.ink;
    final hex = '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final op = c.a;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-opacity="$op" stroke-width="$traco" stroke-linecap="round" stroke-linejoin="round">$d</svg>',
      width: tam,
      height: tam,
    );
  }
}

/// .card do site: branco, borda fina, cantos de 18 e sombra bem leve.
class CartaoSite extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? cor;
  const CartaoSite({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.cor});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(18);
    return Container(
      decoration: BoxDecoration(
        color: cor ?? S.c('card'),
        borderRadius: r,
        border: Border.all(color: S.bordaCartao),
        boxShadow: S.escuro ? null : S.sombraCartao,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: r, onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// .card-h: título (Bricolage 16,5) com subtítulo e um botão pequeno à direita.
class CabecalhoSite extends StatelessWidget {
  final String titulo;
  final String? sub;
  final String? acao;
  final VoidCallback? onAcao;
  final bool seta;
  const CabecalhoSite(this.titulo, {super.key, this.sub, this.acao, this.onAcao, this.seta = true});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: TextStyle(fontFamily: S.fonteNum, fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -.08, color: S.ink, height: 1.5)),
              if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: TextStyle(fontSize: 12.5, color: S.muted, height: 1.5))),
            ]),
          ),
          if (acao != null) ...[const SizedBox(width: 12), BotaoSm(acao!, onTap: onAcao, seta: seta)],
        ]),
      );
}

/// .btn.sm: botão pequeno com borda e cantos de 8.
class BotaoSm extends StatelessWidget {
  final String texto;
  final VoidCallback? onTap;
  final bool seta, primario;
  const BotaoSm(this.texto, {super.key, this.onTap, this.seta = true, this.primario = false});
  @override
  Widget build(BuildContext context) => Material(
        color: primario ? S.cta : S.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: primario ? S.cta : S.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(texto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primario ? S.ctaInk : S.ink)),
              if (seta) ...[const SizedBox(width: 6), IconeSite(Ico.dir, tam: 13, cor: primario ? S.ctaInk : S.ink)],
            ]),
          ),
        ),
      );
}

/// Ícone de categoria: desenho cheio na cor da categoria, sobre um quadrado
/// de cantos arredondados com a mesma cor bem clarinha (no escuro, um pouco
/// mais forte e o ícone mais claro, para não sumir).
class IconeCatSite extends StatelessWidget {
  final Categoria cat;
  final bool entrada;
  final double tam;
  const IconeCatSite(this.cat, {super.key, this.entrada = false, this.tam = 40});
  @override
  Widget build(BuildContext context) {
    final esc = S.escuro;
    final cor = esc ? Color.lerp(cat.cor, Colors.white, .28)! : cat.cor;
    return Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(color: cat.cor.withValues(alpha: esc ? .24 : .14), borderRadius: BorderRadius.circular(tam * .3)),
      alignment: Alignment.center,
      child: Icon(cat.icone, size: tam * .52, color: cor),
    );
  }
}

/// Linha de lançamento do site (.tx): ícone, título, "categoria · forma" e valor.
class LinhaTxSite extends StatelessWidget {
  final Categoria cat;
  final bool entrada;
  final String titulo, sub, valor;
  final Color? corValor, corSub;
  final VoidCallback? onTap;
  /// Precisa ser conferido: o ícone balança e ganha um ponto de aviso.
  final bool conferir;
  const LinhaTxSite({super.key, required this.cat, this.entrada = false, required this.titulo, required this.sub, required this.valor, this.corValor, this.corSub, this.onTap, this.conferir = false});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(children: [
            conferir
                ? Balanca(
                    child: Stack(clipBehavior: Clip.none, children: [
                      IconeCatSite(cat, entrada: entrada),
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(width: 12, height: 12, decoration: BoxDecoration(color: S.neg, shape: BoxShape.circle, border: Border.all(color: S.c('card'), width: 2))),
                      ),
                    ]),
                  )
                : IconeCatSite(cat, entrada: entrada),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: S.ink, height: 1.5)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: corSub ?? S.muted, height: 1.5, fontWeight: conferir ? FontWeight.w600 : null)),
              ]),
            ),
            const SizedBox(width: 11),
            Text(valor, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: corValor ?? S.ink, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
      );
}

/// .tx-l: caixa com as linhas e separadores que começam depois do ícone.
class ListaTxSite extends StatelessWidget {
  final List<Widget> linhas;
  const ListaTxSite(this.linhas, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: S.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: S.bordaCartao),
          boxShadow: S.escuro ? null : [BoxShadow(color: S.ink.withValues(alpha: .04), blurRadius: 2, offset: const Offset(0, 1)), BoxShadow(color: S.ink.withValues(alpha: .12), blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -12)],
        ),
        child: Column(children: [
          for (var i = 0; i < linhas.length; i++) ...[
            if (i > 0) Padding(padding: const EdgeInsets.only(left: 61, right: 10), child: Divider(height: 1.5, thickness: 1.5, color: Color.lerp(S.line, S.muted, .25))),
            linhas[i],
          ],
        ]),
      );
}

/// Cor "#rrggbb" guardada nos dados do site (cartões, por exemplo).
Color? corDeTexto(Object? v) {
  if (v is! String) return null;
  final h = v.replaceAll('#', '');
  if (h.length != 6) return null;
  final n = int.tryParse(h, radix: 16);
  return n == null ? null : Color(0xFF000000 | n);
}

/// .btn.primary: botão cheio na cor principal, cantos de 8 (largura toda).
class BotaoSite extends StatelessWidget {
  final String texto;
  final String? icone;
  final VoidCallback? onTap;
  final bool primario;
  const BotaoSite(this.texto, {super.key, this.icone, this.onTap, this.primario = true});
  @override
  Widget build(BuildContext context) => Material(
        color: primario ? S.cta : S.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: primario ? S.cta : S.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icone != null) ...[IconeSite(icone!, tam: 16, cor: primario ? S.ctaInk : S.ink), const SizedBox(width: 6)],
              Text(texto, style: TextStyle(fontWeight: FontWeight.w700, color: primario ? S.ctaInk : S.ink)),
            ]),
          ),
        ),
      );
}

/// .pl-l: atalho em cartão com ícone num quadrado azul-claro.
class LinkSite extends StatelessWidget {
  final String icone, titulo, sub;
  final VoidCallback onTap;
  final double? progresso;
  const LinkSite({super.key, required this.icone, required this.titulo, required this.sub, required this.onTap, this.progresso});
  @override
  Widget build(BuildContext context) => Material(
        color: S.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: S.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: S.accentSoft, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: IconeSite(icone, tam: 19, cor: S.accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: S.ink, height: 1.5)),
                  const SizedBox(height: 2),
                  Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: S.muted, height: 1.5)),
                  if (progresso != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: progresso!.clamp(0, 1).toDouble(), minHeight: 5, color: progresso! >= 1 ? S.pos : S.accent, backgroundColor: S.surface2),
                    ),
                  ],
                ]),
              ),
              IconeSite(Ico.dir, tam: 16, cor: S.muted),
            ]),
          ),
        ),
      );
}
