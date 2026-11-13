// Visual "Nuvem" do Início: cartão principal sólido, medidor do limite,
// investido com linha, categorias em círculos (como "stories") e saudação.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dados/categorias.dart';
import '../dados/patrimonio.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';

/// true quando o tema escolhido é um dos três do visual Nuvem.
bool get visualNuvem => G.claro && G.nuvem != null;

/// Nome para a saudação ("Olá, Júlio"). Vazio = sem nome.
final nomeUsuario = ValueNotifier<String>('');

Future<void> carregarNome() async {
  try {
    final sp = await SharedPreferences.getInstance();
    nomeUsuario.value = sp.getString('nome') ?? '';
  } catch (_) {}
}

Future<void> definirNome(String v) async {
  nomeUsuario.value = v.trim();
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('nome', v.trim());
  } catch (_) {}
}

/// Avatar com anel colorido (inicial do nome, ou a carteira).
class AvatarNuvem extends StatelessWidget {
  final double tam;
  final VoidCallback? onTap;
  const AvatarNuvem({super.key, this.tam = 44, this.onTap});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: nomeUsuario,
      builder: (_, nome, __) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: tam,
          height: tam,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [G.lavanda, const Color(0xFF7CE0C3), const Color(0xFFF0A23B), G.lavanda]),
          ),
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: G.fundo2, border: Border.all(color: G.fundo2, width: 1.5)),
            alignment: Alignment.center,
            child: nome.isEmpty
                ? Icon(Icons.account_balance_wallet_rounded, size: tam * .44, color: G.lavanda)
                : Text(nome.characters.first.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: tam * .38, color: G.lavanda)),
          ),
        ),
      ),
    );
  }
}

/// "R$ 2.892" grande e ",76" menor e mais claro.
class ValorPartido extends StatelessWidget {
  final double valor;
  final double tam;
  final Color cor, corCentavos;
  const ValorPartido(this.valor, {super.key, this.tam = 40, this.cor = Colors.white, this.corCentavos = const Color(0x99FFFFFF)});
  @override
  Widget build(BuildContext context) {
    Widget texto(double v) {
      final s = brl(v);
      final i = s.lastIndexOf(',');
      final base = TextStyle(fontSize: tam, fontWeight: FontWeight.w800, letterSpacing: -tam * .045, color: cor, height: 1.05);
      return Text.rich(
        i < 0
            ? TextSpan(text: s, style: base)
            : TextSpan(children: [
                TextSpan(text: s.substring(0, i), style: base),
                TextSpan(text: s.substring(i), style: base.copyWith(fontSize: tam * .52, color: corCentavos, letterSpacing: -.4)),
              ]),
        maxLines: 1,
      );
    }

    final filho = semAnimacao(context)
        ? texto(valor)
        : TweenAnimationBuilder<double>(
            tween: Tween<double>(end: valor),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => texto(v),
          );
    return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: filho);
  }
}

/// Cartão principal do Nuvem.
class HeroNuvem extends StatelessWidget {
  final ResumoMes r;
  final ValueChanged<String> onMes;
  final VoidCallback onEntrou, onSaiu;
  const HeroNuvem({super.key, required this.r, required this.onMes, required this.onEntrou, required this.onSaiu});

