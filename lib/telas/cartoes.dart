import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/modelos.dart';
import '../dados/planejar.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';
import '../widgets/formulario.dart';
import '../widgets/site.dart';
import '../dados/repo.dart';

const coresCartao = ['#820ad1', '#ff7a00', '#00a868', '#1f6feb', '#cc092f', '#3a3f5e', '#c9a227', '#e8467c'];

Color corDe(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.tryParse('FF${h.padLeft(6, '0').substring(0, 6)}', radix: 16) ?? 0xFF820AD1);
}

/// Cartões no formato do site: pílulas dos cartões, o cartão escolhido, a
/// fatura (com as outras faturas em pílulas) e o que já está comprometido.
class TelaCartoes extends StatefulWidget {
  final String? inicial;
  const TelaCartoes({super.key, this.inicial});
  @override
  State<TelaCartoes> createState() => _TelaCartoesState();
}

/// Abre direto num cartão (atalhos antigos).
class TelaCartao extends StatelessWidget {
  final String id;
  const TelaCartao({super.key, required this.id});
  @override
  Widget build(BuildContext context) => TelaCartoes(inicial: id);
}

const _icoLapis = '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>';
const _icoSol = '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>';

class _TelaCartoesState extends State<TelaCartoes> {
  late String? selId = widget.inicial;
  String? fat;

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ccs = cartoes(repo);
    final c = ccs.isEmpty ? null : ccs.firstWhere((x) => x.id == selId, orElse: () => ccs.first);
    return Scaffold(
      backgroundColor: S.bg,
      appBar: AppBar(title: const Text('Cartões de crédito', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 40), children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final x in ccs) Padding(padding: const EdgeInsets.only(right: 8), child: _pilulaCartao(x, x.id == c?.id)),
            _pilulaNovo(),
          ]),
        ),
        const SizedBox(height: 14),
        if (c == null)
          CartaoSite(
            padding: const EdgeInsets.all(18),
            child: Text('Cadastre seus cartões para ver a fatura atual, o limite disponível e as parcelas dos próximos meses.', style: TextStyle(color: S.ink2, fontSize: 13.5, height: 1.5)),
          )
        else
          ..._conteudo(context, repo, c, ccs),
      ]),
    );
  }

  List<Widget> _conteudo(BuildContext context, Repo repo, CartaoCredito c, List<CartaoCredito> ccs) {
          final r = resumoCartao(repo, c);
    final sel = r.faturas.firstWhere((f) => f.ym == (fat ?? r.atual), orElse: () => r.faturaAtual);
    return [
      _CartaoGrande(c: c, r: r),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: BotaoSite('Compra', icone: Ico.mais, onTap: () => abrirFolha(context, FormCompra(cartao: c)))),
        const SizedBox(width: 8),
        Expanded(child: BotaoSite('Editar cartão', icone: _icoLapis, primario: false, onTap: () => abrirFolha(context, FormCartao(doc: c.d)))),
      ]),
      const SizedBox(height: 14),
      _fatura(context, repo, c, r, sel),
      const SizedBox(height: 14),
      _Comprometido(ccs: ccs),
    ];
  }

  Widget _pilulaCartao(CartaoCredito x, bool on) {
    final cor = corDe(x.cor);
    return Material(
      color: S.surface,
      shape: StadiumBorder(side: BorderSide(color: on ? cor : S.line, width: on ? 2 : 1)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => setState(() {
          selId = x.id;
          fat = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: on ? ShapeDecoration(shape: StadiumBorder(side: BorderSide(color: cor.withValues(alpha: .25), width: 3))) : null,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 11, height: 11, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(x.nome, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: S.ink)),
          ]),
        ),
      ),
    );
  }

  Widget _pilulaNovo() => InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => abrirFolha(context, const FormCartao()),
        child: CustomPaint(
          painter: _Tracejado(S.line),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 18, color: S.muted),
              const SizedBox(width: 6),
              Text('Cartão', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: S.muted)),
            ]),
          ),
        ),
      );

  Widget _fatura(BuildContext context, Repo repo, CartaoCredito c, ResumoCartao r, Fatura sel) {
    final porCat = <String, double>{};
    for (final it in sel.itens) {
      porCat[it.cat] = (porCat[it.cat] ?? 0) + it.valor;
    }
    final cats = porCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final corSt = switch (sel.st) { 'aberta' => S.accent, 'paga' => S.pos, 'vencida' => S.neg, _ => S.ink2 };
    final pags = repo.doTipo('cpag').where((p) => p['cartao'] == c.id && p['fat'] == sel.ym).toList();
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Fatura de ${mesLongo(sel.ym).toLowerCase()}', style: TextStyle(fontFamily: S.fonteNum, fontSize: 16.5, fontWeight: FontWeight.w700, color: S.ink, height: 1.5)),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Fecha ${dataBr(sel.fech)} · vence ${dataBr(sel.venc)} · '),
            TextSpan(text: sel.stTexto, style: TextStyle(fontWeight: FontWeight.w700, color: corSt)),
          ]),
          style: TextStyle(fontSize: 12.5, color: S.muted, height: 1.5),
        ),
        const SizedBox(height: 12),
        Text(brl(sel.total), style: TextStyle(fontFamily: S.fonteNum, fontSize: 24, fontWeight: FontWeight.w700, color: S.ink)),
        if (sel.pago > 0) Text('Pago ${brl(sel.pago)} · falta ${brl(sel.falta)}', style: TextStyle(color: S.pos, fontSize: 12.5, fontWeight: FontWeight.w600)),
        if (sel.itens.any((i) => i.prevista)) Text('Inclui parcelas previstas, que ainda vão entrar.', style: TextStyle(color: S.muted, fontSize: 12.5)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in r.faturas)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: f.ym == sel.ym ? S.accentSoft : S.surface,
                  shape: StadiumBorder(side: BorderSide(color: f.ym == sel.ym ? S.accent : S.line)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => setState(() => fat = f.ym),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Text('${mesesAbr[int.parse(f.ym.substring(5)) - 1]}/${f.ym.substring(2, 4)}${f.ym == r.atual ? ' · atual' : ''}',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: f.ym == sel.ym ? S.accent : S.ink2)),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        if (sel.falta > 0 && sel.st != 'futura') ...[
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: BotaoSite('Registrar pagamento desta fatura', icone: Ico.certo, primario: false, onTap: () => _pagar(context, c, sel))),
        ],
        if (cats.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (final e in cats)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: catGasto(e.key).cor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(catGasto(e.key).nome, style: TextStyle(fontSize: 12.5, color: S.ink2)),
                const SizedBox(width: 6),
                Text(brl(e.value), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: S.ink)),
              ]),
          ]),
        ],
        const SizedBox(height: 6),
        if (sel.itens.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text('Nenhuma compra nesta fatura.', style: TextStyle(color: S.muted, fontSize: 13)))
        else
          for (final it in sel.itens)
            InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: it.g == null ? null : () => _opcoesCompra(context, it),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: catGasto(it.cat).cor, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: S.ink)),
                      Text(
                        [if (it.g != null) dataCurta(it.g!.data), catGasto(it.cat).nome, if (it.parcN != null && it.parcN! > 1) 'parcela ${it.parcI}/${it.parcN}', if (it.prevista) 'prevista'].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: it.prevista ? S.accent : S.muted, fontSize: 12),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text(brl(it.valor), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: it.prevista ? S.muted : S.ink2)),
                  if (it.g != null) ...[const SizedBox(width: 10), IconeSite(Ico.lixo, tam: 16, cor: S.muted)],
                ]),
              ),
            ),
        if (pags.isNotEmpty) ...[
          Divider(color: S.line, height: 20),
          Text('Pagamentos desta fatura', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: S.ink2)),
          for (final p in pags)
            Row(children: [
              Icon(Icons.check_circle_rounded, color: S.pos, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${brl(numD(p['valor']))} em ${dataBr(str(p['data'], sel.venc))}', style: TextStyle(fontSize: 13, color: S.ink))),
              TextButton(
                onPressed: () async {
                  if (await confirmar(context, 'Desfazer este pagamento?', 'O valor volta a faltar na fatura.', sim: 'Desfazer')) await repo.apagar(str(p['id']));
                },
                child: const Text('Desfazer'),
              ),
            ]),
        ],
      ]),
    );
  }

  Future<void> _pagar(BuildContext context, CartaoCredito c, Fatura f) async {
    final vc = TextEditingController(text: valorCampo(f.falta));
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Pagar fatura de ${mesLongo(f.ym).toLowerCase()}'),
        content: CampoValor(vc, rotulo: 'Valor pago', autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Registrar')),
        ],
      ),
    );
    final v = lerValor(vc.text);
    if (ok != true || v == null || v <= 0 || !context.mounted) return;
    await RepoScope.ler(context).salvar({
      'kind': 'cpag',
      'id': novoId('cp'),
      'cartao': c.id,
      'fat': f.ym,
      'valor': (v * 100).round() / 100,
      'data': hojeIso(),
      'criado': DateTime.now().millisecondsSinceEpoch,
    });
    if (context.mounted) avisar(context, 'Pagamento de ${brl(v)} registrado.');
  }

  Future<void> _opcoesCompra(BuildContext context, ItemFatura it) async {
    final repo = RepoScope.ler(context);
    final g = it.g!;
    final parcelada = it.parcN != null && it.parcN! > 1;
    final escolha = await folhaOuJanela<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(g.desc, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${brl(g.valor)} · ${dataBr(g.data)}')),
          ListTile(leading: Icon(Icons.delete_outline_rounded, color: G.neg), title: Text(parcelada ? 'Excluir só esta parcela' : 'Excluir compra'), onTap: () => Navigator.pop(c, 'uma')),
          if (parcelada) ListTile(leading: Icon(Icons.delete_sweep_outlined, color: G.neg), title: const Text('Excluir todas as parcelas'), onTap: () => Navigator.pop(c, 'todas')),
        ]),
      ),
    );
    if (escolha == null) return;
    final ids = escolha == 'todas' ? idsDaCompra(repo, g) : [g.id];
    await repo.apagarVarios(ids);
    if (context.mounted) avisar(context, ids.length > 1 ? '${ids.length} parcelas excluídas.' : 'Compra excluída.');
  }
}

