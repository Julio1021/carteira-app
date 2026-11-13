import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/planejar.dart';
import '../widgets/formulario.dart';
import 'contas.dart';
import 'importar.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';
import '../widgets/largo.dart';
import '../widgets/painel.dart';
import 'descobertas.dart';
import 'lancar.dart';

class TelaInicio extends StatefulWidget {
  final String ym;
  final ValueChanged<String> onMes;
  final VoidCallback irExtrato;
  final VoidCallback irLimites;
  final void Function(String filtro) irExtratoFiltro;
  final VoidCallback irPlanejar;
  const TelaInicio({super.key, required this.ym, required this.onMes, required this.irExtrato, required this.irLimites, required this.irExtratoFiltro, required this.irPlanejar});
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
    final nomes = ['Lançamentos', if (temContas) 'Contas', 'Gastos'];
    final sel = aba.clamp(0, nomes.length - 1);
    final nome = nomes[sel];
    var o = 0;
    final boasVindas = repo.vazio ? Surge(ordem: o++, child: _BoasVindas()) : null;
    final hero = Surge(ordem: o++, child: HeroMes(r: r, onMes: w.onMes, onEntrou: () => w.irExtratoFiltro('entradas'), onSaiu: () => w.irExtratoFiltro('saidas'), onLimite: w.irLimites));
    final numeros = Surge(ordem: o++, child: _Numeros(r: r, onInvestiu: () => r.investimentos.isEmpty ? abrirFormLanc(context, investido: true) : w.irExtratoFiltro('investido'), onLimite: w.irLimites));
    final atalhos = Surge(ordem: o++, child: _Atalhos(irExtrato: w.irExtrato, irLimites: w.irLimites));
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
            'Gastos' => _OndeFoi(r: r, irLimites: w.irLimites),
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
          const SizedBox(height: 10),
          numeros,
          const SizedBox(height: 16),
          atalhos,
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

/// Dois quadradinhos abaixo do cartão principal: investiu e quanto dá por dia.
class _Numeros extends StatelessWidget {
  final ResumoMes r;
  final VoidCallback onInvestiu, onLimite;
  const _Numeros({required this.r, required this.onInvestiu, required this.onLimite});
  @override
  Widget build(BuildContext context) {
    final hoje = hojeIso();
    final mesAtual = ymDe(hoje) == r.ym;
    final pct = r.pctInvestido;
    final resgatou = r.investiu < 0;
    final inv = Kpi(
      icone: Icons.savings_rounded,
      rotulo: resgatou ? 'Resgatou' : 'Investiu',
      valor: r.investiu.abs(),
      formato: brl,
      sub: r.investimentos.isEmpty ? 'toque para registrar' : (pct != null && !resgatou ? '${(pct * 100).round()}% da renda' : 'no mês'),
      cor: G.lavanda,
      onTap: onInvestiu,
    );
    Kpi segundo;
    if (r.limiteTotal > 0 && mesAtual) {
      final restante = r.limiteTotal - r.gastoComLimite;
      final dias = diasNoMes(r.ym) - int.parse(hoje.substring(8, 10)) + 1;
      segundo = restante <= 0
          ? Kpi(icone: Icons.block_rounded, rotulo: 'Pode gastar/dia', texto: 'R\$ 0', sub: 'limite já usado', cor: G.neg, onTap: onLimite)
          : Kpi(icone: Icons.today_rounded, rotulo: 'Pode gastar/dia', valor: restante / dias, formato: brl, sub: '$dias dia${dias == 1 ? '' : 's'} até o fim', cor: G.pos, onTap: onLimite);
    } else {
      segundo = Kpi(icone: Icons.account_balance_wallet_outlined, rotulo: 'Sobra do mês', valor: r.sobra, formato: brl, sub: 'entrou − saiu', cor: r.sobra < 0 ? G.neg : G.pos);
    }
    return GradeKpi([inv, segundo]);
  }
}

/// Cartão principal: mês, saldo em conta, entrou/saiu e limite.
class HeroMes extends StatelessWidget {
  final ResumoMes r;
  final ValueChanged<String> onMes;
  final VoidCallback onEntrou, onSaiu, onLimite;
  final VoidCallback? onInvestiu;
  const HeroMes({super.key, required this.r, required this.onMes, required this.onEntrou, required this.onSaiu, this.onInvestiu, required this.onLimite});