  @override
  Widget build(BuildContext context) {
    final principal = r.emConta;
    final atual = ymDe(hojeIso()) == r.ym;
    final nomeMes = mesesLongos[int.parse(r.ym.substring(5, 7)) - 1];
    Widget seta(IconData ic, int n, String dica) => Tooltip(
          message: dica,
          child: InkResponse(
            onTap: () => onMes(ymAdd(r.ym, n)),
            radius: 20,
            child: Padding(padding: const EdgeInsets.all(4), child: Icon(ic, size: 20, color: Colors.white)),
          ),
        );
    return Escuro(
      child: Container(
        decoration: BoxDecoration(
          gradient: GH.gradHero,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: GH.sombra, blurRadius: 34, offset: const Offset(0, 18), spreadRadius: -18)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // brilho suave no canto
          Positioned(
            right: -60,
            top: -80,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)])),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(principal != null ? 'Em conta' : 'Sobra do mês', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: GH.texto2, fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
                // seletor de mês compacto
                Container(
                  decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(99)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    seta(Icons.chevron_left_rounded, -1, 'Mês anterior'),
                    GestureDetector(
                      onTap: atual ? null : () => onMes(ymDe(hojeIso())),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text('$nomeMes${atual ? '' : ' ${r.ym.substring(0, 4)}'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                    seta(Icons.chevron_right_rounded, 1, 'Próximo mês'),
                  ]),
                ),
              ]),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .08), end: Offset.zero).animate(a), child: c)),
                child: KeyedSubtree(
                  key: ValueKey(r.ym),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ValorPartido(principal ?? r.sobra, corCentavos: GH.texto2.withValues(alpha: .7)),
                    if (principal != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
                        decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(99)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(r.sobra >= 0 ? Icons.north_east_rounded : Icons.south_east_rounded, size: 15, color: r.sobra >= 0 ? Colors.white : const Color(0xFFFFC2B8)),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              r.sobra >= 0 ? 'Sobraram ${brl(r.sobra)} ${atual ? 'este mês' : 'no mês'}' : 'Faltaram ${brl(-r.sobra)} ${atual ? 'este mês' : 'no mês'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: r.sobra >= 0 ? Colors.white : const Color(0xFFFFC2B8)),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(children: [
                  Expanded(child: _Fluxo('Entrou', r.entrou, Icons.south_west_rounded, const [Color(0xFF3DDC97), Color(0xFF12A26E)], onEntrou)),
                  const SizedBox(width: 10),
                  Expanded(child: _Fluxo('Saiu', r.saiu, Icons.north_east_rounded, const [Color(0xFFF59A7E), Color(0xFFD9533F)], onSaiu)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Fluxo extends StatelessWidget {
  final String rotulo;
  final double valor;
  final IconData icone;
  final List<Color> cores;
  final VoidCallback onTap;
  const _Fluxo(this.rotulo, this.valor, this.icone, this.cores, this.onTap);
  @override
  Widget build(BuildContext context) {
    return Toque(
      child: Material(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: cores)),
                child: Icon(icone, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rotulo, style: TextStyle(color: GH.texto2, fontWeight: FontWeight.w600, fontSize: 11.5)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(brl(valor).replaceFirst('R\$ ', ''), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Os dois quadros abaixo do cartão: limite (medidor) e investido (linha).
class QuadrosNuvem extends StatelessWidget {
  final ResumoMes r;
  final VoidCallback onLimite, onInvestido, onInvestiu;
  const QuadrosNuvem({super.key, required this.r, required this.onLimite, required this.onInvestido, required this.onInvestiu});

  @override
  Widget build(BuildContext context) {
    final hoje = hojeIso();
    final mesAtual = ymDe(hoje) == r.ym;
    // esquerda: limite (com medidor) ou, sem limite, quanto investiu no mês
    Widget esquerda;
    if (r.limiteTotal > 0) {
      final uso = r.gastoComLimite / r.limiteTotal;
      final restante = r.limiteTotal - r.gastoComLimite;
      final dias = mesAtual ? diasNoMes(r.ym) - int.parse(hoje.substring(8, 10)) + 1 : 0;
      final estourou = restante < 0;
      esquerda = Cartao(
        onTap: onLimite,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Limite de gastos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: G.texto2)),
          const SizedBox(height: 8),
          Medidor(frac: uso, alerta: estourou || uso > .85),
          const SizedBox(height: 2),
          Center(
            child: Text(
              estourou ? 'passou ${brl(-restante)}' : (mesAtual && dias > 0 ? '${brl(restante / dias)}/dia livre' : '${brl(restante)} livres'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: estourou ? G.neg : G.apagado, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      );
    } else {
      final pct = r.pctInvestido;
      esquerda = Cartao(
        onTap: onInvestiu,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.investiu < 0 ? 'Resgatou no mês' : 'Investiu no mês', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: G.texto2)),
          const SizedBox(height: 10),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(brl(r.investiu.abs()), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 21, letterSpacing: -.6))),
          const SizedBox(height: 8),
          _Pilula(r.investimentos.isEmpty ? 'toque para lançar' : (pct != null && pct > 0 && pct <= 1 ? '${(pct * 100).round()}% da renda' : 'neste mês')),
        ]),
      );
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: esquerda),
        const SizedBox(width: 12),
        Expanded(child: _Investido(onTap: onInvestido)),
      ]),
    );
  }
}

