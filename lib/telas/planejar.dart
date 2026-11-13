import 'package:flutter/material.dart';

import '../dados/categorias.dart';
import '../dados/modelos.dart';
import '../dados/planejar.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/movimento.dart';
import '../widgets/painel.dart';
import '../widgets/formulario.dart';
import 'cartoes.dart';
import 'contas.dart';
import 'emprestimos.dart';

class TelaPlanejar extends StatelessWidget {
  final VoidCallback irLimites;
  const TelaPlanejar({super.key, required this.irLimites});

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ccs = cartoes(repo);
    final emps = emprestimos(repo);
    final emAberto = emps.where((e) => !dadosEmprestimo(repo, e).quitado).toList();
    final meta = repo.metaSobra;
    final r = ResumoMes.de(repo, ymDe(hojeIso()));
    return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 120), children: emSequencia([
      const CartaoRecebimentos(),
      const SizedBox(height: 14),
      const CartaoContas(),
      const SizedBox(height: 14),
      _Link(
        icone: Icons.credit_card_rounded,
        titulo: 'Cartões de crédito',
        sub: ccs.isEmpty ? 'Cadastre seus cartões e acompanhe as faturas' : '${ccs.length} cartão(ões) · faturas e parcelas',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaCartoes())),
      ),
      const SizedBox(height: 10),
      _Link(
        icone: Icons.track_changes_rounded,
        titulo: 'Meta de sobra do mês',
        sub: meta > 0 ? 'Guardar ${brl(meta)} por mês · este mês: ${brl(r.sobra)}' : 'Defina quanto quer que sobre no mês',
        progresso: meta > 0 ? r.sobra / meta : null,
        onTap: () => _editarMeta(context, meta),
      ),
      const SizedBox(height: 10),
      _Link(
        icone: Icons.tune_rounded,
        titulo: 'Limites de gastos',
        sub: r.limiteTotal > 0 ? '${brl(r.gastoComLimite)} de ${brl(r.limiteTotal)}${r.temLimiteGeral ? ' no mês' : ' nas categorias'} · ${mesLongo(r.ym).toLowerCase()}' : 'Um teto para o mês e, se quiser, por categoria',
        onTap: irLimites,
      ),
      const SizedBox(height: 10),
      _Link(
        icone: Icons.handshake_rounded,
        titulo: 'Dinheiro emprestado',
        sub: emAberto.isEmpty
            ? (emps.isEmpty ? 'Controle o que você emprestou e as parcelas' : 'Tudo recebido')
            : '${emAberto.length} em aberto · faltam ${brl(emAberto.fold<double>(0, (a, e) => a + dadosEmprestimo(repo, e).falta))}',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaEmprestimos())),
      ),
    ]));
  }

  Future<void> _editarMeta(BuildContext context, double atual) async {
    final c = TextEditingController(text: atual > 0 ? valorCampo(atual) : '');
    final v = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Quanto você quer que sobre por mês?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Quando o que entrou menos o que saiu chegar nesse valor, o app mostra que você bateu a meta.', style: TextStyle(color: G.texto2)),
          const SizedBox(height: 12),
          CampoValor(c, autofocus: true, rotulo: 'Meta'),
        ]),
        actions: [
          if (atual > 0) TextButton(onPressed: () => Navigator.pop(d, 0.0), child: Text('Tirar meta', style: TextStyle(color: G.neg))),
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, lerValor(c.text) ?? 0), child: const Text('Salvar')),
        ],
      ),
    );
    if (v == null || !context.mounted) return;
    await RepoScope.ler(context).definirMeta(v < 0 ? 0 : (v * 100).round() / 100);
  }
}

class _Link extends StatelessWidget {
  final IconData icone;
  final String titulo, sub;
  final double? progresso;
  final VoidCallback onTap;
  const _Link({required this.icone, required this.titulo, required this.sub, required this.onTap, this.progresso});
  @override
  Widget build(BuildContext context) {
    return Cartao(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: G.lavandaFundo, borderRadius: BorderRadius.circular(14)),
          child: Icon(icone, color: G.lavandaIcone),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(color: G.apagado, fontSize: 12.5)),
            if (progresso != null) ...[
              const SizedBox(height: 8),
              Barra(progresso!, cor: progresso! >= 1 ? G.pos : G.lavanda, altura: 5),
            ],
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: G.apagado),
      ]),
    );
  }
}

