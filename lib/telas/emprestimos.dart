import 'package:flutter/material.dart';

import '../dados/modelos.dart';
import '../dados/planejar.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/formulario.dart';

class TelaEmprestimos extends StatelessWidget {
  const TelaEmprestimos({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final l = emprestimos(repo);
    return Scaffold(
      appBar: AppBar(title: const Text('Dinheiro emprestado', style: TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirFolha(context, const FormEmprestimo()),
        backgroundColor: G.branco,
        foregroundColor: G.tinta,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo empréstimo', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: l.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text('Emprestou dinheiro para alguém? Cadastre o valor, quando a pessoa começa a pagar e em quantas parcelas. O app mostra quanto falta e avisa parcela atrasada.',
                    textAlign: TextAlign.center, style: TextStyle(color: G.texto2, height: 1.4)),
              ),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 100), children: [
              for (final e in l) ...[_CartaoEmp(e), const SizedBox(height: 12)],
            ]),
    );
  }
}

class _CartaoEmp extends StatefulWidget {
  final Emprestimo e;
  const _CartaoEmp(this.e);
  @override
  State<_CartaoEmp> createState() => _CartaoEmpState();
}

class _CartaoEmpState extends State<_CartaoEmp> {
  bool aberto = false;
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final e = widget.e;
    final d = dadosEmprestimo(repo, e);
    final atr = d.atrasadas;
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: G.lavandaFundo, borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(e.pessoa.isEmpty ? '?' : e.pessoa[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: G.lavandaIcone))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.pessoa, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${brl(e.valor)} em ${dataBr(e.data)}${e.obs.isNotEmpty ? ' · ${e.obs}' : ''}', style: TextStyle(color: G.apagado, fontSize: 12.5)),
            ]),
          ),
          IconButton(tooltip: 'Editar', onPressed: () => abrirFolha(context, FormEmprestimo(doc: e.d)), icon: const Icon(Icons.edit_outlined, size: 20)),
        ]),
        const SizedBox(height: 12),
        Barra(e.valor > 0 ? d.recebido / e.valor : 0, cor: G.pos),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('Recebido ${brl(d.recebido)}', style: TextStyle(color: G.pos, fontWeight: FontWeight.w600, fontSize: 13))),
          Text(d.quitado ? 'Quitado 🎉' : 'Falta ${brl(d.falta)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
        if (!d.quitado && d.prox != null) ...[
          const SizedBox(height: 8),
          Text(
            atr.isNotEmpty
                ? '${atr.length} parcela${atr.length > 1 ? 's' : ''} atrasada${atr.length > 1 ? 's' : ''} · próxima era ${dataCurta(d.prox!.venc)}'
                : 'Próxima parcela: ${brl(d.prox!.valor - d.prox!.coberto)} em ${dataCurta(d.prox!.venc)}',
            style: TextStyle(color: atr.isNotEmpty ? G.neg : G.texto2, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          if (!d.quitado)
            Expanded(
              child: FilledButton.icon(
                onPressed: () => abrirFolha(context, FolhaReceber(e: e, sugestao: d.prox == null ? d.falta : d.prox!.valor - d.prox!.coberto)),
                icon: const Icon(Icons.call_received_rounded, size: 18),
                label: const Text('Recebi um pagamento'),
              ),
            ),
          if (!d.quitado) const SizedBox(width: 8),
          OutlinedButton(onPressed: () => setState(() => aberto = !aberto), child: Text(aberto ? 'Fechar' : 'Detalhes')),
        ]),
        if (aberto) ...[
          if (d.agenda.isNotEmpty) ...[
            const Rotulo('Parcelas'),
            CaixaLista([
              for (final p in d.agenda)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    SizedBox(width: 36, child: Text('${p.k}ª', style: TextStyle(color: G.apagado, fontWeight: FontWeight.w600))),
                    Expanded(child: Text(dataBr(p.venc))),
                    Text(brl(p.valor), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    Icon(
                      switch (p.st) { 'pago' => Icons.check_circle_rounded, 'parcial' => Icons.timelapse_rounded, 'atrasada' => Icons.error_rounded, _ => Icons.radio_button_unchecked_rounded },
                      size: 18,
                      color: switch (p.st) { 'pago' => G.pos, 'parcial' => G.alerta, 'atrasada' => G.neg, _ => G.apagado },
                    ),
                  ]),
                ),
            ]),
          ],
          if (d.recebimentos.isNotEmpty) ...[
            const Rotulo('Pagamentos recebidos'),
            CaixaLista([
              for (final r in d.recebimentos.reversed)
                ListTile(
                  dense: true,
                  title: Text(brl(numD(r['valor'])), style: TextStyle(fontWeight: FontWeight.w600, color: G.pos)),
                  subtitle: Text('em ${dataBr(str(r['data'], hojeIso()))}', style: TextStyle(color: G.apagado)),
                  trailing: IconButton(
                    tooltip: 'Desfazer',
                    icon: const Icon(Icons.undo_rounded, size: 20),
                    onPressed: () async {
                      if (!await confirmar(context, 'Desfazer este pagamento?', 'O valor volta a faltar${r['criouEntrada'] == true ? ' e a entrada lançada junto é apagada' : ''}.', sim: 'Desfazer')) return;
                      await repo.apagarVarios([str(r['id']), if (r['criouEntrada'] == true && r['entrada'] is String) r['entrada'] as String]);
                    },
                  ),
                ),
            ]),
          ],
        ],
      ]),
    );
  }
}

class FolhaReceber extends StatefulWidget {
  final Emprestimo e;
  final double sugestao;
  const FolhaReceber({super.key, required this.e, required this.sugestao});
  @override
  State<FolhaReceber> createState() => _FolhaReceberState();
}

