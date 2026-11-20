import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/invest_pat.dart';
import '../dados/modelos.dart';
import '../dados/patrimonio.dart';
import '../dados/repo.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/formulario.dart';
import '../widgets/largo.dart';
import '../widgets/site.dart';
import 'patrimonio.dart' show FormAtivo;

/// Abre a tela de lançar os valores dos investimentos.
Future<void> abrirLancarValores(BuildContext context, {String? data}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaLancarValores(dataInicial: data)));

/// Lançar o saldo de cada investimento num dia. A data fica fixa no topo e o
/// botão Salvar fixo embaixo (com o resultado), para nunca precisar rolar
/// a tela para achar um ou outro.
class TelaLancarValores extends StatefulWidget {
  final String? dataInicial;
  const TelaLancarValores({super.key, this.dataInicial});
  @override
  State<TelaLancarValores> createState() => _TelaLancarValoresState();
}

class _TelaLancarValoresState extends State<TelaLancarValores> {
  late String data = widget.dataInicial ?? hojeIso();
  late Carteira c;
  final saldoC = <String, TextEditingController>{};
  final aporteC = <String, TextEditingController>{}; // sempre positivo
  final tirou = <String, bool>{}; // true = resgate (tirou dinheiro)
  final aporteAberto = <String>{};
  final foco = <String, FocusNode>{};
  // Saldo digitado à mão? Enquanto não, o saldo acompanha o aporte (saldo sem o
  // aporte do dia + aporte), para o aporte não virar "perda".
  final saldoMexido = <String, bool>{};
  final saldoBase = <String, double?>{};
  final saldoOrig = <String, String>{};
  /// Ativos que você já mexeu: trocar a data não apaga o que foi digitado.
  final tocado = <String>{};
  int periodo = 0; // 0 = desde o último lançamento, 1 = semana, 2 = mês
  // investidos do Extrato que vão virar aporte neste lançamento (id do investido → ativo)
  final usarInvest = <String, String>{};
  final rolagem = ScrollController();
  bool ajuda = false;

  @override
  void initState() {
    super.initState();
    c = calcularCarteira(RepoScope.ler(context));
    _preencher(todos: true);
  }

  @override
  void dispose() {
    for (final x in [...saldoC.values, ...aporteC.values]) {
      x.dispose();
    }
    for (final f in foco.values) {
      f.dispose();
    }
    rolagem.dispose();
    super.dispose();
  }

  TextEditingController _sc(String id) => saldoC.putIfAbsent(id, () => TextEditingController());
  TextEditingController _ac(String id) => aporteC.putIfAbsent(id, () => TextEditingController());
  FocusNode _fo(String id) => foco.putIfAbsent(id, () => FocusNode());

  /// Aporte com sinal: positivo colocou, negativo tirou.
  double _ap(String id) => (lerValor(_ac(id).text) ?? 0) * (tirou[id] == true ? -1 : 1);

  void _setAp(String id, double v) {
    tirou[id] = v < 0;
    _ac(id).text = v.abs() < .005 ? '' : valorCampo(v.abs());
    if (v.abs() >= .005) aporteAberto.add(id);
  }

  /// Preenche com o que já foi lançado na data (ou vazio). Com [todos] falso,
  /// mantém o que você já digitou.
  void _preencher({bool todos = false}) {
    final repo = RepoScope.ler(context);
    for (final p in c.posicoes) {
      final id = p.a.id;
      String s = '';
      double ap = 0;
      double? base;
      if (c.pais.contains(id)) {
        final g = estadoGrupo(repo, c, id, data);
        if (g.totalDoDia != null) {
          s = valorCampo(g.totalDoDia!);
          ap = g.aporteDoDia ?? 0;
          base = g.totalDoDia! - ap;
        }
      } else {
        final ex = repo.porId('l_${id}_$data');
        if (ex != null) {
          s = valorCampo(numD(ex['saldo']));
          ap = numD(ex['aporte']);
          base = numD(ex['saldo']) - ap;
        }
      }
      saldoBase[id] = base ?? _anterior(repo, p);
      if (!todos && tocado.contains(id)) continue;
      _sc(id).text = s;
      aporteAberto.remove(id);
      _setAp(id, ap);
      saldoMexido[id] = false;
      saldoOrig[id] = s;
    }
  }

  void _mudarData(String v) {
    if (v == data) return;
    final repo = RepoScope.ler(context);
    setState(() {
      data = v;
      // aplicações do Extrato depois da nova data não cabem mais neste lançamento
      for (final e in [...usarInvest.entries]) {
        final inv = repo.porId(e.key);
        if (inv != null && Investido(inv).data.compareTo(data) > 0) _usarInvestido(Investido(inv), e.value);
      }
      _preencher();
    });
    HapticFeedback.selectionClick();
  }

