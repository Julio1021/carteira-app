// "Para conferir": tudo que pede uma ação sua, num lugar só.
import '../util/fmt.dart';
import 'avisos.dart';
import 'modelos.dart';
import 'patrimonio.dart';
import 'planejar.dart';
import 'repo.dart';

class Pendencia {
  /// Chave estável (para "ignorar").
  final String k;
  /// transf · receber · conta · semcat · rend · fixos · aviso
  final String tipo;
  final String titulo, sub;
  final double? valor;
  /// 3 urgente · 2 atenção · 1 informação · 0 boa notícia
  final int sev;
  final Object? obj;
  const Pendencia(this.k, this.tipo, this.titulo, this.sub, {this.valor, this.sev = 2, this.obj});
  bool get podeIgnorar => tipo != 'transf' && tipo != 'conta';
}

const gruposConferir = <String, String>{
  'transf': 'Dinheiro que chegou de outra conta sua',
  'receber': 'Recebimentos que ainda não apareceram',
  'conta': 'Contas atrasadas',
  'semcat': 'Gastos sem categoria',
  'rend': 'Rendimentos estranhos nos investimentos',
  'fixos': 'Gastos fixos do mês passado',
  'aviso': 'Avisos do mês',
};

/// Tudo que está pendente, na ordem dos grupos acima.
List<Pendencia> pendencias(Repo repo, {String? hoje}) {
  final h = hoje ?? hojeIso();
  final ym = ymDe(h);
  final ocultos = repo.lista('conf.ocultos').toSet();
  final out = <Pendencia>[];

  for (final e in transfPendentes(repo)) {
    out.add(Pendencia('transf+${e.id}', 'transf', 'Chegou ${brl(e.valor)} de outra conta sua', 'Em ${dataCurta(e.data)}. Foi salário, vale, 13º ou só troca de conta?', sev: 3, obj: e));
  }

  for (final r in repo.rendas.where((r) => r.valor > 0)) {
    for (final m in [ymAdd(ym, -1), ym]) {
      final st = statusRenda(repo, r, m, hoje: h);
      if (st == null || st.rec != null || st.data.compareTo(h) > 0) continue;
      // do mês passado, só se foi há pouco (mais antigo que isso já virou passado)
      if (diasEntre(st.data, h).abs() > 20) continue;
      final k = 'rec+${r.id}+$m';
      if (ocultos.contains(k)) continue;
      final atraso = diasEntre(st.data, h) - 1;
      out.add(Pendencia(
        k,
        'receber',
        m == ym ? '${r.nome} ainda não apareceu' : '${r.nome} de ${mesLongo(m).split(' ').first.toLowerCase()} ainda não apareceu',
        atraso <= 0 ? 'Era para hoje (${dataCurta(st.data)}). Já entrou?' : 'Era para ${dataCurta(st.data)}, há $atraso dia${atraso == 1 ? '' : 's'}. Já entrou?',
        valor: valorEsperado(repo, r, hoje: h),
        sev: atraso > 3 ? 3 : 2,
        obj: (r: r, st: st),
      ));
    }
  }

  if (repo.doTipo('pagar').isNotEmpty) {
    for (final i in mesContas(repo, ym, hoje: h).abertas.where((i) => i.st == 'atrasada')) {
      final atraso = -i.dias;
      out.add(Pendencia('conta+${i.idPagto}', 'conta', i.b.nome, 'Venceu em ${dataCurta(i.venc)}${atraso > 0 ? ', há $atraso dia${atraso == 1 ? '' : 's'}' : ''}.', valor: i.valor, sev: 3, obj: i));
    }
  }

  final ini = '${ymAdd(ym, -1)}-01';
  for (final g in repo.gastos) {
    if (g.cat != 'outros' || g.d['okCat'] == true || g.data.compareTo(ini) < 0) continue;
    out.add(Pendencia('semcat+${g.id}', 'semcat', g.desc, '${dataCurta(g.data)} · está em Outros. Qual é a categoria?', valor: g.valor, sev: 1, obj: g));
  }

  final c = calcularCarteira(repo);
  for (final x in rendimentosSuspeitos(c).where((x) => diasEntre(x.l.data, h).abs() <= 120).take(6)) {
    out.add(Pendencia(
      'rend+${x.l.id}',
      'rend',
      '${x.a.nome}: ${x.rend >= 0 ? 'subiu' : 'caiu'} ${brl(x.rend.abs())} em ${dataCurta(x.l.data)}',
      'Variou ${pct(x.pc.abs())}, muito acima do normal. Você ${x.rend >= 0 ? 'colocou' : 'tirou'} dinheiro e não informou?',
      sev: 1,
      obj: x,
    ));
  }

  for (final a in avisosDoMes(repo, hoje: h)) {
    if (a.fixos) {
      out.add(Pendencia('aviso+${a.k}', 'fixos', 'Gastos fixos para lançar', a.texto, sev: 1, obj: a));
    } else if (a.sev >= 2) {
      out.add(Pendencia('aviso+${a.k}', 'aviso', a.sev >= 3 ? 'Passou do limite' : 'Atenção aos gastos', a.texto, sev: a.sev, obj: a));
    }
  }
  return [
    for (final g in gruposConferir.keys) ...out.where((p) => p.tipo == g && !ocultos.contains(p.k)),
  ];
}

/// Quantas pendências pedem ação (os avisos do mês não entram na conta).
int nPendencias(Repo repo) => pendencias(repo).where((p) => p.tipo != 'aviso').length;

/// Some com a pendência da lista (ex.: "não veio este mês", "está certo").
Future<void> ignorarPendencia(Repo repo, Pendencia p) async {
  switch (p.tipo) {
    case 'semcat':
      final g = p.obj as Gasto;
      await repo.salvar({...g.d, 'okCat': true});
    case 'rend':
      final l = (p.obj as ({Lancamento l, Ativo a, double rend, double pc})).l;
      await repo.salvar({...l.d, 'okRend': true});
    case 'fixos' || 'aviso':
      final a = p.obj as Aviso;
      await repo.guardarLista('av.ocultos', [...repo.lista('av.ocultos'), a.k].reversed.take(300).toList());
    default:
      await repo.guardarLista('conf.ocultos', [...repo.lista('conf.ocultos'), p.k].reversed.take(400).toList());
  }
}