class _Tracejado extends CustomPainter {
  final Color cor;
  _Tracejado(this.cor);
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    final path = Path()..addRRect(rr);
    final pinta = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), pinta);
      }
    }
  }

  @override
  bool shouldRepaint(_Tracejado old) => old.cor != cor;
}

/// O cartão "de plástico": fatura atual, limite e melhor dia de compra.
class _CartaoGrande extends StatelessWidget {
  final CartaoCredito c;
  final ResumoCartao r;
  const _CartaoGrande({required this.c, required this.r});
  @override
  Widget build(BuildContext context) {
    final f = r.faturaAtual;
    final cor = corDe(c.cor);
    final hoje = DateTime.parse(hojeIso());
    final dias = DateTime.parse(f.fech).difference(hoje).inDays;
    const branco = Colors.white;
    final suave = Colors.white.withValues(alpha: .85);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cor, Color.lerp(cor, Colors.black, .18)!]),
        boxShadow: [BoxShadow(color: cor.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -14)],
      ),
      child: Stack(children: [
        Positioned(
          right: -90,
          bottom: -120,
          child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .06))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(c.nome, style: const TextStyle(fontFamily: S.fonteNum, fontWeight: FontWeight.w700, fontSize: 18, color: branco))),
              Container(
                width: 38,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(colors: [Color(0xFFF3D98A), Color(0xFFC9A04A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
              ),
            ]),
            const SizedBox(height: 22),
            Text('Fatura atual · ${mesLongo(f.ym).toLowerCase()}', style: TextStyle(color: suave, fontSize: 12.5)),
            const SizedBox(height: 2),
            Text(brl(f.total), style: const TextStyle(fontFamily: S.fonteNum, fontSize: 28, fontWeight: FontWeight.w800, color: branco)),
            Text(
              dias > 0
                  ? 'Fecha em $dias dia${dias == 1 ? '' : 's'} (${dataCurta(f.fech)}) · vence ${dataCurta(f.venc)}'
                  : 'Fechou em ${dataCurta(f.fech)} · vence ${dataCurta(f.venc)}',
              style: TextStyle(color: suave, fontSize: 12.5),
            ),
            if (c.limite > 0) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: (r.usado / c.limite).clamp(0, 1).toDouble(), minHeight: 7, color: branco, backgroundColor: Colors.white.withValues(alpha: .22)),
              ),
              const SizedBox(height: 8),
              Text('Usado ${brl(r.usado)}', style: TextStyle(color: suave, fontSize: 12.5)),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Disponível '),
                  TextSpan(text: brl(r.disponivel ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, color: branco)),
                  TextSpan(text: ' de ${brl(c.limite)}'),
                ]),
                style: TextStyle(color: suave, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
              child: Row(children: [
                const IconeSite(_icoSol, tam: 14, cor: branco),
                const SizedBox(width: 10),
                Expanded(child: Text('Melhor dia de compra: dia ${c.fecha} (paga só no vencimento seguinte)', style: TextStyle(color: suave, fontSize: 12))),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Faturas de todos os cartões nos próximos 12 meses.
class _Comprometido extends StatelessWidget {
  final List<CartaoCredito> ccs;
  const _Comprometido({required this.ccs});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final por = <String, double>{};
    String? inicio;
    for (final c in ccs) {
      final r = resumoCartao(repo, c);
      if (inicio == null || r.atual.compareTo(inicio) < 0) inicio = r.atual;
      for (final f in r.faturas) {
        if (f.st == 'paga') continue;
        por[f.ym] = (por[f.ym] ?? 0) + f.falta;
      }
    }
    final ini = inicio ?? ymDe(hojeIso());
    final yms = [for (var i = 0; i < 12; i++) ymAdd(ini, i)];
    final max = yms.fold<double>(0, (a, y) => (por[y] ?? 0) > a ? por[y]! : a);
    final depois = yms.skip(1).fold<double>(0, (a, y) => a + (por[y] ?? 0));
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CabecalhoSite('Já comprometido nos próximos meses', sub: 'Faturas de todos os cartões, com as parcelas que ainda vão vir'),
        Text(brl(depois), style: TextStyle(fontFamily: S.fonteNum, fontSize: 22, fontWeight: FontWeight.w700, color: S.ink)),
        Text('depois da fatura atual', style: TextStyle(fontSize: 12.5, color: S.muted)),
        const SizedBox(height: 12),
        for (final y in yms)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 56, child: Text('${mesesAbr[int.parse(y.substring(5)) - 1]}/${y.substring(2, 4)}', style: TextStyle(fontSize: 13, color: S.ink2))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: max > 0 ? (por[y] ?? 0) / max : 0, minHeight: 9, color: S.accent, backgroundColor: S.surface2),
                ),
              ),
              SizedBox(
                width: 96,
                child: Text((por[y] ?? 0) > 0 ? brl(por[y]!) : '—', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: S.ink)),
              ),
            ]),
          ),
      ]),
    );
  }
}

