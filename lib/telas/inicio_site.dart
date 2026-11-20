// Início igual ao do site Diário da Carteira: cartão do mês, atalhos,
// previsão do mês, próximos recebimentos e últimos lançamentos.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'avisos.dart';

import '../dados/categorias.dart';
import '../dados/limites.dart';
import '../dados/planejar.dart';
import '../dados/repo.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/site.dart';
import 'lancar.dart';

const _branco = Colors.white;

/// Quanto ainda deve entrar no mês (recebimentos que não caíram) e quanto falta pagar.
({double aReceber, double faltaPagar}) previsaoMes(Repo repo, String ym) {
  final h = hojeIso();
  var rec = 0.0;
  for (final r in repo.rendas.where((r) => r.valor > 0)) {
    final st = statusRenda(repo, r, ym, hoje: h);
    if (st != null && st.rec == null) rec += valorEsperado(repo, r, hoje: h);
  }
  final falta = repo.doTipo('pagar').isEmpty ? 0.0 : mesContas(repo, ym, hoje: h).falta;
  return (aReceber: rec, faltaPagar: falta);
}

/// Pergunta o saldo em conta de hoje e grava na conta principal.
Future<void> ajustarSaldoConta(BuildContext context) async {
  final repo = RepoScope.ler(context);
  final contas = repo.contas..sort((a, b) => b.saldo.compareTo(a.saldo));
  final atual = saldoEmConta(repo);
  final c = TextEditingController(text: atual != 0 ? valorCampo(atual) : '');
  final v = await showDialog<double>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Quanto tem em conta hoje?'),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: const InputDecoration(prefixText: 'R\$ ', hintText: '0,00'),
        onSubmitted: (t) => Navigator.pop(d, lerValor(t)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(d, lerValor(c.text)), child: const Text('Salvar')),
      ],
    ),
  );
  if (v == null || !context.mounted) return;
  final base = contas.isEmpty ? null : contas.first.d;
  await repo.salvar({
    ...?base,
    'kind': 'conta',
    'id': base?['id'] ?? 'ct_principal',
    'nome': base?['nome'] ?? 'Conta',
    'saldo': (v * 100).round() / 100,
    'data': hojeIso(),
    'ts': DateTime.now().millisecondsSinceEpoch,
  });
}

class InicioSite extends StatelessWidget {
  final String ym;
  final ValueChanged<String> onMes;
  final VoidCallback irExtrato, irLimites, irPlanejar, irCartao, irImportar, irBuscar;
  final void Function(String filtro) irExtratoFiltro;
  final void Function(String cat)? verCategoria;
  const InicioSite({
    super.key,
    required this.ym,
    required this.onMes,
    required this.irExtrato,
    required this.irLimites,
    required this.irPlanejar,
    required this.irCartao,
    required this.irImportar,
    required this.irBuscar,
    required this.irExtratoFiltro,
    this.verCategoria,
  });

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final r = ResumoMes.de(repo, ym);
    final prev = previsaoMes(repo, ym);
    const e = SizedBox(height: 18);
    final temReceb = repo.rendas.isNotEmpty || agendaRecebimentos(repo).isNotEmpty;
    return LayoutBuilder(builder: (context, cons) {
      if (cons.maxWidth >= 860) {
        // computador: cartão do mês, atalhos e recebimentos à esquerda;
        // previsão e lançamentos à direita (como o site no PC)
        return ListView(padding: const EdgeInsets.fromLTRB(28, 14, 28, 40), children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 440,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    HeroSite(r: r, ym: ym, onMes: onMes, prev: prev, irEntradas: () => irExtratoFiltro('entradas'), irSaidas: () => irExtratoFiltro('saidas')),
                    FaixaAvisosSite(verCategoria: verCategoria ?? (_) => irExtratoFiltro('saidas')),
                    e,
                    _atalhos(context),
                    if (temReceb) ...[e, RecebimentosSite(irPlanejar: irPlanejar)],
                  ]),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    PrevisaoSite(r: r, prev: prev, irExtrato: irExtrato, irLimites: irLimites),
                    e,
                    UltimosSite(r: r, irExtrato: irExtrato),
                  ]),
                ),
              ]),
            ),
          ),
        ]);
      }
      return _lista(context, r, prev, temReceb);
    });
  }

  Widget _atalhos(BuildContext context) => AtalhosSite(itens: [
        (Ico.mais, 'Gasto', () => abrirFormLanc(context)),
        (Ico.cima, 'Entrada', () => abrirFormLanc(context, entrada: true)),
        (Ico.cartao, 'Cartão', irCartao),
        (Ico.buscar, 'Buscar', irBuscar),
      ]);

  Widget _lista(BuildContext context, ResumoMes r, ({double aReceber, double faltaPagar}) prev, bool temReceb) {
    const e = SizedBox(height: 18);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 104),
      children: [
        HeroSite(r: r, ym: ym, onMes: onMes, prev: prev, irEntradas: () => irExtratoFiltro('entradas'), irSaidas: () => irExtratoFiltro('saidas')),
        FaixaAvisosSite(verCategoria: verCategoria ?? (_) => irExtratoFiltro('saidas')),
        e,
        _atalhos(context),
        e,
        PrevisaoSite(r: r, prev: prev, irExtrato: irExtrato, irLimites: irLimites),
        if (temReceb) ...[e, RecebimentosSite(irPlanejar: irPlanejar)],
        e,
        UltimosSite(r: r, irExtrato: irExtrato),
      ],
    );
  }
}

