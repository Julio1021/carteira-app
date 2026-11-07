import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/categorias.dart';
import '../dados/modelos.dart';
import '../dados/planejar.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/formulario.dart';

/// Cartão "Contas a pagar" da aba Planejar.
class CartaoContas extends StatefulWidget {
  const CartaoContas({super.key});
  @override
  State<CartaoContas> createState() => _CartaoContasState();
}

class _CartaoContasState extends State<CartaoContas> {
  String ym = ymDe(hojeIso());
  bool verAtrasadas = false, verPagas = false;

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final temContas = repo.doTipo('pagar').isNotEmpty;
    final m = mesContas(repo, ym);
    final ab = m.abertas;
    final grupos = <(String, String)>[('hoje', 'Vencem hoje'), ('breve', 'Próximos 7 dias'), ('futura', ym == ymDe(hojeIso()) ? 'Mais adiante' : 'A pagar')];
    final atr = ab.where((i) => i.st == 'atrasada').toList();
    final pct = m.total > 0 ? m.pago / m.total : 0.0;

    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Contas a pagar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          FilledButton.icon(
            onPressed: () => abrirFolha(context, const FormConta()),
            style: FilledButton.styleFrom(minimumSize: const Size(10, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nova conta'),
          ),
        ]),
        const SizedBox(height: 12),
        if (!temContas)
          const Text('Cadastre aluguel, luz, internet, parcelas e boletos. O app mostra o que vence primeiro, avisa o que está atrasado e calcula quanto falta pagar.',
              style: TextStyle(color: G.texto2, height: 1.35))
        else ...[
          SeletorMes(ym: ym, onMudar: (v) => setState(() => ym = v)),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Falta pagar ', style: TextStyle(color: G.texto2)),
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(brl(m.falta), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: m.nAtrasadas > 0 ? G.neg : G.texto)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Barra(pct, cor: G.pos),
          const SizedBox(height: 6),
          Text('Pago ${brl(m.pago)} de ${brl(m.total)}${ab.isNotEmpty ? ' · ${ab.length} em aberto' : ''}', style: const TextStyle(color: G.apagado, fontSize: 12.5)),
          const SizedBox(height: 12),
          if (atr.isNotEmpty) ...[
            _BlocoAtrasadas(lista: atr, aberto: verAtrasadas, onTap: () => setState(() => verAtrasadas = !verAtrasadas)),
            const SizedBox(height: 12),
          ],
          for (final (st, nome) in grupos)
            if (ab.any((i) => i.st == st)) ...[
              _TituloGrupo(nome, ab.where((i) => i.st == st).toList()),
              CaixaLista([for (final i in ab.where((i) => i.st == st)) LinhaConta(i)]),
              const SizedBox(height: 12),
            ],
          if (m.pagas.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => verPagas = !verPagas),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: _TituloGrupo('Pagas', m.pagas, semPadding: true)),
                  Icon(verPagas ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: G.apagado),
                ]),
              ),
            ),
            if (verPagas) ...[const SizedBox(height: 6), CaixaLista([for (final i in m.pagas) LinhaConta(i)])],
          ],
          if (ab.isEmpty && m.pagas.isEmpty) Text('Nenhuma conta em ${mesLongo(ym).toLowerCase()}.', style: const TextStyle(color: G.apagado)),
        ],
      ]),
    );
  }
}

class _TituloGrupo extends StatelessWidget {
  final String nome;
  final List<InstConta> l;
  final bool semPadding;
  const _TituloGrupo(this.nome, this.l, {this.semPadding = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: semPadding ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8, left: 2),
        child: Text('$nome  ·  ${l.length} · ${brl(l.fold<double>(0, (a, i) => a + i.valor))}', style: const TextStyle(fontWeight: FontWeight.w700, color: G.texto2, fontSize: 13)),
      );
}

class _BlocoAtrasadas extends StatelessWidget {
  final List<InstConta> lista;
  final bool aberto;
  final VoidCallback onTap;
  const _BlocoAtrasadas({required this.lista, required this.aberto, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final por = <String, int>{};
    for (final i in lista) {
      por[i.b.nome] = (por[i.b.nome] ?? 0) + 1;
    }
    final nomes = por.entries.map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key).join(', ');
    return Container(
      decoration: BoxDecoration(color: const Color(0x12FF6B81), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x47FF6B81))),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: G.neg, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${lista.length} atrasada${lista.length > 1 ? 's' : ''} · ${brl(lista.fold<double>(0, (a, i) => a + i.valor))}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFFF8DA0))),
                  Text(nomes, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: G.apagado, fontSize: 12)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(99)),
                child: Text(aberto ? 'Fechar' : 'Ver', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ]),
          ),
        ),
        if (aberto) Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), child: CaixaLista([for (final i in lista) LinhaConta(i)])),
      ]),
    );
  }
}

