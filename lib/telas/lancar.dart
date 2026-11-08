import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/categorias.dart';
import '../dados/modelos.dart';
import '../dados/patrimonio.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';

/// Menu do botão +: o que você quer registrar?
Future<void> abrirMenuLancar(BuildContext context) async {
  final escolha = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Lançar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('O que você quer registrar?', style: TextStyle(color: G.apagado)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _OpcaoMenu(Icons.remove_rounded, 'Gasto', 'Débito, Pix, dinheiro', () => Navigator.pop(c, 'gasto'), destaque: true)),
            const SizedBox(width: 10),
            Expanded(child: _OpcaoMenu(Icons.arrow_upward_rounded, 'Entrada', 'Salário, Pix recebido…', () => Navigator.pop(c, 'entrada'), corIcone: G.pos)),
          ]),
          const SizedBox(height: 10),
          Cartao(
            onTap: () => Navigator.pop(c, 'invest'),
            raio: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: G.lavandaFundo, borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.savings_rounded, color: G.lavanda),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Investido', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('Dinheiro que foi para investir (ou voltou de um resgate)', style: TextStyle(color: G.apagado, fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ),
  );
  if (escolha == null || !context.mounted) return;
  await abrirFormLanc(context, entrada: escolha == 'entrada', investido: escolha == 'invest');
}

class _OpcaoMenu extends StatelessWidget {
  final IconData ic;
  final String t, sub;
  final VoidCallback onTap;
  final bool destaque;
  final Color? corIcone;
  const _OpcaoMenu(this.ic, this.t, this.sub, this.onTap, {this.destaque = false, this.corIcone});
  @override
  Widget build(BuildContext context) {
    return Cartao(
      onTap: onTap,
      raio: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: destaque ? G.branco : G.v(0x14), borderRadius: BorderRadius.circular(13)),
          child: Icon(ic, color: destaque ? G.tinta : (corIcone ?? G.texto)),
        ),
        const SizedBox(height: 14),
        Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text(sub, style: TextStyle(color: G.apagado, fontSize: 12.5)),
      ]),
    );
  }
}

/// Formulário de gasto, entrada ou investido. Passe [doc] para editar um existente.
Future<void> abrirFormLanc(BuildContext context, {bool entrada = false, bool investido = false, Doc? doc}) {
  final tipo = doc != null ? (doc['kind'] == 'invest' ? 'invest' : (doc['kind'] == 'entrada' ? 'entrada' : 'gasto')) : (investido ? 'invest' : (entrada ? 'entrada' : 'gasto'));
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FormLanc(tipo: tipo, doc: doc),
  );
}

class FormLanc extends StatefulWidget {
  /// 'gasto', 'entrada' ou 'invest'
  final String tipo;
  final Doc? doc;
  const FormLanc({super.key, required this.tipo, this.doc});
  @override
  State<FormLanc> createState() => _FormLancState();
}

class _FormLancState extends State<FormLanc> {
  late String tipo = widget.tipo;
  bool get entrada => tipo == 'entrada';
  bool get invest => tipo == 'invest';
  bool resgate = false;
  String? ativo;
  final valorC = TextEditingController();
  final descC = TextEditingController();
  final valorF = FocusNode();
  late String data = hojeIso();
  String cat = 'mercado';
  String catE = 'pix';
  String pag = 'Pix';
  bool fixo = false;
  bool catEscolhida = false;
  String? erro;

  bool get editando => widget.doc != null;