  @override
  Widget build(BuildContext context) {
    final uso = r.usoLimite;
    final corLim = uso == null ? GE.branco : (uso > 1 ? GE.neg : (uso > .85 ? GH.alerta : GE.branco));
    final principal = r.emConta;
    return Escuro(child: Container(
      decoration: BoxDecoration(
        gradient: GH.gradHero,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x17FFFFFF)),
        boxShadow: [BoxShadow(color: GH.sombra, blurRadius: 50, offset: Offset(0, 28), spreadRadius: -30)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: GH.safira ? const Aurora() : const Aurora(a: Color(0x1FFFFFFF), b: Color(0x24B9BFF6))))),
        Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(children: [
        SeletorMes(ym: r.ym, onMudar: onMes, escuro: true),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (atual, antigos) => Stack(alignment: Alignment.topCenter, children: [...antigos, if (atual != null) atual]),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(a), child: child),
          ),
          child: KeyedSubtree(key: ValueKey(r.ym), child: _corpo(context, principal, uso, corLim)),
        ),
      ]),
        ),
      ]),
    ));
  }

  Widget _corpo(BuildContext context, double? principal, double? uso, Color corLim) {
    return Column(children: [
        const SizedBox(height: 14),
        Text(principal != null ? 'Em conta' : 'Sobra do mês', style: TextStyle(color: GH.texto2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        FittedBox(
          child: ValorAnimado(principal ?? r.sobra, estilo: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: Colors.white)),
        ),
        if (principal != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Sobra do mês: ${brl(r.sobra)}', style: TextStyle(color: GH.texto2, fontSize: 13)),
          ),
        Builder(builder: (context) {
          final pts = sobraDiaADia(r);
          if (pts.length < 3) return const SizedBox(height: 16);
          return Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 10, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              LinhaMes(pts),
              const SizedBox(height: 2),
              Row(children: [
                Text('dia 1', style: TextStyle(color: GH.apagado, fontSize: 10.5)),
                Expanded(child: Text('sobra do mês, dia a dia', textAlign: TextAlign.center, style: TextStyle(color: GH.apagado, fontSize: 10.5))),
                Text(ymDe(hojeIso()) == r.ym ? 'hoje' : 'dia ${pts.length}', style: TextStyle(color: GH.apagado, fontSize: 10.5)),
              ]),
            ]),
          );
        }),
        Row(children: [
          Expanded(child: _Bloco(rotulo: 'Entrou', valor: r.entrou, claro: true, icone: Icons.south_west_rounded, corIcone: GH.posIcone, onTap: onEntrou)),
          const SizedBox(width: 10),
          Expanded(child: _Bloco(rotulo: 'Saiu', valor: r.saiu, claro: false, icone: Icons.north_east_rounded, corIcone: GH.negIcone, onTap: onSaiu)),
        ]),
        if (r.limiteTotal > 0) ...[
          const SizedBox(height: 16),
          InkWell(
            onTap: onLimite,
            borderRadius: BorderRadius.circular(10),
            child: Column(children: [
              Row(children: [
                Text('Limite de gastos', style: TextStyle(color: GH.texto2, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: brl(r.gastoComLimite), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      TextSpan(text: ' de ${brl(r.limiteTotal)}', style: TextStyle(color: GH.texto2, fontSize: 12)),
                    ]),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Barra(uso ?? 0, cor: corLim, trilho: const Color(0x1FFFFFFF)),
            ]),
          ),
        ],
      ]);
  }
}

class _Bloco extends StatelessWidget {
  final String rotulo;
  final double valor;
  final bool claro;
  final IconData icone;
  final Color corIcone;
  final VoidCallback onTap;
  const _Bloco({required this.rotulo, required this.valor, required this.claro, required this.icone, required this.corIcone, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(20);
    return Toque(child: DecoratedBox(
      decoration: BoxDecoration(
        color: GH.vidro ? GH.vidroFundo : (claro ? GE.branco : null),
        gradient: GH.vidro || claro ? null : GE.gradLavanda,
        borderRadius: r,
        border: GH.vidro ? Border.all(color: GH.vidroBorda) : null,
        boxShadow: GH.vidro ? null : const [BoxShadow(color: Color(0xE6000000), blurRadius: 26, offset: Offset(0, 14), spreadRadius: -18)],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: GH.vidro ? Colors.white : const Color(0x1612131C), borderRadius: BorderRadius.circular(12)),
                child: Icon(icone, size: 18, color: corIcone),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rotulo, style: TextStyle(color: GH.vidro ? GH.texto2 : const Color(0x9E12131C), fontWeight: FontWeight.w600, fontSize: 12.5)),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: ValorAnimado(valor, estilo: TextStyle(color: GH.vidro ? Colors.white : GE.tinta, fontWeight: FontWeight.w800, fontSize: 16))),
                ]),
              ),
            ]),
          ),
        ),
      ),
    ));
  }
}

class _Atalhos extends StatelessWidget {
  final VoidCallback irExtrato, irLimites;
  const _Atalhos({required this.irExtrato, required this.irLimites});
  @override
  Widget build(BuildContext context) {
    Widget at(IconData i, String t, VoidCallback f, {bool destaque = false, Color? cor}) => Expanded(
          child: Column(children: [
            Toque(
              escala: .9,
              child: Material(
                color: destaque ? G.branco : (cor != null ? cor.withValues(alpha: G.claro ? .10 : .14) : G.v(0x10)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: destaque ? G.branco : (cor != null ? cor.withValues(alpha: .22) : G.borda))),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: f,
                  child: SizedBox(width: 46, height: 46, child: Icon(i, color: destaque ? G.tinta : (cor ?? G.texto), size: 20)),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: G.texto2)),
          ]),
        );
    return Row(children: [
      at(Icons.remove_rounded, 'Gasto', () => abrirFormLanc(context), destaque: true),
      at(Icons.add_rounded, 'Entrada', () => abrirFormLanc(context, entrada: true), cor: G.pos),
      at(Icons.savings_outlined, 'Investir', () => abrirFormLanc(context, investido: true), cor: G.lavanda),
      at(Icons.file_download_outlined, 'Importar', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaImportarExtrato()))),
    ]);
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