  /// Aporte mudou: se o saldo não foi digitado à mão, ele passa a incluir o aporte.
  void _aporteMudou(String id) {
    tocado.add(id);
    if (saldoMexido[id] == true) return;
    final b = saldoBase[id];
    final ap = _ap(id);
    if (b == null) return;
    if (ap == 0) {
      _sc(id).text = saldoOrig[id] ?? '';
    } else {
      final v = b + ap;
      _sc(id).text = v < 0 ? '0,00' : valorCampo(v);
    }
  }

  double? _anterior(Repo repo, PosAtivo p) {
    if (c.pais.contains(p.a.id)) {
      final g = estadoGrupo(repo, c, p.a.id, data);
      return g.dataAnterior == null ? null : g.totalAnterior;
    }
    return anteriorDe(c, p.a.id, data)?.saldo;
  }

  String? _dataAnterior(Repo repo, PosAtivo p) {
    if (c.pais.contains(p.a.id)) return estadoGrupo(repo, c, p.a.id, data).dataAnterior;
    return anteriorDe(c, p.a.id, data)?.data;
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    final repo = RepoScope.ler(context);
    final ops = <Doc>[];
    final apagar = <String>[];
    final erros = <String>[];
    for (final p in c.posicoes) {
      final id = p.a.id;
      final ts = _sc(id).text.trim();
      final s = lerValor(ts);
      final ap = _ap(id);
      if (c.pais.contains(id)) {
        if (ts.isEmpty) continue;
        if (s == null || s < 0) {
          erros.add(p.a.nome);
          continue;
        }
        ops.addAll(docsGrupo(estadoGrupo(repo, c, id, data), data, s, ap));
      } else {
        final ex = repo.porId('l_${id}_$data');
        if (ts.isEmpty) {
          if (ex != null) apagar.add(ex['id'] as String);
          continue;
        }
        if (s == null || s < 0) {
          erros.add(p.a.nome);
          continue;
        }
        ops.add(docLanc(id, data, s, ap));
      }
    }
    if (erros.isNotEmpty) return avisar(context, 'Confira o saldo de ${erros.join(', ')}: use números como 1.234,56.');
    if (ops.isEmpty && apagar.isEmpty) return avisar(context, 'Preencha o saldo de pelo menos um investimento.');
    if (apagar.isNotEmpty) await repo.apagarVarios(apagar);
    if (ops.isNotEmpty) await repo.salvarVarios(ops);
    if (usarInvest.isNotEmpty) {
      final ligar = <Doc>[];
      usarInvest.forEach((invId, ativoId) {
        final inv = repo.porId(invId);
        if (inv == null) return;
        final filhos = [for (final a in c.ativos) if (a.pai == ativoId) a.id];
        final alvo = filhos.isEmpty ? ativoId : filhos.first;
        ligar.add({...inv, 'ativo': alvo, 'pat': 'l_${alvo}_$data', 'patV': 0, 'patNovo': false});
      });
      await repo.salvarVarios(ligar);
    }
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    avisar(context, 'Valores de ${dataBr(data)} salvos.');
    Navigator.of(context).maybePop();
  }

  /// Início do período escolhido (segunda-feira da semana ou dia 1 do mês).
  String _inicioPeriodo() {
    final d = DateTime.parse(data);
    if (periodo == 1) return isoDe(d.subtract(Duration(days: d.weekday - 1)));
    return '${data.substring(0, 8)}01';
  }

  /// Base de comparação do resultado: saldo de partida, a data dele e os aportes
  /// já lançados no período (o aporte digitado agora é somado à parte).
  ({double base, String dBase, double apAntes, double apPeso})? _base(Repo repo, PosAtivo p) {
    if (periodo == 0) {
      final ant = _anterior(repo, p);
      return ant == null ? null : (base: ant, dBase: _dataAnterior(repo, p)!, apAntes: 0, apPeso: 0);
    }
    final ini = _inicioPeriodo();
    final ids = c.pais.contains(p.a.id) ? [for (final a in c.ativos) if (a.pai == p.a.id) a.id] : [p.a.id];
    var base = 0.0, ap = 0.0;
    String? dBase;
    var achou = false;
    final movs = <Lancamento>[];
    for (final id in ids) {
      final ls = (c.porAtivo[id] ?? const <Lancamento>[]).where((l) => l.data.compareTo(data) < 0).toList();
      if (ls.isEmpty) continue;
      final antes = ls.where((l) => l.data.compareTo(ini) < 0).toList();
      final dentro = ls.where((l) => l.data.compareTo(ini) >= 0).toList();
      Lancamento partida;
      if (antes.isNotEmpty) {
        partida = antes.last;
        movs.addAll(dentro);
      } else {
        // o ativo começou dentro do período: parte do primeiro lançamento dele
        partida = dentro.first;
        movs.addAll(dentro.skip(1));
      }
      ap += movs.where((l) => l.ativo == id).fold<double>(0, (t, l) => t + l.aporte);
      achou = true;
      base += partida.saldo;
      if (dBase == null || partida.data.compareTo(dBase) < 0) dBase = partida.data;
    }
    if (!achou) return null;
    // % pelo método de Dietz: cada aporte pesa pelo tempo que ficou aplicado no período
    final fim = DateTime.parse(data);
    final total = fim.difference(DateTime.parse(dBase!)).inDays;
    var peso = 0.0;
    if (total > 0) {
      for (final l in movs) {
        peso += l.aporte * fim.difference(DateTime.parse(l.data)).inDays / total;
      }
    }
    return (base: base, dBase: dBase, apAntes: ap, apPeso: peso);
  }

