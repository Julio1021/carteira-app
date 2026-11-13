// Peças do Início: luz de fundo e linha do mês no cartão principal, e a
// faixa "Para você" (retrospectiva + descobertas automáticas sobre o mês).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dados/analise.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';
import '../widgets/painel.dart';
import 'retro.dart';

/// Manchas de luz suaves no fundo do cartão principal.
class Aurora extends CustomPainter {
  final Color a, b;
  const Aurora({this.a = const Color(0x30FFFFFF), this.b = const Color(0x2E8FB0FF)});
  @override
  void paint(Canvas canvas, Size s) {
    void luz(Offset c, double r, Color cor) =>
        canvas.drawCircle(c, r, Paint()..shader = RadialGradient(colors: [cor, cor.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)));
    luz(Offset(s.width * .95, -s.height * .05), s.width * .62, a);
    luz(Offset(-s.width * .05, s.height * 1.02), s.width * .58, b);
  }

  @override
  bool shouldRepaint(Aurora o) => o.a != a || o.b != b;
}

/// Sobra acumulada dia a dia (entrou − saiu) até hoje ou até o fim do mês.
List<double> sobraDiaADia(ResumoMes r, {String? hoje}) {
  final h = hoje ?? hojeIso();
  final n = diasNoMes(r.ym);
  final ate = ymDe(h) == r.ym ? int.parse(h.substring(8, 10)).clamp(1, n).toInt() : n;
  final dia = List.filled(n + 1, 0.0);
  int d(String data) => data.startsWith(r.ym) ? int.parse(data.substring(8, 10)).clamp(1, n).toInt() : (data.compareTo('${r.ym}-01') < 0 ? 1 : n);
  for (final g in r.gastos) {
    dia[d(g.data)] -= g.valor;
  }
  for (final e in r.entradas) {
    if (!e.entreContas) dia[d(e.data)] += e.valor;
  }
  final out = <double>[];
  var soma = 0.0;
  for (var k = 1; k <= ate; k++) {
    soma += dia[k];
    out.add(soma);
  }
  return out;
}

/// Linha fina com a sobra do mês dia a dia, desenhada da esquerda para a direita.
class LinhaMes extends StatelessWidget {
  final List<double> pontos;
  final Color cor;
  final double altura;
  const LinhaMes(this.pontos, {super.key, this.cor = Colors.white, this.altura = 44});
  @override
  Widget build(BuildContext context) {
    if (pontos.length < 2) return const SizedBox.shrink();
    Widget pinta(double v) => CustomPaint(size: Size(double.infinity, altura), painter: _LinhaPainter(pontos, cor, v));
    if (semAnimacao(context)) return pinta(1);
    return TweenAnimationBuilder<double>(
      key: ValueKey(pontos.length),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => pinta(v),
    );
  }
}

class _LinhaPainter extends CustomPainter {
  final List<double> p;
  final Color cor;
  final double v;
  _LinhaPainter(this.p, this.cor, this.v);
  @override
  void paint(Canvas canvas, Size s) {
    var mn = p.reduce(math.min), mx = p.reduce(math.max);
    // a escala acompanha os valores do mês (sem prender no zero), para a
    // variação aparecer mesmo quando o salário entra logo no dia 1
    if (mx - mn < 1e-6) mx = mn + 1;
    final folga = (mx - mn) * .12;
    mn -= folga;
    const topo = 6.0, base = 6.0;
    final h = s.height - topo - base;
    Offset pt(int i) => Offset(s.width * i / (p.length - 1), topo + h * (1 - (p[i] - mn) / (mx - mn)));
    final linha = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < p.length; i++) {
      final a = pt(i - 1), b = pt(i);
      final cx = (a.dx + b.dx) / 2;
      linha.cubicTo(cx, a.dy, cx, b.dy, b.dx, b.dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, s.width * v + 6, s.height));
    final area = Path.from(linha)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [cor.withValues(alpha: .26), cor.withValues(alpha: 0)]).createShader(Offset.zero & s),
    );
    // linha do zero (onde a sobra vira falta)
    final yZero = topo + h * (1 - (0 - mn) / (mx - mn));
    if (mn < 0 && mx > 0 && p.any((x) => x < 0)) canvas.drawLine(Offset(0, yZero), Offset(s.width, yZero), Paint()..color = cor.withValues(alpha: .25)..strokeWidth = 1);
    canvas.drawPath(
      linha,
      Paint()
        ..color = cor.withValues(alpha: .95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
    if (v > .97) {
      final fim = pt(p.length - 1);
      canvas.drawCircle(fim, 7, Paint()..color = cor.withValues(alpha: .25));
      canvas.drawCircle(fim, 3.6, Paint()..color = cor);
    }
  }

  @override
  bool shouldRepaint(_LinhaPainter o) => o.v != v || o.p != p || o.cor != cor;
}