/// Uma conta na lista, com o botão Pagar e a sugestão de gasto encontrado.
class LinhaConta extends StatelessWidget {
  final InstConta i;
  const LinhaConta(this.i, {super.key});

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final pago = i.st == 'pago';
    final corSt = switch (i.st) { 'atrasada' => G.neg, 'hoje' => G.alerta, 'pago' => G.pos, _ => G.apagado };
    final meta = <String>[
      if (i.b.rep == 'parcelas') 'Parcela ${i.n}/${i.b.parc}',
      if (i.ym != ymDe(hojeIso()) && !pago && i.st == 'atrasada') mesLongo(i.ym).toLowerCase(),
      catGasto(i.b.cat).nome,
    ].join(' · ');
    return Column(children: [
      InkWell(
        onTap: () => abrirFolha(context, FormConta(doc: i.b.d)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(children: [
            CaixaData(i.venc, destaque: i.st == 'hoje', cor: i.st == 'atrasada' ? G.neg : (pago ? G.pos : null)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i.b.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(i.statusTexto, style: TextStyle(color: corSt, fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: G.apagado, fontSize: 12)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(brl(i.valor), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (!pago)
                FilledButton(
                  onPressed: () => abrirFolha(context, FolhaPagar(i)),
                  style: FilledButton.styleFrom(minimumSize: const Size(10, 32), padding: const EdgeInsets.symmetric(horizontal: 14), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  child: const Text('Pagar'),
                )
              else if (i.fonte != 'extrato')
                TextButton(
                  onPressed: () async {
                    if (!await confirmar(context, 'Desfazer pagamento?', '${i.b.nome} volta a ficar em aberto${i.p?['criouGasto'] == true ? ' e o gasto lançado junto é apagado' : ''}.', sim: 'Desfazer')) return;
                    final ids = [i.idPagto, if (i.p?['criouGasto'] == true && i.p?['gasto'] is String) i.p!['gasto'] as String];
                    await repo.apagarVarios(ids);
                    if (context.mounted) avisar(context, 'Pagamento desfeito.');
                  },
                  style: TextButton.styleFrom(minimumSize: const Size(10, 30), padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('Desfazer', style: TextStyle(fontSize: 12.5)),
                ),
            ]),
          ]),
        ),
      ),
      if (!pago && i.sug != null)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Já foi paga? Encontrei “${i.sug!.desc}” de ${brl(i.sug!.valor)} em ${dataCurta(i.sug!.data)}.', style: const TextStyle(fontSize: 12.5, color: G.texto2)),
            const SizedBox(height: 6),
            Row(children: [
              OutlinedButton(
                onPressed: () async {
                  await repo.salvarVarios(docsVincular(i, i.sug!));
                  if (context.mounted) avisar(context, '${i.b.nome} marcada como paga.');
                },
                style: OutlinedButton.styleFrom(minimumSize: const Size(10, 34)),
                child: const Text('Sim, é esta'),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: () => repo.salvar(docRejeitar(i, i.sug!.id)), child: const Text('Não')),
            ]),
          ]),
        ),
    ]);
  }
}

/// Folha "Pagar conta": valor, data, lançar nos gastos ou vincular a um gasto existente.
class FolhaPagar extends StatefulWidget {
  final InstConta i;
  const FolhaPagar(this.i, {super.key});
  @override
  State<FolhaPagar> createState() => _FolhaPagarState();
}

class _FolhaPagarState extends State<FolhaPagar> {
  late final valorC = TextEditingController(text: valorCampo(widget.i.valor));
  late String data = hojeIso().compareTo('${widget.i.ym}-01') < 0 ? widget.i.venc : hojeIso();
  late bool lancar = widget.i.b.chave.isEmpty;
  String? erro;

