// Objetivos: cartões com anel de progresso, previsão de chegada e formulário.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/modelos.dart';
import '../dados/objetivos.dart';
import '../dados/patrimonio.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/formulario.dart';
import '../widgets/movimento.dart';
import '../widgets/painel.dart';

const iconesObjetivo = <IconData>[
  Icons.flag_rounded,
  Icons.shield_rounded,
  Icons.flight_takeoff_rounded,
  Icons.directions_car_rounded,
  Icons.home_rounded,
  Icons.school_rounded,
  Icons.beach_access_rounded,
  Icons.favorite_rounded,
];

IconData iconeObjetivo(int i) => iconesObjetivo[i.clamp(0, iconesObjetivo.length - 1).toInt()];

String _mesAno(String ym) => '${mesesAbr[int.parse(ym.substring(5, 7)) - 1]}/${ym.substring(0, 4)}';

/// Anel de progresso que se enche ao aparecer.
class Anel extends StatelessWidget {
  final double frac; // 0..1
  final double tam, espessura;
  final Color cor;
  final Color? trilho;
  final Widget? centro;
  const Anel({super.key, required this.frac, required this.cor, this.tam = 64, this.espessura = 7, this.trilho, this.centro});
  @override
  Widget build(BuildContext context) {
    final t = trilho ?? G.v(0x18);
    Widget pinta(double v) => CustomPaint(
          size: Size.square(tam),
          painter: _AnelPainter(v, cor, t, espessura),
          child: SizedBox(width: tam, height: tam, child: Center(child: centro)),
        );
    if (semAnimacao(context)) return pinta(frac);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: frac),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => pinta(v),
    );
  }
}

class _AnelPainter extends CustomPainter {
  final double v, esp;
  final Color cor, trilho;
  _AnelPainter(this.v, this.cor, this.trilho, this.esp);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.shortestSide - esp) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = esp
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, base..color = trilho);
    if (v <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = esp
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [cor.withValues(alpha: .55), cor],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v.clamp(0, 1), false, p);
  }

  @override
  bool shouldRepaint(_AnelPainter o) => o.v != v || o.cor != cor || o.trilho != trilho;
}

/// Seção "Objetivos" da Visão geral do Patrimônio.
class CartaoObjetivos extends StatelessWidget {
  final Carteira c;
  const CartaoObjetivos({super.key, required this.c});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final lista = objetivosDe(repo);
    final hoje = hojeIso();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TituloSecao(
        'Objetivos',
        direita: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () => abrirFolha(context, const FormObjetivo()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 16, color: G.lavanda),
              const SizedBox(width: 2),
              Text('Novo', style: TextStyle(color: G.lavanda, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ]),
          ),
        ),
      ),
      if (lista.isEmpty)
        Cartao(
          onTap: () => abrirFolha(context, const FormObjetivo()),
          child: Row(children: [
            Anel(frac: .68, cor: G.lavanda, tam: 52, espessura: 6, centro: Icon(Icons.flag_rounded, size: 20, color: G.lavanda)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Crie seu primeiro objetivo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text('Reserva, viagem, carro… veja quanto falta e quando chega lá.', style: TextStyle(color: G.apagado, fontSize: 12.5, height: 1.3)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: G.apagado),
          ]),
        )
      else
        for (var i = 0; i < lista.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _LinhaObjetivo(p: progressoDe(lista[i], c, hoje: hoje), hoje: hoje),
        ],
      const SizedBox(height: 14),
    ]);
  }
}

class _LinhaObjetivo extends StatelessWidget {
  final Progresso p;
  final String hoje;
  const _LinhaObjetivo({required this.p, required this.hoje});
  @override
  Widget build(BuildContext context) {
    final o = p.o;
    const ouro = Color(0xFFD9A21E);
    final cor = p.concluido ? ouro : G.lavanda;
    final prev = p.previsao(hoje);
    final porMes = p.porMesParaPrazo(hoje);
    final atrasado = p.atrasado(hoje);
    String linha;
    if (p.concluido) {
      linha = 'Objetivo alcançado!';
    } else if (o.prazo != null && porMes != null) {
      linha = atrasado ? 'Para ${_mesAno(o.prazo!)}: precisa de ${brl(porMes)}/mês' : 'No ritmo para ${_mesAno(o.prazo!)}';
    } else if (prev != null) {
      linha = 'No ritmo atual, chega em ${_mesAno(prev)}';
    } else {
      linha = 'Faltam ${brl(p.falta)}';
    }
    return Cartao(
      onTap: () => abrirFolha(context, FormObjetivo(doc: o.d)),
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Row(children: [
        Anel(
          frac: p.frac,
          cor: cor,
          centro: p.concluido
              ? const Icon(Icons.check_rounded, color: ouro, size: 26)
              : Text('${(p.frac * 100).floor()}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: G.texto)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(iconeObjetivo(o.icone), size: 15, color: cor),
              const SizedBox(width: 6),
              Expanded(child: Text(o.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            ]),
            const SizedBox(height: 3),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: brl(p.atual), style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' de ${brl(o.alvo)}', style: TextStyle(color: G.apagado)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 3),
            Row(children: [
              if (atrasado) ...[Icon(Icons.schedule_rounded, size: 13, color: G.alerta), const SizedBox(width: 4)],
              Expanded(child: Text(linha, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.concluido ? ouro : (atrasado ? G.alerta : G.apagado), fontWeight: p.concluido ? FontWeight.w700 : FontWeight.w500))),
            ]),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: G.apagado),
      ]),
    );
  }
}

