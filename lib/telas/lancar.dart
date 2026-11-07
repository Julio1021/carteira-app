import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/categorias.dart';
import '../dados/modelos.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';

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
        ]),
      ),
    ),
  );
  if (escolha == null || !context.mounted) return;
  await abrirFormLanc(context, entrada: escolha == 'entrada');
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

/// Formulário de gasto ou entrada. Passe [doc] para editar um existente.
Future<void> abrirFormLanc(BuildContext context, {bool entrada = false, Doc? doc}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FormLanc(entrada: doc != null ? doc['kind'] == 'entrada' : entrada, doc: doc),
  );
}

class FormLanc extends StatefulWidget {
  final bool entrada;
  final Doc? doc;
  const FormLanc({super.key, required this.entrada, this.doc});
  @override
  State<FormLanc> createState() => _FormLancState();
}

class _FormLancState extends State<FormLanc> {
  late bool entrada = widget.entrada;
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
      if (entrada) {
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
    final lista = repo.doTipo(entrada ? 'entrada' : 'gasto').toList()
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
      if (entrada) {
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
    if (entrada) {
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
      base['id'] = novoId(entrada ? 'e' : 'g');
    }
    await repo.salvar(base);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    Navigator.pop(context);
    avisar(context, editando ? 'Lançamento atualizado.' : (entrada ? 'Entrada lançada.' : 'Gasto lançado.'));
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
    final catAtual = entrada ? catE : cat;
    final sugs = editando ? const <Doc>[] : _sugestoes(descC.text);
    final h = hojeIso();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(editando ? 'Editar lançamento' : (entrada ? 'Nova entrada' : 'Novo gasto'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
            if (editando) IconButton(tooltip: 'Excluir', onPressed: _excluir, icon: Icon(Icons.delete_outline_rounded, color: G.neg)),
          ]),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Gasto'), icon: Icon(Icons.remove_rounded)),
              ButtonSegment(value: true, label: Text('Entrada'), icon: Icon(Icons.add_rounded)),
            ],
            selected: {entrada},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: G.branco,
              selectedForegroundColor: G.tinta,
              foregroundColor: G.texto2,
              side: BorderSide(color: G.borda),
            ),
            onSelectionChanged: (s) => setState(() => entrada = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: valorC,
            focusNode: valorF,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: entrada ? G.pos : G.texto, letterSpacing: -1),
            decoration: InputDecoration(prefixText: 'R\$ ', prefixStyle: TextStyle(fontSize: 22, color: G.apagado, fontWeight: FontWeight.w700), hintText: '0,00', errorText: erro),
            onChanged: (_) {
              if (erro != null) setState(() => erro = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descC,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Descrição', hintText: entrada ? 'Ex.: Salário' : 'Ex.: Supermercado Dia'),
            onChanged: (_) => setState(() {}),
          ),
          if (sugs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in sugs)
                  ActionChip(
                    avatar: Icon((entrada ? catEntrada(str(s['cat'])) : catGasto(str(s['cat']))).icone, size: 16),
                    label: Text(str(s['desc'])),
                    onPressed: () => _usarSugestao(s),
                  ),
              ]),
            ),
          const SizedBox(height: 18),
          Text('Categoria', style: TextStyle(fontWeight: FontWeight.w700, color: G.texto2)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in cats)
              ChoiceChip(
                selected: c.id == catAtual,
                avatar: Icon(c.icone, size: 16, color: c.id == catAtual ? G.tinta : c.cor),
                label: Text(c.nome),
                labelStyle: TextStyle(fontWeight: FontWeight.w700, color: c.id == catAtual ? G.tinta : G.texto2),
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
          if (!entrada) ...[
            const SizedBox(height: 18),
            Text('Como pagou', style: TextStyle(fontWeight: FontWeight.w700, color: G.texto2)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in formasPagamento)
                ChoiceChip(
                  selected: p == pag,
                  label: Text(p),
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, color: p == pag ? G.tinta : G.texto2),
                  onSelected: (_) => setState(() => pag = p),
                ),
            ]),
          ],
          const SizedBox(height: 18),
          Text('Data', style: TextStyle(fontWeight: FontWeight.w700, color: G.texto2)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(selected: data == h, label: const Text('Hoje'), labelStyle: TextStyle(fontWeight: FontWeight.w700, color: data == h ? G.tinta : G.texto2), onSelected: (_) => setState(() => data = h)),
            ChoiceChip(
                selected: data == addDias(h, -1),
                label: const Text('Ontem'),
                labelStyle: TextStyle(fontWeight: FontWeight.w700, color: data == addDias(h, -1) ? G.tinta : G.texto2),
                onSelected: (_) => setState(() => data = addDias(h, -1))),
            ChoiceChip(
              selected: data != h && data != addDias(h, -1),
              avatar: Icon(Icons.calendar_month_rounded, size: 16, color: data != h && data != addDias(h, -1) ? G.tinta : G.texto2),
              label: Text(data != h && data != addDias(h, -1) ? dataBr(data) : 'Outra data'),
              labelStyle: TextStyle(fontWeight: FontWeight.w700, color: data != h && data != addDias(h, -1) ? G.tinta : G.texto2),
              onSelected: (_) => _escolherData(),
            ),
          ]),
          if (!entrada) ...[
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: fixo,
              onChanged: (v) => setState(() => fixo = v),
              title: const Text('Gasto fixo', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Repete todo mês (aluguel, internet…). O app lembra de lançar.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(onPressed: _salvar, child: Text(editando ? 'Salvar alterações' : (entrada ? 'Lançar entrada' : 'Lançar gasto'))),
        ]),
      ),
    );
  }
}
