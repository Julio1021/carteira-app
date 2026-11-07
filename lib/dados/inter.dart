// Leitura do "Extrato de movimentações" de investimentos do Inter (PDF),
// com a mesma lógica do site.
import '../util/fmt.dart';
import 'modelos.dart';
import 'patrimonio.dart';
import 'repo.dart';

/// Um pedaço de texto da página, com posição (y cresce para cima, como no PDF).
class ItemTexto {
  final String s;
  final double x, y;
  const ItemTexto(this.s, this.x, this.y);
}

class _Linha {
  final double y;
  final List<ItemTexto> itens = [];
  String texto = '';
  _Linha(this.y);
}

double interNum(String s) {
  s = s.replaceAll(RegExp(r'[^\d.,]'), '');
  if (s.isEmpty) return double.nan;
  return s.contains(',') ? double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? double.nan : double.tryParse(s) ?? double.nan;
}

List<_Linha> _linhas(List<ItemTexto> items) {
  final its = items.where((i) => i.s.trim().isNotEmpty).toList()
    ..sort((a, b) {
      final c = b.y.compareTo(a.y);
      return c != 0 ? c : a.x.compareTo(b.x);
    });
  final ls = <_Linha>[];
  for (final it in its) {
    var l = ls.where((l) => (l.y - it.y).abs() <= 1.5).firstOrNull;
    if (l == null) {
      l = _Linha(it.y);
      ls.add(l);
    }
    l.itens.add(it);
  }
  for (final l in ls) {
    l.itens.sort((a, b) => a.x.compareTo(b.x));
    l.texto = l.itens.map((i) => i.s).join(' ').replaceAll('\u0000', '±').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  ls.sort((a, b) => b.y.compareTo(a.y));
  return ls;
}

const _meses = {'janeiro': 1, 'fevereiro': 2, 'março': 3, 'marco': 3, 'abril': 4, 'maio': 5, 'junho': 6, 'julho': 7, 'agosto': 8, 'setembro': 9, 'outubro': 10, 'novembro': 11, 'dezembro': 12};

class TipoInter {
  final String key, nome, classe;
  const TipoInter(this.key, this.nome, this.classe);
}

TipoInter interTipo(String produto, String ativo) {
  final p = produto.toUpperCase(), a = ativo.toUpperCase();
  if (p.contains('TESOURO')) {
    final t = ativo.replaceFirst(RegExp(r'^\s*Tesouro\s*', caseSensitive: false), '').replaceFirst(RegExp(r'[\s-]+$'), '').trim();
    return TipoInter('tesouro:${t.toLowerCase()}', 'Tesouro $t', 'Tesouro Direto');
  }
  if (RegExp(r'\bLC[IA]\b').hasMatch(a)) return const TipoInter('lcilca', 'LCI/LCA', 'Renda Fixa');
  if (RegExp(r'\bCDB\b').hasMatch(a) && (RegExp(r'\bINTER\b').hasMatch(a) || a.contains('APLICAUT'))) return const TipoInter('cdbinter', 'CDB Inter', 'Renda Fixa');
  if (RegExp(r'\b(CDB|RDB|LC)\b').hasMatch(a)) return const TipoInter('cdboutros', 'CDB de outros emissores', 'Renda Fixa');
  return const TipoInter('outros', 'Outros títulos', 'Renda Fixa');
}

class MovInter {
  final String data, produto, ativo, codigo, tipo; // tipo: aplicacao | resgate
  final double? qtd;
  final double valor, liquido;
  MovInter(this.data, this.produto, this.ativo, this.codigo, this.tipo, this.qtd, this.valor, this.liquido);
}

class ExtratoInter {
  String? inicio, fim;
  double? posicaoTotal;
  final List<MovInter> rows = [];
  final List<String> avisos = [];
}

class _Ancora {
  final double y;
  final String date;
  final Map<String, List<ItemTexto>> byCol;
  final bool ancora;
  _Ancora(this.y, this.date, this.byCol, this.ancora);
}

ExtratoInter lerExtratoInter(List<List<ItemTexto>> paginas) {
  final out = ExtratoInter();
  String? date;
  String? secao;
  for (final pg in paginas) {
    final ls = _linhas(pg);
    Map<String, double>? cols;
    final ancoras = <_Ancora>[], frags = <_Ancora>[];
    for (final l in ls) {
      final t = l.texto;
      var m = RegExp(r'movimenta\S*\s+de\s+(\d{2})/(\d{2})/(\d{4})\s+a\s+(\d{2})/(\d{2})/(\d{4})', caseSensitive: false).firstMatch(t);
      if (m != null) {
        if (out.inicio == null) {
          out.inicio = '${m[3]}-${m[2]}-${m[1]}';
          out.fim = '${m[6]}-${m[5]}-${m[4]}';
        }
        continue;
      }
      if (t.startsWith(RegExp(r'CPF\b'))) continue;
      m = RegExp(r'^Posi\S*o Total\s*R\$\s*([\d.,]+)', caseSensitive: false).firstMatch(t);
      if (m != null) {
        out.posicaoTotal = interNum(m[1]!);
        continue;
      }
      if (RegExp(r'^Entradas$', caseSensitive: false).hasMatch(t)) {
        secao = 'entradas';
        continue;
      }
      if (RegExp(r'^Sa\S*das$', caseSensitive: false).hasMatch(t)) {
        secao = 'saidas';
        continue;
      }
      if (RegExp(r'^Movimenta\S*es$', caseSensitive: false).hasMatch(t)) {
        secao = null;
        continue;
      }
      if (secao != null) continue;
      m = RegExp(r'^(\d{1,2}) de ([a-zç]+) de (\d{4})$', caseSensitive: false).firstMatch(t);
      if (m != null && _meses.containsKey(m[2]!.toLowerCase())) {
        date = '${m[3]}-${doisDig(_meses[m[2]!.toLowerCase()]!)}-${doisDig(int.parse(m[1]!))}';
        continue;
      }
      if (t.startsWith('Produto') && t.contains('Quantidade')) {
        double? f(String w, [int n = 0]) {
          final l2 = l.itens.where((i) => i.s == w).toList();
          return l2.length > n ? l2[n].x : null;
        }

        final c = {
          'prod': f('Produto'),
          'ativo': f('Ativo'),
          'cod': f('Código') ?? f('Ativo', 1),
          'qtd': f('Quantidade'),
          'val': f('Valor'),
          'iof': f('IOF'),
          'ir': f('IR'),
          'liq': f('Valor', 1),
        };
        if (c.values.every((v) => v != null)) cols = {for (final e in c.entries) e.key: e.value!};
        continue;
      }
      if (cols == null || date == null) continue;
      final cc = cols;
      String col(double x) {
        final e = x + 2;
        if (e < cc['ativo']!) return 'prod';
        if (e < cc['cod']!) return 'ativo';
        if (e < cc['qtd']!) return 'cod';
        if (e < cc['val']!) return 'qtd';
        if (e < cc['iof']!) return 'val';
        if (e < cc['ir']!) return 'iof';
        if (e < cc['liq']!) return 'ir';
        return 'liq';
      }

      final byCol = <String, List<ItemTexto>>{};
      for (final i in l.itens) {
        (byCol[col(i.x)] ??= []).add(i);
      }
      final temValor = (byCol['val'] ?? const []).any((i) => i.s.contains('R\$'));
      if (temValor) {
        ancoras.add(_Ancora(l.y, date, byCol, true));
      } else if (byCol.keys.every((k) => k == 'prod' || k == 'ativo' || k == 'cod')) {
        frags.add(_Ancora(l.y, date, byCol, false));
      }
    }
    // nomes quebrados em várias linhas: junta os pedaços à linha principal mais próxima
    final seq = [...ancoras, ...frags]..sort((p, q) => q.y.compareTo(p.y));
    final grupos = <List<_Ancora>>[];
    double? ultimoY;
    String? ultimoD;
    for (final it in seq) {
      if (grupos.isNotEmpty && ultimoY != null && ultimoY - it.y <= 13 && ultimoD == it.date) {
        grupos.last.add(it);
      } else {
        grupos.add([it]);
      }
      ultimoY = it.y;
      ultimoD = it.date;
    }
    for (final g in grupos) {
      final as = g.where((i) => i.ancora).toList();
      for (final f in g.where((i) => !i.ancora)) {
        final pool = as.isNotEmpty ? as : ancoras.where((a) => a.date == f.date).toList();
        _Ancora? best;
        var bd = double.infinity;
        for (final a in pool) {
          final d = (a.y - f.y).abs();
          if (d < bd) {
            bd = d;
            best = a;
          }
        }
        if (best != null && (as.isNotEmpty || bd <= 30)) {
          f.byCol.forEach((k, v) => (best!.byCol[k] ??= []).addAll(v));
        }
      }
    }
    for (final a in ancoras) {
      String txt(String k) {
        final l2 = [...(a.byCol[k] ?? const <ItemTexto>[])]..sort((p, q) {
            final c = q.y.compareTo(p.y);
            return c != 0 ? c : p.x.compareTo(q.x);
          });
        return l2.map((i) => i.s).join(' ').replaceAll('\u0000', '').replaceAll(RegExp(r'\s+'), ' ').trim();
      }

      final qItems = a.byCol['qtd'] ?? const <ItemTexto>[];
      final neg = qItems.any((i) => i.s.contains('\u0000') || i.s.trim().startsWith('-') || i.s.trim().startsWith('−'));
      final qtd = interNum(qItems.map((i) => i.s).join());
      final valor = interNum(txt('val')), liq = interNum(txt('liq'));
      if (!valor.isFinite) {
        out.avisos.add('Linha sem valor em ${a.date}');
        continue;
      }
      out.rows.add(MovInter(a.date, txt('prod'), txt('ativo'), txt('cod').replaceAll(RegExp(r'\s+'), ''), neg ? 'resgate' : 'aplicacao', qtd.isFinite ? qtd : null, valor, liq.isFinite ? liq : valor));
    }
  }
  out.rows.sort((a, b) => a.data.compareTo(b.data));
  return out;
}

/// Lançamentos diários por tipo de investimento.
class GrupoInter {
  final TipoInter tipo;
  double aplicado = 0, resgatado = 0, ganho = 0;
  int n = 0, semCusto = 0;
  final Set<String> codigos = {};
  final Map<String, ({double fluxo, double ganho, double custo})> dias = {};
  List<({String data, double aporte, double saldo})> lista = [];
  GrupoInter(this.tipo);
  double get saldoFinal => lista.isEmpty ? 0 : lista.last.saldo;
}

List<GrupoInter> interPorTipo(List<MovInter> rows) {
  final grupos = <String, GrupoInter>{};
  final custo = <String, ({double un, double val, String grupo})>{};
  for (final r in rows) {
    final tp = interTipo(r.produto, r.ativo);
    final g = grupos.putIfAbsent(tp.key, () => GrupoInter(tp));
    final valido = r.codigo.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length >= 6;
    final ck = valido ? r.codigo : '${tp.key}|sem-codigo|${r.ativo}';
    g.codigos.add(ck);
    g.n++;
    var c = custo[ck] ?? (un: 0.0, val: 0.0, grupo: tp.key);
    final d0 = g.dias[r.data] ?? (fluxo: 0.0, ganho: 0.0, custo: 0.0);
    var fluxo = d0.fluxo, ganho = d0.ganho;
    if (r.tipo == 'aplicacao') {
      c = (un: c.un + (r.qtd ?? 0), val: c.val + r.valor, grupo: c.grupo);
      fluxo += r.valor;
      g.aplicado += r.valor;
    } else {
      double principal;
      final ok = '${tp.key}|sem-codigo|${r.ativo}';
      final orf = custo[ok];
      if (!(c.un > 0) && orf != null && orf.un > 0 && r.qtd != null) {
        final u = r.qtd! < orf.un ? r.qtd! : orf.un;
        principal = orf.val * (u / orf.un);
        var nu = orf.un - u, nv = orf.val - principal;
        if (nu < 1e-9) {
          nu = 0;
          nv = 0;
        }
        custo[ok] = (un: nu, val: nv, grupo: orf.grupo);
      } else if (c.un > 0 && r.qtd != null) {
        final u = r.qtd! < c.un ? r.qtd! : c.un;
        principal = c.val * (u / c.un);
        var nu = c.un - u, nv = c.val - principal;
        if (nu < 1e-9) {
          nu = 0;
          nv = 0;
        }
        c = (un: nu, val: nv, grupo: c.grupo);
      } else {
        principal = r.valor;
        g.semCusto++;
      }
      fluxo -= r.valor;
      ganho += r.valor - principal;
      g.resgatado += r.valor;
      g.ganho += r.valor - principal;
    }
    custo[ck] = c;
    final custoGrupo = custo.values.where((x) => x.grupo == tp.key).fold<double>(0, (s, x) => s + x.val);
    g.dias[r.data] = (fluxo: fluxo, ganho: ganho, custo: custoGrupo);
  }
  for (final g in grupos.values) {
    final ds = g.dias.keys.toList()..sort();
    g.lista = [
      for (final d in ds) (data: d, aporte: (g.dias[d]!.fluxo * 100).round() / 100, saldo: g.dias[d]!.custo < 0 ? 0.0 : (g.dias[d]!.custo * 100).round() / 100),
    ];
  }
  return grupos.values.toList()..sort((a, b) => b.aplicado.compareTo(a.aplicado));
}

/// Soma várias séries (carregando o último saldo de cada uma).
List<({String data, double aporte, double saldo})> somarSeries(List<List<({String data, double aporte, double saldo})>> listas) {
  final datas = {for (final l in listas) for (final d in l) d.data}.toList()..sort();
  final idx = List.filled(listas.length, 0), cur = List.filled(listas.length, 0.0);
  return [
    for (final dt in datas)
      () {
        var ap = 0.0;
        for (var k = 0; k < listas.length; k++) {
          final l = listas[k];
          while (idx[k] < l.length && l[idx[k]].data == dt) {
            cur[k] = l[idx[k]].saldo;
            ap += l[idx[k]].aporte;
            idx[k]++;
          }
        }
        return (data: dt, aporte: (ap * 100).round() / 100, saldo: (cur.fold<double>(0, (a, b) => a + b) * 100).round() / 100);
      }(),
  ];
}

/// Monta os registros da importação.
/// [modo] "junto": tudo num ativo só ([alvo], ou um novo "Inter").
/// [modo] "separado": um ativo por tipo, dentro do ativo [alvo] (ou de um novo "Inter").
/// [saldoFinal]: saldo informado no fim do período (opcional) para corrigir o rendimento.
List<Doc> docsImportInter(Repo repo, ExtratoInter ex, List<GrupoInter> grupos, {required String modo, String? alvo, double? saldoFinal}) {
  final impId = 'imp_${DateTime.now().millisecondsSinceEpoch}';
  final docs = <Doc>[];
  var paiId = alvo;
  if (paiId == null) {
    paiId = novoId('a');
    docs.add({'kind': 'ativo', 'id': paiId, 'nome': 'Inter', 'classe': 'Renda Fixa', 'inst': 'Inter', 'cor': '#ff7a00', 'ordem': DateTime.now().millisecondsSinceEpoch, 'imp': impId});
  }
  void lancar(String ativo, List<({String data, double aporte, double saldo})> dias) {
    for (final d in dias) {
      if (repo.porId('l_${ativo}_${d.data}') != null) continue; // não sobrescreve o que você já lançou
      docs.add({...docLanc(ativo, d.data, d.saldo, d.aporte), 'imp': impId});
    }
  }

  List<({String data, double aporte, double saldo})> comSaldoFinal(List<({String data, double aporte, double saldo})> dias, double? sf) {
    if (sf == null || sf < 0 || ex.fim == null) return dias;
    final l = [...dias];
    final i = l.indexWhere((d) => d.data == ex.fim);
    if (i >= 0) {
      l[i] = (data: l[i].data, aporte: l[i].aporte, saldo: sf);
    } else if (l.isEmpty || ex.fim!.compareTo(l.last.data) > 0) {
      l.add((data: ex.fim!, aporte: 0.0, saldo: sf));
    }
    return l;
  }

  if (modo == 'junto') {
    lancar(paiId, comSaldoFinal(somarSeries(grupos.map((g) => g.lista).toList()), saldoFinal));
    return docs;
  }
  final filhos = repo.doTipo('ativo').where((a) => a['pai'] == paiId && a['oculto'] != true).toList();
  var cor = 0;
  for (final g in grupos) {
    final ex0 = filhos.where((a) => a['impTipo'] == g.tipo.key || str(a['nome']).toLowerCase() == g.tipo.nome.toLowerCase()).firstOrNull;
    var id = ex0 == null ? null : str(ex0['id']);
    if (id == null) {
      id = novoId('a');
      docs.add({'kind': 'ativo', 'id': id, 'nome': g.tipo.nome, 'classe': g.tipo.classe, 'inst': 'Inter', 'cor': cor++ % 8, 'ordem': DateTime.now().millisecondsSinceEpoch + docs.length, 'imp': impId, 'impTipo': g.tipo.key, 'pai': paiId});
    }
    lancar(id, g.lista);
  }
  return docs;
}

/// Desfaz uma importação do Inter (apaga ativos e lançamentos que vieram dela).
List<String> idsDaImportacaoInter(Repo repo, String impId) => [
      for (final d in [...repo.doTipo('ativo'), ...repo.doTipo('lanc')])
        if (d['imp'] == impId) str(d['id'])
    ];

List<({String id, int quando, int lanc})> importacoesInter(Repo repo) {
  final m = <String, ({String id, int quando, int lanc})>{};
  for (final d in repo.doTipo('lanc')) {
    final imp = d['imp'];
    if (imp is! String || !imp.startsWith('imp_')) continue;
    final x = m[imp] ?? (id: imp, quando: int.tryParse(imp.substring(4)) ?? 0, lanc: 0);
    m[imp] = (id: x.id, quando: x.quando, lanc: x.lanc + 1);
  }
  return m.values.toList()..sort((a, b) => b.quando.compareTo(a.quando));
}

/// Atalho para o ativo "Inter" existente, se houver.
Ativo? ativoInter(Repo repo) {
  final vis = repo.doTipo('ativo').map(Ativo.new).where((a) => !a.oculto).toList();
  final ids = {for (final a in vis) a.id};
  final topo = vis.where((a) => a.pai == null || !ids.contains(a.pai));
  return topo.where((a) => RegExp('inter', caseSensitive: false).hasMatch(a.nome) && a.d['imp'] == null).firstOrNull ??
      topo.where((a) => RegExp('inter', caseSensitive: false).hasMatch(a.nome)).firstOrNull;
}