  /// Rendimentos de lançamentos já salvos que fogem do normal (provável aporte não informado).
  List<({Lancamento l, Ativo a, double rend, double pc})> _suspeitos() {
    final out = <({Lancamento l, Ativo a, double rend, double pc})>[];
    for (final a in c.ativos) {
      final ls = c.porAtivo[a.id] ?? const <Lancamento>[];
      for (var i = 1; i < ls.length; i++) {
        final prev = ls[i - 1], l = ls[i];
        if (prev.saldo <= 0 || l.d['okRend'] == true) continue;
        final rend = l.saldo - prev.saldo - l.aporte;
        final pc = rend / prev.saldo;
        if (pc.abs() > .02 && rend.abs() >= 20) out.add((l: l, a: a, rend: rend, pc: pc));
      }
    }
    out.sort((x, y) => y.l.data.compareTo(x.l.data));
    return out;
  }

  /// Ativos (do topo) em que o investido ainda cabe como aporte: depois do último lançamento deles.
  List<PosAtivo> _alvosDe(Repo repo, Investido i) => [
        for (final p in c.posicoes)
          if ((_dataAnterior(repo, p) ?? '0000').compareTo(i.data) < 0) p,
      ];

  void _usarInvestido(Investido i, String ativoId) {
    final ant = usarInvest[i.id];
    if (ant != null) _somarAporte(ant, -i.liquido);
    if (ant == ativoId) {
      usarInvest.remove(i.id);
    } else {
      usarInvest[i.id] = ativoId;
      _somarAporte(ativoId, i.liquido);
    }
  }

  void _somarAporte(String id, double v) {
    _setAp(id, _ap(id) + v);
    _aporteMudou(id);
  }

