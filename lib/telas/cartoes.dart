import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/modelos.dart';
import '../dados/planejar.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/formulario.dart';

const coresCartao = ['#820ad1', '#ff7a00', '#00a868', '#1f6feb', '#cc092f', '#3a3f5e', '#c9a227', '#e8467c'];

Color corDe(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.tryParse('FF${h.padLeft(6, '0').substring(0, 6)}', radix: 16) ?? 0xFF820AD1);
}

class TelaCartoes extends StatelessWidget {
  const TelaCartoes({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ccs = cartoes(repo);
    return Scaffold(
      appBar: AppBar(title: const Text('Cartões de crédito', style: TextStyle(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirFolha(context, const FormCartao()),
        backgroundColor: G.branco,
        foregroundColor: G.tinta,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo cartão', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ccs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text('Cadastre seus cartões para ver a fatura atual, o limite disponível e as parcelas dos próximos meses.', textAlign: TextAlign.center, style: TextStyle(color: G.texto2)),
              ),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 100), children: [
              for (final c in ccs) ...[_ResumoCartaoWidget(c), const SizedBox(height: 12)],
            ]),
    );
  }
}

class _ResumoCartaoWidget extends StatelessWidget {
  final CartaoCredito c;
  const _ResumoCartaoWidget(this.c);
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final r = resumoCartao(repo, c);
    final f = r.faturaAtual;
    final cor = corDe(c.cor);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaCartao(id: c.id))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(cor, Colors.white, .05)!, Color.lerp(cor, Colors.black, .45)!]),
          boxShadow: [BoxShadow(color: cor.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -16)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.credit_card_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white))),
            _Selo(f.stTexto),
          ]),
          const SizedBox(height: 14),
          Text('Fatura de ${mesLongo(f.ym).toLowerCase()}', style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5)),
          Text(brl(f.total), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
          Text('Fecha ${dataCurta(f.fech)} · vence ${dataCurta(f.venc)}', style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5)),
          if (r.disponivel != null) ...[
            const SizedBox(height: 12),
            Barra(c.limite > 0 ? r.usado / c.limite : 0, cor: Colors.white, trilho: const Color(0x33FFFFFF), altura: 6),
            const SizedBox(height: 6),
            Text('Disponível ${brl(r.disponivel!)} de ${brl(c.limite)}', style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ]),
      ),
    );
  }
}

class _Selo extends StatelessWidget {
  final String t;
  const _Selo(this.t);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(99)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
      );
}

/// Um cartão: faturas mês a mês, compras, pagamento da fatura.
class TelaCartao extends StatefulWidget {
  final String id;
  const TelaCartao({super.key, required this.id});
  @override
  State<TelaCartao> createState() => _TelaCartaoState();
}

