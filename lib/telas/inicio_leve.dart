// Início no visual Leve: poucos blocos, brancos, com uma informação cada.
// O que é menos usado mora no menu "Mais" (Retrospectiva, relatórios, etc.).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/categorias.dart';
import '../dados/patrimonio.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';
import 'inicio_nuvem.dart' show curtoBr;

/// Troca de mês discreta, no topo do Início: ‹ novembro de 2026 ›
class MesLeve extends StatelessWidget {
  final String ym;
  final ValueChanged<String> onMes;
  const MesLeve({super.key, required this.ym, required this.onMes});
  @override
  Widget build(BuildContext context) {
    final atual = ym == ymDe(hojeIso());
    Widget seta(IconData i, int n, String t) => IconButton(
          tooltip: t,
          visualDensity: VisualDensity.compact,
          onPressed: () {
            HapticFeedback.selectionClick();
            onMes(ymAdd(ym, n));
          },
          icon: Icon(i, color: G.apagado, size: 22),
        );
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      seta(Icons.chevron_left_rounded, -1, 'Mês anterior'),
      GestureDetector(
        onTap: atual ? null : () => onMes(ymDe(hojeIso())),
        child: SizedBox(
          width: 170,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(mesLongo(ym), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            if (!atual) Text('voltar para hoje', style: TextStyle(fontSize: 11, color: G.lavanda, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
      seta(Icons.chevron_right_rounded, 1, 'Próximo mês'),
    ]);
  }
}

/// Saldo em conta (ou a sobra do mês) e, embaixo, receitas e despesas.
class ResumoLeve extends StatelessWidget {
  final ResumoMes r;
  final VoidCallback onEntradas, onSaidas;
  const ResumoLeve({super.key, required this.r, required this.onEntradas, required this.onSaidas});
  @override
  Widget build(BuildContext context) {
    final emConta = r.emConta;
    final sobra = r.sobra;
    Widget lado(String rot, double v, IconData ic, Color cor, VoidCallback onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: cor.withValues(alpha: G.claro ? .12 : .2), shape: BoxShape.circle),
                  child: Icon(ic, color: cor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rot, style: TextStyle(color: G.apagado, fontSize: 12.5)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: ValorBrl(v, estilo: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cor)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        );
    return Cartao(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(emConta != null ? 'Saldo em contas' : 'Sobra do mês', textAlign: TextAlign.center, style: TextStyle(color: G.apagado, fontSize: 12.5)),
        const SizedBox(height: 4),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ValorBrl(emConta ?? sobra, estilo: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -.8, color: (emConta ?? sobra) < 0 ? G.neg : G.texto)),
          ),
        ),
        if (emConta != null && (r.entrou > 0 || r.saiu > 0)) ...[
          const SizedBox(height: 2),
          Text(
            sobra >= 0 ? 'Sobraram ${brl(sobra)} neste mês' : 'Saiu ${brl(-sobra)} a mais do que entrou',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: sobra >= 0 ? G.pos : G.negTexto, fontWeight: FontWeight.w500),
          ),
        ],
        const SizedBox(height: 12),
        Divider(height: 1, color: G.borda),
        const SizedBox(height: 8),
        Row(children: [
          lado('Receitas', r.entrou, Icons.arrow_upward_rounded, G.pos, onEntradas),
          const SizedBox(width: 10),
          lado('Despesas', r.saiu, Icons.arrow_downward_rounded, G.saida, onSaidas),
        ]),
      ]),
    );
  }
}