  /// Resultado de um ativo (null sem base ou sem saldo digitado).
  ({double rend, double? pc, double ant, String dAnt, double aporte, double saldo})? _resultado(Repo repo, PosAtivo p) {
    final b = _base(repo, p);
    final s = lerValor(_sc(p.a.id).text);
    if (b == null || s == null) return null;
    final aporte = _ap(p.a.id) + b.apAntes;
    final rend = s - b.base - aporte;
    final capital = b.base + b.apPeso;
    return (rend: rend, pc: capital > 0 ? rend / capital : null, ant: b.base, dAnt: b.dBase, aporte: aporte, saldo: s);
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ps = c.posicoes;
    final largo = telaLarga(context);
    if (ps.isEmpty) {
      return Scaffold(
        backgroundColor: S.bg,
        appBar: AppBar(title: const Text('Lançar valores')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Cadastre um investimento para lançar o saldo dele.', textAlign: TextAlign.center, style: TextStyle(color: S.ink2)),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: () => abrirFolha(context, const FormAtivo()), icon: const Icon(Icons.add_rounded), label: const Text('Novo investimento')),
            ]),
          ),
        ),
      );
    }
    final soltos = investidosSemAtivo(repo).where((i) => i.data.compareTo(data) <= 0).where((i) => _alvosDe(repo, i).isNotEmpty).take(6).toList();
    final suspeitos = _suspeitos();
    final preenchidos = ps.where((p) => _sc(p.a.id).text.trim().isNotEmpty).length;

    // total do resultado (para a barra de baixo e o resumo)
    var rendeu = 0.0, aportes = 0.0, antes = 0.0, depois = 0.0, peso = 0.0;
    var n = 0;
    for (final p in ps) {
      final b = _base(repo, p);
      final sv = lerValor(_sc(p.a.id).text);
      if (b == null || sv == null) continue;
      final ap = _ap(p.a.id) + b.apAntes;
      rendeu += sv - b.base - ap;
      aportes += ap;
      peso += b.apPeso;
      antes += b.base;
      depois += sv;
      n++;
    }

    final lista = ListView(
      controller: rolagem,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        _ComoPreencher(aberto: ajuda, aoTocar: () => setState(() => ajuda = !ajuda)),
        const SizedBox(height: 10),
        if (soltos.isNotEmpty) ...[
          _InvestSoltos(
            itens: soltos,
            alvos: (i) => _alvosDe(repo, i),
            escolhido: usarInvest,
            aoEscolher: (i, p) => setState(() => _usarInvestido(i, p.a.id)),
          ),
          const SizedBox(height: 10),
        ],
        for (var k = 0; k < ps.length; k++) ...[
          _cartaoAtivo(repo, ps[k], proximo: k + 1 < ps.length ? ps[k + 1].a.id : null),
          const SizedBox(height: 10),
        ],
        if (n > 0) ...[
          const SizedBox(height: 6),
          _SeletorPeriodo(valor: periodo, aoMudar: (v) => setState(() => periodo = v)),
          const SizedBox(height: 10),
          _ResumoLanc(n: n, rendeu: rendeu, aportes: aportes, antes: antes, depois: depois, peso: peso, periodo: periodo, data: data),
        ],
        if (suspeitos.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Suspeitos(
            itens: suspeitos,
            corrigir: (l) {
              setState(() {
                periodo = 0;
                data = l.data;
                tocado.clear();
                _preencher(todos: true);
              });
              rolagem.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
            },
            estaCerto: (l) => repo.salvar({...l.d, 'okRend': true}),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: S.bg,
      appBar: AppBar(
        backgroundColor: S.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Lançar valores'),
      ),
      body: Column(children: [
        // data sempre à vista
        _BarraData(data: data, preenchidos: preenchidos, total: ps.length, aoMudar: _mudarData),
        Expanded(child: largo ? Centralizar(max: 760, child: lista) : lista),
        // salvar sempre à vista (sobe junto com o teclado)
        _BarraSalvar(n: n, rendeu: rendeu, pc: antes + peso > 0 ? rendeu / (antes + peso) : null, periodo: periodo, data: data, preenchidos: preenchidos, aoSalvar: _salvar),
      ]),
    );
  }

  Widget _cartaoAtivo(Repo repo, PosAtivo p, {String? proximo}) {
    final id = p.a.id;
    final ant = _anterior(repo, p);
    final dAnt = _dataAnterior(repo, p);
    final s = lerValor(_sc(id).text);
    final ap = _ap(id);
    final rend = (s != null && ant != null) ? s - ant - ap : null;
    final res = _resultado(repo, p);
    final abertoAp = aporteAberto.contains(id);
    final cheio = _sc(id).text.trim().isNotEmpty;

    Widget? aviso;
    // 1) o saldo parece não incluir o aporte/resgate (o "rendimento" fica perto de −aporte)
    if (rend != null && s != null && ap != 0 && (rend + ap).abs() < ap.abs() * .5) {
      aviso = _Aviso(
        texto: ap > 0
            ? 'O saldo parece não incluir o dinheiro que você colocou. Digite o total do banco já com ele.'
            : 'O saldo parece ainda incluir o dinheiro que você tirou. Digite o total do banco depois de tirar.',
        botao: ap > 0 ? 'Somar ${brl(ap)} ao saldo' : 'Descontar ${brl(-ap)} do saldo',
        aoTocar: () => setState(() {
          final v = s + ap;
          _sc(id).text = valorCampo(v < 0 ? 0 : v);
          saldoMexido[id] = true;
          tocado.add(id);
        }),
      );
    }
    // 2) rendeu (ou caiu) demais: provável aporte/resgate não informado
    else if (rend != null && s != null && ant! > 0 && (rend / ant).abs() > .02 && rend.abs() >= 20) {
      aviso = _Aviso(
        texto: rend > 0
            ? 'Subiu ${pct(rend / ant)} desde ${dataCurta(dAnt!)}, muito acima do normal. Você colocou dinheiro nesse período?'
            : 'Caiu ${pct(-rend / ant)} desde ${dataCurta(dAnt!)}, muito acima do normal. Você tirou dinheiro nesse período?',
        botao: ap == 0 ? (rend > 0 ? 'Sim, coloquei ${brl(rend)}' : 'Sim, tirei ${brl(-rend)}') : (rend > 0 ? 'Somar ${brl(rend)} ao que coloquei' : 'Somar ${brl(-rend)} ao que tirei'),
        aoTocar: () => setState(() {
          saldoMexido[id] = true;
          tocado.add(id);
          _setAp(id, ap + rend);
          aporteAberto.add(id);
        }),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: S.c('card'),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cheio ? p.cor.withValues(alpha: .55) : S.bordaCartao, width: cheio ? 1.4 : 1),
        boxShadow: S.escuro ? null : S.sombraCartao,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: p.cor, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.a.nome, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: S.ink, height: 1.3)),
              Text(
                ant == null ? 'Primeiro lançamento: o saldo vira o valor aplicado' : 'Último: ${brl(ant)} em ${dataCurta(dAnt!)}${p.filhos != null ? ' · ${p.filhos!.length} itens' : ''}',
                style: TextStyle(fontSize: 12.5, color: S.muted, height: 1.4),
              ),
            ]),
          ),
          if (cheio) Icon(Icons.check_circle_rounded, size: 20, color: p.cor),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _sc(id),
          focusNode: _fo(id),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: proximo != null ? TextInputAction.next : TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          scrollPadding: const EdgeInsets.only(bottom: 160),
          style: TextStyle(fontFamily: S.fonteNum, fontSize: 22, fontWeight: FontWeight.w700, color: S.ink),
          decoration: InputDecoration(
            labelText: 'Saldo no banco agora',
            prefixText: 'R\$ ',
            hintText: ant == null ? '0,00' : valorCampo(ant),
            hintStyle: TextStyle(color: S.muted.withValues(alpha: .6)),
          ),
          onChanged: (_) => setState(() {
            saldoMexido[id] = true;
            tocado.add(id);
          }),
          onSubmitted: (_) {
            if (proximo != null) {
              _fo(proximo).requestFocus();
            } else {
              FocusScope.of(context).unfocus();
            }
          },
        ),
        const SizedBox(height: 8),
        if (!abertoAp)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: S.accent, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), visualDensity: VisualDensity.compact),
              onPressed: () => setState(() => aporteAberto.add(id)),
              icon: const Icon(Icons.swap_vert_rounded, size: 18),
              label: Text(ant == null ? 'Coloquei ou tirei dinheiro hoje' : 'Coloquei ou tirei dinheiro desde ${dataCurta(dAnt!)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          )
        else
          _CampoAporte(
            c: _ac(id),
            tirou: tirou[id] == true,
            desde: dAnt,
            aoMudarTipo: (t) => setState(() {
              tirou[id] = t;
              _aporteMudou(id);
            }),
            aoMudar: () => setState(() => _aporteMudou(id)),
            aoFechar: () => setState(() {
              _setAp(id, 0);
              aporteAberto.remove(id);
              _aporteMudou(id);
            }),
          ),
        if (res != null) _LinhaRend(rend: res.rend, pc: res.pc, ant: res.ant, dAnt: res.dAnt, aporte: res.aporte, saldo: res.saldo, data: data, periodo: periodo),
        if (aviso != null) aviso,
      ]),
    );
  }
}

