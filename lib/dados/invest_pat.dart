// Liga os lançamentos "Investido" ao Patrimônio: o aporte entra no ativo
// escolhido sem precisar lançar duas vezes.
//
// No doc do investido ficam:
//   pat     → id do lançamento do Patrimônio (l_<ativo>_<data>)
//   patV    → quanto foi somado ao saldo/aporte desse lançamento (0 = só vinculado)
//   patNovo → true se o lançamento foi criado por aqui
// No lançamento criado por aqui fica 'auto': true.
import 'modelos.dart';
import 'patrimonio.dart';
import 'repo.dart';
import '../util/fmt.dart';

/// Mudanças a gravar: docs para salvar e ids para apagar.
class Mudancas {
  final Map<String, Doc> salvar = {};
  final Set<String> apagar = {};
  final Repo repo;
  Mudancas(this.repo);

  Doc? ler(String id) => apagar.contains(id) ? null : (salvar[id] ?? repo.porId(id));
  void poe(Doc d) {
    final id = str(d['id']);
    apagar.remove(id);
    salvar[id] = d;
  }

  void tirar(String id) {
    salvar.remove(id);
    apagar.add(id);
  }

  Future<void> gravar() async {
    if (salvar.isNotEmpty) await repo.salvarVarios(salvar.values.toList());
    if (apagar.isNotEmpty) await repo.apagarVarios(apagar.toList());
  }
}

double _r2(double v) => (v * 100).round() / 100;

/// Ids de lançamentos do Patrimônio já usados por outros investidos (vínculo sem somar).
Set<String> _vinculados(Repo repo, {String? exceto}) => {
      for (final d in repo.doTipo('invest'))
        if (d['id'] != exceto && d['pat'] is String && numD(d['patV']) == 0) d['pat'] as String
    };

/// Lançamento do Patrimônio que já registra este mesmo aporte (mesmo valor, até 3 dias de diferença).
Lancamento? aporteJaLancado(Repo repo, String ativoId, String data, double liquido, {String? exceto}) {
  final usados = _vinculados(repo, exceto: exceto);
  Lancamento? melhor;
  var dist = 99;
  for (final l in repo.doTipo('lanc').map(Lancamento.new)) {
    if (l.ativo != ativoId || usados.contains(l.id) || l.d['auto'] == true) continue;
    if ((l.aporte - liquido).abs() > .009 || l.aporte == 0) continue;
    final dd = (DateTime.parse(data).difference(DateTime.parse(l.data)).inHours / 24).round().abs();
    if (dd <= 3 && dd < dist) {
      melhor = l;
      dist = dd;
    }
  }
  return melhor;
}

/// Desfaz o efeito de um investido no Patrimônio (antes de editar ou apagar).
void desligarDoPatrimonio(Mudancas m, Doc inv) {
  final pat = inv['pat'];
  if (pat is! String) return;
  final v = numD(inv['patV']);
  if (v != 0) {
    final l = m.ler(pat);
    if (l != null) {
      final criadoAqui = inv['patNovo'] == true;
      // se o lançamento criado aqui foi sobrescrito à mão, não mexe
      if (!criadoAqui || l['auto'] == true) {
        final aporte = _r2(numD(l['aporte']) - v);
        final saldo = _r2(numD(l['saldo']) - v);
        final outros = m.repo.doTipo('invest').any((d) => d['id'] != inv['id'] && d['pat'] == pat);
        if (l['auto'] == true && aporte.abs() < .005 && !outros) {
          m.tirar(pat);
        } else {
          m.poe({...l, 'aporte': aporte, 'saldo': saldo < 0 ? 0 : saldo});
        }
      }
    }
  }
  inv.remove('pat');
  inv.remove('patV');
  inv.remove('patNovo');
}