class _Pilula extends StatelessWidget {
  final String t;
  const _Pilula(this.t);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: G.lavandaFundo, borderRadius: BorderRadius.circular(99)),
        child: Text(t, style: TextStyle(color: G.lavanda, fontWeight: FontWeight.w700, fontSize: 11.5)),
      );
}

/// Medidor em meia-lua.
class Medidor extends StatelessWidget {
  final double frac;
  final bool alerta;
  const Medidor({super.key, required this.frac, this.alerta = false});
  @override
  Widget build(BuildContext context) {
    final f = frac.clamp(0.0, 1.0).toDouble();
    Widget pinta(double v) => CustomPaint(
          painter: _MedidorPainter(v, alerta ? G.neg : G.lavanda, G.v(0x14)),
          child: SizedBox(
            height: 70,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text('${(frac * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21, letterSpacing: -.6, color: alerta ? G.neg : G.texto)),
            ),
          ),
        );
    if (semAnimacao(context)) return pinta(f);
    return TweenAnimationBuilder<double>(tween: Tween<double>(begin: 0, end: f), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic, builder: (_, v, __) => pinta(v));
  }
}

class _MedidorPainter extends CustomPainter {
  final double v;
  final Color cor, trilho;
  _MedidorPainter(this.v, this.cor, this.trilho);
  @override
  void paint(Canvas canvas, Size s) {
    const esp = 11.0;
    final r = math.min(s.width / 2 - esp, s.height - esp / 2 - 2);
    final c = Offset(s.width / 2, s.height - 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = esp
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, base..color = trilho);
    if (v <= 0) return;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = esp
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(startAngle: math.pi, endAngle: math.pi * 2, colors: [Color.lerp(cor, Colors.white, .45)!, cor]).createShader(rect);
    canvas.drawArc(rect, math.pi, math.pi * v, false, p);
  }

  @override
  bool shouldRepaint(_MedidorPainter o) => o.v != v || o.cor != cor || o.trilho != trilho;
}

/// Quanto está investido, com a linha dos últimos meses.
class _Investido extends StatelessWidget {
  final VoidCallback onTap;
  const _Investido({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = calcularCarteira(RepoScope.of(context));
    final dias = c.dias;
    final total = dias.isEmpty ? 0.0 : dias.last.total;
    // últimos ~6 meses, no máximo 60 pontos
    final corte = addDias(hojeIso(), -183);
    final ult = dias.where((d) => d.data.compareTo(corte) >= 0).map((d) => d.total).toList();
    final pts = <double>[];
    if (ult.length >= 2) {
      final passo = math.max(1, (ult.length / 60).ceil());
      for (var i = 0; i < ult.length; i += passo) {
        pts.add(ult[i]);
      }
      if (pts.last != ult.last) pts.add(ult.last);
    }
    // variação nos últimos 30 dias (inclui aportes)
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Investido', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: G.texto2)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(total >= 100000 ? 'R\$ ${curtoBr(total)}' : brl(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 21, letterSpacing: -.6)),
        ),
        const Spacer(),
        if (pts.length >= 2) SizedBox(height: 34, width: double.infinity, child: CustomPaint(painter: _Faisca(pts, G.lavanda))),
        const SizedBox(height: 4),
        if (var30 != null)
          Text('${var30 >= 0 ? '+' : '−'}${(var30.abs() * 100).toStringAsFixed(1).replaceAll('.', ',')}% em 30 dias',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: var30 >= 0 ? G.pos : G.neg))
        else
          Text(dias.isEmpty ? 'toque para começar' : 'seu patrimônio', style: TextStyle(fontSize: 11.5, color: G.apagado)),
      ]),
    );
  }
}

