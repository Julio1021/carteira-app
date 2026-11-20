import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/categorias.dart';
import '../dados/modelos.dart';
import '../dados/planejar.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';
import '../widgets/formulario.dart';
import '../widgets/site.dart';
import '../dados/resumo.dart';

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
    final atr = ab.where((i) => i.st == 'atrasada').toList();
    final pct = m.total > 0 ? m.pago / m.total : 0.0;
    final grupos = <(String, String, Color)>[
      ('atrasada', 'Atrasadas', S.neg),
      ('hoje', 'Vencem hoje', S.second),
      ('breve', 'Próximos 7 dias', S.ink2),
      ('futura', ym == ymDe(hojeIso()) ? 'Mais adiante' : 'A pagar', S.ink2),
    ];
    final emConta = repo.contas.isEmpty ? null : saldoEmConta(repo);
    TextStyle b([Color? c]) => TextStyle(fontWeight: FontWeight.w700, color: c ?? S.ink);
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Contas a pagar', style: TextStyle(fontFamily: S.fonteNum, fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -.08, color: S.ink, height: 1.5)),
              const SizedBox(height: 2),
              if (temContas)
                Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Falta pagar '),
                  TextSpan(text: brl(m.falta), style: b()),
                  TextSpan(text: ' em ${mesLongo(ym).toLowerCase()}'),
                ]), style: TextStyle(fontSize: 12.5, color: S.muted, height: 1.5))
              else
                Text('Aluguel, luz, internet, parcelas e boletos', style: TextStyle(fontSize: 12.5, color: S.muted, height: 1.5)),
            ]),
          ),
          if (atr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 18, left: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: S.negSoft, borderRadius: BorderRadius.circular(999)),
                child: Text('${atr.length} atrasada${atr.length > 1 ? 's' : ''}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: S.neg)),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        BotaoSite('Nova conta', icone: Ico.mais, onTap: () => abrirFolha(context, const FormConta())),
        if (!temContas) ...[
          const SizedBox(height: 12),
          Text('O app mostra o que vence primeiro, avisa o que está atrasado e calcula quanto falta pagar.', style: TextStyle(color: S.ink2, fontSize: 13, height: 1.45)),
        ] else ...[
          const SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('Falta pagar', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: S.muted)),
            const SizedBox(width: 10),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(brl(m.falta), style: TextStyle(fontFamily: S.fonteNum, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.26, color: atr.isNotEmpty ? S.neg : S.ink)),
              ),
            ),
          ]),
          Text.rich(TextSpan(children: [
            TextSpan(text: '${ab.length} conta${ab.length == 1 ? '' : 's'}'),
            if (atr.isNotEmpty) ...[const TextSpan(text: ' · '), TextSpan(text: '${atr.length} atrasada${atr.length > 1 ? 's' : ''}', style: b(S.neg))],
          ]), style: TextStyle(fontSize: 12.5, color: S.muted, height: 1.5)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Stack(children: [
                Positioned.fill(child: ColoredBox(color: S.surface2)),
                Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: pct.clamp(0, 1).toDouble(), heightFactor: 1, child: ColoredBox(color: S.pos))),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Pago '),
            TextSpan(text: brl(m.pago), style: b()),
            const TextSpan(text: ' de '),
            TextSpan(text: brl(m.total), style: b()),
            if (emConta != null && ym == ymDe(hojeIso())) ...[
              const TextSpan(text: ' · faltará em conta '),
              TextSpan(text: brl(emConta - m.falta), style: b(emConta - m.falta < 0 ? S.neg : null)),
            ],
          ]), style: TextStyle(fontSize: 12.5, color: S.muted, height: 1.5)),
          for (final (st, nome, cor) in grupos)
            if (ab.any((i) => i.st == st)) ...[
              const SizedBox(height: 14),
              Text.rich(TextSpan(children: [
                TextSpan(text: nome),
                TextSpan(text: '   ${ab.where((i) => i.st == st).length} · ${brl(ab.where((i) => i.st == st).fold<double>(0, (a, i) => a + i.valor))}', style: const TextStyle(fontWeight: FontWeight.w500)),
              ]), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cor)),
              const SizedBox(height: 2),
              for (final i in ab.where((i) => i.st == st)) LinhaConta(i),
            ],
          if (m.pagas.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => verPagas = !verPagas),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      const TextSpan(text: 'Pagas'),
                      TextSpan(text: '   ${m.pagas.length} · ${brl(m.pagas.fold<double>(0, (a, i) => a + i.valor))}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    ]), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: S.pos)),
                  ),
                  IconeSite(verPagas ? '<path d="M18 15l-6-6-6 6"/>' : Ico.baixo, tam: 16, cor: S.muted),
                ]),
              ),
            ),
            if (verPagas) for (final i in m.pagas) LinhaConta(i),
          ],
          if (ab.isEmpty && m.pagas.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Nenhuma conta em ${mesLongo(ym).toLowerCase()}.', style: TextStyle(color: S.muted))),
        ],
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
    final atr = i.st == 'atrasada';
    final corSt = switch (i.st) { 'atrasada' => S.neg, 'hoje' => S.second, 'pago' => S.pos, _ => S.muted };
    final meta = <String>[
      catGasto(i.b.cat).nome,
      if (i.b.rep == 'parcelas') 'Parcela ${i.n}/${i.b.parc}' else if (i.b.rep == 'mensal') 'Todo mês' else 'Uma vez',
      if (i.b.variavel) 'valor estimado',
      i.b.pag,
    ].join(' · ');
    final mesAnt = !pago && i.ym.compareTo(ymDe(hojeIso())) < 0;
    final mes = mesesLongos[int.parse(i.venc.substring(5, 7)) - 1].substring(0, 3).toLowerCase();
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: S.line))),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: atr ? S.negSoft : (pago ? S.posSoft : S.surface2), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(i.venc.substring(8, 10), style: TextStyle(fontFamily: S.fonteNum, fontSize: 18, fontWeight: FontWeight.w700, height: 1, color: atr ? S.neg : (pago ? S.pos : S.ink))),
              const SizedBox(height: 3),
              Text(mes, style: TextStyle(fontSize: 10, letterSpacing: .2, height: 1, color: atr ? S.neg : (pago ? S.pos : S.ink2))),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: i.b.nome),
                if (mesAnt) TextSpan(text: ' · mês anterior', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: S.muted)),
              ]), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: S.ink, height: 1.5)),
              const SizedBox(height: 2),
              Text.rich(TextSpan(children: [
                TextSpan(text: i.statusTexto),
                TextSpan(text: ' · $meta', style: TextStyle(fontWeight: FontWeight.w500, color: S.muted)),
              ]), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: corSt, height: 1.5)),
            ]),
          ),
          GestureDetector(
            onTap: () => abrirFolha(context, FormConta(doc: i.b.d)),
            child: Padding(padding: const EdgeInsets.all(6), child: IconeSite('<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>', tam: 16, cor: S.muted)),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 58, top: 4),
          child: Row(children: [
            Expanded(child: Text('${i.b.variavel && !pago ? 'cerca de ' : ''}${brl(i.valor)}', style: TextStyle(fontFamily: S.fonteNum, fontSize: 16, fontWeight: FontWeight.w700, color: S.ink))),
            if (!pago)
              BotaoSm('Pagar', primario: true, seta: false, onTap: () => abrirFolha(context, FolhaPagar(i)))
            else if (i.fonte != 'extrato')
              BotaoSm('Desfazer', seta: false, onTap: () async {
                if (!await confirmar(context, 'Desfazer pagamento?', '${i.b.nome} volta a ficar em aberto${i.p?['criouGasto'] == true ? ' e o gasto lançado junto é apagado' : ''}.', sim: 'Desfazer')) return;
                final ids = [i.idPagto, if (i.p?['criouGasto'] == true && i.p?['gasto'] is String) i.p!['gasto'] as String];
                await repo.apagarVarios(ids);
                if (context.mounted) avisar(context, 'Pagamento desfeito.');
              }),
          ]),
        ),
        if (!pago && i.sug != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: S.surface2, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 2), child: IconeSite('<path d="M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7"/><path d="M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7"/>', tam: 14, cor: S.accent)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Já foi paga? Encontrei '),
                    TextSpan(text: i.sug!.desc, style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ' de ${brl(i.sug!.valor)} em ${dataCurta(i.sug!.data)}.'),
                  ]), style: TextStyle(fontSize: 12.5, color: S.ink2, height: 1.5)),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                BotaoSm('Sim, é esta', seta: false, onTap: () async {
                  await repo.salvarVarios(docsVincular(i, i.sug!));
                  if (context.mounted) avisar(context, '${i.b.nome} marcada como paga.');
                }),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => repo.salvar(docRejeitar(i, i.sug!.id)),
                  style: TextButton.styleFrom(foregroundColor: S.ink, textStyle: const TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w700)),
                  child: const Text('Não'),
                ),
              ]),
            ]),
          ),
      ]),
    );
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
      Text('Vencimento ${dataBr(widget.i.venc)}', style: TextStyle(color: G.apagado)),
      const SizedBox(height: 14),
      CampoValor(valorC, rotulo: 'Valor pago', grande: true, erro: erro),
      const Rotulo('Data do pagamento'),
      CampoData(data: data, onMudar: (v) => setState(() => data = v)),
      const SizedBox(height: 6),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: lancar,
        onChanged: (v) => setState(() => lancar = v),
        title: const Text('Lançar também nos gastos', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          widget.i.b.chave.isNotEmpty ? 'Desligado porque esta conta é reconhecida no extrato: ao importar, o gasto entra sozinho.' : 'Cria o gasto no extrato do mês, já ligado a esta conta.',
          style: TextStyle(color: G.apagado, fontSize: 12.5),
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
      if (erro != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(erro!, style: TextStyle(color: G.neg))),
      const Rotulo('Repete?'),
      Opcoes<String>(itens: const [('mensal', 'Todo mês'), ('parcelas', 'Parcelado'), ('unica', 'Uma vez')], valor: rep, onMudar: (v) => setState(() => rep = v)),
      const SizedBox(height: 14),
      if (rep == 'unica') ...[
        Text('Vencimento', style: TextStyle(fontWeight: FontWeight.w600, color: G.texto2)),
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
        title: const Text('Valor muda todo mês', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Como luz e água: o app usa o último valor pago como estimativa.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
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