/// Saudação pelo horário.
String saudacao([DateTime? agora]) {
  final h = (agora ?? DateTime.now()).hour;
  return h < 5 ? 'Boa noite' : (h < 12 ? 'Bom dia' : (h < 18 ? 'Boa tarde' : 'Boa noite'));
}

String dataPorExtenso([DateTime? agora]) {
  final d = agora ?? DateTime.now();
  const dias = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
  return '${dias[d.weekday - 1]}, ${d.day} de ${mesesLongos[d.month - 1].toLowerCase()}';
}

class _Item {
  final IconData icone;
  final Color cor;
  final String antes, forte, depois;
  const _Item(this.icone, this.cor, this.antes, this.forte, this.depois);
}

/// Faixa "Para você": retrospectiva e descobertas sobre o mês, lado a lado.
class FaixaDescobertas extends StatelessWidget {
  final String ym;
  const FaixaDescobertas({super.key, required this.ym});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final r = ResumoMes.de(repo, ym);
    final hoje = hojeIso();
    final itens = <_Item>[];
    // previsão de fechamento, só no mês atual e com alguns dias de dados
    if (ymDe(hoje) == ym && r.saiu > 0) {
      final dia = int.parse(hoje.substring(8, 10));
      if (dia >= 5 && dia < diasNoMes(ym)) {
        final previsto = r.saiu / dia * diasNoMes(ym);
        final sobra = r.entrou - previsto;
        itens.add(_Item(
          Icons.insights_rounded,
          sobra >= 0 ? G.pos : G.alerta,
          'Nesse ritmo, o mês fecha ',
          sobra >= 0 ? 'com sobra de ${brl(sobra)}' : 'faltando ${brl(-sobra)}',
          '.',
        ));
      }
    }
    IconData ic(String t) => switch (t) {
          'maior' => Icons.shopping_bag_outlined,
          'sobe' => Icons.trending_up_rounded,
          'desce' => Icons.trending_down_rounded,
          'semgasto' => Icons.event_available_rounded,
          'semana' => Icons.calendar_view_week_rounded,
          'invest' => Icons.savings_outlined,
          _ => Icons.auto_awesome_rounded,
        };
    for (final d in destaquesDoMes(repo, ym).take(4)) {
      itens.add(_Item(ic(d.tipo), d.tom > 0 ? G.pos : (d.tom < 0 ? G.alerta : G.lavanda), d.antes, d.forte, d.depois));
    }
    final mesRetro = mesDaRetro(repo, ym);
    final temRetro = repo.gastos.any((g) => g.data.startsWith(mesRetro)) || repo.entradas.any((e) => e.data.startsWith(mesRetro));
    if (!temRetro && itens.isEmpty) return const SizedBox.shrink();
    final nomeMes = mesesLongos[int.parse(mesRetro.substring(5, 7)) - 1].toLowerCase();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TituloSecao('Para você'),
      SizedBox(
        height: 118,
        child: ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          children: [
            if (temRetro) _CartaoRetro(mes: nomeMes, onTap: () => abrirRetro(context, mesRetro)),
            for (final it in itens)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: SizedBox(
                  width: 226,
                  child: Cartao(
                    padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: it.cor.withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
                        child: Icon(it.icone, size: 17, color: it.cor),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: it.antes),
                            TextSpan(text: it.forte, style: TextStyle(fontWeight: FontWeight.w700, color: G.texto)),
                            TextSpan(text: it.depois),
                          ]),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: G.texto2, fontSize: 13, height: 1.3),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    ]);
  }
}

class _CartaoRetro extends StatelessWidget {
  final String mes;
  final VoidCallback onTap;
  const _CartaoRetro({required this.mes, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(20);
    return Toque(
      escala: .96,
      child: Container(
        width: 168,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6C4DE6), Color(0xFF2A52D6), Color(0xFF14B8A6)], stops: [0, .55, 1]),
          boxShadow: const [BoxShadow(color: Color(0x592A52D6), blurRadius: 22, offset: Offset(0, 10), spreadRadius: -8)],
        ),
        child: Stack(fit: StackFit.expand, children: [
          const Positioned.fill(child: CustomPaint(painter: Aurora(a: Color(0x40FFFFFF), b: Color(0x00FFFFFF)))),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 12, 11),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 17),
                    const Spacer(),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                    ),
                  ]),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          const Text('Retrospectiva', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -.3)),
                          Text('Como foi $mes', style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 12.5)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