/// Próximos recebimentos: linha do tempo, quanto dá por dia até o próximo e a
/// lista dos recebimentos (Salário, Vale e os que a pessoa criar).
class CartaoRecebimentos extends StatelessWidget {
  const CartaoRecebimentos({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final h = hojeIso();
    final ag = agendaRecebimentos(repo);
    final lista = [...repo.rendas.where((r) => r.valor > 0)]..sort((a, b) {
        int ordem(Renda r) => r.id == 'rd_salario' ? 0 : (r.id == 'rd_va' ? 1 : 2);
        final c = ordem(a).compareTo(ordem(b));
        return c != 0 ? c : a.nome.compareTo(b.nome);
      });
    // até o próximo dinheiro: quanto dá por dia com o que está em conta
    final prox = ag.where((x) => !x.recebido && x.renda != null && x.data.compareTo(h) >= 0).firstOrNull;
    String? ateLa;
    if (prox != null && repo.contas.isNotEmpty) {
      final dias = diasEntre(h, prox.data) - 1;
      final saldo = saldoEmConta(repo);
      if (dias >= 1) {
        final quem = '${prox.nome} (${dataCurta(prox.data)})';
        ateLa = saldo > 0
            ? '$dias dia${dias == 1 ? '' : 's'} até $quem: com o saldo em conta, dá ${brl(saldo / dias)}/dia.'
            : '$dias dia${dias == 1 ? '' : 's'} até $quem, e o saldo em conta está zerado.';
      }
    }
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CabecalhoCartao('Próximos recebimentos', acao: 'Adicionar', onAcao: () => abrirFolha(context, const FormRenda())),
        if (ag.isNotEmpty) ...[
          Row(children: [
            for (final x in ag)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: x.renda == null
                      ? null
                      : () => x.recebido ? abrirFolha(context, FormRenda(r: x.renda)) : confirmarRecebido(context, x.renda!, x.data, x.valor),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Column(children: [
                      Text(dataCurta(x.data), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(x.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: G.apagado, fontSize: 11.5)),
                      const SizedBox(height: 8),
                      Icon(x.recebido ? Icons.check_circle_rounded : (x.atrasado ? Icons.error_rounded : Icons.radio_button_unchecked_rounded),
                          color: x.recebido ? G.pos : (x.atrasado ? G.neg : G.lavanda), size: 20),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: G.v(0x14), borderRadius: BorderRadius.circular(99)),
                          child: Text(brl(x.valor), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: x.recebido ? G.pos : G.lavanda)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
          if (ateLa != null) Dica(ateLa, icone: Icons.calendar_today_rounded, cor: G.lavanda),
          const SizedBox(height: 14),
        ],
        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cadastre o que você recebe todo mês para o app avisar quando cair e marcar como recebido.', style: TextStyle(color: G.apagado, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in presetsRenda.take(3))
                  ActionChip(
                    avatar: Icon(p.icone, size: 16, color: G.lavanda),
                    label: Text(p.nome),
                    onPressed: () => abrirFolha(context, FormRenda(preset: p)),
                  ),
              ]),
            ]),
          )
        else
          CaixaLista([for (final r in lista) _LinhaRenda(r: r)]),
      ]),
    );
  }
}

/// Pergunta valor e data e lança a entrada do recebimento.
Future<void> confirmarRecebido(BuildContext context, Renda r, String data, double valor) async {
  final h = hojeIso();
  final ok = await abrirFolha<bool>(context, _FolhaReceber(r: r, data: data.compareTo(h) > 0 ? h : data, valor: valor));
  if (ok == true && context.mounted) avisar(context, '${r.nome} lançado nas entradas.');
}

class _FolhaReceber extends StatefulWidget {
  final Renda r;
  final String data;
  final double valor;
  const _FolhaReceber({required this.r, required this.data, required this.valor});
  @override
  State<_FolhaReceber> createState() => _FolhaReceberState();
}

