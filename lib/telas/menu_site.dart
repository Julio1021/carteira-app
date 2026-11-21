// Menu do botão do meio (como o do site): preferências, atalhos e a escolha do tema.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tema.dart';
import '../tema_site.dart';
import '../widgets/comum.dart';
import '../widgets/site.dart';
import '../dados/conferir.dart';
import 'conferir.dart';
import 'busca.dart';
import 'cartoes.dart';
import 'emprestimos.dart';
import 'importar.dart';
import 'limites.dart';
import 'retro.dart';

Future<void> abrirMenuSite(BuildContext context, String ym) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: S.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        maxChildSize: .95,
        builder: (c, sc) => _Menu(ym: ym, sc: sc),
      ),
    );

class _Menu extends StatefulWidget {
  final String ym;
  final ScrollController sc;
  const _Menu({required this.ym, required this.sc});
  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> {
  bool temas = false;
  String get ym => widget.ym;
  ScrollController get sc => widget.sc;

  @override
  Widget build(BuildContext context) {
    void ir(Widget t) {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => t));
    }

    Widget bloco(Widget child) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: S.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: S.line)),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
    Widget link(String d, String t, String sub, VoidCallback onTap) => bloco(
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(children: [
                IconeSite(d, tam: 22, cor: S.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: S.ink)),
                    Text(sub, style: TextStyle(fontSize: 13, color: S.muted)),
                  ]),
                ),
                IconeSite(Ico.dir, tam: 16, cor: S.ink),
              ]),
            ),
          ),
        );
    return ListView(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: privacidade,
          builder: (_, o, __) => bloco(SwitchListTile(
            value: o,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              definirPrivacidade(v);
            },
            title: Text('Esconder valores', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: S.ink)),
            subtitle: Text(o ? 'Os valores aparecem como •••' : 'Para usar o app em público', style: TextStyle(fontSize: 13, color: S.muted)),
          )),
        ),
        Builder(builder: (context) {
          final n = nPendencias(RepoScope.of(context));
          return link(Ico.lampada, 'Para conferir', n == 0 ? 'Nada pendente agora' : '$n coisa${n == 1 ? '' : 's'} pedindo sua atenção', () {
            Navigator.pop(context);
            abrirConferir(context);
          });
        }),
        link(Ico.importar, 'Importar extrato do banco', 'Arquivo OFX ou CSV', () => ir(const TelaImportarExtrato())),
        link(Ico.cartao, 'Cartões de crédito', 'Faturas, limites e compras parceladas', () => ir(const TelaCartoes())),
        link(Ico.buscar, 'Buscar lançamentos', 'Em todos os meses', () => ir(const TelaBusca())),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Mais', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: S.muted)),
        ),
        link(Ico.ajustes, 'Limites de gastos', 'Limite geral e por categoria', () => ir(TelaLimites(ym: ym))),
        link('<path d="M7 12l3 3 7-7"/><circle cx="12" cy="12" r="9"/>', 'Empréstimos', 'Dinheiro que você emprestou e vai receber', () => ir(const TelaEmprestimos())),
        link('<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>', 'Retrospectiva', 'Como foi o mês passado', () {
          Navigator.pop(context);
          abrirRetro(context, mesDaRetro(RepoScope.ler(context), ym));
        }),
        link('<path d="M17.5 19H9a7 7 0 1 1 6.7-9h1.8a4.5 4.5 0 1 1 0 9z"/>', 'Ajustes e Google Drive', 'Nome, tela cheia, backup e sincronização', () {
          Navigator.pop(context);
          Navigator.of(context).pushNamed('/ajustes');
        }),
        ValueListenableBuilder<String>(
          valueListenable: aparencia,
          builder: (_, atual, __) => link(
            '<circle cx="12" cy="12" r="9"/><path d="M12 3a9 9 0 0 0 0 18z"/>',
            'Tema: ${temasSite.where((t) => t.id == atual).firstOrNull?.nome ?? 'padrão'}',
            temas ? 'Escolha abaixo' : '${temasSite.length} temas para escolher',
            () => setState(() => temas = !temas),
          ),
        ),
        if (temas) ValueListenableBuilder<String>(
          valueListenable: aparencia,
          builder: (_, atual, __) => GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [for (final t in temasSite) _CartaoTema(t: t, on: t.id == atual)],
          ),
        ),
      ],
    );
  }
}

class _CartaoTema extends StatelessWidget {
  final TemaSite t;
  final bool on;
  const _CartaoTema({required this.t, required this.on});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          HapticFeedback.selectionClick();
          await definirAparencia(t.id);
        },
        child: Container(
          decoration: BoxDecoration(
            color: t['bg'],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? S.accent : S.line, width: on ? 2 : 1),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // miniatura: o cartão do mês e uma linha
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(colors: [t['cta'], Color.lerp(t['cta'], Colors.black, .35)!]),
                ),
                padding: const EdgeInsets.all(6),
                alignment: Alignment.bottomLeft,
                child: Container(width: 40, height: 6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .85), borderRadius: BorderRadius.circular(3))),
              ),
            ),
            const SizedBox(height: 6),
            Text(t.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t['ink'])),
            Text(t.tipo, style: TextStyle(fontSize: 11, color: t['muted'])),
          ]),
        ),
      );
}