/// Data do lançamento, sempre à vista no topo, com Hoje/Ontem a um toque.
class _BarraData extends StatelessWidget {
  final String data;
  final int preenchidos, total;
  final ValueChanged<String> aoMudar;
  const _BarraData({required this.data, required this.preenchidos, required this.total, required this.aoMudar});

  static const _dias = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];

  @override
  Widget build(BuildContext context) {
    final h = hojeIso(), o = addDias(h, -1);
    final semana = _dias[DateTime.parse(data).weekday - 1];
    final rotulo = data == h ? 'Hoje' : (data == o ? 'Ontem' : '${semana[0].toUpperCase()}${semana.substring(1)}');
    Future<void> escolher() async {
      final d = await showDatePicker(
        context: context,
        initialDate: dataDe(data),
        firstDate: DateTime(2015),
        lastDate: dataDe(h),
        helpText: 'Dia dos valores',
        cancelText: 'Cancelar',
        confirmText: 'Escolher',
      );
      if (d != null) aoMudar(isoDe(d));
    }

    Widget rapido(String t, String v) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Material(
            color: data == v ? S.ink : S.surface,
            shape: StadiumBorder(side: BorderSide(color: data == v ? S.ink : S.line)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => aoMudar(v),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: data == v ? S.bg : S.ink2)),
              ),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(color: S.bg, border: Border(bottom: BorderSide(color: S.line))),
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Material(
              color: S.c('card'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: S.line)),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: escolher,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Icon(Icons.calendar_month_rounded, size: 22, color: S.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Valores do dia', style: TextStyle(fontSize: 11.5, color: S.muted, fontWeight: FontWeight.w600)),
                        Text('$rotulo, ${dataBr(data)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: S.ink)),
                      ]),
                    ),
                    Icon(Icons.expand_more_rounded, color: S.muted),
                  ]),
                ),
              ),
            ),
          ),
          rapido('Hoje', h),
          rapido('Ontem', o),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : preenchidos / total,
                minHeight: 5,
                backgroundColor: S.line,
                valueColor: AlwaysStoppedAnimation(S.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$preenchidos de $total preenchidos', style: TextStyle(fontSize: 12, color: S.muted, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

/// Barra de baixo: resultado do que já foi digitado e o botão Salvar.
class _BarraSalvar extends StatelessWidget {
  final int n, periodo, preenchidos;
  final double rendeu;
  final double? pc;
  final String data;
  final VoidCallback aoSalvar;
  const _BarraSalvar({required this.n, required this.rendeu, required this.pc, required this.periodo, required this.data, required this.preenchidos, required this.aoSalvar});
  @override
  Widget build(BuildContext context) {
    final cor = rendeu.abs() < .005 ? S.ink2 : (rendeu > 0 ? S.pos : S.neg);
    return Container(
      decoration: BoxDecoration(
        color: S.c('card'),
        border: Border(top: BorderSide(color: S.line)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(children: [
            Expanded(
              child: n == 0
                  ? Text(preenchidos == 0 ? 'Digite o saldo de cada investimento' : 'Pronto para salvar', style: TextStyle(fontSize: 13, color: S.muted, height: 1.35))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(periodo == 0 ? 'Desde o último lançamento' : 'Resultado${_noPeriodo(periodo, data)}', style: TextStyle(fontSize: 11.5, color: S.muted, fontWeight: FontWeight.w600)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${rendeu.abs() < .005 ? 'Não rendeu' : (rendeu > 0 ? 'Rendeu' : 'Perdeu')} ${brl(rendeu, sinal: true)}${pc != null ? '  ${pct(pc!, sinal: true)}' : ''}',
                          style: TextStyle(fontFamily: S.fonteNum, fontSize: 17, fontWeight: FontWeight.w800, color: cor),
                        ),
                      ),
                    ]),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
              onPressed: aoSalvar,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "Como preencher?": ajuda curta, fechada por padrão.
class _ComoPreencher extends StatelessWidget {
  final bool aberto;
  final VoidCallback aoTocar;
  const _ComoPreencher({required this.aberto, required this.aoTocar});
  @override
  Widget build(BuildContext context) {
    Widget linha(String r, String t) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '$r ', style: TextStyle(fontWeight: FontWeight.w700, color: S.ink)),
              TextSpan(text: t),
            ]),
            style: TextStyle(color: S.ink2, fontSize: 13, height: 1.4),
          ),
        );
    return Material(
      color: S.surface2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.help_outline_rounded, size: 18, color: S.accent),
              const SizedBox(width: 8),
              Expanded(child: Text('Como preencher', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: S.ink))),
              AnimatedRotation(turns: aberto ? .5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.expand_more_rounded, color: S.muted)),
            ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: !aberto
                  ? const SizedBox(width: double.infinity)
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      linha('1. Saldo no banco agora:', 'o total que o app do banco mostra para aquele investimento, já com o que você colocou ou tirou.'),
                      linha('2. Coloquei ou tirei dinheiro:', 'só se você mexeu no dinheiro desde o último lançamento. Se só rendeu, não precisa.'),
                      linha('3. Salvar:', 'o app separa o que foi dinheiro seu do que foi rendimento.'),
                      linha('Dica:', 'deixe em branco o que não quiser atualizar agora.'),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Coloquei / Tirei + valor (sem precisar digitar sinal de menos).
class _CampoAporte extends StatelessWidget {
  final TextEditingController c;
  final bool tirou;
  final String? desde;
  final ValueChanged<bool> aoMudarTipo;
  final VoidCallback aoMudar, aoFechar;
  const _CampoAporte({required this.c, required this.tirou, required this.desde, required this.aoMudarTipo, required this.aoMudar, required this.aoFechar});
  @override
  Widget build(BuildContext context) {
    Widget tipo(bool t, IconData ic, String txt) {
      final on = tirou == t;
      final cor = t ? S.neg : S.pos;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => aoMudarTipo(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? cor.withValues(alpha: .12) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: on ? cor : S.line, width: on ? 1.5 : 1),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(ic, size: 17, color: on ? cor : S.muted),
              const SizedBox(width: 6),
              Text(txt, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? cor : S.ink2)),
            ]),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(color: S.surface2, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(desde == null ? 'Mexeu no dinheiro hoje?' : 'Desde ${dataCurta(desde!)}, você:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: S.ink2)),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: aoFechar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text('Não mexi', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: S.accent)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          tipo(false, Icons.add_circle_outline_rounded, 'Coloquei'),
          const SizedBox(width: 8),
          tipo(true, Icons.remove_circle_outline_rounded, 'Tirei'),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          scrollPadding: const EdgeInsets.only(bottom: 160),
          decoration: InputDecoration(labelText: tirou ? 'Quanto tirou' : 'Quanto colocou', prefixText: 'R\$ ', hintText: '0,00', isDense: true),
          onChanged: (_) => aoMudar(),
        ),
      ]),
    );
  }
}

