import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/modelos.dart';
import '../dados/planejar.dart';
import '../dados/repo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/formulario.dart';
import '../widgets/movimento.dart';

/// Abre "o que foi esse dinheiro?" para um depósito. Com [pre], já começa
/// com esse recebimento na primeira parte (vindo de "Recebi: ...").
Future<void> abrirClassificar(BuildContext context, Entrada e, {Renda? pre}) async {
  final msg = await abrirFolha<String>(context, FolhaClassificar(e: e, pre: pre));
  if (msg != null && context.mounted) avisar(context, msg);
}

/// Transferência entre suas contas, depósito dividido ou depósito que você
/// quer dividir: diz o que foi cada parte do dinheiro.
class FolhaClassificar extends StatefulWidget {
  final Entrada e;
  final Renda? pre;
  const FolhaClassificar({super.key, required this.e, this.pre});
  @override
  State<FolhaClassificar> createState() => _FolhaClassificarState();
}

class _Parte {
  String? chave;
  final c = TextEditingController();
  /// O valor foi preenchido pelo app (troca junto quando muda o tipo).
  bool auto = true;
}

class _FolhaClassificarState extends State<FolhaClassificar> {
  Entrada get e => widget.e;
  bool get transf => e.entreContas && e.valor > 0;
  /// null = ainda não escolheu (só nas transferências); true = foi entrada.
  late bool? entrada = transf ? (widget.pre != null ? true : null) : true;
  final partes = <_Parte>[];
  bool salvando = false;

  @override
  void initState() {
    super.initState();
    final ns = naturezas(RepoScope.ler(context), e.data);
    final p = _Parte();
    final pre = widget.pre == null ? null : ns.where((n) => n.rd == widget.pre!.id).firstOrNull;
    final n = pre ?? (transf ? null : ns.first);
    if (n != null) {
      p.chave = n.chave;
      p.c.text = valorCampo(_padrao(n, e.valor));
    }
    _ouvir(p);
    partes.add(p);
  }

  double _padrao(Natureza n, double livre) => n.valor != null && n.valor! > 0 && n.valor! <= livre + .009 ? n.valor! : livre;

  void _ouvir(_Parte p) => p.c.addListener(() => setState(() {}));

  @override
  void dispose() {
    for (final p in partes) {
      p.c.dispose();
    }
    super.dispose();
  }

  double get soma => partes.fold<double>(0, (a, p) => a + (lerValor(p.c.text) ?? 0));
  double get sobra => ((e.valor - soma) * 100).round() / 100;

  void _fechar(String msg) {
    mostrarConfirmacao(context);
    Navigator.pop(context, msg);
  }

  Future<void> _soTransferencia() async {
    await RepoScope.ler(context).salvar(Map<String, dynamic>.from(e.d)..remove('pend'));
    if (mounted) _fechar('Certo: foi só troca entre suas contas.');
  }

  Future<void> _confirmar(List<Natureza> ns) async {
    final repo = RepoScope.ler(context);
    final ps = <(Natureza, double)>[];
    for (var k = 0; k < partes.length; k++) {
      final p = partes[k];
      final n = ns.where((x) => x.chave == p.chave).firstOrNull;
      final v = lerValor(p.c.text);
      if (n == null) {
        avisar(context, partes.length == 1 ? 'Escolha o que foi esse dinheiro.' : 'Escolha o que foi a parte ${k + 1}.');
        return;
      }
      if (v == null || v <= 0) {
        avisar(context, 'Informe o valor de ${n.desc}.');
        return;
      }
      ps.add((n, v));
    }
    if (sobra < -.009) {
      avisar(context, 'As partes somam ${brl(soma)}, mais que os ${brl(e.valor)} do depósito.');
      return;
    }
    setState(() => salvando = true);
    final apagar = manuaisSubstituidos(repo, e, ps);
    await repo.salvarVarios(docsPartes(e, ps));
    if (apagar.isNotEmpty) await repo.apagarVarios(apagar);
    if (!mounted) return;
    _fechar(ps.length == 1 && sobra <= .009 ? 'Salvo como ${ps.first.$1.desc}.' : 'Dividido: ${ps.map((p) => '${p.$1.desc} ${brl(p.$2)}').join(' + ')}.');
  }