class _FolhaReceberState extends State<_FolhaReceber> {
  late final c = TextEditingController(text: valorCampo(widget.valor));
  late String data = widget.data;
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CorpoFolha([
        TituloFolha('Recebi: ${widget.r.nome}'),
        const SizedBox(height: 4),
        Text(widget.r.variavel ? 'O valor varia: confira o que entrou de fato.' : 'Confira o valor e o dia; vira uma entrada no extrato.', style: TextStyle(color: G.apagado, fontSize: 13)),
        const SizedBox(height: 12),
        CampoValor(c, rotulo: 'Valor recebido', grande: true),
        const Rotulo('Quando entrou'),
        CampoData(data: data, onMudar: (v) => setState(() => data = v)),
        const SizedBox(height: 18),
        FilledButton.icon(
          icon: const Icon(Icons.check_rounded),
          onPressed: () async {
            final v = lerValor(c.text);
            if (v == null || v <= 0) {
              avisar(context, 'Informe o valor, como 3.500,00.');
              return;
            }
            await RepoScope.ler(context).salvar(docRecebido(widget.r, v, data));
            if (context.mounted) Navigator.pop(context, true);
          },
          label: const Text('Confirmar recebimento'),
        ),
      ]);
}

class _LinhaRenda extends StatelessWidget {
  final Renda r;
  const _LinhaRenda({required this.r});

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final h = hojeIso();
    // ocorrência deste mês (ou a próxima, para anuais e de data única)
    StatusRenda? st;
    for (var k = 0; k <= 12 && st == null; k++) {
      final s = statusRenda(repo, r, ymAdd(ymDe(h), k));
      if (s != null && (k == 0 || s.rec == null)) st = s;
      if (r.freq == 'mensal') break;
    }
    final esp = valorEsperado(repo, r);
    final quando = r.freq == 'unica'
        ? 'em ${r.dataUnica.length == 10 ? dataBr(r.dataUnica) : '?'}'
        : (r.freq == 'anual' ? 'todo ano em ${mesesLongos[r.mes - 1].toLowerCase()}' : (r.regra == 'util' ? 'último dia útil' : 'todo dia ${r.dia}'));
    String linha;
    Color cor = G.apagado;
    if (st == null) {
      linha = r.freq == 'unica' ? 'Já passou · $quando' : 'Cai $quando';
    } else if (st.rec != null) {
      linha = 'Recebido em ${dataCurta(st.rec!.data)} · $quando';
    } else if (st.dias < 0) {
      linha = 'Ainda não recebido (era ${dataCurta(st.data)})';
      cor = G.alerta;
    } else {
      linha = 'Cai em ${dataCurta(st.data)} · $quando';
    }
    final pode = st != null && st.rec == null && st.dias <= 0;
    return InkWell(
      onTap: () => abrirFolha(context, FormRenda(r: r)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Icon(iconeRenda(r), color: G.lavanda),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(linha, style: TextStyle(color: cor, fontSize: 12.5)),
              if (r.variavel) Text('Valor varia · média de ${brl(esp)}', style: TextStyle(color: G.lavanda, fontSize: 12)),
              if (r.id == 'rd_salario' && r.mesSeguinte) Text('Conta como dinheiro do mês seguinte', style: TextStyle(color: G.lavanda, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(brl(esp), style: const TextStyle(fontWeight: FontWeight.w700)),
            if (pode)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(10, 28), padding: const EdgeInsets.symmetric(horizontal: 6)),
                onPressed: () => confirmarRecebido(context, r, st!.data, esp),
                child: const Text('Marcar recebido', style: TextStyle(fontSize: 12.5)),
              ),
          ]),
        ]),
      ),
    );
  }
}

IconData iconeRenda(Renda r) => switch (r.id) {
      'rd_salario' => Icons.work_rounded,
      'rd_va' => Icons.restaurant_menu_rounded,
      _ => presetsRenda.where((p) => p.nome == r.nome).map((p) => p.icone).firstOrNull ?? catEntrada(r.cat).icone,
    };

/// Modelos prontos para criar um recebimento.
class PresetRenda {
  final String? id; // Salário e Vale usam os ids que o site conhece
  final String nome, cat, freq, regra;
  final int dia, mes;
  final bool variavel;
  final IconData icone;
  const PresetRenda(this.nome, this.cat, this.icone, {this.id, this.freq = 'mensal', this.regra = 'dia', this.dia = 5, this.mes = 12, this.variavel = false});
}

const presetsRenda = [
  PresetRenda('Salário', 'salario', Icons.work_rounded, id: 'rd_salario', regra: 'util'),
  PresetRenda('Vale alimentação', 'beneficios', Icons.restaurant_menu_rounded, id: 'rd_va', dia: 20),
  PresetRenda('Freela', 'vendas', Icons.laptop_mac_rounded, variavel: true),
  PresetRenda('Aluguel recebido', 'outros_e', Icons.home_work_rounded, dia: 10),
  PresetRenda('13º salário', 'salario', Icons.card_giftcard_rounded, freq: 'anual', dia: 20, mes: 12),
  PresetRenda('Restituição do IR', 'outros_e', Icons.account_balance_rounded, freq: 'unica'),
];