  @override
  void dispose() {
    valorC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final perto = gastosParecidos(repo, widget.i);
    return CorpoFolha([
      TituloFolha('Pagar ${widget.i.b.nome}'),
      Text('Vencimento ${dataBr(widget.i.venc)}', style: const TextStyle(color: G.apagado)),
      const SizedBox(height: 14),
      CampoValor(valorC, rotulo: 'Valor pago', grande: true, erro: erro),
      const Rotulo('Data do pagamento'),
      CampoData(data: data, onMudar: (v) => setState(() => data = v)),
      const SizedBox(height: 6),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: lancar,
        onChanged: (v) => setState(() => lancar = v),
        title: const Text('Lançar também nos gastos', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          widget.i.b.chave.isNotEmpty ? 'Desligado porque esta conta é reconhecida no extrato: ao importar, o gasto entra sozinho.' : 'Cria o gasto no extrato do mês, já ligado a esta conta.',
          style: const TextStyle(color: G.apagado, fontSize: 12.5),
        ),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        icon: const Icon(Icons.check_rounded),
        label: const Text('Confirmar pagamento'),
        onPressed: () async {
          final v = lerValor(valorC.text);
          if (v == null || v <= 0) {
            setState(() => erro = 'Informe o valor pago.');
            return;
          }
          await repo.salvarVarios(docsPagamento(widget.i, (v * 100).round() / 100, data, lancarGasto: lancar));
          HapticFeedback.lightImpact();
          if (!context.mounted) return;
          Navigator.pop(context);
          avisar(context, '${widget.i.b.nome} paga${lancar ? ' e lançada nos gastos' : ''}.');
        },
      ),
      if (perto.isNotEmpty) ...[
        const Rotulo('Já está nos seus gastos? Vincule em vez de lançar de novo:'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in perto)
            ActionChip(
              avatar: Icon(catGasto(g.cat).icone, size: 16),
              label: Text('${g.desc} · ${brl(g.valor)} · ${dataCurta(g.data)}'),
              onPressed: () async {
                await repo.salvarVarios(docsVincular(widget.i, g));
                if (!context.mounted) return;
                Navigator.pop(context);
                avisar(context, '${widget.i.b.nome} marcada como paga.');
              },
            ),
        ]),
      ],
    ]);
  }
}

/// Formulário de conta a pagar (nova ou editar).
class FormConta extends StatefulWidget {
  final Doc? doc;
  const FormConta({super.key, this.doc});
  @override
  State<FormConta> createState() => _FormContaState();
}

class _FormContaState extends State<FormConta> {
  final nomeC = TextEditingController(), valorC = TextEditingController(), chaveC = TextEditingController();
  String rep = 'mensal';
  int dia = 10, cada = 1, parc = 2;
  String ini = ymDe(hojeIso());
  String data = hojeIso();
  String cat = 'contas', pag = 'Boleto';
  bool variavel = false;
  String? erro;

  ContaPagar? get base => widget.doc == null ? null : ContaPagar(widget.doc!);

  @override
  void initState() {
    super.initState();
    final b = base;
    if (b != null) {
      nomeC.text = b.nome;
      valorC.text = valorCampo(b.valor);
      chaveC.text = b.chave;
      rep = b.rep;
      dia = b.dia;
      cada = b.cada;
      parc = b.parc < 2 ? 2 : b.parc;
      ini = b.ini == '0000-00' ? ini : b.ini;
      data = b.data ?? data;
      cat = b.cat;
      pag = b.pag;
      variavel = b.variavel;
    }
  }

  @override
  void dispose() {
    nomeC.dispose();
    valorC.dispose();
    chaveC.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = nomeC.text.trim(), v = lerValor(valorC.text);
    if (nome.isEmpty) return setState(() => erro = 'Informe o nome da conta.');
    if (v == null || v <= 0) return setState(() => erro = 'Informe o valor, como 150,00.');
    final repo = RepoScope.ler(context);
    final doc = <String, dynamic>{
      ...?widget.doc,
      'kind': 'pagar',
      'id': base?.id ?? novoId('pg'),
      'nome': nome,
      'valor': (v * 100).round() / 100,
      'rep': rep,
      'cat': cat,
      'pag': pag,
      'chave': chaveC.text.trim(),
      'variavel': variavel,
      'criado': base?.criado ?? DateTime.now().millisecondsSinceEpoch,
    };
    doc.remove('data');
    doc.remove('parc');
    if (rep == 'mensal') {
      doc['dia'] = dia;
      doc['ini'] = ini;
      if (cada > 1) {
        doc['cada'] = cada;
      } else {
        doc.remove('cada');
      }
    } else if (rep == 'parcelas') {
      doc.remove('cada');
      doc.remove('fim');
      doc['dia'] = dia;
      doc['ini'] = ini;
      doc['parc'] = parc;
    } else {
      doc.remove('cada');
      doc.remove('fim');
      doc['data'] = data;
      doc['dia'] = int.parse(data.substring(8, 10));
      doc['ini'] = ymDe(data);
    }
    await repo.salvar(doc);
    if (!mounted) return;
    Navigator.pop(context);
    avisar(context, base != null ? 'Conta atualizada.' : '$nome adicionada às contas a pagar.');
  }

  Future<void> _excluir() async {
    final b = base!;
    if (!await confirmar(context, 'Excluir ${b.nome}?', 'A conta e o histórico de pagamentos dela serão apagados. Os gastos lançados continuam no extrato.')) return;
    if (!mounted) return;
    final repo = RepoScope.ler(context);
    await repo.apagarVarios([b.id, ...repo.doTipo('pagto').where((p) => p['conta'] == b.id).map((p) => str(p['id']))]);
    if (!mounted) return;
    Navigator.pop(context);
    avisar(context, 'Conta excluída.');
  }