class _TelaCartaoState extends State<TelaCartao> {
  String? fat;

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final d = repo.porId(widget.id);
    if (d == null) return const Scaffold(body: Center(child: Text('Cartão excluído.')));
    final c = CartaoCredito(d);
    final r = resumoCartao(repo, c);
    final sel = r.faturas.firstWhere((f) => f.ym == (fat ?? r.atual), orElse: () => r.faturaAtual);
    return Scaffold(
      appBar: AppBar(
        title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(tooltip: 'Editar cartão', onPressed: () => abrirFolha(context, FormCartao(doc: d)), icon: const Icon(Icons.edit_outlined))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirFolha(context, FormCompra(cartao: c)),
        backgroundColor: G.branco,
        foregroundColor: G.tinta,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova compra', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 100), children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in r.faturas)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: f.ym == sel.ym,
                  label: Text('${mesesAbr[int.parse(f.ym.substring(5)) - 1]}/${f.ym.substring(2, 4)} · ${brl(f.total)}'),
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, color: f.ym == sel.ym ? G.tinta : G.texto2),
                  onSelected: (_) => setState(() => fat = f.ym),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Cartao(
          gradiente: G.gradHero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Fatura de ${mesLongo(sel.ym).toLowerCase()}', style: const TextStyle(color: G.texto2))),
              _Selo(sel.stTexto),
            ]),
            const SizedBox(height: 4),
            Text(brl(sel.total), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            Text('Fecha ${dataBr(sel.fech)} · vence ${dataBr(sel.venc)}', style: const TextStyle(color: G.texto2, fontSize: 13)),
            if (sel.pago > 0) Text('Pago ${brl(sel.pago)} · falta ${brl(sel.falta)}', style: const TextStyle(color: G.pos, fontSize: 13, fontWeight: FontWeight.w700)),
            if (sel.itens.any((i) => i.prevista)) const Text('Inclui parcelas previstas, que ainda vão entrar.', style: TextStyle(color: G.apagado, fontSize: 12)),
            if (sel.falta > 0 && sel.st != 'futura') ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _pagar(context, c, sel),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Registrar pagamento da fatura'),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        if (sel.itens.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text('Nenhuma compra nesta fatura.', textAlign: TextAlign.center, style: TextStyle(color: G.apagado)))
        else
          CaixaLista([
            for (final it in sel.itens)
              ListTile(
                onTap: it.g == null ? null : () => _opcoesCompra(context, it),
                leading: IconeCategoria(catGasto(it.cat), tam: 38),
                title: Text(it.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  [if (it.g != null) dataCurta(it.g!.data), if (it.parcN != null && it.parcN! > 1) 'parcela ${it.parcI}/${it.parcN}', if (it.prevista) 'prevista'].join(' · '),
                  style: TextStyle(color: it.prevista ? G.lavanda : G.apagado, fontSize: 12.5),
                ),
                trailing: Text(brl(it.valor), style: TextStyle(fontWeight: FontWeight.w800, color: it.prevista ? G.apagado : G.texto)),
              ),
          ]),
        if (sel.pago > 0) ...[
          const Rotulo('Pagamentos desta fatura'),
          CaixaLista([
            for (final p in repo.doTipo('cpag').where((p) => p['cartao'] == c.id && p['fat'] == sel.ym))
              ListTile(
                leading: const Icon(Icons.check_circle_rounded, color: G.pos),
                title: Text(brl(numD(p['valor'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('em ${dataBr(str(p['data'], sel.venc))}', style: const TextStyle(color: G.apagado)),
                trailing: IconButton(
                  tooltip: 'Desfazer pagamento',
                  icon: const Icon(Icons.undo_rounded),
                  onPressed: () async {
                    if (await confirmar(context, 'Desfazer este pagamento?', 'O valor volta a faltar na fatura.', sim: 'Desfazer')) await repo.apagar(str(p['id']));
                  },
                ),
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
    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(g.desc, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${brl(g.valor)} · ${dataBr(g.data)}')),
          ListTile(leading: const Icon(Icons.delete_outline_rounded, color: G.neg), title: Text(parcelada ? 'Excluir só esta parcela' : 'Excluir compra'), onTap: () => Navigator.pop(c, 'uma')),
          if (parcelada) ListTile(leading: const Icon(Icons.delete_sweep_outlined, color: G.neg), title: const Text('Excluir todas as parcelas'), onTap: () => Navigator.pop(c, 'todas')),
        ]),
      ),
    );
    if (escolha == null) return;
    final ids = escolha == 'todas' ? idsDaCompra(repo, g) : [g.id];
    await repo.apagarVarios(ids);
    if (context.mounted) avisar(context, ids.length > 1 ? '${ids.length} parcelas excluídas.' : 'Compra excluída.');
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
      if (parc > 1 && v > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('$parc × ${brl(v / parc)}', style: const TextStyle(color: G.lavanda, fontWeight: FontWeight.w700))),
      const Rotulo('Data da compra'),
      CampoData(data: data, onMudar: (x) => setState(() => data = x)),
      Padding(padding: const EdgeInsets.only(top: 6), child: Text('Entra na fatura de ${mesLongo(f0).toLowerCase()}', style: const TextStyle(color: G.apagado, fontSize: 12.5))),
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
