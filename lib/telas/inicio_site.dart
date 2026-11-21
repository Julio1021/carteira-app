// Início igual ao do site Diário da Carteira: cartão do mês, atalhos,
// previsão do mês, próximos recebimentos e últimos lançamentos.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'avisos.dart';

import '../dados/categorias.dart';
import '../dados/limites.dart';
import '../dados/modelos.dart' show str;
import '../dados/objetivos.dart';
import '../dados/patrimonio.dart';
import '../dados/planejar.dart';
import '../dados/repo.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/animado.dart';
import '../widgets/site.dart';
import 'classificar.dart';
import 'conferir.dart';
import 'lancar.dart';
import 'planejar.dart';

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
                    ConferirSite(verCategoria: verCategoria),
                    const ComemoracaoSite(),
                    e,
                    _atalhos(context),
                  ]),
                ),
                const SizedBox(width: 20),
                Expanded(child: PrevisaoSite(r: r, prev: prev, irExtrato: irExtrato, irLimites: irLimites)),
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

  /// Celular: só o essencial. Quanto tem e quanto vai sobrar, o que pede
  /// sua atenção, atalhos e o ritmo dos gastos. Recebimentos ficam em
  /// Planejar e os lançamentos no Extrato.
  Widget _lista(BuildContext context, ResumoMes r, ({double aReceber, double faltaPagar}) prev, bool temReceb) {
    const e = SizedBox(height: 18);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 104),
      children: [
        HeroSite(r: r, ym: ym, onMes: onMes, prev: prev, irEntradas: () => irExtratoFiltro('entradas'), irSaidas: () => irExtratoFiltro('saidas')),
        ConferirSite(verCategoria: verCategoria),
        const ComemoracaoSite(),
        e,
        _atalhos(context),
        e,
        PrevisaoSite(r: r, prev: prev, irExtrato: irExtrato, irLimites: irLimites),
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
                      child: NumeroAnimado(entrada ? r.entrou : r.saiu, formato: brl, style: const TextStyle(color: _branco, fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.5)),
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
        TrocaMesArrastando(
          ym: ym,
          aoTrocar: (d) => onMes(ymAdd(ym, d)),
          child: Container(
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
                  child: NumeroAnimado(emConta ?? r.sobra, formato: brl, style: const TextStyle(fontFamily: S.fonteNum, color: _branco, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -.68, height: 1.1)),
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
                  NumeroAnimado(emConta + prev.aReceber - prev.faltaPagar, formato: brl, style: const TextStyle(color: _branco, fontSize: 15, fontWeight: FontWeight.w800)),
                ]),
              ],
              const SizedBox(height: 14),
            ] else
              const SizedBox(height: 10),
            Row(children: [kpi(true), const SizedBox(width: 8), kpi(false)]),
          ]),
        ),
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
          Builder(builder: (_) {
            final ideal = lim * fracDia;
            final ritmo = fracDia > 0 ? uso / fracDia : uso;
            final msg = uso > 1
                ? 'Você passou ${brl(g - lim)} do limite do mês.'
                : (proj == null
                    ? 'Mês fechado: gastou ${brl(g)} de ${brl(lim)}.'
                    : (ritmo <= .9
                        ? 'Tranquilo: ${brl(ideal - g)} abaixo do ritmo. No ritmo atual, fecha o mês em ${brl(proj)}.'
                        : (ritmo <= 1.15
                            ? 'Atenção: perto do ritmo ideal. No ritmo atual, fecha o mês em ${brl(proj)}.'
                            : 'Rápido demais: ${brl(g - ideal)} acima do ritmo. No ritmo atual, fecha o mês em ${brl(proj)}.')));
            return GestureDetector(
              onTap: irLimites,
              behavior: HitTestBehavior.opaque,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.temLimiteGeral ? 'Gasto do limite do mês' : 'Gasto do limite das categorias', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: S.muted)),
                      const SizedBox(height: 2),
                      Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
                        NumeroAnimado(g, formato: brl, style: TextStyle(fontFamily: S.fonteNum, fontSize: 21, fontWeight: FontWeight.w800, color: S.ink)),
                        Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('de ${brl(lim)}', style: TextStyle(fontSize: 12.5, color: S.muted))),
                      ]),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: S.surface2, borderRadius: BorderRadius.circular(99)),
                    child: Text('${(uso * 100).round()}% usado', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: S.ink2)),
                  ),
                ]),
                const SizedBox(height: 10),
                VelocimetroRitmo(
                  ritmo: ritmo,
                  titulo: '${(ritmo * 100).round()}% do ritmo',
                  sub: mesAtual ? '${brl(g)} gastos · o ideal até hoje é ${brl(ideal)}' : '${brl(g)} de ${brl(lim)}',
                ),
                const SizedBox(height: 6),
                Text(msg, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: S.ink2, height: 1.45)),
              ]),
            );
          }),
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