  Future<void> _encerrar() async {
    final b = base!;
    final mesAnt = ymAdd(ymDe(hojeIso()), -1);
    await RepoScope.ler(context).salvar({...b.d, 'fim': b.fim == null ? mesAnt : ''});
    if (!mounted) return;
    Navigator.pop(context);
    avisar(context, b.fim == null ? '${b.nome} encerrada: não aparece mais a partir deste mês.' : '${b.nome} reaberta.');
  }

  @override
  Widget build(BuildContext context) {
    return CorpoFolha([
      TituloFolha(base != null ? 'Editar conta' : 'Nova conta', onExcluir: base != null ? _excluir : null),
      const SizedBox(height: 12),
      TextField(controller: nomeC, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Aluguel, Luz, Internet')),
      const SizedBox(height: 12),
      CampoValor(valorC, rotulo: variavel ? 'Valor aproximado' : 'Valor'),
      if (erro != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(erro!, style: const TextStyle(color: G.neg))),
      const Rotulo('Repete?'),
      Opcoes<String>(itens: const [('mensal', 'Todo mês'), ('parcelas', 'Parcelado'), ('unica', 'Uma vez')], valor: rep, onMudar: (v) => setState(() => rep = v)),
      const SizedBox(height: 14),
      if (rep == 'unica') ...[
        const Text('Vencimento', style: TextStyle(fontWeight: FontWeight.w700, color: G.texto2)),
        const SizedBox(height: 8),
        CampoData(data: data, onMudar: (v) => setState(() => data = v), comOntem: false),
      ] else ...[
        Row(children: [
          Expanded(child: CampoDia(dia: dia, onMudar: (v) => setState(() => dia = v))),
          const SizedBox(width: 10),
          Expanded(
            child: rep == 'parcelas'
                ? DropdownButtonFormField<int>(
                    initialValue: parc,
                    isExpanded: true,
                    dropdownColor: G.fundo2,
                    decoration: const InputDecoration(labelText: 'Parcelas'),
                    items: [for (var q = 2; q <= 60; q++) DropdownMenuItem(value: q, child: Text('$q vezes'))],
                    onChanged: (v) => setState(() => parc = v ?? parc),
                  )
                : DropdownButtonFormField<int>(
                    initialValue: const [1, 2, 3, 6, 12].contains(cada) ? cada : 1,
                    isExpanded: true,
                    dropdownColor: G.fundo2,
                    decoration: const InputDecoration(labelText: 'Frequência'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Todo mês')),
                      DropdownMenuItem(value: 2, child: Text('A cada 2 meses')),
                      DropdownMenuItem(value: 3, child: Text('A cada 3 meses')),
                      DropdownMenuItem(value: 6, child: Text('A cada 6 meses')),
                      DropdownMenuItem(value: 12, child: Text('Uma vez por ano')),
                    ],
                    onChanged: (v) => setState(() => cada = v ?? 1),
                  ),
          ),
        ]),
        const SizedBox(height: 12),
        CampoMes(ym: ini, rotulo: rep == 'parcelas' ? 'Primeira parcela em' : 'A partir de', onMudar: (v) => setState(() => ini = v)),
      ],
      const Rotulo('Categoria'),
      DropdownButtonFormField<String>(
        initialValue: cat,
        isExpanded: true,
        dropdownColor: G.fundo2,
        decoration: const InputDecoration(),
        items: [
          for (final c in categoriasGasto)
            DropdownMenuItem(value: c.id, child: Row(children: [Icon(c.icone, size: 18, color: c.cor), const SizedBox(width: 10), Text(c.nome)])),
        ],
        onChanged: (v) => setState(() => cat = v ?? cat),
      ),
      const Rotulo('Como costuma pagar'),
      Opcoes<String>(itens: [for (final p in formasPagamento) (p, p)], valor: pag, onMudar: (v) => setState(() => pag = v)),
      const SizedBox(height: 14),
      TextField(
        controller: chaveC,
        decoration: const InputDecoration(labelText: 'Como aparece no extrato (opcional)', hintText: 'Ex.: VIVO, ENEL, CONDOMINIO', helperText: 'Quando um gasto com esse nome aparecer, a conta fica paga sozinha.'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: variavel,
        onChanged: (v) => setState(() => variavel = v),
        title: const Text('Valor muda todo mês', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('Como luz e água: o app usa o último valor pago como estimativa.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: _salvar, child: Text(base != null ? 'Salvar alterações' : 'Adicionar conta')),
      if (base != null && base!.rep == 'mensal') ...[
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _encerrar, child: Text(base!.fim == null ? 'Encerrar esta conta (parou de pagar)' : 'Reabrir esta conta')),
      ],
    ]);
  }
}