/// Cartão do topo (.hx): mês, saldo em conta, fim do mês, entrou/saiu e limite.
class HeroSite extends StatelessWidget {
  final ResumoMes r;
  final String ym;
  final ValueChanged<String> onMes;
  final ({double aReceber, double faltaPagar}) prev;
  final VoidCallback irEntradas, irSaidas;
  /// No Extrato o cartão é menor: só o mês e entrou/saiu.
  final bool mini;
  const HeroSite({super.key, required this.r, required this.ym, required this.onMes, required this.prev, required this.irEntradas, required this.irSaidas, this.mini = false});

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final cta = S.cta;
    final emConta = r.emConta;
    final contas = repo.contas;
    String? atu;
    var velho = false;
    if (contas.isNotEmpty) {
      final d = (contas.map((c) => c.data).toList()..sort()).last;
      final dias = diasEntre(d, hojeIso()) - 1;
      velho = dias >= 2;
      atu = dias <= 0 ? 'atualizado hoje' : (dias == 1 ? 'atualizado ontem' : 'atualizado há $dias dias');
    }
    Widget seta(String d, int n) => _Toque(
          onTap: () {
            HapticFeedback.selectionClick();
            onMes(ymAdd(ym, n));
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Color(0x29FFFFFF), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: IconeSite(d, tam: 18, cor: _branco),
          ),
        );
    Widget kpi(bool entrada) => Expanded(
          child: _Toque(
            onTap: entrada ? irEntradas : irSaidas,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(color: const Color(0x21FFFFFF), border: Border.all(color: const Color(0x38FFFFFF)), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: _branco, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: IconeSite(entrada ? Ico.entrou : Ico.saiu, tam: 15, cor: entrada ? const Color(0xFF11764A) : const Color(0xFFC23B2A)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entrada ? 'Entrou' : 'Saiu', style: const TextStyle(color: _branco, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.5)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(brl(entrada ? r.entrou : r.saiu), style: const TextStyle(color: _branco, fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.5)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(begin: const Alignment(-.55, -1), end: const Alignment(.55, 1), colors: [cta, Color.lerp(cta, Colors.black, .35)!]),
        boxShadow: [BoxShadow(color: cta.withValues(alpha: .55), blurRadius: 36, offset: const Offset(0, 18), spreadRadius: -18)],
      ),
      child: Stack(children: [
        // brilho no canto de cima, à direita
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(center: const Alignment(1, -1), radius: 1.1, colors: [S.accent.withValues(alpha: .7), S.accent.withValues(alpha: 0)], stops: const [0, .6]),
            ),
          ),
        ),
        // círculo decorativo grande no canto de baixo, como no site
        Positioned(
          right: -70,
          bottom: -110,
          child: Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .05))),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x2EFFFFFF)))),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              seta(Ico.esq, -1),
              Expanded(
                child: Center(
                  child: _Toque(
                    onTap: ym == ymDe(hojeIso()) ? null : () => onMes(ymDe(hojeIso())),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(mesLongo(ym), style: const TextStyle(color: _branco, fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 5),
                        const IconeSite(Ico.baixo, tam: 15, cor: _branco),
                      ]),
                    ),
                  ),
                ),
              ),
              seta(Ico.dir, 1),
            ]),
            if (!mini) ...[
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(emConta != null ? 'Em conta' : 'Sobra do mês', style: const TextStyle(color: _branco, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                ValueListenableBuilder<bool>(
                  valueListenable: privacidade,
                  builder: (_, o, __) => _Toque(
                    onTap: () => definirPrivacidade(!o),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: IconeSite(o ? Ico.olhoFechado : Ico.olho, tam: 15, cor: _branco.withValues(alpha: .85))),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(brl(emConta ?? r.sobra), style: const TextStyle(fontFamily: S.fonteNum, color: _branco, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -.68, height: 1.1)),
                ),
              ),
              const SizedBox(height: 3),
              if (atu != null)
                Center(
                  child: _Toque(
                    onTap: () => ajustarSaldoConta(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: velho ? const Color(0x47FFC478) : const Color(0x29FFFFFF), borderRadius: BorderRadius.circular(99)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(child: Text('$atu · ajustar', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _branco, fontSize: 12, fontWeight: FontWeight.w600, height: 1.5))),
                        const SizedBox(width: 4),
                        const IconeSite(Ico.baixo, tam: 12, cor: _branco),
                      ]),
                    ),
                  ),
                )
              else
                Center(
                  child: _Toque(
                    onTap: () => ajustarSaldoConta(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0x29FFFFFF), borderRadius: BorderRadius.circular(99)),
                      child: const Text('informar saldo em conta', style: TextStyle(color: _branco, fontSize: 12, fontWeight: FontWeight.w600, height: 1.5)),
                    ),
                  ),
                ),
              if (emConta != null && ym == ymDe(hojeIso())) ...[
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  const Flexible(child: Text('Previsão para o fim do mês:', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _branco, fontSize: 13))),
                  const SizedBox(width: 5),
                  Text(brl(emConta + prev.aReceber - prev.faltaPagar), style: const TextStyle(color: _branco, fontSize: 15, fontWeight: FontWeight.w800)),
                ]),
              ],
              const SizedBox(height: 14),
            ] else
              const SizedBox(height: 10),
            Row(children: [kpi(true), const SizedBox(width: 8), kpi(false)]),
          ]),
        ),
      ]),
    );
  }
}