/// Toque num ponto da linha do tempo: recebimento já lançado abre para
/// corrigir (valor, dia, dividir); o que ainda não entrou abre para marcar.
/// Parcelas de empréstimo vão para a lista completa.
void _tocarRecebimento(BuildContext context, ItemAgenda x, VoidCallback irLista) {
  final r = x.renda;
  if (r == null) return irLista();
  final repo = RepoScope.ler(context);
  StatusRenda? st;
  for (final ym in [ymDe(x.data), ymAdd(ymDe(x.data), -1), ymAdd(ymDe(x.data), 1)]) {
    final s = statusRenda(repo, r, ym);
    if (s != null && (s.rec?.data == x.data || s.data == x.data)) {
      st = s;
      break;
    }
  }
  confirmarRecebido(context, r, st?.data ?? x.data, x.valor, rec: x.recebido ? st?.rec : null);
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
          Builder(builder: (context) {
            final h = hojeIso();
            final n = ag.length;
            // até onde a linha vai: o centro do último ponto que já passou + parte do caminho até o próximo
            var prog = 0.0;
            for (var k = 0; k < n; k++) {
              if (ag[k].data.compareTo(h) <= 0 || ag[k].recebido) prog = (k + .5) / n;
            }
            final passados = ag.where((x) => x.data.compareTo(h) <= 0 || x.recebido).length;
            if (passados < n) {
              final ini = passados == 0 ? null : ag[passados - 1].data;
              final fim = ag[passados].data;
              final tot = ini == null ? 30 : diasEntre(ini, fim);
              final foi = ini == null ? math.max(0, 30 - diasEntre(h, fim)) : diasEntre(ini, h);
              final parte = tot <= 0 ? 0.0 : (foi / tot).clamp(0.0, 1.0);
              prog = passados == 0 ? .5 / n * parte : prog + parte / n;
            }
            final proximo = ag.indexWhere((x) => !x.recebido && !x.atrasado && x.data.compareTo(h) >= 0);
            return Stack(children: [
            // a linha que liga os pontos (cinza) e a parte já percorrida (cor do tema)
            Positioned(left: 0, right: 0, top: 72, child: Container(height: 2, color: S.line)),
            Positioned(
              left: 0,
              right: 0,
              top: 71,
              child: LayoutBuilder(
                builder: (_, c) => Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: animacoesLigadas(context) ? 0 : prog, end: prog),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Container(width: c.maxWidth * v, height: 4, decoration: BoxDecoration(color: S.accent, borderRadius: BorderRadius.circular(99))),
                  ),
                ),
              ),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var k = 0; k < n; k++)
                Expanded(
                  child: Builder(builder: (_) {
                    final x = ag[k];
                    return _Toque(
                    onTap: () => _tocarRecebimento(context, x, irPlanejar),
                    child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(children: [
                      Text('${x.data.substring(8, 10)}/${x.data.substring(5, 7)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: S.ink, height: 1.5)),
                      // altura fixa de 2 linhas: os pontos ficam todos na mesma altura da linha
                      SizedBox(
                        height: 35,
                        child: Text(x.nome, maxLines: 2, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: x.atrasado ? S.neg : S.ink2, fontWeight: x.atrasado ? FontWeight.w600 : FontWeight.w400, height: 1.5)),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: x.recebido
                            ? _CheckEstoura(cor: S.pos)
                            : _Ponto(cor: x.atrasado ? S.neg : (k == proximo ? S.accent : S.muted), cheio: x.atrasado, pulsa: k == proximo),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(color: x.atrasado ? S.negSoft : (x.recebido ? S.posSoft : S.surface2), borderRadius: BorderRadius.circular(99)),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(brl(x.valor), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: x.atrasado ? S.neg : (x.recebido ? S.pos : S.ink2))),
                        ),
                      ),
                    ]),
                  ));
                  }),
                ),
            ]),
          ]);
          }),
        if (ag.any((x) => x.renda != null && !x.recebido && x.data.compareTo(hojeIso()) <= 0)) ...[
          const SizedBox(height: 12),
          Text('Toque num recebimento para marcar que entrou, ou para corrigir se veio junto com outro valor.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: S.muted, height: 1.4)),
        ],
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
String valorLancSite(Lanc l) => l.ehEntrada
    ? '${l.valor < 0 ? '−' : '+'} ${brl(l.valor.abs())}'
    : (l.ehGasto ? '− ${brl(l.valor)}' : brl(l.valor));

/// Lançamento que abre "o que foi esse dinheiro?" em vez do formulário:
/// transferência entre suas contas (que chegou) ou parte de um depósito dividido.
bool abreClassificar(Lanc l) => l.ehEntrada && ((l.e!.entreContas && l.e!.valor > 0) || l.e!.d['div'] is String);

/// Abre o lançamento: formulário ou, para transferências e divisões, a folha
/// "o que foi esse dinheiro?".
void abrirLancamento(BuildContext context, Lanc l) => abreClassificar(l) ? abrirClassificar(context, l.e!) : abrirFormLanc(context, doc: l.doc);

Widget linhaLancSite(BuildContext context, Repo repo, Lanc l, {VoidCallback? onTap}) {
  final e = l.e;
  final transf = e != null && e.entreContas;
  final pend = e != null && transfPendente(e);
  return LinhaTxSite(
    cat: l.ehEntrada ? catEntrada(l.e!.cat) : (l.ehGasto ? catGasto(l.g!.cat) : catGasto('outros')),
    entrada: l.ehEntrada,
    titulo: transf ? (e!.valor >= 0 ? 'Transferência de outra conta sua' : 'Transferência para outra conta sua') : l.desc,
    sub: pend
        ? 'Toque para conferir: foi salário, vale, 13º ou só troca de conta?'
        : (transf ? 'Entre suas contas · não conta como ${e!.valor >= 0 ? 'entrada' : 'gasto'}' : subLancSite(repo, l)),
    corSub: pend ? S.neg : null,
    valor: valorLancSite(l),
    corValor: transf ? S.muted : (l.ehEntrada ? S.pos : null),
    conferir: pend,
    onTap: onTap ?? () => abrirLancamento(context, l),
  );
}

class UltimosSite extends StatelessWidget {
  final ResumoMes r;
  final VoidCallback irExtrato;
  const UltimosSite({super.key, required this.r, required this.irExtrato});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ult = r.ateHoje.take(6).toList();
    final novos = idsNovos([for (final l in ult) str(l.doc['id'])]);
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoSite('Últimos lançamentos', sub: mesLongo(r.ym), acao: 'Ver extrato', onAcao: irExtrato),
        if (ult.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Nada lançado neste mês.', style: TextStyle(color: S.muted)))
        else
          Padding(padding: const EdgeInsets.only(top: 6), child: ListaTxSite([
                for (final l in ult) EntradaNova(key: ValueKey(l.doc['id']), novo: novos.contains(str(l.doc['id'])), child: linhaLancSite(context, repo, l)),
              ])),
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


/// Ponto da linha do tempo; o próximo recebimento pulsa de leve.
class _Ponto extends StatefulWidget {
  final Color cor;
  final bool cheio, pulsa;
  const _Ponto({required this.cor, required this.cheio, required this.pulsa});
  @override
  State<_Ponto> createState() => _PontoState();
}

class _PontoState extends State<_Ponto> with SingleTickerProviderStateMixin {
  late final AnimationController an = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  bool iniciou = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (iniciou) return;
    iniciou = true;
    if (widget.pulsa && animacoesLigadas(context)) an.repeat();
  }

  @override
  void dispose() {
    an.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: an,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          if (widget.pulsa)
            Container(
              width: 16 + 14 * an.value,
              height: 16 + 14 * an.value,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.cor.withValues(alpha: .28 * (1 - an.value))),
            ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.cheio ? widget.cor : S.surface,
              border: Border.all(color: widget.cor, width: widget.pulsa ? 3 : 2),
            ),
          ),
        ]),
      );
}

