import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/planejar.dart';
import '../widgets/formulario.dart';
import 'contas.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';
import '../widgets/largo.dart';
import '../widgets/painel.dart';
import 'descobertas.dart';
import 'inicio_nuvem.dart';
import 'lancar.dart';

class TelaInicio extends StatefulWidget {
  final String ym;
  final ValueChanged<String> onMes;
  final VoidCallback irExtrato;
  final VoidCallback irLimites;
  final void Function(String filtro) irExtratoFiltro;
  final VoidCallback irPlanejar;
  final ValueChanged<String>? irCategoria;
  final VoidCallback? irPatrimonio;
  const TelaInicio({super.key, required this.ym, required this.onMes, required this.irExtrato, required this.irLimites, required this.irExtratoFiltro, required this.irPlanejar, this.irCategoria, this.irPatrimonio});
  @override
  State<TelaInicio> createState() => _TelaInicioState();
}

class _TelaInicioState extends State<TelaInicio> {
  int aba = 0;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final repo = RepoScope.of(context);
    final r = ResumoMes.de(repo, w.ym);
    final temContas = repo.doTipo('pagar').isNotEmpty;
    final contas = temContas ? mesContas(repo, ymDe(hojeIso())) : null;
    final atrasadas = contas?.abertas.where((i) => i.st == 'atrasada').length ?? 0;
    // os gastos por categoria já aparecem nos círculos
    final nomes = ['Lançamentos', if (temContas) 'Contas'];
    final sel = aba.clamp(0, nomes.length - 1);
    final nome = nomes[sel];
    var o = 0;
    final boasVindas = repo.vazio ? Surge(ordem: o++, child: _BoasVindas()) : null;
    void investiu() => r.investimentos.isEmpty ? abrirFormLanc(context, investido: true) : w.irExtratoFiltro('investido');
    final hero = Surge(
      ordem: o++,
      child: HeroNuvem(r: r, onMes: w.onMes, onEntrou: () => w.irExtratoFiltro('entradas'), onSaiu: () => w.irExtratoFiltro('saidas')),
    );
    final numeros = Surge(
      ordem: o++,
      child: QuadrosNuvem(r: r, onLimite: w.irLimites, onInvestiu: investiu, onInvestido: w.irPatrimonio ?? investiu),
    );
    final historias = Surge(ordem: o++, child: HistoriasGastos(r: r, onCategoria: (c) => w.irCategoria != null ? w.irCategoria!(c) : w.irExtratoFiltro('saidas'), onAnalise: () => w.irExtratoFiltro('saidas')));
    final descobertas = Surge(ordem: o++, child: FaixaDescobertas(ym: w.ym));
    final abas = Surge(
      ordem: o++,
      child: Segmentos(
        nomes: [for (final n in nomes) n == 'Contas' && (contas?.abertas.isNotEmpty ?? false) ? 'Contas ${contas!.abertas.length}' : n],
        marcas: [for (final n in nomes) n == 'Contas' && atrasadas > 0 ? '!' : null],
        sel: sel,
        onSel: (i) => setState(() => aba = i),
      ),
    );
    final conteudo = Surge(
      ordem: o++,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: semAnimacao(context) ? 0 : 240),
        layoutBuilder: (atual, antigos) => Stack(alignment: Alignment.topCenter, children: [...antigos, if (atual != null) atual]),
        child: KeyedSubtree(
          key: ValueKey(nome),
          child: switch (nome) {
            'Contas' => _ContasInicio(irPlanejar: w.irPlanejar),
            _ => _Ultimos(r: r, irExtrato: w.irExtrato, quantos: telaLarga(context) ? 10 : 5),
          },
        ),
      ),
    );
    return LayoutBuilder(builder: (context, cons) {
      if (cons.maxWidth >= 860) {
        // computador: à esquerda o mês (cartão, números, contas e gastos), à
        // direita os lançamentos. Os atalhos saem: o menu já tem "Novo lançamento".
        return ListView(
          padding: const EdgeInsets.fromLTRB(28, 6, 28, 40),
          children: [
            Centralizar(
              max: 1180,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 440,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (boasVindas != null) ...[boasVindas, const SizedBox(height: 16)],
                    hero,
                    const SizedBox(height: 10),
                    numeros,
                    const SizedBox(height: 18),
                    historias,
                    const SizedBox(height: 14),
                    descobertas,
                    if (temContas) ...[const SizedBox(height: 16), Surge(ordem: 3, child: _ContasInicio(irPlanejar: w.irPlanejar))],
                    const SizedBox(height: 16),
                    Surge(ordem: 4, child: _OndeFoi(r: r, irLimites: w.irLimites)),
                  ]),
                ),
                const SizedBox(width: 24),
                Expanded(child: Surge(ordem: 2, child: _Ultimos(r: r, irExtrato: w.irExtrato, quantos: 14))),
              ]),
            ),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
        children: [
          if (boasVindas != null) ...[boasVindas, const SizedBox(height: 16)],
          hero,
          const SizedBox(height: 12),
          numeros,
          const SizedBox(height: 20),
          historias,
          const SizedBox(height: 14),
          descobertas,
          const SizedBox(height: 16),
          abas,
          const SizedBox(height: 10),
          conteudo,
        ],
      );
    });
  }
}

