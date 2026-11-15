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
import 'inicio_leve.dart';
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
  @override
  Widget build(BuildContext context) {
    final w = widget;
    final repo = RepoScope.of(context);
    final r = ResumoMes.de(repo, w.ym);
    final temContas = repo.doTipo('pagar').isNotEmpty;
    var o = 0;
    Widget surge(Widget c) => Surge(ordem: o++, child: c);
    final boasVindas = repo.vazio ? surge(_BoasVindas()) : null;
    void verCategoria(String c) => w.irCategoria != null ? w.irCategoria!(c) : w.irExtratoFiltro('saidas');
    final mes = MesLeve(ym: w.ym, onMes: w.onMes);
    final resumo = surge(ResumoLeve(r: r, onEntradas: () => w.irExtratoFiltro('entradas'), onSaidas: () => w.irExtratoFiltro('saidas')));
    final contas = temContas ? surge(_ContasInicio(irPlanejar: w.irPlanejar)) : null;
    final gastos = surge(GastosLeve(r: r, onCategoria: verCategoria, onVer: () => w.irExtratoFiltro('saidas')));
    final limite = surge(LimiteLeve(r: r, onTap: w.irLimites));
    final invest = surge(InvestLeve(onTap: w.irPatrimonio ?? () {}));
    const e = SizedBox(height: 12);
    return LayoutBuilder(builder: (context, cons) {
      if (cons.maxWidth >= 860) {
        // computador: resumo, limite, investimentos e contas à esquerda;
        // gastos e lançamentos à direita
        return ListView(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
          children: [
            Centralizar(
              max: 1180,
              child: Column(children: [
                mes,
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 420,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (boasVindas != null) ...[boasVindas, e],
                      resumo,
                      e,
                      limite,
                      e,
                      invest,
                      if (contas != null) ...[e, contas],
                    ]),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      gastos,
                      e,
                      _Ultimos(r: r, irExtrato: w.irExtrato, quantos: 12),
                    ]),
                  ),
                ]),
              ]),
            ),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
        children: [
          mes,
          const SizedBox(height: 4),
          if (boasVindas != null) ...[boasVindas, e],
          resumo,
          if (contas != null) ...[e, contas],
          e,
          gastos,
          e,
          limite,
          e,
          invest,
          e,
          surge(_Ultimos(r: r, irExtrato: w.irExtrato)),
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

class _BoasVindas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Cartao(
      gradiente: LinearGradient(colors: [G.lavandaFundo, G.v(0x08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bem-vindo ao Diário da Carteira', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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