/// Recebimento que já entrou: a bolinha vira um check verde com um "estouro".
class _CheckEstoura extends StatelessWidget {
  final Color cor;
  const _CheckEstoura({required this.cor});
  @override
  Widget build(BuildContext context) {
    final liga = animacoesLigadas(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: liga ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (_, v, __) => Transform.scale(
        scale: v,
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: cor, boxShadow: [BoxShadow(color: cor.withValues(alpha: .35), blurRadius: 8 * v)]),
          alignment: Alignment.center,
          child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
        ),
      ),
    );
  }
}


/// Comemoração: mês anterior fechado dentro do limite e objetivos alcançados.
/// O confete sai uma vez só; o cartão fica até a pessoa fechar.
class ComemoracaoSite extends StatefulWidget {
  const ComemoracaoSite({super.key});
  @override
  State<ComemoracaoSite> createState() => _ComemoracaoSiteState();
}

class _ComemoracaoSiteState extends State<ComemoracaoSite> {
  bool soltou = false;

  List<(String chave, String titulo, String texto)> _motivos(Repo repo) {
    final out = <(String, String, String)>[];
    final hoje = hojeIso();
    final ant = ymAdd(ymDe(hoje), -1);
    if (int.parse(hoje.substring(8, 10)) <= 10) {
      final r = ResumoMes.de(repo, ant);
      final lim = r.limiteTotal, g = r.gastoComLimite;
      if (lim > 0 && g > 0 && g <= lim) {
        final mes = mesesLongos[int.parse(ant.substring(5)) - 1];
        out.add(('lim:$ant', '$mes fechou dentro do limite!', 'Você gastou ${brl(g)} de ${brl(lim)} e sobraram ${brl(lim - g)}.'));
      }
    }
    final objs = objetivosDe(repo);
    if (objs.isNotEmpty) {
      final c = calcularCarteira(repo);
      for (final o in objs) {
        final p = progressoDe(o, c);
        if (p.concluido) out.add(('obj:${o.id}', 'Objetivo alcançado: ${o.nome}!', 'Você chegou a ${brl(p.atual)} de ${brl(o.alvo)}.'));
      }
    }
    final fechados = repo.lista('comemorou.fechado').toSet();
    return out.where((m) => !fechados.contains(m.$1)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ms = _motivos(repo);
    if (ms.isEmpty) return const SizedBox.shrink();
    final jaSoltou = repo.lista('comemorou').toSet();
    final novos = ms.where((m) => !jaSoltou.contains(m.$1)).toList();
    if (novos.isNotEmpty && !soltou) {
      soltou = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        soltarConfete(context);
        await repo.guardarLista('comemorou', {...jaSoltou, ...novos.map((m) => m.$1)}.toList());
      });
    }
    final m = ms.first;
    final ouro = const Color(0xFFD9A21B);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [ouro.withValues(alpha: .22), S.pos.withValues(alpha: .14)]),
          border: Border.all(color: ouro.withValues(alpha: .45)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: ouro, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: S.ink)),
              const SizedBox(height: 2),
              Text(m.$3, style: TextStyle(fontSize: 12.5, color: S.ink2, height: 1.4)),
            ]),
          ),
          IconButton(
            tooltip: 'Fechar',
            visualDensity: VisualDensity.compact,
            onPressed: () => repo.guardarLista('comemorou.fechado', {...repo.lista('comemorou.fechado'), m.$1}.toList()),
            icon: Icon(Icons.close_rounded, size: 20, color: S.ink2),
          ),
        ]),
      ),
    );
  }
}
