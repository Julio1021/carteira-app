import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tema.dart';
import '../util/fmt.dart';

/// Peças pequenas reutilizadas nos formulários.

class CampoValor extends StatelessWidget {
  final TextEditingController c;
  final String rotulo;
  final bool grande;
  final String? erro;
  final bool autofocus;
  const CampoValor(this.c, {super.key, this.rotulo = 'Valor', this.grande = false, this.erro, this.autofocus = false});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: c,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: grande ? const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1) : null,
      decoration: InputDecoration(labelText: rotulo, prefixText: 'R\$ ', hintText: '0,00', errorText: erro),
    );
  }
}

class Rotulo extends StatelessWidget {
  final String t;
  const Rotulo(this.t, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: G.texto2)),
      );
}

/// Linha de opções em "chips" (uma escolhida).
class Opcoes<T> extends StatelessWidget {
  final List<(T, String)> itens;
  final T valor;
  final ValueChanged<T> onMudar;
  const Opcoes({super.key, required this.itens, required this.valor, required this.onMudar});
  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (v, t) in itens)
        ChoiceChip(
          selected: v == valor,
          label: Text(t),
          labelStyle: TextStyle(fontWeight: FontWeight.w700, color: v == valor ? G.tinta : G.texto2),
          onSelected: (_) => onMudar(v),
        ),
    ]);
  }
}

/// Seletor de data com botões Hoje / Ontem / outra.
class CampoData extends StatelessWidget {
  final String data;
  final ValueChanged<String> onMudar;
  final bool comOntem;
  const CampoData({super.key, required this.data, required this.onMudar, this.comOntem = true});
  @override
  Widget build(BuildContext context) {
    final h = hojeIso(), o = addDias(h, -1);
    final outra = data != h && (!comOntem || data != o);
    TextStyle st(bool s) => TextStyle(fontWeight: FontWeight.w700, color: s ? G.tinta : G.texto2);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      ChoiceChip(selected: data == h, label: const Text('Hoje'), labelStyle: st(data == h), onSelected: (_) => onMudar(h)),
      if (comOntem) ChoiceChip(selected: data == o, label: const Text('Ontem'), labelStyle: st(data == o), onSelected: (_) => onMudar(o)),
      ChoiceChip(
        selected: outra,
        avatar: Icon(Icons.calendar_month_rounded, size: 16, color: outra ? G.tinta : G.texto2),
        label: Text(outra ? dataBr(data) : 'Outra data'),
        labelStyle: st(outra),
        onSelected: (_) async {
          final d = await showDatePicker(context: context, initialDate: dataDe(data), firstDate: DateTime(2015), lastDate: DateTime(2036));
          if (d != null) onMudar(isoDe(d));
        },
      ),
    ]);
  }
}

/// Escolha de mês (aaaa-mm) numa lista.
class CampoMes extends StatelessWidget {
  final String ym;
  final String rotulo;
  final ValueChanged<String> onMudar;
  const CampoMes({super.key, required this.ym, required this.onMudar, this.rotulo = 'A partir de'});
  @override
  Widget build(BuildContext context) {
    final base = ymDe(hojeIso());
    final meses = [for (var k = -24; k <= 24; k++) ymAdd(base, k)];
    if (!meses.contains(ym)) meses.add(ym);
    meses.sort();
    return DropdownButtonFormField<String>(
      initialValue: ym,
      isExpanded: true,
      decoration: InputDecoration(labelText: rotulo),
      dropdownColor: G.fundo2,
      items: [for (final m in meses) DropdownMenuItem(value: m, child: Text(mesLongo(m)))],
      onChanged: (v) {
        if (v != null) onMudar(v);
      },
    );
  }
}

/// Escolha do dia do mês (1 a 31).
class CampoDia extends StatelessWidget {
  final int dia;
  final String rotulo;
  final ValueChanged<int> onMudar;
  const CampoDia({super.key, required this.dia, required this.onMudar, this.rotulo = 'Dia do vencimento'});
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: dia.clamp(1, 31).toInt(),
      isExpanded: true,
      decoration: InputDecoration(labelText: rotulo),
      dropdownColor: G.fundo2,
      items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('Dia $d'))],
      onChanged: (v) {
        if (v != null) onMudar(v);
      },
    );
  }
}

/// Cabeçalho padrão de folha (bottom sheet) com título e botão de excluir opcional.
class TituloFolha extends StatelessWidget {
  final String t;
  final VoidCallback? onExcluir;
  const TituloFolha(this.t, {super.key, this.onExcluir});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(t, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
        if (onExcluir != null) IconButton(tooltip: 'Excluir', onPressed: onExcluir, icon: Icon(Icons.delete_outline_rounded, color: G.neg)),
      ]);
}

/// Envolve o conteúdo de uma folha: rolagem e espaço para o teclado.
class CorpoFolha extends StatelessWidget {
  final List<Widget> filhos;
  const CorpoFolha(this.filhos, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filhos),
        ),
      );
}

Future<T?> abrirFolha<T>(BuildContext context, Widget filho) =>
    showModalBottomSheet<T>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => filho);

Future<bool> confirmar(BuildContext context, String titulo, String texto, {String sim = 'Excluir', bool perigo = true}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(
          style: perigo ? FilledButton.styleFrom(backgroundColor: G.neg, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(sim),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Caixinha de data (dia + mês abreviado) usada nas listas de contas.
class CaixaData extends StatelessWidget {
  final String iso;
  final bool destaque;
  final Color? cor;
  const CaixaData(this.iso, {super.key, this.destaque = false, this.cor});
  @override
  Widget build(BuildContext context) {
    final fundo = destaque ? G.branco : (cor?.withValues(alpha: .16) ?? G.v(0x12));
    final txt = destaque ? G.tinta : (cor ?? G.texto);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(14)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(iso.substring(8, 10), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: txt, height: 1)),
        Text(mesesAbr[int.parse(iso.substring(5, 7)) - 1].toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: txt.withValues(alpha: .7))),
      ]),
    );
  }
}