/// Fileira de atalhos redondos (.hx-atl); o primeiro é o principal (cheio).
class AtalhosSite extends StatelessWidget {
  final List<(String, String, VoidCallback)> itens;
  const AtalhosSite({super.key, required this.itens});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
        child: Row(children: [
          for (var k = 0; k < itens.length; k++)
            Expanded(
              child: _Toque(
                onTap: () {
                  HapticFeedback.selectionClick();
                  itens[k].$3();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: k == 0 ? S.cta : S.surface,
                        border: Border.all(color: k == 0 ? S.cta : S.line),
                        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4), spreadRadius: -8)],
                      ),
                      alignment: Alignment.center,
                      child: IconeSite(itens[k].$1, tam: 21, cor: k == 0 ? S.ctaInk : S.accent),
                    ),
                    const SizedBox(height: 6),
                    Text(itens[k].$2, maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: S.ink, height: 1.5)),
                  ]),
                ),
              ),
            ),
        ]),
      );
}

/// "Previsão do mês": barra do limite com o dia de hoje marcado e o resumo do mês.
class PrevisaoSite extends StatelessWidget {
  final ResumoMes r;
  final ({double aReceber, double faltaPagar}) prev;
  final VoidCallback irExtrato, irLimites;
  const PrevisaoSite({super.key, required this.r, required this.prev, required this.irExtrato, required this.irLimites});