class FormRenda extends StatefulWidget {
  final Renda? r;
  final PresetRenda? preset;
  const FormRenda({super.key, this.r, this.preset});
  @override
  State<FormRenda> createState() => _FormRendaState();
}

class _FormRendaState extends State<FormRenda> {
  late final Renda? r = widget.r;
  late final valorC = TextEditingController(text: r != null && r!.valor > 0 ? valorCampo(r!.valor) : '');
  late final nomeC = TextEditingController(text: r?.nome ?? widget.preset?.nome ?? '');
  late String? idFixo = r != null && !r!.livre ? r!.id : null;
  late String regra = r?.regra ?? widget.preset?.regra ?? 'dia';
  late int dia = r?.dia ?? widget.preset?.dia ?? 5;
  late int mes = r?.mes ?? widget.preset?.mes ?? 12;
  late String freq = r?.freq ?? widget.preset?.freq ?? 'mensal';
  late String dataU = r != null && r!.dataUnica.length == 10 ? r!.dataUnica : hojeIso();
  late String cat = r?.cat ?? widget.preset?.cat ?? 'outros_e';
  late bool variavel = r?.variavel ?? widget.preset?.variavel ?? false;
  late bool mesSeg = r?.mesSeguinte ?? false;

  @override
  void initState() {
    super.initState();
    // Salário/Vale ainda não cadastrados: usam o id que o site conhece
    final p = widget.preset;
    if (r == null && p?.id != null && RepoScope.ler(context).porId(p!.id!) == null) idFixo = p.id;
  }

  @override
  void dispose() {
    valorC.dispose();
    nomeC.dispose();
    super.dispose();
  }

  void _usarPreset(PresetRenda p) {
    setState(() {
      nomeC.text = p.nome;
      cat = p.cat;
      freq = p.freq;
      regra = p.regra;
      dia = p.dia;
      mes = p.mes;
      variavel = p.variavel;
      idFixo = p.id != null && RepoScope.ler(context).porId(p.id!) == null ? p.id : null;
    });
  }

  Future<void> _salvar() async {
    final v = lerValor(valorC.text);
    final nome = nomeC.text.trim();
    if (nome.isEmpty) {
      avisar(context, 'Dê um nome, como "Freela" ou "Aluguel".');
      return;
    }
    if (v == null || v <= 0) {
      avisar(context, variavel ? 'Informe um valor de referência (pode ser a média).' : 'Informe o valor, como 3.500,00.');
      return;
    }
    final repo = RepoScope.ler(context);
    final fixo = idFixo;
    final doc = <String, dynamic>{
      ...?r?.d,
      'kind': fixo != null ? 'renda' : 'rendaapp',
      'id': fixo ?? r?.id ?? novoId('rd'),
      'nome': nome,
      'valor': (v * 100).round() / 100,
      'regra': regra,
      'dia': regra == 'util' ? null : dia,
      'freq': freq == 'mensal' ? null : freq,
      'mes': freq == 'anual' ? mes : null,
      'dataU': freq == 'unica' ? dataU : null,
      'var': variavel ? true : null,
      'cat': fixo != null ? null : cat,
      if (fixo == 'rd_salario') 'mesSeg': mesSeg,
    }..removeWhere((k, x) => x == null && k != 'dia');
    await repo.salvar(doc);
    if (!mounted) return;
    Navigator.pop(context);
    avisar(context, '$nome salvo.');
  }