  Future<void> _desfazer() async {
    final repo = RepoScope.ler(context);
    final x = desfazerDivisao(repo, e.d['div'] as String);
    if (x.salvar.isNotEmpty) await repo.salvarVarios(x.salvar);
    if (x.apagar.isNotEmpty) await repo.apagarVarios(x.apagar);
    if (mounted) _fechar('Divisão desfeita: voltou a ser um lançamento só.');
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    if (e.d['div'] is String) return _dividido(repo);
    final ns = naturezas(repo, e.data);
    final titulo = transf ? 'Transferência de outra conta sua' : e.desc;
    return CorpoFolha([
      TituloFolha(titulo),
      const SizedBox(height: 2),
      Text('${brl(e.valor)} em ${dataCurta(e.data)}${transf ? ' · ainda não conta como entrada' : ''}', style: TextStyle(color: G.apagado, fontSize: 13)),
      if (transf) ...[
        const Rotulo('O que foi esse dinheiro?'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: OpcaoCartao(sel: entrada == false, icone: Icons.sync_alt_rounded, titulo: 'Só mudei de conta', sub: 'Não conta como entrada', onTap: () => setState(() => entrada = false))),
          const SizedBox(width: 10),
          Expanded(child: OpcaoCartao(sel: entrada == true, icone: Icons.south_west_rounded, titulo: 'Foi uma entrada', sub: 'Salário, vale ou 13º', onTap: () => setState(() => entrada = true))),
        ]),
      ],
      if (entrada == true) ...[
        for (var k = 0; k < partes.length; k++) _parteUi(k, ns),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add_rounded),
            onPressed: partes.length >= 4 || sobra <= .009
                ? null
                : () => setState(() {
                      final p = _Parte()..c.text = valorCampo(sobra);
                      _ouvir(p);
                      partes.add(p);
                    }),
            label: Text(partes.length == 1 ? 'Veio mais uma coisa junto' : 'Mais uma parte'),
          ),
        ),
        if (soma > 0)
          _Resumo(e: e, partes: [
          for (final p in partes)
            (ns.where((n) => n.chave == p.chave).firstOrNull?.desc ?? 'Falta escolher o que foi', lerValor(p.c.text) ?? 0),
        ], sobra: sobra, transf: transf),
      ],
      const SizedBox(height: 18),
      if (entrada == false)
        FilledButton.icon(icon: const Icon(Icons.check_rounded), onPressed: _soTransferencia, label: const Text('Confirmar'))
      else if (entrada == true)
        FilledButton.icon(icon: const Icon(Icons.check_rounded), onPressed: salvando ? null : () => _confirmar(ns), label: const Text('Confirmar')),
    ]);
  }

  Widget _parteUi(int k, List<Natureza> ns) {
    final p = partes[k];
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(color: G.campo, borderRadius: BorderRadius.circular(16), border: Border.all(color: G.borda)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(partes.length == 1 ? 'Foi o quê?' : 'Parte ${k + 1}: foi o quê?', style: TextStyle(fontWeight: FontWeight.w700, color: G.texto))),
          if (k > 0)
            IconButton(
              tooltip: 'Tirar esta parte',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => partes.removeAt(k).c.dispose()),
              icon: Icon(Icons.close_rounded, color: G.apagado),
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in ns)
            ChoiceChip(
              selected: p.chave == n.chave,
              label: Text(n.rotulo),
              labelStyle: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, color: p.chave == n.chave ? G.tinta : G.texto2),
              onSelected: (_) => setState(() {
                p.chave = n.chave;
                if (p.auto || p.c.text.isEmpty) {
                  final outras = soma - (lerValor(p.c.text) ?? 0);
                  p.c.text = valorCampo(_padrao(n, ((e.valor - outras) * 100).round() / 100));
                  p.auto = true;
                }
              }),
            ),
        ]),
        const SizedBox(height: 12),
        Focus(
          onFocusChange: (f) {
            if (f) p.auto = false;
          },
          child: CampoValor(p.c, rotulo: 'Valor'),
        ),
      ]),
    );
  }

  Widget _dividido(Repo repo) {
    final ps = partesDivisao(repo, e.d['div'] as String)..sort((a, b) => b.valor.compareTo(a.valor));
    return CorpoFolha([
      const TituloFolha('Depósito dividido'),
      const SizedBox(height: 2),
      Text('${brl(numD(e.d['divT']))} em ${dataCurta(e.data)}, separado em:', style: TextStyle(color: G.apagado, fontSize: 13)),
      const SizedBox(height: 12),
      CaixaLista([
        for (final x in ps)
          ListTile(
            leading: IconeCategoria(catEntrada(x.cat), tam: 36),
            title: Text(x.entreContas ? 'Continua como transferência entre contas' : x.desc, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(catEntrada(x.cat).nome, style: TextStyle(color: G.apagado, fontSize: 12.5)),
            trailing: Text(brl(x.valor), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ]),
      const SizedBox(height: 16),
      OutlinedButton.icon(icon: const Icon(Icons.undo_rounded), onPressed: _desfazer, label: const Text('Desfazer divisão')),
    ]);
  }
}

/// Barra e legenda de como o depósito fica.
class _Resumo extends StatelessWidget {
  final Entrada e;
  final List<(String, double)> partes;
  final double sobra;
  final bool transf;
  const _Resumo({required this.e, required this.partes, required this.sobra, required this.transf});
  static const _cores = [Color(0xFFE8A33A), Color(0xFF3F6FD8), Color(0xFF1F9D6B), Color(0xFFB57BFF)];
  @override
  Widget build(BuildContext context) {
    final passou = sobra < -.009;
    final itens = [
      for (var k = 0; k < partes.length; k++) (partes[k].$1, partes[k].$2, _cores[k % _cores.length]),
      if (sobra > .009) (transf ? 'Continua como transferência entre contas' : 'Continua como ${e.desc}', sobra, G.apagado),
    ];
    Widget leg(String n, double v, Color c) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(n, style: TextStyle(fontSize: 13, color: G.texto2, height: 1.35))),
            const SizedBox(width: 8),
            Text(brl(v), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: G.texto)),
          ]),
        );
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: G.borda)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Depósito de ${brl(e.valor)}', style: TextStyle(fontWeight: FontWeight.w700, color: G.texto)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 12,
            child: passou
                ? Container(color: G.neg)
                : Row(children: [
                    for (var k = 0; k < itens.length; k++) ...[
                      if (k > 0) const SizedBox(width: 2),
                      Expanded(flex: ((itens[k].$2 / e.valor) * 1000).round().clamp(30, 1000).toInt(), child: Container(color: itens[k].$3)),
                    ],
                  ]),
          ),
        ),
        const SizedBox(height: 4),
        for (final (n, v, c) in itens) leg(n, v, c),
        const SizedBox(height: 8),
        Text(
          passou ? 'As partes passam do depósito em ${brl(-sobra)}.' : 'O total no extrato continua ${brl(e.valor)}: nada fica duplicado.',
          style: TextStyle(fontSize: 12, color: passou ? G.negTexto : G.apagado),
        ),
      ]),
    );
  }
}

/// Cartão de escolha com rádio (ex.: "Só mudei de conta" / "Foi uma entrada").
class OpcaoCartao extends StatelessWidget {
  final bool sel;
  final IconData icone;
  final String titulo, sub;
  final VoidCallback onTap;
  const OpcaoCartao({super.key, required this.sel, required this.icone, required this.titulo, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: sel ? G.lavandaFundo : G.campo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: sel ? G.lavanda : G.borda, width: sel ? 1.6 : 1)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icone, size: 20, color: sel ? G.lavandaIcone : G.apagado),
                const Spacer(),
                Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: sel ? G.lavanda : G.apagado),
              ]),
              const SizedBox(height: 8),
              Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: G.texto, height: 1.25)),
              const SizedBox(height: 3),
              Text(sub, style: TextStyle(fontSize: 12, color: G.apagado, height: 1.3)),
            ]),
          ),
        ),
      );
}