/// Uma linha com o resultado do ativo; toque para ver o caminho
/// saldo anterior → colocou/tirou → saldo de agora.
class _LinhaRend extends StatefulWidget {
  final double rend, ant, aporte, saldo;
  final double? pc;
  final String dAnt, data;
  final int periodo;
  const _LinhaRend({required this.rend, required this.pc, required this.ant, required this.dAnt, required this.aporte, required this.saldo, required this.data, required this.periodo});
  @override
  State<_LinhaRend> createState() => _LinhaRendState();
}

class _LinhaRendState extends State<_LinhaRend> {
  bool aberto = false;
  @override
  Widget build(BuildContext context) {
    final w = widget;
    final igual = w.rend.abs() < .005;
    final cor = igual ? S.ink2 : (w.rend > 0 ? S.pos : S.neg);
    final fundo = igual ? S.surface2 : (w.rend > 0 ? S.posSoft : S.negSoft);
    final dias = DateTime.parse(w.data).difference(DateTime.parse(w.dAnt)).inDays;
    final varia = w.saldo - w.ant;
    Widget passo(String r, String v, {Color? c}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r, style: TextStyle(fontSize: 11.5, color: S.muted)),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c ?? S.ink))),
          ]),
        );
    final seta = Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward_rounded, size: 15, color: S.muted));
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => aberto = !aberto),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(igual ? Icons.remove_rounded : (w.rend > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded), color: cor, size: 19),
                const SizedBox(width: 7),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('${igual ? 'Não rendeu' : (w.rend > 0 ? 'Rendeu' : 'Perdeu')} ${brl(w.rend, sinal: true)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cor)),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${w.pc != null ? '${pct(w.pc!, sinal: true)} · ' : ''}${dias <= 0 ? 'no dia' : 'em $dias dia${dias == 1 ? '' : 's'}'}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cor),
                ),
                AnimatedRotation(turns: aberto ? .5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.expand_more_rounded, color: S.muted, size: 20)),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: !aberto
                    ? const SizedBox(width: double.infinity)
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Divider(height: 16, color: cor.withValues(alpha: .18)),
                        Row(children: [
                          passo('Em ${dataCurta(w.dAnt)}', brl(w.ant)),
                          if (w.aporte != 0) ...[seta, passo(w.aporte > 0 ? 'Colocou' : 'Tirou', brl(w.aporte, sinal: true), c: S.accent)],
                          seta,
                          passo('Agora', brl(w.saldo)),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          'O saldo ${varia >= 0 ? 'subiu' : 'caiu'} ${brl(varia.abs())}${w.aporte != 0 ? ': ${brl(w.aporte.abs())} foi dinheiro que você ${w.aporte > 0 ? 'colocou' : 'tirou'} e ${brl(w.rend.abs())} foi ${w.rend >= 0 ? 'rendimento' : 'perda'}' : ''}.',
                          style: TextStyle(fontSize: 12, color: S.ink2, height: 1.35),
                        ),
                      ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Aviso amarelo com o texto inteiro e um botão de largura total embaixo.
class _Aviso extends StatelessWidget {
  final String texto, botao;
  final VoidCallback aoTocar;
  const _Aviso({required this.texto, required this.botao, required this.aoTocar});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: S.second.withValues(alpha: .12), borderRadius: BorderRadius.circular(12), border: Border.all(color: S.second.withValues(alpha: .35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 18, color: S.second),
            const SizedBox(width: 8),
            Expanded(child: Text(texto, style: TextStyle(fontSize: 13, color: S.ink, height: 1.4))),
          ]),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: aoTocar,
            style: OutlinedButton.styleFrom(foregroundColor: S.ink, side: BorderSide(color: S.second.withValues(alpha: .6)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            child: Text(botao, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

/// Aplicações/resgates registrados no Extrato que ainda não foram para o Patrimônio.
class _InvestSoltos extends StatelessWidget {
  final List<Investido> itens;
  final List<PosAtivo> Function(Investido) alvos;
  final Map<String, String> escolhido;
  final void Function(Investido, PosAtivo) aoEscolher;
  const _InvestSoltos({required this.itens, required this.alvos, required this.escolhido, required this.aoEscolher});
  @override
  Widget build(BuildContext context) => CartaoSite(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.link_rounded, size: 19, color: S.accent),
            const SizedBox(width: 8),
            Expanded(child: Text('Do Extrato: para qual investimento foi?', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: S.ink))),
          ]),
          const SizedBox(height: 4),
          Text('Toque no investimento certo e o valor entra como dinheiro que você colocou (ou tirou), sem virar rendimento.', style: TextStyle(fontSize: 12.5, color: S.ink2, height: 1.4)),
          for (final i in itens) ...[
            Divider(height: 20, color: S.line),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.desc, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: S.ink)),
                  Text('${dataCurta(i.data)} · ${i.resgate ? 'tirou (voltou para a conta)' : 'colocou (saiu da conta)'}', style: TextStyle(fontSize: 12, color: S.muted)),
                ]),
              ),
              const SizedBox(width: 8),
              Text(brl(i.liquido, sinal: true), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: S.accent)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in alvos(i))
                Material(
                  color: escolhido[i.id] == p.a.id ? S.accent : S.surface,
                  shape: StadiumBorder(side: BorderSide(color: escolhido[i.id] == p.a.id ? S.accent : S.line)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => aoEscolher(i, p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (escolhido[i.id] == p.a.id) ...[const Icon(Icons.check_rounded, size: 16, color: Colors.white), const SizedBox(width: 4)],
                        Text(p.a.nome, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: escolhido[i.id] == p.a.id ? Colors.white : S.ink)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ],
        ]),
      );
}