  @override
  Widget build(BuildContext context) {
    final lim = r.limiteTotal, g = r.gastoComLimite;
    final hoje = hojeIso();
    final mesAtual = ymDe(hoje) == r.ym;
    final fracDia = mesAtual ? int.parse(hoje.substring(8, 10)) / diasNoMes(r.ym) : (r.ym.compareTo(ymDe(hoje)) < 0 ? 1.0 : 0.0);
    final uso = lim > 0 ? g / lim : 0.0;
    final proj = lim > 0 ? projecaoMes(g, r.ym) : null;
    final noRitmo = uso <= fracDia + .02;
    final cor = uso > 1 ? S.neg : (noRitmo ? S.pos : S.second);
    final entradas = r.entrou + (mesAtual ? prev.aReceber : 0), saidas = r.saiu + r.agendado + (mesAtual ? prev.faltaPagar : 0);
    Widget linha(String d, String rot, double v, Color c, Color fundo) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            Container(width: 26, height: 26, decoration: BoxDecoration(color: fundo, shape: BoxShape.circle), alignment: Alignment.center, child: IconeSite(d, tam: 16, cor: c)),
            const SizedBox(width: 6),
            Expanded(child: Text(rot, style: TextStyle(fontSize: 12.5, color: S.ink))),
            Text(brl(v), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
          ]),
        );
    return CartaoSite(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Previsão do mês', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: S.ink, height: 1.5)),
        const SizedBox(height: 12),
        if (lim > 0) ...[
          GestureDetector(
            onTap: irLimites,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.temLimiteGeral ? 'Do limite do mês' : 'Do limite das categorias', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: S.muted)),
                  const SizedBox(height: 2),
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text(brl(g), style: TextStyle(fontFamily: S.fonteNum, fontSize: 20, fontWeight: FontWeight.w800, color: S.ink)),
                    Flexible(child: Text(' de ${brl(lim)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: S.muted))),
                  ]),
                ]),
              ),
              Text('${(uso * 100).round()}%', style: TextStyle(fontFamily: S.fonteNum, fontSize: 20, fontWeight: FontWeight.w800, color: cor)),
            ]),
          ),
          const SizedBox(height: 16),
          _BarraHoje(uso: uso, hoje: mesAtual ? fracDia : null, cor: cor),
          const SizedBox(height: 10),
          Text(
            uso > 1
                ? 'Você passou ${brl(g - lim)} do limite.'
                : (proj == null
                    ? 'Faltam ${brl(lim - g)} para chegar ao limite.'
                    : (noRitmo
                        ? 'Você está gastando dentro do ritmo. No ritmo atual, fecha o mês em ${brl(proj)}.'
                        : 'Você está gastando acima do ritmo. No ritmo atual, fecha o mês em ${brl(proj)}.')),
            style: TextStyle(fontSize: 12.5, color: S.ink2, height: 1.5),
          ),
          const SizedBox(height: 14),
        ],
        linha(Ico.cima, 'Entradas', entradas, S.pos, S.posSoft),
        linha(Ico.desce, 'Saídas', saidas, S.neg, S.negSoft),
        linha(Ico.pizza, 'Sobra', entradas - saidas, S.accent, S.accentSoft),
        Material(
          color: S.surface,
          shape: StadiumBorder(side: BorderSide(color: S.line)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: irExtrato,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              child: Row(children: [
                const SizedBox(width: 16),
                Expanded(child: Text('Ver extrato completo', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: S.ink))),
                IconeSite(Ico.dir, tam: 14, cor: S.ink),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _BarraHoje extends StatelessWidget {
  final double uso;
  final double? hoje;
  final Color cor;
  const _BarraHoje({required this.uso, required this.hoje, required this.cor});
  @override
  Widget build(BuildContext context) {
    final verde = cor == S.pos;
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      final xh = hoje == null ? null : (w * hoje!).clamp(1.0, w - 1);
      return SizedBox(
        height: 30,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0,
            right: 0,
            top: 16,
            height: 14,
            child: Container(
              decoration: BoxDecoration(color: S.surface2, borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))]),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: math.min(1, uso),
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: LinearGradient(colors: verde ? const [Color(0xFF1F9D6B), Color(0xFF34C47A)] : [cor, Color.lerp(cor, Colors.white, .25)!]),
                  ),
                ),
              ),
            ),
          ),
          if (xh != null)
            Positioned(
              left: xh - 13.5,
              top: 0,
              width: 27,
              child: Column(children: [
                Text('HOJE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: S.ink2, letterSpacing: .2, height: 1)),
                const SizedBox(height: 2),
                Container(width: 2, height: 22, decoration: BoxDecoration(color: S.ink, borderRadius: BorderRadius.circular(2))),
              ]),
            ),
        ]),
      );
    });
  }
}

