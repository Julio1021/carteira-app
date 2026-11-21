import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/avisos.dart';
import '../dados/conferir.dart';
import '../dados/modelos.dart';
import '../dados/patrimonio.dart';
import '../dados/planejar.dart';
import '../dados/repo.dart';
import '../util/fmt.dart';
import '../widgets/animado.dart';
import '../widgets/comum.dart';
import '../widgets/formulario.dart';
import '../widgets/largo.dart';
import '../widgets/site.dart';
import 'classificar.dart';
import 'contas.dart' show FolhaPagar;
import 'lancar.dart';
import 'lancar_valores.dart';
import 'limites.dart';
import 'planejar.dart' show confirmarRecebido;

/// Abre a lista "Para conferir".
Future<void> abrirConferir(BuildContext context, {void Function(String cat)? verCategoria}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaConferir(verCategoria: verCategoria)));

/// Tudo que pede uma ação sua, num lugar só: resolva um por um até zerar.
class TelaConferir extends StatelessWidget {
  final void Function(String cat)? verCategoria;
  const TelaConferir({super.key, this.verCategoria});

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ps = pendencias(repo);
    final grupos = <String, List<Pendencia>>{};
    for (final p in ps) {
      (grupos[p.tipo] ??= []).add(p);
    }
    final n = ps.where((p) => p.tipo != 'aviso').length;
    final lista = ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
      children: [
        Text(
          n == 0 ? 'Nada pendente. Tudo em dia.' : (n == 1 ? '1 coisa pede sua atenção.' : '$n coisas pedem sua atenção.'),
          style: TextStyle(fontSize: 14, color: S.ink2, height: 1.4),
        ),
        if (ps.isEmpty) ...[
          const SizedBox(height: 40),
          Icon(Icons.task_alt_rounded, size: 64, color: S.pos),
          const SizedBox(height: 12),
          Text('Tudo conferido', textAlign: TextAlign.center, style: TextStyle(fontFamily: S.fonteNum, fontSize: 20, fontWeight: FontWeight.w700, color: S.ink)),
          const SizedBox(height: 4),
          Text('Quando importar o extrato ou chegar uma data, o que precisar de você aparece aqui.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: S.muted, height: 1.4)),
        ],
        for (final g in gruposConferir.keys)
          if (grupos[g] case final itens?) ...[
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Text(gruposConferir[g]!, style: TextStyle(fontFamily: S.fonteNum, fontSize: 16, fontWeight: FontWeight.w700, color: S.ink))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: S.surface2, borderRadius: BorderRadius.circular(99)),
                child: Text('${itens.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: S.ink2)),
              ),
            ]),
            const SizedBox(height: 8),
            for (final p in itens) ...[
              _Item(p: p, verCategoria: verCategoria),
              const SizedBox(height: 8),
            ],
          ],
      ],
    );
    return Scaffold(
      backgroundColor: S.bg,
      appBar: AppBar(backgroundColor: S.bg, surfaceTintColor: Colors.transparent, title: const Text('Para conferir')),
      body: telaLarga(context) ? Centralizar(max: 760, child: lista) : lista,
    );
  }
}

class _Item extends StatelessWidget {
  final Pendencia p;
  final void Function(String cat)? verCategoria;
  const _Item({required this.p, this.verCategoria});

  Color get _cor => switch (p.sev) { 3 => S.neg, 2 => S.second, 0 => S.pos, _ => S.accent };

  IconData get _icone => switch (p.tipo) {
        'transf' => Icons.sync_alt_rounded,
        'receber' => Icons.south_west_rounded,
        'conta' => Icons.receipt_long_rounded,
        'semcat' => Icons.label_outline_rounded,
        'rend' => Icons.show_chart_rounded,
        'fixos' => Icons.event_repeat_rounded,
        _ => Icons.info_outline_rounded,
      };