  Future<void> _remover() async {
    final rr = r;
    if (rr == null) return;
    if (!await confirmar(context, 'Remover ${rr.nome}?', 'Os lançamentos que já entraram continuam no extrato.', sim: 'Remover')) return;
    if (!mounted) return;
    await RepoScope.ler(context).apagar(rr.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final sal = idFixo == 'rd_salario';
    final hist = r == null ? const <MesRenda>[] : historicoRenda(repo, r!);
    return CorpoFolha([
      TituloFolha(r == null ? 'Novo recebimento' : r!.nome, onExcluir: r == null ? null : _remover),
      if (r == null) ...[
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in presetsRenda)
            ChoiceChip(
              selected: nomeC.text == p.nome,
              avatar: Icon(p.icone, size: 16, color: nomeC.text == p.nome ? G.tinta : G.lavanda),
              label: Text(p.nome),
              labelStyle: TextStyle(fontWeight: FontWeight.w600, color: nomeC.text == p.nome ? G.tinta : G.texto2),
              onSelected: (_) => _usarPreset(p),
            ),
        ]),
      ],
      const SizedBox(height: 12),
      if (idFixo == null)
        TextField(controller: nomeC, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nome'), onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      CampoValor(valorC, rotulo: variavel ? 'Valor de referência' : 'Valor que você recebe', grande: true),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: variavel,
        onChanged: (v) => setState(() => variavel = v),
        title: const Text('O valor muda de um mês para outro', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('O app passa a esperar a média das últimas 3 vezes que entrou.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
      ),
      const Rotulo('Com que frequência'),
      Opcoes<String>(itens: const [('mensal', 'Todo mês'), ('anual', 'Uma vez por ano'), ('unica', 'Só uma vez')], valor: freq, onMudar: (v) => setState(() => freq = v)),
      if (freq == 'unica') ...[
        const Rotulo('Quando vai cair'),
        _Data(data: dataU, onMudar: (v) => setState(() => dataU = v)),
      ] else ...[
        if (freq == 'anual') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: mes,
            isExpanded: true,
            dropdownColor: G.fundo2,
            decoration: const InputDecoration(labelText: 'Mês'),
            items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(mesesLongos[m - 1]))],
            onChanged: (v) => setState(() => mes = v ?? mes),
          ),
        ],
        const Rotulo('Em que dia'),
        Opcoes<String>(itens: const [('util', 'Último dia útil'), ('dia', 'Num dia fixo')], valor: regra, onMudar: (v) => setState(() => regra = v)),
        if (regra == 'dia') ...[const SizedBox(height: 12), CampoDia(dia: dia, rotulo: 'Dia do mês', onMudar: (v) => setState(() => dia = v))],
      ],
      if (idFixo == null) ...[
        const Rotulo('Entra no extrato como'),
        DropdownButtonFormField<String>(
          initialValue: categoriasEntrada.any((c) => c.id == cat) ? cat : 'outros_e',
          isExpanded: true,
          dropdownColor: G.fundo2,
          decoration: const InputDecoration(),
          items: [
            for (final c in categoriasEntrada.where((c) => c.id != 'proprias'))
              DropdownMenuItem(value: c.id, child: Row(children: [Icon(c.icone, size: 18, color: c.cor), const SizedBox(width: 10), Flexible(child: Text(c.nome, overflow: TextOverflow.ellipsis))])),
          ],
          onChanged: (v) => setState(() => cat = v ?? cat),
        ),
      ],
      if (sal)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: mesSeg,
          onChanged: (v) => setState(() => mesSeg = v),
          title: const Text('Salário conta no mês seguinte', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('O salário que cai no fim do mês vira dinheiro do mês seguinte no resumo.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
        ),
      const SizedBox(height: 16),
      FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      if (hist.isNotEmpty) ...[
        const Rotulo('Últimas vezes'),
        CaixaLista([
          for (final m in hist)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Icon(m.rec != null ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 18, color: m.rec != null ? G.pos : G.alerta),
                const SizedBox(width: 10),
                Expanded(child: Text(mesLongo(m.ym), style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(m.rec != null ? '${brl(m.rec!.valor)} · ${dataCurta(m.rec!.data)}' : 'não encontrado',
                    style: TextStyle(color: m.rec != null ? G.texto2 : G.apagado, fontSize: 13)),
              ]),
            ),
        ]),
        Rodape('Procura uma entrada até 10 dias antes ou depois da data${hist.any((m) => m.rec == null) ? '. Se entrou e não aparece, lance a entrada com este nome' : ''}.'),
      ],
    ]);
  }
}

/// Data livre (sem os atalhos "Hoje/Ontem", que não fazem sentido para algo futuro).
class _Data extends StatelessWidget {
  final String data;
  final ValueChanged<String> onMudar;
  const _Data({required this.data, required this.onMudar});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        icon: const Icon(Icons.calendar_month_rounded, size: 18),
        label: Text(dataBr(data)),
        onPressed: () async {
          final d = await showDatePicker(context: context, initialDate: dataDe(data), firstDate: DateTime(2015), lastDate: DateTime(2036));
          if (d != null) onMudar(isoDe(d));
        },
      );
}