/// Criar ou editar um objetivo.
class FormObjetivo extends StatefulWidget {
  final Doc? doc;
  const FormObjetivo({super.key, this.doc});
  @override
  State<FormObjetivo> createState() => _FormObjetivoState();
}

class _FormObjetivoState extends State<FormObjetivo> {
  late final nomeC = TextEditingController(text: widget.doc == null ? '' : Objetivo(widget.doc!).nome);
  late final valorC = TextEditingController(text: widget.doc == null ? '' : valorCampo(Objetivo(widget.doc!).alvo));
  late final guardC = TextEditingController(text: widget.doc == null || Objetivo(widget.doc!).guardado == 0 ? '' : valorCampo(Objetivo(widget.doc!).guardado));
  late String fonte = widget.doc == null ? 'total' : Objetivo(widget.doc!).fonte;
  late String? ativo = widget.doc == null ? null : Objetivo(widget.doc!).ativo;
  late String? prazo = widget.doc == null ? null : Objetivo(widget.doc!).prazo;
  late int icone = widget.doc == null ? 0 : Objetivo(widget.doc!).icone;
  String? erro;

  @override
  void dispose() {
    nomeC.dispose();
    valorC.dispose();
    guardC.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final v = lerValor(valorC.text);
    if (nomeC.text.trim().isEmpty) {
      setState(() => erro = 'Dê um nome ao objetivo.');
      return;
    }
    if (v == null || v <= 0) {
      setState(() => erro = 'Informe o valor que você quer alcançar.');
      return;
    }
    if (fonte == 'ativo' && ativo == null) {
      setState(() => erro = 'Escolha o ativo que acompanha este objetivo.');
      return;
    }
    final repo = RepoScope.ler(context);
    final antigo = widget.doc;
    final novo = docObjetivo(
      id: antigo == null ? null : str(antigo['id']),
      nome: nomeC.text.trim(),
      valor: v,
      fonte: fonte,
      ativo: fonte == 'ativo' ? ativo : null,
      guardado: lerValor(guardC.text) ?? 0,
      prazo: prazo,
      icone: icone,
      criado: antigo == null ? null : numI(antigo['criado']),
    );
    await repo.salvar(novo);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    Navigator.pop(context);
    avisar(context, antigo == null ? 'Objetivo criado.' : 'Objetivo atualizado.');
  }

  Future<void> _excluir() async {
    final nav = Navigator.of(context);
    final repo = RepoScope.ler(context);
    if (!await confirmar(context, 'Excluir objetivo?', '“${nomeC.text}” será apagado. Seus investimentos não mudam.')) return;
    await repo.apagar(str(widget.doc!['id']));
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = calcularCarteira(RepoScope.of(context));
    final h = ymDe(hojeIso());
    return CorpoFolha([
      TituloFolha(widget.doc == null ? 'Novo objetivo' : 'Editar objetivo', onExcluir: widget.doc == null ? null : _excluir),
      const SizedBox(height: 10),
      TextField(
        controller: nomeC,
        autofocus: widget.doc == null,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Reserva de emergência'),
      ),
      const SizedBox(height: 12),
      CampoValor(valorC, rotulo: 'Quanto você quer juntar'),
      const Rotulo('Ícone'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < iconesObjetivo.length; i++)
          Toque(
            escala: .9,
            child: GestureDetector(
              onTap: () => setState(() => icone = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: i == icone ? G.lavandaFundo : G.v(0x0C),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: i == icone ? G.lavanda : G.borda, width: i == icone ? 1.6 : 1),
                ),
                child: Icon(iconesObjetivo[i], size: 20, color: i == icone ? G.lavanda : G.texto2),
              ),
            ),
          ),
      ]),
      const Rotulo('Acompanhar por'),
      Opcoes<String>(
        itens: const [('total', 'Tudo o que está investido'), ('ativo', 'Um ativo'), ('manual', 'Eu informo o valor')],
        valor: fonte,
        onMudar: (v) => setState(() => fonte = v),
      ),
      if (fonte == 'ativo') ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: c.posicoes.any((p) => p.a.id == ativo) ? ativo : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ativo'),
          dropdownColor: G.fundo2,
          items: [for (final p in c.posicoes) DropdownMenuItem(value: p.a.id, child: Text('${p.a.nome} · ${brl(p.valor)}', overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => ativo = v),
        ),
      ],
      if (fonte == 'manual') ...[
        const SizedBox(height: 12),
        CampoValor(guardC, rotulo: 'Quanto já tem guardado'),
      ],
      const SizedBox(height: 6),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: prazo != null,
        onChanged: (v) => setState(() => prazo = v ? ymAdd(h, 12) : null),
        title: const Text('Tenho um prazo', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Mostra quanto precisa por mês para chegar a tempo', style: TextStyle(color: G.apagado, fontSize: 12.5)),
      ),
      if (prazo != null) CampoMes(ym: prazo!, rotulo: 'Até', onMudar: (v) => setState(() => prazo = v)),
      if (erro != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(erro!, style: TextStyle(color: G.neg))),
      const SizedBox(height: 18),
      FilledButton(onPressed: _salvar, child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(widget.doc == null ? 'Criar objetivo' : 'Salvar'))),
    ]);
  }
}