  /// Botão principal: resolve a pendência.
  (String, VoidCallback) _acao(BuildContext context, Repo repo) => switch (p.tipo) {
        'transf' => ('Conferir', () => abrirClassificar(context, p.obj as Entrada)),
        'receber' => (
            'Já entrou',
            () {
              final x = p.obj as ({Renda r, StatusRenda st});
              confirmarRecebido(context, x.r, x.st.data, valorEsperado(repo, x.r));
            }
          ),
        'conta' => ('Pagar', () => abrirFolha(context, FolhaPagar(p.obj as InstConta))),
        'semcat' => ('Escolher categoria', () => abrirFormLanc(context, doc: (p.obj as Gasto).d)),
        'rend' => (
            'Corrigir este dia',
            () => abrirLancarValores(context, data: (p.obj as ({Lancamento l, Ativo a, double rend, double pc})).l.data),
          ),
        'fixos' => (
            'Lançar fixos',
            () async {
              final docs = docsLancarFixos(repo, ymDe(hojeIso()));
              await repo.salvarVarios(docs);
              if (context.mounted) avisar(context, '${docs.length} gasto${docs.length == 1 ? '' : 's'} fixo${docs.length == 1 ? '' : 's'} lançado${docs.length == 1 ? '' : 's'}.');
            }
          ),
        _ => (
            (p.obj as Aviso).cat != null ? 'Ver gastos' : 'Ver limites',
            () async {
              final a = p.obj as Aviso;
              if (a.cat != null && verCategoria != null) {
                Navigator.pop(context);
                verCategoria!(a.cat!);
              } else {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaLimites(ym: ymDe(hojeIso()))));
              }
            }
          ),
      };

  String get _ignorar => switch (p.tipo) {
        'receber' => 'Não veio',
        'semcat' => 'Fica em Outros',
        'rend' => 'Está certo',
        _ => 'Dispensar',
      };

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final (rotulo, fazer) = _acao(context, repo);
    Widget icone = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: _cor.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Icon(_icone, size: 21, color: _cor),
    );
    if (p.tipo == 'transf') icone = Balanca(child: icone);
    return CartaoSite(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          icone,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.titulo, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: S.ink, height: 1.3)),
              const SizedBox(height: 2),
              Text(p.sub, style: TextStyle(fontSize: 12.5, color: S.ink2, height: 1.4)),
            ]),
          ),
          if (p.valor != null) ...[
            const SizedBox(width: 8),
            Text(brl(p.valor!), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: S.ink)),
          ],
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8), minimumSize: const Size(40, 40)),
              onPressed: () {
                HapticFeedback.selectionClick();
                fazer();
              },
              child: Text(rotulo, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          if (p.podeIgnorar) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8), minimumSize: const Size(40, 40)),
                onPressed: () => ignorarPendencia(repo, p),
                child: Text(_ignorar, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// Cartão do Início: quantas coisas para conferir e as primeiras delas.
/// Quando chegou dinheiro de outra conta sua, o ícone balança e o celular
/// vibra uma vez ao aparecer.
class ConferirSite extends StatelessWidget {
  final void Function(String cat)? verCategoria;
  const ConferirSite({super.key, this.verCategoria});
  static bool _vibrou = false;

  @override
  Widget build(BuildContext context) {
    final ps = pendencias(RepoScope.of(context)).where((p) => p.tipo != 'aviso').toList();
    if (ps.isEmpty) return const SizedBox.shrink();
    final transf = ps.any((p) => p.tipo == 'transf');
    final urgente = ps.any((p) => p.sev >= 3);
    if (transf && !_vibrou && animacoesLigadas(context)) {
      _vibrou = true;
      HapticFeedback.heavyImpact();
    }
    final cor = urgente ? S.neg : S.accent;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CartaoSite(
        onTap: () => abrirConferir(context, verCategoria: verCategoria),
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Balanca(
            ligado: transf,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: Text('${ps.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ps.length == 1 ? '1 coisa para conferir' : '${ps.length} coisas para conferir', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: S.ink, height: 1.3)),
              const SizedBox(height: 4),
              for (final p in ps.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 6), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: S.muted, shape: BoxShape.circle))),
                    const SizedBox(width: 7),
                    Expanded(child: Text(p.titulo, style: TextStyle(fontSize: 12.5, color: S.ink2, height: 1.4))),
                  ]),
                ),
              if (ps.length > 3) Padding(padding: const EdgeInsets.only(top: 2), child: Text('e mais ${ps.length - 3}', style: TextStyle(fontSize: 12.5, color: S.muted))),
            ]),
          ),
          const SizedBox(width: 6),
          Padding(padding: const EdgeInsets.only(top: 12), child: IconeSite(Ico.dir, tam: 16, cor: S.muted)),
        ]),
      ),
    );
  }
}