/// Lançamentos já salvos com rendimento fora do normal.
class _Suspeitos extends StatelessWidget {
  final List<({Lancamento l, Ativo a, double rend, double pc})> itens;
  final ValueChanged<Lancamento> corrigir, estaCerto;
  const _Suspeitos({required this.itens, required this.corrigir, required this.estaCerto});
  @override
  Widget build(BuildContext context) => CartaoSite(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Rendimentos para conferir', style: TextStyle(fontFamily: S.fonteNum, fontSize: 16, fontWeight: FontWeight.w700, color: S.ink)),
          const SizedBox(height: 4),
          Text('Variações acima de 2% num lançamento costumam ser dinheiro que você colocou ou tirou e não informou.', style: TextStyle(fontSize: 12.5, color: S.ink2, height: 1.4)),
          for (final x in itens.take(8)) ...[
            Divider(height: 20, color: S.line),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(x.a.nome, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: S.ink)),
                  Text('Lançamento de ${dataBr(x.l.data)}', style: TextStyle(fontSize: 12, color: S.muted)),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${x.rend >= 0 ? 'Rendeu' : 'Perdeu'} ${brl(x.rend, sinal: true)}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: x.rend >= 0 ? S.pos : S.neg)),
                Text(pct(x.pc, sinal: true), style: TextStyle(fontSize: 12, color: S.muted)),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => corrigir(x.l), child: const Text('Corrigir este dia', textAlign: TextAlign.center))),
              const SizedBox(width: 8),
              Expanded(child: TextButton(onPressed: () => estaCerto(x.l), child: const Text('Está certo', textAlign: TextAlign.center))),
            ]),
          ],
        ]),
      );
}

