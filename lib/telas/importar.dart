import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/importar.dart';
import '../dados/inter.dart';
import '../dados/modelos.dart';
import '../dados/pdf_texto.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/formulario.dart';

Future<Uint8List?> _escolherArquivo() async {
  final f = await FilePicker.pickFile(type: FileType.any);
  if (f == null) return null;
  return f.readAsBytes();
}

String _texto(Uint8List b) {
  try {
    return utf8.decode(b);
  } catch (_) {
    return latin1.decode(b);
  }
}

// =====================================================================
// Extrato do banco (OFX)
// =====================================================================

class TelaImportarExtrato extends StatefulWidget {
  const TelaImportarExtrato({super.key});
  @override
  State<TelaImportarExtrato> createState() => _TelaImportarExtratoState();
}

class _TelaImportarExtratoState extends State<TelaImportarExtrato> {
  Ofx? ofx;
  String nome = '';
  String dono = '';
  final over = <String, String>{};
  bool pularDup = true, verIgn = false, ocupado = false;
  final donoC = TextEditingController();

  @override
  void dispose() {
    donoC.dispose();
    super.dispose();
  }

  Future<void> _abrir() async {
    final b = await _escolherArquivo();
    if (b == null) return;
    final t = _texto(b);
    if (!t.toUpperCase().contains('<STMTTRN>') && !t.toUpperCase().contains('<OFX>')) {
      if (mounted) avisar(context, 'Esse arquivo não parece um extrato OFX. No app do banco, exporte o extrato no formato OFX.');
      return;
    }
    final o = lerOfx(t);
    if (!mounted) return;
    final repo = RepoScope.ler(context);
    final conta = repo.porId(contaIdOfx(o));
    final d = conta != null && conta['dono'] is String ? conta['dono'] as String : adivinhaDono(o.tx);
    setState(() {
      ofx = o;
      dono = d;
      donoC.text = d;
      over.clear();
    });
  }

  Future<void> _importar(PlanoImport p) async {
    final repo = RepoScope.ler(context);
    setState(() => ocupado = true);
    final docs = docsImportacao(repo, ofx!, p, dono: dono, over: over, pularDup: pularDup);
    final ni = docs.where((d) => d['kind'] == 'invest').length;
    if (p.apagarEntradas.isNotEmpty) await repo.apagarVarios(p.apagarEntradas);
    await repo.salvarVarios(docs);
    if (!mounted) return;
    final ng = docs.where((d) => d['kind'] == 'gasto').length, ne = docs.where((d) => d['kind'] == 'entrada').length;
    setState(() {
      ocupado = false;
      ofx = null;
    });
    avisar(context, '$ng gasto(s), $ne entrada(s)${ni > 0 ? ' e $ni investimento(s)' : ''} importados.');
  }