/// "Próximos recebimentos": linha do tempo com até 3 datas.
class RecebimentosSite extends StatelessWidget {
  final VoidCallback irPlanejar;
  const RecebimentosSite({super.key, required this.irPlanejar});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ag = agendaRecebimentos(repo).take(3).toList();
    return CartaoSite(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Próximos recebimentos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: S.ink, height: 1.5))),
          _Toque(
            onTap: irPlanejar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconeSite(Ico.calendario2, tam: 17, cor: S.accent),
                const SizedBox(width: 6),
                Text('Ajustar', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: S.accent)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        if (ag.isEmpty)
          Text('Cadastre seus recebimentos em Planejar.', style: TextStyle(color: S.muted, fontSize: 12.5))
        else
          Stack(children: [
            // a linha que liga os pontos
            Positioned(left: 0, right: 0, top: 58, child: Container(height: 2, color: S.line)),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final x in ag)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(children: [
                      Text('${x.data.substring(8, 10)}/${x.data.substring(5, 7)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: S.ink, height: 1.5)),
                      // atrasado: o nome fica vermelho (o "· atrasado" escrito se perdia no corte)
                      Text(x.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: x.atrasado ? S.neg : S.ink2, fontWeight: x.atrasado ? FontWeight.w600 : FontWeight.w400, height: 1.5)),
                      const SizedBox(height: 7),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: x.atrasado ? S.neg : (x.recebido ? S.pos : S.surface),
                          border: Border.all(color: x.atrasado ? S.neg : (x.recebido ? S.pos : S.muted), width: 2),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(color: x.atrasado ? S.negSoft : (x.recebido ? S.posSoft : S.surface2), borderRadius: BorderRadius.circular(99)),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(brl(x.valor), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: x.atrasado ? S.neg : (x.recebido ? S.pos : S.ink2))),
                        ),
                      ),
                    ]),
                  ),
                ),
            ]),
          ]),
      ]),
    );
  }
}

/// Texto de baixo de uma linha de lançamento, como no site ("Mercado · Débito").
String subLancSite(Repo repo, Lanc l) {
  if (l.ehInvest) return 'Investido';
  if (l.ehEntrada) return catEntrada(l.e!.cat).nome;
  final g = l.g!;
  final cc = g.d['cartao'];
  if (cc is String) {
    final c = repo.porId(cc);
    if (c != null) return '${catGasto(g.cat).nome} · Cartão ${c['nome'] ?? ''}';
  }
  return '${catGasto(g.cat).nome} · ${g.pag}';
}

/// Valor com sinal, como no site: "− R$ 48,90" / "+ R$ 150,00".
String valorLancSite(Lanc l) => l.ehEntrada ? '+ ${brl(l.valor)}' : (l.ehGasto ? '− ${brl(l.valor)}' : brl(l.valor));

Widget linhaLancSite(BuildContext context, Repo repo, Lanc l, {VoidCallback? onTap}) => LinhaTxSite(
      cat: l.ehEntrada ? catEntrada(l.e!.cat) : (l.ehGasto ? catGasto(l.g!.cat) : catGasto('outros')),
      entrada: l.ehEntrada,
      titulo: l.desc,
      sub: subLancSite(repo, l),
      valor: valorLancSite(l),
      corValor: l.ehEntrada ? S.pos : null,
      onTap: onTap ?? () => abrirFormLanc(context, doc: l.doc),
    );

class UltimosSite extends StatelessWidget {
  final ResumoMes r;
  final VoidCallback irExtrato;
  const UltimosSite({super.key, required this.r, required this.irExtrato});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ult = r.ateHoje.take(6).toList();
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoSite('Últimos lançamentos', sub: mesLongo(r.ym), acao: 'Ver extrato', onAcao: irExtrato),
        if (ult.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Nada lançado neste mês.', style: TextStyle(color: S.muted)))
        else
          Padding(padding: const EdgeInsets.only(top: 6), child: ListaTxSite([for (final l in ult) linhaLancSite(context, repo, l)])),
      ]),
    );
  }
}

/// Toque com leve encolhida, como os botões do site (:active scale).
class _Toque extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Toque({required this.child, this.onTap});
  @override
  State<_Toque> createState() => _ToqueState();
}

class _ToqueState extends State<_Toque> {
  bool baixo = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => baixo = true),
        onTapCancel: () => setState(() => baixo = false),
        onTapUp: (_) => setState(() => baixo = false),
        onTap: widget.onTap,
        child: AnimatedScale(scale: baixo ? .94 : 1, duration: const Duration(milliseconds: 120), child: widget.child),
      );
}