/// " na semana" / " em novembro" (vazio no modo dia).
String _noPeriodo(int periodo, String data) => switch (periodo) {
      1 => ' na semana',
      2 => ' em ${mesesLongos[int.parse(data.substring(5, 7)) - 1].toLowerCase()}',
      _ => '',
    };

/// Dia · Semana · Mês: de onde parte a conta do resultado.
class _SeletorPeriodo extends StatelessWidget {
  final int valor;
  final ValueChanged<int> aoMudar;
  const _SeletorPeriodo({required this.valor, required this.aoMudar});
  @override
  Widget build(BuildContext context) {
    const nomes = ['Dia', 'Semana', 'Mês'];
    const dicas = ['desde o último lançamento', 'desde segunda-feira', 'desde o dia 1º'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('Ver resultado por', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: S.ink2)),
        const Spacer(),
        Text(dicas[valor], style: TextStyle(fontSize: 12, color: S.muted)),
      ]),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: S.c('tabs-bg'), borderRadius: BorderRadius.circular(99), border: Border.all(color: S.line)),
        child: Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => aoMudar(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == valor ? S.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: i == valor ? [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 6, offset: const Offset(0, 2))] : null,
                  ),
                  child: Text(nomes[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: i == valor ? S.ink : S.muted)),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

/// Resumo de todos os investimentos do lançamento.
class _ResumoLanc extends StatelessWidget {
  final int n;
  final double rendeu, aportes, antes, depois, peso;
  final int periodo;
  final String data;
  const _ResumoLanc({required this.n, required this.rendeu, required this.aportes, required this.antes, required this.depois, this.peso = 0, required this.periodo, required this.data});
  @override
  Widget build(BuildContext context) {
    final cor = rendeu.abs() < .005 ? S.ink2 : (rendeu > 0 ? S.pos : S.neg);
    final pc = antes + peso > 0 ? rendeu / (antes + peso) : null;
    Widget lin(String r, String v, {Color? c, bool forte = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(r, style: TextStyle(fontSize: 13, color: S.ink2))),
            Text(v, style: TextStyle(fontSize: forte ? 14.5 : 13.5, fontWeight: FontWeight.w700, color: c ?? S.ink)),
          ]),
        );
    return CartaoSite(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(periodo == 0 ? 'Resultado deste lançamento' : 'Resultado${_noPeriodo(periodo, data)}', style: TextStyle(fontFamily: S.fonteNum, fontSize: 16.5, fontWeight: FontWeight.w700, color: S.ink)),
        Text('$n investimento${n == 1 ? '' : 's'} com saldo preenchido', style: TextStyle(fontSize: 12.5, color: S.muted)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('${rendeu >= 0 ? 'Rendeu' : 'Perdeu'} ${brl(rendeu, sinal: true)}', style: TextStyle(fontFamily: S.fonteNum, fontSize: 24, fontWeight: FontWeight.w800, color: cor)),
            ),
          ),
          if (pc != null) Text(pct(pc, sinal: true), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cor)),
        ]),
        Divider(height: 20, color: S.line),
        lin('Antes', brl(antes)),
        if (aportes != 0) lin(aportes > 0 ? 'Você colocou' : 'Você tirou', brl(aportes, sinal: true), c: S.accent),
        lin(rendeu >= 0 ? 'Rendimento' : 'Perda', brl(rendeu, sinal: true), c: cor),
        lin('Depois', brl(depois), forte: true),
      ]),
    );
  }
}