  Future<void> _trocarCat(ItemImport x, bool entrada) async {
    final cats = entrada ? categoriasEntrada : categoriasGasto;
    final v = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .75),
          child: ListView(shrinkWrap: true, children: [
            ListTile(title: Text(x.desc, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Vale para todos deste estabelecimento, agora e nas próximas importações.')),
            for (final cat in cats) ListTile(leading: Icon(cat.icone, color: cat.cor), title: Text(cat.nome), selected: cat.id == x.cat, onTap: () => Navigator.pop(c, cat.id)),
            ListTile(leading: Icon(Icons.block_rounded, color: G.apagado), title: const Text('Não é gasto (ignorar)'), onTap: () => Navigator.pop(c, 'ignorar')),
          ]),
        ),
      ),
    );
    if (v != null) setState(() => over[entrada ? 'E|${x.ch}' : x.ch] = v);
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final o = ofx;
    return Scaffold(
      appBar: AppBar(title: const Text('Importar extrato', style: TextStyle(fontWeight: FontWeight.w700))),
      body: o == null ? _inicio(repo) : _previa(repo, o),
    );
  }

  Widget _inicio(dynamic repo) {
    final feitas = importacoesFeitas(RepoScope.of(context));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 40), children: [
      Cartao(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Traga os gastos e entradas do banco de uma vez', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              'No app do banco (Inter, Nubank, Mercado Pago…), exporte o extrato da conta no formato OFX e escolha o arquivo aqui. O app separa gastos e entradas, sugere a categoria, reconhece salário e vale, pagamento de fatura e transferências entre suas contas, e não duplica o que já foi importado ou lançado à mão.',
              style: TextStyle(color: G.texto2, height: 1.4)),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _abrir, icon: const Icon(Icons.file_open_outlined), label: const Text('Escolher arquivo OFX')),
        ]),
      ),
      if (feitas.isNotEmpty) ...[
        const Rotulo('Extratos importados'),
        CaixaLista([
          for (final f in feitas)
            ListTile(
              title: Text('${f.n} lançamento(s)', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${dataBr(f.ini)} a ${dataBr(f.fim)}${f.quando > 0 ? ' · importado em ${dataBr(isoDe(DateTime.fromMillisecondsSinceEpoch(f.quando)))}' : ''}', style: TextStyle(color: G.apagado, fontSize: 12.5)),
              trailing: TextButton(
                onPressed: () async {
                  final r = RepoScope.ler(context);
                  if (!await confirmar(context, 'Desfazer esta importação?', 'Apaga os ${f.n} lançamentos que vieram desse arquivo. O que você lançou à mão continua.', sim: 'Desfazer')) return;
                  await r.apagarVarios([for (final d in [...r.doTipo('gasto'), ...r.doTipo('entrada'), ...r.doTipo('invest'), ...r.doTipo('cpag')]) if (d['imp'] == f.id) str(d['id'])]);
                  if (mounted) avisar(this.context, 'Importação desfeita.');
                },
                child: Text('Desfazer', style: TextStyle(color: G.neg)),
              ),
            ),
        ]),
      ],
    ]);
  }

  Widget _previa(dynamic repo, Ofx o) {
    final rp = RepoScope.of(context);
    final propInv = propriasSaoInvestimento(rp);
    final p = planoImport(rp, o, dono: dono, over: over, propInvest: propInv);
    final gastos = p.gastos.where((x) => x.cat != 'ignorar').toList();
    final entram = gastos.where((x) => !(x.dup && pularDup)).toList();
    final ents = p.entradas.where((x) => x.cat != 'ignorar').toList();
    final candidatos = candidatosDono(o.tx);
    return Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 110), children: [
        Cartao(
          gradiente: G.gradHero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nomeBanco(o), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('${o.inicio != null ? dataBr(o.inicio!) : '?'} a ${o.fim != null ? dataBr(o.fim!) : '?'} · ${o.tx.length} movimentações', style: TextStyle(color: G.texto2)),
            if (o.saldo != null) Text('Saldo em ${dataBr(o.saldoData!)}: ${brl(o.saldo!)} (atualiza "Em conta")', style: TextStyle(color: G.texto2, fontSize: 12.5)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Num('${entram.length}', 'gastos novos')),
              Expanded(child: _Num('${ents.length}', 'entradas')),
              if (p.invest.isNotEmpty) Expanded(child: _Num('${p.invest.length}', 'investidos')),
              Expanded(child: _Num('${p.jaImportados}', 'já estavam')),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Cartao(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Seu nome no extrato', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Pix entre suas próprias contas não viram gasto nem entrada.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
            const SizedBox(height: 10),
            TextField(controller: donoC, decoration: const InputDecoration(hintText: 'Nome completo, como aparece no Pix'), onSubmitted: (v) => setState(() => dono = v.trim())),
            if (candidatos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in candidatos)
                  ChoiceChip(
                    selected: nomeIgual(c.nome, dono),
                    label: Text(c.nome),
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, color: nomeIgual(c.nome, dono) ? G.tinta : G.texto2),
                    onSelected: (_) => setState(() {
                      dono = c.nome;
                      donoC.text = c.nome;
                    }),
                  ),
              ]),
            ],
          ]),
        ),
        if (p.duplicados > 0) ...[
          const SizedBox(height: 12),
          SwitchListTile(
            value: pularDup,
            onChanged: (v) => setState(() => pularDup = v),
            title: Text('Pular ${p.duplicados} que parecem já lançados à mão', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Mesmo dia e mesmo valor de um gasto que você já tinha lançado.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
          ),
        ],
        if (gastos.isNotEmpty) ...[
          const Rotulo('Gastos (toque para trocar a categoria)'),
          CaixaLista([
            for (final x in gastos)
              ListTile(
                onTap: () => _trocarCat(x, false),
                leading: IconeCategoria(catGasto(x.cat), tam: 36),
                title: Text(x.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: x.dup && pularDup ? G.apagado : G.texto)),
                subtitle: Text('${dataCurta(x.t.data)} · ${catGasto(x.cat).nome}${x.dup ? ' · já lançado?' : ''}', style: TextStyle(color: x.dup ? G.alerta : G.apagado, fontSize: 12)),
                trailing: Text(brl(-x.valor), style: TextStyle(fontWeight: FontWeight.w700, decoration: x.dup && pularDup ? TextDecoration.lineThrough : null)),
              ),
          ]),
        ],
        if (ents.isNotEmpty) ...[
          const Rotulo('Entradas'),
          CaixaLista([
            for (final x in ents)
              ListTile(
                onTap: x.ch.startsWith('__') ? null : () => _trocarCat(x, true),
                leading: IconeCategoria(catEntrada(x.cat), tam: 36),
                title: Text(x.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${dataCurta(x.t.data)} · ${catEntrada(x.cat).nome}', style: TextStyle(color: G.apagado, fontSize: 12)),
                trailing: Text(brl(x.valor, sinal: true), style: TextStyle(fontWeight: FontWeight.w700, color: G.pos)),
              ),
          ]),
        ],
        if (p.propSaidas > 0) ...[
          const SizedBox(height: 12),
          SwitchListTile(
            value: propInv,
            onChanged: (v) => rp.salvar(docPropriasInvest(rp, v)),
            title: Text('Os ${p.propSaidas} Pix para suas próprias contas foram para investir', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Ex.: mandar dinheiro para o Nubank ou o Mercado Pago para aplicar. Ligado, eles aparecem como Investido. A escolha fica salva para as próximas importações.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
          ),
        ],
        if (p.invest.isNotEmpty) ...[
          const Rotulo('Investido (não conta como gasto)'),
          CaixaLista([
            for (final x in p.invest)
              ListTile(
                leading: IconeCategoria(x.cat == 'resgate' ? catResgate : catInvestido, tam: 36),
                title: Text(x.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${dataCurta(x.t.data)} · ${x.cat == 'resgate' ? 'Resgate' : 'Aplicação'}', style: TextStyle(color: G.apagado, fontSize: 12)),
                trailing: Text('${x.cat == 'resgate' ? '←' : '→'} ${brl(x.valor)}', style: TextStyle(fontWeight: FontWeight.w700, color: G.lavanda)),
              ),
          ]),
        ],
        if (p.ignorados.isNotEmpty) ...[
          const Rotulo('Ficaram de fora'),
          CaixaLista([
            for (final e in p.ignorados.entries)
              ListTile(dense: true, title: Text(e.key), trailing: Text('${e.value.n} · ${brl(e.value.v)}', style: TextStyle(color: G.apagado))),
          ]),
        ],
      ]),
      Positioned(
        left: 14,
        right: 14,
        bottom: 16,
        child: SafeArea(
          child: Row(children: [
            OutlinedButton(onPressed: ocupado ? null : () => setState(() => ofx = null), child: const Text('Cancelar')),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: ocupado || (entram.isEmpty && ents.isEmpty && p.invest.isEmpty && p.pagFatura.isEmpty) ? null : () => _importar(p),
                child: Text(ocupado ? 'Importando…' : 'Importar ${entram.length + ents.length + p.invest.length} lançamento(s)'),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _Num extends StatelessWidget {
  final String n, t;
  const _Num(this.n, this.t);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(n, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(t, style: TextStyle(color: G.texto2, fontSize: 12)),
      ]);
}

// =====================================================================
// Investimentos do Inter (PDF)
// =====================================================================

class TelaImportarInter extends StatefulWidget {
  const TelaImportarInter({super.key});
  @override
  State<TelaImportarInter> createState() => _TelaImportarInterState();
}

class _TelaImportarInterState extends State<TelaImportarInter> {
  Uint8List? pdf;
  ExtratoInter? ex;
  List<GrupoInter> grupos = [];
  String modo = 'separado';
  String? alvo; // null = criar "Inter"
  String? erro;
  bool ocupado = false;
  final saldoC = TextEditingController();

  @override
  void dispose() {
    saldoC.dispose();
    super.dispose();
  }

  Future<void> _abrir({String? senha}) async {
    final b = senha == null ? await _escolherArquivo() : pdf;
    if (b == null) return;
    setState(() {
      ocupado = true;
      erro = null;
      pdf = b;
    });
    try {
      final pgs = textoDoPdf(b, senha: senha);
      final e = lerExtratoInter(pgs);
      if (e.rows.isEmpty) {
        setState(() {
          ocupado = false;
          erro = 'Não encontrei movimentações nesse PDF. Confira se é o "Extrato de movimentações" de investimentos do Inter.';
        });
        return;
      }
      if (!mounted) return;
      final repo = RepoScope.ler(context);
      final inter = ativoInter(repo);
      final temFilhos = inter != null && repo.doTipo('ativo').any((a) => a['pai'] == inter.id && a['oculto'] != true);
      final temLanc = inter != null && repo.doTipo('lanc').any((l) => l['ativo'] == inter.id);
      setState(() {
        ex = e;
        grupos = interPorTipo(e.rows);
        alvo = inter?.id;
        modo = temLanc && !temFilhos ? 'junto' : 'separado';
        ocupado = false;
        pdf = null;
      });
    } on SenhaPdf catch (s) {
      setState(() => ocupado = false);
      if (!mounted) return;
      final c = TextEditingController();
      final v = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(s.errada ? 'Senha incorreta' : 'PDF com senha'),
          content: TextField(controller: c, autofocus: true, obscureText: true, decoration: const InputDecoration(labelText: 'Senha do arquivo', helperText: 'No Inter, costuma ser parte do seu CPF.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Abrir')),
          ],
        ),
      );
      if (v != null && v.isNotEmpty) await _abrir(senha: v);
    } catch (_) {
      setState(() {
        ocupado = false;
        erro = 'Não foi possível ler o PDF. Verifique se o arquivo abre normalmente.';
      });
    }
  }

  Future<void> _importar() async {
    final repo = RepoScope.ler(context);
    setState(() => ocupado = true);
    final docs = docsImportInter(repo, ex!, grupos, modo: modo, alvo: alvo, saldoFinal: lerValor(saldoC.text));
    await repo.salvarVarios(docs);
    if (!mounted) return;
    setState(() {
      ocupado = false;
      ex = null;
    });
    avisar(context, 'Importação concluída: ${docs.where((d) => d['kind'] == 'lanc').length} lançamento(s).');
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final e = ex;
    final feitas = importacoesInter(repo);
    final topos = repo.doTipo('ativo').where((a) => a['oculto'] != true && a['pai'] == null).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Investimentos do Inter', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 40), children: [
        if (e == null) ...[
          Cartao(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Importe o extrato de movimentações', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('No app do Inter: Investimentos → Extrato de movimentações → escolha o período → exportar PDF. O app lê as aplicações e os resgates e monta o histórico de cada tipo (CDB, LCI/LCA, Tesouro…).',
                  style: TextStyle(color: G.texto2, height: 1.4)),
              const SizedBox(height: 14),
              FilledButton.icon(onPressed: ocupado ? null : _abrir, icon: const Icon(Icons.picture_as_pdf_outlined), label: Text(ocupado ? 'Lendo o PDF…' : 'Escolher PDF')),
              if (erro != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(erro!, style: TextStyle(color: G.neg))),
            ]),
          ),
          if (feitas.isNotEmpty) ...[
            const Rotulo('Importações feitas'),
            CaixaLista([
              for (final f in feitas)
                ListTile(
                  title: Text('${f.lanc} lançamento(s)', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(f.quando > 0 ? 'em ${dataBr(isoDe(DateTime.fromMillisecondsSinceEpoch(f.quando)))}' : '', style: TextStyle(color: G.apagado)),
                  trailing: TextButton(
                    onPressed: () async {
                      if (!await confirmar(context, 'Desfazer esta importação?', 'Apaga os ativos e lançamentos que vieram desse PDF.', sim: 'Desfazer')) return;
                      await repo.apagarVarios(idsDaImportacaoInter(repo, f.id));
                    },
                    child: Text('Desfazer', style: TextStyle(color: G.neg)),
                  ),
                ),
            ]),
          ],
        ] else ...[
          Cartao(
            gradiente: G.gradHero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e.rows.length} movimentações', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text('${e.inicio != null ? dataBr(e.inicio!) : '?'} a ${e.fim != null ? dataBr(e.fim!) : '?'}${e.posicaoTotal != null && e.posicaoTotal!.isFinite ? ' · posição total ${brl(e.posicaoTotal!)}' : ''}',
                  style: TextStyle(color: G.texto2)),
            ]),
          ),
          const Rotulo('O que encontrei'),
          CaixaLista([
            for (final g in grupos)
              ListTile(
                title: Text(g.tipo.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Aplicado ${brl(g.aplicado)} · resgatado ${brl(g.resgatado)}${g.ganho != 0 ? ' · rendeu ${brl(g.ganho, sinal: true)}' : ''}', style: TextStyle(color: G.apagado, fontSize: 12.5)),
                trailing: Text(brl(g.saldoFinal), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ]),
          const Rotulo('Onde guardar'),
          Opcoes<String>(itens: const [('separado', 'Um ativo por tipo'), ('junto', 'Tudo num ativo só')], valor: modo, onMudar: (v) => setState(() => modo = v)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: alvo,
            isExpanded: true,
            dropdownColor: G.fundo2,
            decoration: InputDecoration(labelText: modo == 'junto' ? 'Ativo' : 'Dentro do ativo'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Criar novo "Inter"')),
              for (final a in topos) DropdownMenuItem<String?>(value: str(a['id']), child: Text(str(a['nome']))),
            ],
            onChanged: (v) => setState(() => alvo = v),
          ),
          if (modo == 'junto') ...[
            const SizedBox(height: 12),
            CampoValor(saldoC, rotulo: 'Saldo no fim do período (opcional)'),
            Text('Com o saldo atual do app do Inter, o rendimento do período fica certo.', style: TextStyle(color: G.apagado, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: ocupado ? null : _importar, child: Text(ocupado ? 'Importando…' : 'Importar')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: ocupado ? null : () => setState(() => ex = null), child: const Text('Cancelar')),
          const SizedBox(height: 8),
          Text('Dias em que você já lançou um saldo à mão não são sobrescritos.', style: TextStyle(color: G.apagado, fontSize: 12)),
        ],
      ]),
    );
  }
}