/// Lança (ou vincula) o investido no ativo escolhido. Retorna uma mensagem curta.
String ligarAoPatrimonio(Mudancas m, Doc inv, String ativoId) {
  final i = Investido(inv);
  final liq = i.liquido;
  final data = i.data;
  // 1) já existe esse aporte lançado no Patrimônio? só vincula
  final ja = aporteJaLancado(m.repo, ativoId, data, liq, exceto: i.id);
  if (ja != null) {
    inv['pat'] = ja.id;
    inv['patV'] = 0;
    inv['patNovo'] = false;
    return 'Vinculado ao aporte já lançado em ${dataCurta(ja.data)}.';
  }
  // 2) soma no lançamento do dia ou cria um novo a partir do último saldo
  final id = 'l_${ativoId}_$data';
  final ex = m.ler(id);
  if (ex != null) {
    m.poe({...ex, 'saldo': _r2(numD(ex['saldo']) + liq), 'aporte': _r2(numD(ex['aporte']) + liq)});
    inv['patNovo'] = false;
  } else {
    final c = calcularCarteira(m.repo);
    final ant = anteriorDe(c, ativoId, data);
    final base = ant?.saldo ?? 0;
    final saldo = base + liq;
    if (saldo < -.005) return 'O resgate é maior que o saldo do ativo; não lancei no Patrimônio.';
    m.poe({...docLanc(ativoId, data, saldo < 0 ? 0 : saldo, liq), 'auto': true});
    inv['patNovo'] = true;
  }
  inv['pat'] = id;
  inv['patV'] = liq;
  return 'Lançado no Patrimônio.';
}

/// Investidos que ainda não foram para nenhum ativo do Patrimônio.
List<Investido> investidosSemAtivo(Repo repo) => repo.investidos.where((i) => i.d['pat'] == null && i.d['semPat'] != true).toList()
  ..sort((a, b) => b.data.compareTo(a.data));

/// Conferência de um mês: o que saiu da conta para investir × aportes lançados no Patrimônio.
class Conferencia {
  final String ym;
  final double saiuParaInvestir, aportes;
  Conferencia(this.ym, this.saiuParaInvestir, this.aportes);
  double get diferenca => saiuParaInvestir - aportes;
  bool get bate => diferenca.abs() < 1;
}

List<Conferencia> conferenciaMeses(Repo repo, Carteira c, {int meses = 3, String? hoje}) {
  final ymH = ymDe(hoje ?? hojeIso());
  final out = <Conferencia>[];
  for (var k = 0; k < meses; k++) {
    final ym = ymAdd(ymH, -k);
    final inv = repo.investidos.where((i) => ymDe(i.data) == ym && i.d['semPat'] != true).fold<double>(0, (t, i) => t + i.liquido);
    final mp = c.meses.where((m) => m.ym == ym);
    final ap = mp.isEmpty ? 0.0 : mp.first.aportes;
    if (inv.abs() < .005 && ap.abs() < .005) continue;
    out.add(Conferencia(ym, _r2(inv), _r2(ap)));
  }
  return out;
}

/// Ao apagar um lançamento, desfaz o que dependia dele (conta paga, recebimento, Patrimônio).
void cascataApagar(Mudancas m, Doc d) {
  final id = str(d['id']);
  switch (d['kind']) {
    case 'invest':
      desligarDoPatrimonio(m, d);
    case 'gasto':
      for (final p in m.repo.doTipo('pagto')) {
        if (p['gasto'] != id) continue;
        if (p['criouGasto'] == true) {
          m.tirar(str(p['id']));
        } else {
          final n = Map<String, dynamic>.from(p)
            ..['pago'] = false
            ..remove('gasto')
            ..remove('valor')
            ..remove('data');
          m.poe(n);
        }
      }
    case 'entrada':
      for (final r in m.repo.doTipo('receb')) {
        if (r['entrada'] == id) m.tirar(str(r['id']));
      }
  }
  m.tirar(id);
}

/// Mantém a conta paga em dia quando o gasto que a pagou é editado.
void sincronizarPagto(Mudancas m, Doc gasto) {
  for (final p in m.repo.doTipo('pagto')) {
    if (p['gasto'] == gasto['id'] && p['pago'] == true) m.poe({...p, 'valor': gasto['valor'], 'data': gasto['data']});
  }
}