/// Gastos do mês por categoria: anel fino e as maiores categorias ao lado.
class GastosLeve extends StatelessWidget {
  final ResumoMes r;
  final ValueChanged<String> onCategoria;
  final VoidCallback onVer;
  const GastosLeve({super.key, required this.r, required this.onCategoria, required this.onVer});
  @override
  Widget build(BuildContext context) {
    final itens = r.porCategoria.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = itens.fold<double>(0, (a, e) => a + e.value);
    final top = itens.take(5).toList();
    final resto = total - top.fold<double>(0, (a, e) => a + e.value);
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoCartao('Gastos por categoria', acao: itens.isEmpty ? null : 'Ver tudo', onAcao: onVer),
        if (itens.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Nenhum gasto neste mês.', style: TextStyle(color: G.apagado)))
        else
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: _Anel([for (final e in top) e.value, if (resto > 0) resto], [for (final e in top) catGasto(e.key).cor, if (resto > 0) G.v(0x22)]),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('total', style: TextStyle(fontSize: 11, color: G.apagado)),
                    Text(curtoBr(total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(children: [
                for (final e in top)
                  InkWell(
                    onTap: () => onCategoria(e.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: catGasto(e.key).cor, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(catGasto(e.key).nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
                        Text(brl(e.value), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
      ]),
    );
  }
}

class _Anel extends CustomPainter {
  final List<double> v;
  final List<Color> c;
  _Anel(this.v, this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final tot = v.fold<double>(0, (a, b) => a + b);
    if (tot <= 0) return;
    const esp = 10.0;
    final rect = Rect.fromLTWH(esp / 2, esp / 2, s.width - esp, s.height - esp);
    var ang = -math.pi / 2;
    final gap = v.length > 1 ? .035 : 0.0;
    for (var i = 0; i < v.length; i++) {
      final a = v[i] / tot * math.pi * 2;
      canvas.drawArc(
        rect,
        ang + gap / 2,
        math.max(0.001, a - gap),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = esp
          ..color = c[i],
      );
      ang += a;
    }
  }

  @override
  bool shouldRepaint(_Anel o) => o.v.toString() != v.toString();
}

/// Limite do mês numa linha: barra fina, quanto foi e quanto sobra por dia.
class LimiteLeve extends StatelessWidget {
  final ResumoMes r;
  final VoidCallback onTap;
  const LimiteLeve({super.key, required this.r, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final lim = r.limiteTotal;
    if (lim <= 0) {
      return Cartao(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(children: [
          Icon(Icons.speed_rounded, color: G.lavanda, size: 22),
          const SizedBox(width: 12),
          const Expanded(child: Text('Definir um limite de gastos', style: TextStyle(fontWeight: FontWeight.w600))),
          Icon(Icons.chevron_right_rounded, color: G.apagado),
        ]),
      );
    }
    final g = r.gastoComLimite;
    final uso = g / lim;
    final resta = lim - g;
    final hoje = hojeIso();
    final mesAtual = ymDe(hoje) == r.ym;
    final dias = mesAtual ? diasNoMes(r.ym) - int.parse(hoje.substring(8, 10)) + 1 : 0;
    final cor = uso > 1 ? G.neg : (uso >= .8 ? G.alerta : G.lavanda);
    return Cartao(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(r.temLimiteGeral ? 'Limite do mês' : 'Limites das categorias', style: const TextStyle(fontWeight: FontWeight.w600))),
          Text('${(uso * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w700, color: cor)),
        ]),
        const SizedBox(height: 10),
        Barra(uso, cor: cor, altura: 6),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('${brl(g)} de ${brl(lim)}', style: TextStyle(fontSize: 12.5, color: G.apagado))),
          Text(
            resta < 0 ? 'passou ${brl(-resta)}' : (dias > 0 ? '${brl(resta / dias)}/dia livre' : 'sobraram ${brl(resta)}'),
            style: TextStyle(fontSize: 12.5, color: resta < 0 ? G.negTexto : G.apagado, fontWeight: FontWeight.w500),
          ),
        ]),
      ]),
    );
  }
}

/// Investimentos numa linha: total e a variação de 30 dias.
class InvestLeve extends StatelessWidget {
  final VoidCallback onTap;
  const InvestLeve({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = calcularCarteira(RepoScope.of(context));
    final dias = c.dias;
    final total = dias.isEmpty ? 0.0 : dias.last.total;
    final corte30 = addDias(hojeIso(), -30);
    double? base30;
    for (final d in dias) {
      if (d.data.compareTo(corte30) >= 0) {
        base30 = d.total;
        break;
      }
    }
    final var30 = base30 != null && base30 > 0 && dias.isNotEmpty ? total / base30 - 1 : null;
    return Cartao(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: G.lavandaFundo, shape: BoxShape.circle),
          child: Icon(Icons.trending_up_rounded, color: G.lavandaIcone, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Investimentos', style: TextStyle(color: G.apagado, fontSize: 12.5)),
            if (dias.isEmpty)
              const Text('Comece a acompanhar', style: TextStyle(fontWeight: FontWeight.w600))
            else
              ValorBrl(total, estilo: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: G.texto)),
          ]),
        ),
        if (var30 != null)
          Text('${var30 >= 0 ? '+' : '−'}${(var30.abs() * 100).toStringAsFixed(1).replaceAll('.', ',')}% em 30 dias',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: var30 >= 0 ? G.pos : G.negTexto)),
        Icon(Icons.chevron_right_rounded, color: G.apagado),
      ]),
    );
  }
}