class _Ultimos extends StatelessWidget {
  final ResumoMes r;
  final VoidCallback irExtrato;
  final int quantos;
  const _Ultimos({required this.r, required this.irExtrato, this.quantos = 5});
  @override
  Widget build(BuildContext context) {
    final ult = r.lancamentos.take(quantos).toList();
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoCartao('Últimos lançamentos', sub: mesLongo(r.ym), acao: 'Ver extrato', onAcao: irExtrato),
        if (ult.isEmpty)
          Vazio(icone: Icons.receipt_long_rounded, titulo: 'Nada lançado neste mês', texto: 'Comece pelo primeiro gasto ou entrada.', acao: 'Lançar gasto', onAcao: () => abrirFormLanc(context))
        else
          CaixaLista([for (final l in ult) LinhaLanc(l, onTap: () => abrirFormLanc(context, doc: l.doc))]),
      ]),
    );
  }
}

/// Para onde foi o dinheiro: as categorias que mais pesaram no mês.
class _OndeFoi extends StatelessWidget {
  final ResumoMes r;
  final VoidCallback irLimites;
  const _OndeFoi({required this.r, required this.irLimites});
  @override
  Widget build(BuildContext context) {
    final itens = r.porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = itens.take(4).toList();
    final maior = top.isEmpty ? 1.0 : top.first.value;
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoCartao('Para onde foi o dinheiro', sub: '${itens.length} categoria${itens.length == 1 ? '' : 's'} no mês', acao: 'Limites', onAcao: irLimites),
        if (itens.isEmpty) Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Nenhum gasto neste mês.', style: TextStyle(color: G.apagado))),
        for (final e in top)
          Builder(builder: (_) {
            final cat = catGasto(e.key);
            final lim = r.limites[e.key];
            final frac = lim != null && lim > 0 ? e.value / lim : e.value / maior;
            final cor = lim != null && lim > 0 && e.value > lim ? G.neg : cat.cor;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                IconeCategoria(cat, tam: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(cat.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(brl(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    Barra(frac, cor: cor, altura: 5),
                    if (lim != null && lim > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          e.value > lim ? 'Passou ${brl(e.value - lim)} do limite de ${brl(lim)}' : 'Restam ${brl(lim - e.value)} de ${brl(lim)}',
                          style: TextStyle(fontSize: 11.5, color: e.value > lim ? G.neg : G.apagado),
                        ),
                      ),
                  ]),
                ),
              ]),
            );
          }),
      ]),
    );
  }
}

class _BoasVindas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Cartao(
      gradiente: LinearGradient(colors: [G.lavandaFundo, G.v(0x08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bem-vindo ao Diário da Carteira', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Traga seus dados do app antigo: lá, toque em Ajustes → Backup → Exportar. Depois, aqui, importe o arquivo.', style: TextStyle(color: G.texto2)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/ajustes'),
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('Importar backup'),
        ),
      ]),
    );
  }
}

/// Contas que vencem: atrasadas num bloco e as três próximas.
class _ContasInicio extends StatelessWidget {
  final VoidCallback irPlanejar;
  const _ContasInicio({required this.irPlanejar});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    if (repo.doTipo('pagar').isEmpty) return const SizedBox.shrink();
    final m = mesContas(repo, ymDe(hojeIso()));
    final ab = m.abertas;
    final atr = ab.where((i) => i.st == 'atrasada').toList();
    final prox = ab.where((i) => i.st != 'atrasada').take(3).toList();
    return Padding(
      padding: EdgeInsets.zero,
      child: Cartao(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CabecalhoCartao('Contas a pagar', sub: ab.isEmpty ? 'Tudo pago este mês' : 'Falta pagar ${brl(m.falta)} este mês', acao: 'Ver contas', onAcao: irPlanejar),
          if (atr.isNotEmpty)
            Material(
              color: G.alerta.withValues(alpha: G.claro ? .10 : .12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: G.alerta.withValues(alpha: .35))),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: irPlanejar,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: G.alerta.withValues(alpha: .22), borderRadius: BorderRadius.circular(11)),
                      child: Icon(Icons.schedule_rounded, color: G.alerta, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${atr.length} conta${atr.length > 1 ? 's' : ''} atrasada${atr.length > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(brl(atr.fold<double>(0, (a, i) => a + i.valor)), style: TextStyle(fontWeight: FontWeight.w700, color: G.negTexto)),
                  ]),
                ),
              ),
            ),
          if (atr.isNotEmpty && prox.isNotEmpty) const SizedBox(height: 10),
          if (prox.isNotEmpty)
            CaixaLista([
              for (final i in prox)
                InkWell(
                  onTap: () => abrirFolha(context, FolhaPagar(i)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      CaixaData(i.venc, destaque: i.st == 'hoje'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.b.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(i.statusTexto, style: TextStyle(fontSize: 12.5, color: i.st == 'hoje' ? G.alerta : G.apagado)),
                        ]),
                      ),
                      Text(brl(i.valor), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ]),
        ]),
      ),
    );
  }
}