/// "65,4 mil" (sem o R$), com privacidade.
String curtoBr(double v) {
  if (valoresOcultos) return '••••';
  if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(1).replaceAll('.', ',')} mi';
  return '${(v / 1e3).toStringAsFixed(1).replaceAll('.', ',')} mil';
}

class _Faisca extends CustomPainter {
  final List<double> p;
  final Color cor;
  _Faisca(this.p, this.cor);
  @override
  void paint(Canvas canvas, Size s) {
    var mn = p.reduce(math.min), mx = p.reduce(math.max);
    if (mx - mn < 1e-6) mx = mn + 1;
    Offset pt(int i) => Offset(s.width * i / (p.length - 1), 3 + (s.height - 6) * (1 - (p[i] - mn) / (mx - mn)));
    final linha = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < p.length; i++) {
      final a = pt(i - 1), b = pt(i), cx = (a.dx + b.dx) / 2;
      linha.cubicTo(cx, a.dy, cx, b.dy, b.dx, b.dy);
    }
    final area = Path.from(linha)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(area, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [cor.withValues(alpha: .28), cor.withValues(alpha: 0)]).createShader(Offset.zero & s));
    canvas.drawPath(
      linha,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Faisca o) => o.p != p || o.cor != cor;
}

/// "Seus gastos": categorias do mês em círculos com anel (parte do total, ou do limite).
class HistoriasGastos extends StatelessWidget {
  final ResumoMes r;
  final ValueChanged<String> onCategoria;
  final VoidCallback onAnalise;
  const HistoriasGastos({super.key, required this.r, required this.onCategoria, required this.onAnalise});
  @override
  Widget build(BuildContext context) {
    final itens = r.porCategoria.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (itens.isEmpty) return const SizedBox.shrink();
    final total = itens.fold<double>(0, (a, e) => a + e.value);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 2, 10),
        child: Row(children: [
          const Expanded(child: Text('Seus gastos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -.3))),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onAnalise,
            child: Padding(padding: const EdgeInsets.all(4), child: Text('Ver extrato', style: TextStyle(color: G.lavanda, fontWeight: FontWeight.w700, fontSize: 13))),
          ),
        ]),
      ),
      SizedBox(
        height: 106,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: itens.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final e = itens[i];
            final cat = catGasto(e.key);
            final lim = r.limites[e.key];
            final temLim = lim != null && lim > 0;
            final frac = temLim ? e.value / lim : e.value / total;
            final passou = temLim && e.value > lim;
            final cor = passou ? G.neg : cat.cor;
            return Toque(
              escala: .92,
              child: GestureDetector(
                onTap: () => onCategoria(e.key),
                child: SizedBox(
                  width: 64,
                  child: Column(children: [
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: Stack(alignment: Alignment.center, children: [
                        CustomPaint(size: const Size.square(62), painter: _AnelCat(frac.clamp(0.0, 1.0).toDouble(), cor)),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: G.fundo2, boxShadow: [BoxShadow(color: G.sombra(0x55), blurRadius: 8, offset: const Offset(0, 2))]),
                          child: Icon(cat.icone, color: cat.cor, size: 23),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Text(valoresOcultos ? '•••' : _semCentavos(e.value), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: passou ? G.neg : G.texto)),
                    Text(cat.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: G.apagado, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  static String _semCentavos(double v) {
    final s = brl(v.roundToDouble()).replaceFirst('R\$ ', '');
    final i = s.lastIndexOf(',');
    return i < 0 ? s : s.substring(0, i);
  }
}

class _AnelCat extends CustomPainter {
  final double v;
  final Color cor;
  _AnelCat(this.v, this.cor);
  @override
  void paint(Canvas canvas, Size s) {
    const esp = 4.0;
    final rect = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - esp / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = esp
      ..color = cor.withValues(alpha: .18));
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * math.max(v, .04), false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = esp
      ..strokeCap = StrokeCap.round
      ..color = cor);
  }

  @override
  bool shouldRepaint(_AnelCat o) => o.v != v || o.cor != cor;
}
