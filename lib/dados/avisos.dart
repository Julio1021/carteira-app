// Avisos do mês (o sininho), com as mesmas regras do site.
import '../util/fmt.dart';
import 'categorias.dart';
import 'modelos.dart';
import 'planejar.dart';
import 'repo.dart';
import 'resumo.dart';

class Aviso {
  final String k;
  final int sev; // 3 grave · 2 atenção · 1 informação · 0 boa notícia
  final String texto;
  final String? cat, busca;
  final double val;
  final bool fixos;
  Aviso(this.k, this.sev, this.texto, {this.cat, this.busca, this.val = 0, this.fixos = false});
}

/// Gastos fixos do mês anterior que ainda não foram lançados neste mês.
List<Gasto> fixosPendentes(Repo repo, String ym) {
  final ant = ymAdd(ym, -1);
  final doMes = repo.gastos.where((g) => g.data.startsWith(ym)).toList();
  return repo.gastos
      .where((g) => g.fixo && g.data.startsWith(ant))
      .where((f) => !doMes.any((g) => g.desc.toLowerCase() == f.desc.toLowerCase() && g.cat == f.cat))
      .toList();
}

List<Doc> docsLancarFixos(Repo repo, String ym) {
  final dim = diasNoMes(ym);
  var i = 0;
  return [
    for (final f in fixosPendentes(repo, ym))
      {
        ...f.d,
        'id': '${novoId('g')}${i++}',
        'data': '$ym-${doisDig(int.parse(f.data.substring(8, 10)).clamp(1, dim).toInt())}',
        'criado': DateTime.now().millisecondsSinceEpoch + i,
      }..remove('ext')..remove('imp')..remove('pg'),
  ];
}

List<Aviso> avisosDoMes(Repo repo, {String? hoje}) {
  final h = hoje ?? hojeIso();
  final ref = ymDe(h);
  final todos = repo.gastos;
  final doMes = todos.where((g) => g.data.startsWith(ref)).toList();
  final frac = (int.parse(h.substring(8, 10)) / diasNoMes(ref)).clamp(0, 1).toDouble();
  final av = <Aviso>[];
  final cur = <String, double>{};
  for (final g in doMes) {
    cur[g.cat] = (cur[g.cat] ?? 0) + g.valor;
  }
  final prevs = [1, 2, 3].map((i) => ymAdd(ref, -i)).where((m) => todos.any((g) => g.data.startsWith(m))).toList();
  final media = <String, double>{};
  for (final g in todos) {
    if (prevs.contains(ymDe(g.data))) media[g.cat] = (media[g.cat] ?? 0) + g.valor / prevs.length;
  }
  final lim = {for (final l in repo.limites) l.cat: l.limite};
  final comLimite = <String>{};
  lim.forEach((c, l) {
    final v = cur[c] ?? 0, nome = catGasto(c).nome;
    if (v >= l) {
      av.add(Aviso('lim+$c$ref', 3, 'Você passou ${brl(v - l)} do limite de $nome este mês (${brl(v)} de ${brl(l)}).', cat: c));
      comLimite.add(c);
    } else if (frac < .95 && frac > 0 && v / frac > l * 1.05 && v >= l * .3) {
      av.add(Aviso('proj+$c$ref', 2, 'No ritmo atual, $nome deve fechar o mês perto de ${brl(v / frac)}, acima do limite de ${brl(l)}.', cat: c));
      comLimite.add(c);
    } else if (v >= l * .8) {
      av.add(Aviso('quase+$c$ref', 2, 'Faltam ${brl(l - v)} para atingir o limite de $nome (${(v / l * 100).round()}% usado).', cat: c));
      comLimite.add(c);
    }
  });
  for (final c in {...cur.keys, ...media.keys}) {
    if (comLimite.contains(c) || c == 'cartao') continue;
    final v = cur[c] ?? 0, base = (media[c] ?? 0) * frac, nome = catGasto(c).nome;
    if (base >= 30 && v > base * 1.3 && v - base >= 50) {
      final x = v / base;
      final comp = x >= 2 ? '${x.toStringAsFixed(1).replaceAll('.', ',')}× maior que a' : '${((x - 1) * 100).round()}% acima da';
      av.add(Aviso('alta+$c$ref', 2, '$nome está $comp sua média para esta altura do mês: ${brl(v)} contra ${brl(base)}.', cat: c, val: v - base));
    } else if (base >= 80 && v < base * .7 && base - v >= 80 && frac > .5) {
      av.add(Aviso('baixa+$c$ref', 0, 'Boa! $nome está ${((1 - v / base) * 100).round()}% abaixo da sua média: ${brl(v)} contra ${brl(base)}.', cat: c, val: base - v));
    }
  }
  final r = ResumoMes.de(repo, ref);
  final e = r.entrou, g = r.saiu;
  var aReceber = 0.0;
  for (final rd in repo.rendas.where((x) => x.valor > 0)) {
    final st = statusRenda(repo, rd, ref, hoje: h);
    if (st.rec == null && st.data.compareTo(h) >= 0) aReceber += rd.valor;
  }
  if (e > 0) {
    if (g > e && aReceber <= 0) {
      av.add(Aviso('saldo-$ref', 3, 'Até agora, este mês, você gastou ${brl(g - e)} a mais do que entrou (${brl(g)} de gastos para ${brl(e)} de entradas).'));
    } else if (frac >= .6 && e > g) {
      av.add(Aviso('saldo+$ref', 0, 'Até agora sobraram ${brl(e - g)}, ou ${((e - g) / e * 100).round()}% do que entrou.'));
    }
  }
  if (doMes.length >= 5) {
    final vs = doMes.map((x) => x.valor).toList()..sort();
    final med = vs[vs.length ~/ 2];
    final mx = doMes.reduce((a, b) => b.valor > a.valor ? b : a);
    if (mx.valor >= 200 && mx.valor >= med * 5) av.add(Aviso('maior-${mx.id}', 1, 'Maior gasto este mês: ${mx.desc}, ${brl(mx.valor)} em ${dataCurta(mx.data)}.', busca: mx.desc));
  }
  final ocultos = repo.lista('av.ocultos').toSet();
  final l = av.where((a) => !ocultos.contains(a.k)).toList()
    ..sort((a, b) {
      final c = b.sev.compareTo(a.sev);
      return c != 0 ? c : b.val.compareTo(a.val);
    });
  final out = l.take(5).toList();
  final fx = fixosPendentes(repo, ref);
  if (fx.isNotEmpty && !ocultos.contains('fixos-$ref')) {
    final nomes = fx.take(3).map((f) => f.desc).join(', ') + (fx.length > 3 ? '…' : '');
    out.insert(0, Aviso('fixos-$ref', 1, '${fx.length} gasto(s) fixo(s) de ${mesLongo(ymAdd(ref, -1)).toLowerCase()} ainda não lançado(s): $nomes.', fixos: true));
  }
  return out;
}