class FormCompra extends StatefulWidget {
  final CartaoCredito cartao;
  const FormCompra({super.key, required this.cartao});
  @override
  State<FormCompra> createState() => _FormCompraState();
}

class _FormCompraState extends State<FormCompra> {
  final descC = TextEditingController(), valorC = TextEditingController();
  int parc = 1;
  String data = hojeIso(), cat = 'compras';
  String? erro;

  @override
  void dispose() {
    descC.dispose();
    valorC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = lerValor(valorC.text) ?? 0;
    final f0 = widget.cartao.faturaDe(data);
    return CorpoFolha([
      TituloFolha('Compra no ${widget.cartao.nome}'),
      const SizedBox(height: 12),
      CampoValor(valorC, rotulo: 'Valor total', grande: true, erro: erro),
      const SizedBox(height: 12),
      TextField(controller: descC, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Ex.: Geladeira')),
      const Rotulo('Parcelas'),
      DropdownButtonFormField<int>(
        initialValue: parc,
        isExpanded: true,
        dropdownColor: G.fundo2,
        decoration: const InputDecoration(),
        items: [for (var q = 1; q <= 24; q++) DropdownMenuItem(value: q, child: Text(q == 1 ? 'À vista' : '$q vezes'))],
        onChanged: (x) => setState(() => parc = x ?? 1),
      ),
      if (parc > 1 && v > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('$parc × ${brl(v / parc)}', style: TextStyle(color: G.lavanda, fontWeight: FontWeight.w600))),
      const Rotulo('Data da compra'),
      CampoData(data: data, onMudar: (x) => setState(() => data = x)),
      Padding(padding: const EdgeInsets.only(top: 6), child: Text('Entra na fatura de ${mesLongo(f0).toLowerCase()}', style: TextStyle(color: G.apagado, fontSize: 12.5))),
      const Rotulo('Categoria'),
      DropdownButtonFormField<String>(
        initialValue: cat,
        isExpanded: true,
        dropdownColor: G.fundo2,
        decoration: const InputDecoration(),
        items: [for (final c in categoriasGasto) DropdownMenuItem(value: c.id, child: Row(children: [Icon(c.icone, size: 18, color: c.cor), const SizedBox(width: 10), Text(c.nome)]))],
        onChanged: (x) => setState(() => cat = x ?? cat),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () async {
          final val = lerValor(valorC.text), desc = descC.text.trim();
          if (val == null || val <= 0) return setState(() => erro = 'Informe o valor.');
          final docs = docsCompra(widget.cartao, desc: desc.isEmpty ? catGasto(cat).nome : desc, valor: val, parcelas: parc, data: data, cat: cat);
          await RepoScope.ler(context).salvarVarios(docs);
          if (!context.mounted) return;
          Navigator.pop(context);
          avisar(context, parc > 1 ? 'Compra lançada em $parc parcelas.' : 'Compra lançada.');
        },
        child: const Text('Lançar compra'),
      ),
    ]);
  }
}

class FormCartao extends StatefulWidget {
  final Doc? doc;
  const FormCartao({super.key, this.doc});
  @override
  State<FormCartao> createState() => _FormCartaoState();
}

class _FormCartaoState extends State<FormCartao> {
  late final CartaoCredito? base = widget.doc == null ? null : CartaoCredito(widget.doc!);
  late final nomeC = TextEditingController(text: base?.nome ?? '');
  late final bancoC = TextEditingController(text: base?.banco ?? '');
  late final limC = TextEditingController(text: base != null && base!.limite > 0 ? valorCampo(base!.limite) : '');
  late int fecha = base?.fecha ?? 3, vence = base?.vence ?? 10;
  late String cor = base?.cor ?? coresCartao.first;