class _FolhaReceberState extends State<FolhaReceber> {
  late final valorC = TextEditingController(text: widget.sugestao > 0 ? valorCampo(widget.sugestao) : '');
  String data = hojeIso();
  bool lancar = true;

  @override
  void dispose() {
    valorC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CorpoFolha([
      TituloFolha('Pagamento de ${widget.e.primeiroNome}'),
      const SizedBox(height: 12),
      CampoValor(valorC, rotulo: 'Valor recebido', grande: true),
      const Rotulo('Quando'),
      CampoData(data: data, onMudar: (v) => setState(() => data = v)),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: lancar,
        onChanged: (v) => setState(() => lancar = v),
        title: const Text('Lançar também nas entradas', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Desligue se o Pix já veio no extrato importado.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: () async {
          final v = lerValor(valorC.text);
          if (v == null || v <= 0) return avisar(context, 'Informe o valor recebido.');
          final repo = RepoScope.ler(context);
          await repo.salvarVarios(docsRecebimento(repo, widget.e, (v * 100).round() / 100, data, lancarEntrada: lancar));
          if (!context.mounted) return;
          Navigator.pop(context);
          avisar(context, '+ ${brl(v)} de ${widget.e.primeiroNome} registrado.');
        },
        child: const Text('Registrar'),
      ),
    ]);
  }
}

class FormEmprestimo extends StatefulWidget {
  final Doc? doc;
  const FormEmprestimo({super.key, this.doc});
  @override
  State<FormEmprestimo> createState() => _FormEmprestimoState();
}

class _FormEmprestimoState extends State<FormEmprestimo> {
  late final Emprestimo? base = widget.doc == null ? null : Emprestimo(widget.doc!);
  late final pessoaC = TextEditingController(text: base?.pessoa ?? '');
  late final valorC = TextEditingController(text: base != null ? valorCampo(base!.valor) : '');
  late final obsC = TextEditingController(text: base?.obs ?? '');
  late String data = base?.data ?? hojeIso();
  late String ini = (base?.ini.isNotEmpty ?? false) ? base!.ini : ymAdd(ymDe(hojeIso()), 1);
  late int parc = base?.parc ?? 10;
  late int dia = base?.dia ?? 10;

  @override
  void dispose() {
    pessoaC.dispose();
    valorC.dispose();
    obsC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = lerValor(valorC.text) ?? 0;
    return CorpoFolha([
      TituloFolha(base != null ? 'Editar empréstimo' : 'Novo empréstimo', onExcluir: base != null ? _excluir : null),
      const SizedBox(height: 12),
      TextField(controller: pessoaC, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Para quem você emprestou')),
      const SizedBox(height: 12),
      CampoValor(valorC, rotulo: 'Valor emprestado'),
      const Rotulo('Quando emprestou'),
      CampoData(data: data, onMudar: (x) => setState(() => data = x)),
      const Rotulo('Como a pessoa vai pagar'),
      DropdownButtonFormField<int>(
        initialValue: parc.clamp(0, 60).toInt(),
        isExpanded: true,
        dropdownColor: G.fundo2,
        decoration: const InputDecoration(),
        items: [
          const DropdownMenuItem(value: 0, child: Text('Sem parcelas definidas')),
          for (var q = 1; q <= 60; q++) DropdownMenuItem(value: q, child: Text(q == 1 ? 'De uma vez' : 'Em $q parcelas')),
        ],
        onChanged: (x) => setState(() => parc = x ?? parc),
      ),
      if (parc > 1 && v > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('$parc × ${brl(v / parc)}', style: TextStyle(color: G.lavanda, fontWeight: FontWeight.w600))),
      if (parc > 0) ...[
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: CampoMes(ym: ini, rotulo: 'Começa a pagar em', onMudar: (x) => setState(() => ini = x))),
          const SizedBox(width: 10),
          Expanded(child: CampoDia(dia: dia, rotulo: 'Dia', onMudar: (x) => setState(() => dia = x))),
        ]),
      ],
      const SizedBox(height: 12),
      TextField(controller: obsC, decoration: const InputDecoration(labelText: 'Observação (opcional)')),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () async {
          final pessoa = pessoaC.text.trim(), val = lerValor(valorC.text);
          if (pessoa.isEmpty) return avisar(context, 'Informe para quem você emprestou.');
          if (val == null || val <= 0) return avisar(context, 'Informe o valor, como 2.000,00.');
          await RepoScope.ler(context).salvar({
            ...?widget.doc,
            'kind': 'emprestimo',
            'id': base?.id ?? novoId('em'),
            'pessoa': pessoa,
            'valor': (val * 100).round() / 100,
            'data': data,
            'ini': ini,
            'parc': parc,
            'dia': dia,
            'obs': obsC.text.trim(),
            'criado': base?.criado ?? DateTime.now().millisecondsSinceEpoch,
          });
          if (!context.mounted) return;
          Navigator.pop(context);
          avisar(context, base != null ? 'Empréstimo atualizado.' : 'Empréstimo para $pessoa cadastrado.');
        },
        child: Text(base != null ? 'Salvar alterações' : 'Cadastrar'),
      ),
    ]);
  }

  Future<void> _excluir() async {
    final b = base!;
    if (!await confirmar(context, 'Excluir o empréstimo de ${b.pessoa}?', 'O empréstimo e os pagamentos registrados nele serão apagados. As entradas no extrato continuam.')) return;
    if (!mounted) return;
    final repo = RepoScope.ler(context);
    await repo.apagarVarios([b.id, ...repo.doTipo('receb').where((r) => r['emp'] == b.id).map((r) => str(r['id']))]);
    if (!mounted) return;
    Navigator.pop(context);
    avisar(context, 'Empréstimo excluído.');
  }
}
