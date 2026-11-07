import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/planejar.dart';
import '../widgets/formulario.dart';
import 'busca.dart';
import 'contas.dart';
import 'importar.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import 'lancar.dart';

class TelaInicio extends StatelessWidget {
  final String ym;
  final ValueChanged<String> onMes;
  final VoidCallback irExtrato;
  final VoidCallback irLimites;
  final void Function(String filtro) irExtratoFiltro;
  final VoidCallback irPlanejar;
  const TelaInicio({super.key, required this.ym, required this.onMes, required this.irExtrato, required this.irLimites, required this.irExtratoFiltro, required this.irPlanejar});

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final r = ResumoMes.de(repo, ym);
    final ult = r.lancamentos.take(6).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 130),
      children: [
        if (repo.vazio) ...[_BoasVindas(), const SizedBox(height: 14)],
        HeroMes(r: r, onMes: onMes, onEntrou: () => irExtratoFiltro('entradas'), onSaiu: () => irExtratoFiltro('saidas'), onLimite: irLimites),
        const SizedBox(height: 16),
        _Atalhos(irExtrato: irExtrato, irLimites: irLimites),
        const SizedBox(height: 16),
        _ContasInicio(irPlanejar: irPlanejar),
        if (r.porCategoria.isNotEmpty) ...[_OndeFoi(r: r, irLimites: irLimites), const SizedBox(height: 14)],
        Cartao(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CabecalhoCartao('Últimos lançamentos', sub: mesLongo(ym), acao: 'Ver extrato', onAcao: irExtrato),
            if (ult.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Nada lançado neste mês. Toque no + para começar.', style: TextStyle(color: G.apagado)))
            else
              CaixaLista([for (final l in ult) LinhaLanc(l, onTap: () => abrirFormLanc(context, doc: (l.g?.d ?? l.e!.d)))]),
          ]),
        ),
      ],
    );
  }
}

/// Cartão principal: mês, saldo em conta, entrou/saiu e limite.
class HeroMes extends StatelessWidget {
  final ResumoMes r;
  final ValueChanged<String> onMes;
  final VoidCallback onEntrou, onSaiu, onLimite;
  const HeroMes({super.key, required this.r, required this.onMes, required this.onEntrou, required this.onSaiu, required this.onLimite});

  @override
  Widget build(BuildContext context) {
    final uso = r.usoLimite;
    final corLim = uso == null ? G.branco : (uso > 1 ? G.neg : (uso > .85 ? G.alerta : G.branco));
    final principal = r.emConta;
    return Container(
      decoration: BoxDecoration(
        gradient: G.gradHero,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x17FFFFFF)),
        boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 50, offset: Offset(0, 28), spreadRadius: -30)],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(children: [
        SeletorMes(ym: r.ym, onMudar: onMes),
        const SizedBox(height: 14),
        Text(principal != null ? 'Em conta' : 'Sobra do mês', style: const TextStyle(color: G.texto2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(brl(principal ?? r.sobra), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1.5, color: Colors.white)),
        ),
        if (principal != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Sobra do mês: ${brl(r.sobra)}', style: const TextStyle(color: G.texto2, fontSize: 13)),
          ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _Bloco(rotulo: 'Entrou', valor: r.entrou, claro: true, icone: Icons.south_west_rounded, corIcone: G.posEscuro, onTap: onEntrou)),
          const SizedBox(width: 10),
          Expanded(child: _Bloco(rotulo: 'Saiu', valor: r.saiu, claro: false, icone: Icons.north_east_rounded, corIcone: G.negEscuro, onTap: onSaiu)),
        ]),
        if (r.limiteTotal > 0) ...[
          const SizedBox(height: 16),
          InkWell(
            onTap: onLimite,
            borderRadius: BorderRadius.circular(10),
            child: Column(children: [
              Row(children: [
                const Text('Limite de gastos', style: TextStyle(color: G.texto2, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: brl(r.gastoComLimite), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      TextSpan(text: ' de ${brl(r.limiteTotal)}', style: const TextStyle(color: G.texto2, fontSize: 12)),
                    ]),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Barra(uso ?? 0, cor: corLim),
            ]),
          ),
        ],
      ]),
    );
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: claro ? G.branco : null,
        gradient: claro ? null : G.gradLavanda,
        borderRadius: r,
        boxShadow: const [BoxShadow(color: Color(0xE6000000), blurRadius: 26, offset: Offset(0, 14), spreadRadius: -18)],
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
                decoration: BoxDecoration(color: const Color(0x1612131C), borderRadius: BorderRadius.circular(12)),
                child: Icon(icone, size: 18, color: corIcone),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rotulo, style: const TextStyle(color: Color(0x9E12131C), fontWeight: FontWeight.w700, fontSize: 12.5)),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(brl(valor), style: const TextStyle(color: G.tinta, fontWeight: FontWeight.w800, fontSize: 16))),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Atalhos extends StatelessWidget {
  final VoidCallback irExtrato, irLimites;
  const _Atalhos({required this.irExtrato, required this.irLimites});
  @override
  Widget build(BuildContext context) {
    Widget at(IconData i, String t, VoidCallback f, {bool destaque = false}) => Expanded(
          child: Column(children: [
            Material(
              color: destaque ? G.branco : const Color(0x10FFFFFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: destaque ? G.branco : G.borda)),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: f,
                child: SizedBox(width: 54, height: 54, child: Icon(i, color: destaque ? G.tinta : G.texto, size: 22)),
              ),
            ),
            const SizedBox(height: 7),
            Text(t, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: G.texto2)),
          ]),
        );
    return Row(children: [
      at(Icons.add_rounded, 'Gasto', () => abrirFormLanc(context), destaque: true),
      at(Icons.arrow_upward_rounded, 'Entrada', () => abrirFormLanc(context, entrada: true)),
      at(Icons.file_download_outlined, 'Importar', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaImportarExtrato()))),
      at(Icons.search_rounded, 'Buscar', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaBusca()))),
      at(Icons.tune_rounded, 'Limites', irLimites),
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
    final top = itens.take(5).toList();
    final maior = top.isEmpty ? 1.0 : top.first.value;
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoCartao('Para onde foi o dinheiro', sub: '${itens.length} categoria${itens.length == 1 ? '' : 's'} no mês', acao: 'Limites', onAcao: irLimites),
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
                      Expanded(child: Text(cat.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text(brl(e.value), style: const TextStyle(fontWeight: FontWeight.w800)),
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
      gradiente: const LinearGradient(colors: [Color(0x29B9BFF6), Color(0x08FFFFFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bem-vindo ao Diário da Carteira', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Traga seus dados do app antigo: lá, toque em Ajustes → Backup → Exportar. Depois, aqui, importe o arquivo.', style: TextStyle(color: G.texto2)),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Cartao(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CabecalhoCartao('Contas a pagar', sub: ab.isEmpty ? 'Tudo pago este mês' : 'Falta pagar ${brl(m.falta)} este mês', acao: 'Ver contas', onAcao: irPlanejar),
          if (atr.isNotEmpty)
            Material(
              color: const Color(0x1AFF6B81),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0x47FF6B81))),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: irPlanejar,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: G.neg, borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${atr.length} conta${atr.length > 1 ? 's' : ''} atrasada${atr.length > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text(brl(atr.fold<double>(0, (a, i) => a + i.valor)), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFFF8DA0))),
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
                          Text(i.b.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(i.statusTexto, style: TextStyle(fontSize: 12.5, color: i.st == 'hoje' ? G.alerta : G.apagado)),
                        ]),
                      ),
                      Text(brl(i.valor), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
            ]),
        ]),
      ),
    );
  }
}