  @override
  void initState() {
    super.initState();
    final d = widget.doc;
    if (d != null) {
      valorC.text = valorCampo(numD(d['valor']));
      descC.text = str(d['desc']);
      data = str(d['data'], hojeIso());
      if (invest) {
        resgate = d['mov'] == 'resgate';
        ativo = d['ativo'] is String ? d['ativo'] as String : null;
      } else if (entrada) {
        catE = str(d['cat'], 'outros_e');
      } else {
        cat = str(d['cat'], 'outros');
        pag = str(d['pag'], 'Pix');
        fixo = d['fixo'] == true;
      }
      catEscolhida = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => valorF.requestFocus());
    }
  }

  @override
  void dispose() {
    valorC.dispose();
    descC.dispose();
    valorF.dispose();
    super.dispose();
  }

  /// Sugestões de descrição a partir do que você já lançou.
  List<Doc> _sugestoes(String q) {
    final repo = RepoScope.ler(context);
    final t = q.trim().toLowerCase();
    if (t.length < 2) return const [];
    final vistos = <String>{};
    final out = <Doc>[];
    final lista = repo.doTipo(invest ? 'invest' : (entrada ? 'entrada' : 'gasto')).toList()
      ..sort((a, b) => str(b['data']).compareTo(str(a['data'])));
    for (final d in lista) {
      final desc = str(d['desc']);
      final k = desc.toLowerCase();
      if (!k.contains(t) || vistos.contains(k)) continue;
      vistos.add(k);
      out.add(d);
      if (out.length >= 5) break;
    }
    return out;
  }

  void _usarSugestao(Doc d) {
    setState(() {
      descC.text = str(d['desc']);
      if (invest) {
        if (d['ativo'] is String) ativo = d['ativo'] as String;
      } else if (entrada) {
        catE = str(d['cat'], catE);
      } else {
        cat = str(d['cat'], cat);
        pag = str(d['pag'], pag);
      }
      catEscolhida = true;
    });
  }

  Future<void> _escolherData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: dataDe(data),
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Data do lançamento',
    );
    if (d != null) setState(() => data = isoDe(d));
  }

  Future<void> _salvar() async {
    final v = lerValor(valorC.text);
    if (v == null || v <= 0) {
      setState(() => erro = 'Informe um valor maior que zero.');
      valorF.requestFocus();
      return;
    }
    final repo = RepoScope.ler(context);
    final base = Map<String, dynamic>.from(widget.doc ?? {});
    final desc = descC.text.trim();
    if (invest) {
      base.addAll({
        'kind': 'invest',
        'id': base['id'] ?? novoId('i'),
        'desc': desc.isEmpty ? (resgate ? 'Resgate' : 'Aplicação') : desc,
        'valor': (v * 100).round() / 100,
        'data': data,
        'mov': resgate ? 'resgate' : 'aplic',
      });
      if (ativo != null) {
        base['ativo'] = ativo;
      } else {
        base.remove('ativo');
      }
      base.remove('cat');
      base.remove('pag');
      base.remove('fixo');
    } else if (entrada) {
      base.addAll({
        'kind': 'entrada',
        'id': base['id'] ?? novoId('e'),
        'desc': desc.isEmpty ? catEntrada(catE).nome : desc,
        'valor': (v * 100).round() / 100,
        'data': data,
        'cat': catE,
      });
      base.remove('pag');
      base.remove('fixo');
    } else {
      base.addAll({
        'kind': 'gasto',
        'id': base['id'] ?? novoId('g'),
        'desc': desc.isEmpty ? catGasto(cat).nome : desc,
        'valor': (v * 100).round() / 100,
        'data': data,
        'cat': cat,
        'pag': pag,
        'fixo': fixo,
      });
    }
    base['criado'] ??= DateTime.now().millisecondsSinceEpoch;
    // um gasto que vira entrada (ou o contrário) troca de id para não misturar
    if (widget.doc != null && widget.doc!['kind'] != base['kind']) {
      await repo.apagar(widget.doc!['id'] as String);
      base['id'] = novoId(invest ? 'i' : (entrada ? 'e' : 'g'));
    }
    await repo.salvar(base);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    if (!editando) mostrarConfirmacao(context, cor: invest ? G.lavanda : G.pos, icone: invest ? Icons.savings_rounded : Icons.check_rounded);
    Navigator.pop(context);
    avisar(context, editando ? 'Lançamento atualizado.' : (invest ? (resgate ? 'Resgate registrado.' : 'Investimento registrado.') : (entrada ? 'Entrada lançada.' : 'Gasto lançado.')));
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: Text('“${descC.text}” de ${brl(lerValor(valorC.text) ?? 0)} será apagado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: G.neg, foregroundColor: Colors.white), onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await RepoScope.ler(context).apagar(widget.doc!['id'] as String);
    if (!mounted) return;
    Navigator.pop(context);
    avisar(context, 'Lançamento excluído.');
  }

  @override
  Widget build(BuildContext context) {
    final cats = entrada ? categoriasEntrada : categoriasGasto;
    final repoA = RepoScope.of(context);
    final paiIds = {for (final a in repoA.doTipo('ativo')) if (a['pai'] is String) a['pai'] as String};
    final ativos = repoA.doTipo('ativo').map(Ativo.new).where((a) => !a.oculto && !paiIds.contains(a.id)).toList()..sort((a, b) => a.ordem.compareTo(b.ordem));
    final catAtual = entrada ? catE : cat;
    final sugs = editando ? const <Doc>[] : _sugestoes(descC.text);
    final h = hojeIso();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(editando ? 'Editar lançamento' : (invest ? 'Investido' : (entrada ? 'Nova entrada' : 'Novo gasto')), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
            if (editando) IconButton(tooltip: 'Excluir', onPressed: _excluir, icon: Icon(Icons.delete_outline_rounded, color: G.neg)),
          ]),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'gasto', label: Text('Gasto')),
              ButtonSegment(value: 'entrada', label: Text('Entrada')),
              ButtonSegment(value: 'invest', label: Text('Investido')),
            ],
            selected: {tipo},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: G.branco,
              selectedForegroundColor: G.tinta,
              foregroundColor: G.texto2,
              side: BorderSide(color: G.borda),
            ),
            onSelectionChanged: (s) => setState(() => tipo = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: valorC,
            focusNode: valorF,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: invest ? G.lavanda : (entrada ? G.pos : G.texto), letterSpacing: -1),
            decoration: InputDecoration(prefixText: 'R\$ ', prefixStyle: TextStyle(fontSize: 22, color: G.apagado, fontWeight: FontWeight.w700), hintText: '0,00', errorText: erro),
            onChanged: (_) {
              if (erro != null) setState(() => erro = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descC,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Descrição', hintText: invest ? 'Ex.: CDB Inter, Tesouro Selic' : (entrada ? 'Ex.: Salário' : 'Ex.: Supermercado Dia')),
            onChanged: (_) => setState(() {}),
          ),
          if (sugs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in sugs)
                  ActionChip(
                    avatar: Icon(invest ? Icons.savings_rounded : (entrada ? catEntrada(str(s['cat'])) : catGasto(str(s['cat']))).icone, size: 16),
                    label: Text(str(s['desc'])),
                    onPressed: () => _usarSugestao(s),
                  ),
              ]),
            ),
          if (invest) ...[
            const SizedBox(height: 18),
            Text('Movimento', style: TextStyle(fontWeight: FontWeight.w600, color: G.texto2)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (r, t) in const [(false, 'Apliquei (saiu da conta)'), (true, 'Resgatei (voltou para a conta)')])
                ChoiceChip(
                  selected: resgate == r,
                  label: Text(t),
                  labelStyle: TextStyle(fontWeight: FontWeight.w600, color: resgate == r ? G.tinta : G.texto2),
                  onSelected: (_) => setState(() => resgate = r),
                ),
            ]),
            if (ativos.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Onde (opcional)', style: TextStyle(fontWeight: FontWeight.w600, color: G.texto2)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in ativos)
                  ChoiceChip(
                    selected: ativo == a.id,
                    label: Text(a.nome),
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, color: ativo == a.id ? G.tinta : G.texto2),
                    onSelected: (v) => setState(() => ativo = v ? a.id : null),
                  ),
              ]),
            ],
            const SizedBox(height: 10),
            Text('Não entra no "Saiu" nem nos limites: aparece como Investido no Início, no Extrato e na Análise.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
          ],
          if (!invest) ...[
          const SizedBox(height: 18),
          Text('Categoria', style: TextStyle(fontWeight: FontWeight.w600, color: G.texto2)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in cats)
              ChoiceChip(
                selected: c.id == catAtual,
                avatar: Icon(c.icone, size: 16, color: c.id == catAtual ? G.tinta : c.cor),
                label: Text(c.nome),
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: c.id == catAtual ? G.tinta : G.texto2),
                onSelected: (_) => setState(() {
                  if (entrada) {
                    catE = c.id;
                  } else {
                    cat = c.id;
                  }
                  catEscolhida = true;
                }),
              ),
          ]),
          ],
          if (!entrada && !invest) ...[
            const SizedBox(height: 18),
            Text('Como pagou', style: TextStyle(fontWeight: FontWeight.w600, color: G.texto2)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in formasPagamento)
                ChoiceChip(
                  selected: p == pag,
                  label: Text(p),
                  labelStyle: TextStyle(fontWeight: FontWeight.w600, color: p == pag ? G.tinta : G.texto2),
                  onSelected: (_) => setState(() => pag = p),
                ),
            ]),
          ],
          const SizedBox(height: 18),
          Text('Data', style: TextStyle(fontWeight: FontWeight.w600, color: G.texto2)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(selected: data == h, label: const Text('Hoje'), labelStyle: TextStyle(fontWeight: FontWeight.w600, color: data == h ? G.tinta : G.texto2), onSelected: (_) => setState(() => data = h)),
            ChoiceChip(
                selected: data == addDias(h, -1),
                label: const Text('Ontem'),
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: data == addDias(h, -1) ? G.tinta : G.texto2),
                onSelected: (_) => setState(() => data = addDias(h, -1))),
            ChoiceChip(
              selected: data != h && data != addDias(h, -1),
              avatar: Icon(Icons.calendar_month_rounded, size: 16, color: data != h && data != addDias(h, -1) ? G.tinta : G.texto2),
              label: Text(data != h && data != addDias(h, -1) ? dataBr(data) : 'Outra data'),
              labelStyle: TextStyle(fontWeight: FontWeight.w600, color: data != h && data != addDias(h, -1) ? G.tinta : G.texto2),
              onSelected: (_) => _escolherData(),
            ),
          ]),
          if (!entrada && !invest) ...[
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: fixo,
              onChanged: (v) => setState(() => fixo = v),
              title: const Text('Gasto fixo', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Repete todo mês (aluguel, internet…). O app lembra de lançar.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(onPressed: _salvar, child: Text(editando ? 'Salvar alterações' : (invest ? (resgate ? 'Registrar resgate' : 'Registrar investimento') : (entrada ? 'Lançar entrada' : 'Lançar gasto')))),
        ]),
      ),
    );
  }
}