  @override
  void dispose() {
    nomeC.dispose();
    bancoC.dispose();
    limC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CorpoFolha([
      TituloFolha(base != null ? 'Editar cartão' : 'Novo cartão', onExcluir: base != null ? _excluir : null),
      const SizedBox(height: 12),
      TextField(controller: nomeC, decoration: const InputDecoration(labelText: 'Nome do cartão', hintText: 'Ex.: Nubank, Inter')),
      const SizedBox(height: 12),
      TextField(controller: bancoC, decoration: const InputDecoration(labelText: 'Banco (opcional)')),
      const SizedBox(height: 12),
      CampoValor(limC, rotulo: 'Limite (opcional)'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: CampoDia(dia: fecha, rotulo: 'Fecha no dia', onMudar: (v) => setState(() => fecha = v))),
        const SizedBox(width: 10),
        Expanded(child: CampoDia(dia: vence, rotulo: 'Vence no dia', onMudar: (v) => setState(() => vence = v))),
      ]),
      const Rotulo('Cor'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final c in coresCartao)
          GestureDetector(
            onTap: () => setState(() => cor = c),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: corDe(c), shape: BoxShape.circle, border: Border.all(color: c == cor ? G.branco : Colors.transparent, width: 3)),
            ),
          ),
      ]),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: () async {
          final nome = nomeC.text.trim();
          if (nome.isEmpty) return avisar(context, 'Dê um nome ao cartão.');
          final lim = lerValor(limC.text) ?? 0;
          await RepoScope.ler(context).salvar({
            ...?widget.doc,
            'kind': 'cartao',
            'id': base?.id ?? novoId('cc'),
            'nome': nome,
            'banco': bancoC.text.trim(),
            'limite': lim > 0 ? (lim * 100).round() / 100 : 0,
            'fecha': fecha,
            'vence': vence,
            'desde': widget.doc?['desde'] ?? hojeIso(),
            'cor': cor,
            'criado': base?.criado ?? DateTime.now().millisecondsSinceEpoch,
          });
          if (!context.mounted) return;
          Navigator.pop(context);
          avisar(context, base != null ? 'Cartão atualizado.' : 'Cartão $nome adicionado.');
        },
        child: Text(base != null ? 'Salvar alterações' : 'Adicionar cartão'),
      ),
    ]);
  }

  Future<void> _excluir() async {
    final b = base!;
    if (!await confirmar(context, 'Excluir o cartão ${b.nome}?', 'O cartão, as compras e os pagamentos de fatura dele serão apagados.')) return;
    if (!mounted) return;
    final repo = RepoScope.ler(context);
    await repo.apagarVarios([
      b.id,
      ...repo.gastos.where((g) => g.d['cartao'] == b.id).map((g) => g.id),
      ...repo.doTipo('cpag').where((p) => p['cartao'] == b.id).map((p) => str(p['id'])),
    ]);
    if (!mounted) return;
    Navigator.pop(context);
    avisar(context, 'Cartão excluído.');
  }
}
