// Lançamento rápido: entende uma frase como "mercado 45,90 débito ontem"
// e monta o lançamento, escolhendo a categoria pelo seu histórico.
import '../util/fmt.dart';
import 'modelos.dart';

class Rapido {
  final bool entrada;
  final String desc;
  final double? valor;
  final String cat, pag, data;

  /// true quando a categoria veio de um lançamento parecido que você já fez.
  final bool doHistorico;
  const Rapido({required this.entrada, required this.desc, required this.valor, required this.cat, required this.pag, required this.data, this.doHistorico = false});

  bool get pronto => valor != null && valor! > 0;

  /// [descPadrao] entra quando a frase só tinha o valor (ex.: nome da categoria).
  Doc doc({String descPadrao = 'Gasto'}) {
    final v = ((valor ?? 0) * 100).round() / 100;
    final d = desc.isEmpty ? descPadrao : desc;
    final agora = DateTime.now().millisecondsSinceEpoch;
    return entrada
        ? {'kind': 'entrada', 'id': novoId('e'), 'desc': d, 'valor': v, 'data': data, 'cat': cat, 'criado': agora}
        : {'kind': 'gasto', 'id': novoId('g'), 'desc': d, 'valor': v, 'data': data, 'cat': cat, 'pag': pag, 'fixo': false, 'criado': agora};
  }
}

/// Minúsculas e sem acentos, para comparar textos.
String semAcento(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç', para = 'aaaaaeeeeiiiiooooouuuuc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = de.indexOf(ch);
    b.write(i >= 0 ? para[i] : ch);
  }
  return b.toString();
}

const _palavras = <String, List<String>>{
  'mercado': ['mercado', 'supermercado', 'atacad', 'assai', 'carrefour', 'hortifruti', 'feira', 'acougue', 'sacolao'],
  'alimentacao': ['ifood', 'restaurante', 'lanche', 'pizza', 'hamburg', 'almoco', 'jantar', 'cafe', 'padaria', 'sorvete', 'acai', 'marmita', 'pastel'],
  'transporte': ['uber', '99', 'gasolina', 'posto', 'combustivel', 'onibus', 'metro', 'estacionamento', 'pedagio', 'etanol', 'taxi', 'oficina'],
  'saude': ['farmacia', 'drogaria', 'drogasil', 'remedio', 'medico', 'consulta', 'exame', 'dentista', 'hospital'],
  'lazer': ['cinema', 'show', 'ingresso', 'jogo', 'viagem', 'hotel', 'passeio'],
  'assinaturas': ['netflix', 'spotify', 'prime', 'disney', 'hbo', 'youtube', 'icloud', 'assinatura'],
  'contas': ['luz', 'agua', 'energia', 'gas', 'condominio'],
  'internet': ['internet', 'fibra', 'wifi'],
  'moradia': ['aluguel', 'iptu', 'reforma'],
  'educacao': ['curso', 'livro', 'faculdade', 'escola', 'mensalidade', 'apostila'],
  'pets': ['racao', 'pet', 'veterinario'],
  'cuidados': ['cabelo', 'barbeiro', 'barbearia', 'salao', 'manicure'],
  'compras': ['amazon', 'shopee', 'roupa', 'tenis', 'magalu', 'presente', 'shein'],
  'recarga': ['recarga'],
  'impostos': ['imposto', 'ipva', 'taxa', 'multa'],
};

const _pags = <String, String>{'pix': 'Pix', 'debito': 'Débito', 'credito': 'Crédito', 'dinheiro': 'Dinheiro', 'boleto': 'Boleto', 'cartao': 'Crédito'};

final _numero = RegExp(r'(?:r\$\s*)?(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)');

/// Lê a frase. Devolve null quando não há nada escrito.
Rapido? lerRapido(String texto, List<Gasto> historico, {String? hoje}) {
  var t = texto.trim();
  if (t.isEmpty) return null;
  final h = hoje ?? hojeIso();
  var entrada = false;
  if (t.startsWith('+')) {
    entrada = true;
    t = t.substring(1).trim();
  }
  // valor: o último número da frase
  double? valor;
  final ms = _numero.allMatches(t.toLowerCase()).toList();
  if (ms.isNotEmpty) {
    final m = ms.last;
    valor = lerValor(m.group(1));
    t = (t.substring(0, m.start) + t.substring(m.end)).trim();
  }
  var data = h;
  String? pag;
  final sobra = <String>[];
  for (final p in t.split(RegExp(r'\s+'))) {
    if (p.isEmpty) continue;
    final n = semAcento(p);
    if (n == 'ontem') {
      data = addDias(h, -1);
    } else if (n == 'anteontem') {
      data = addDias(h, -2);
    } else if (n == 'hoje') {
      data = h;
    } else if (_pags.containsKey(n)) {
      pag = _pags[n];
    } else if (n == 'recebi' || n == 'entrada' || n == 'entrou') {
      entrada = true;
    } else if (n == 'no' || n == 'na' || n == 'de' || n == 'em' || n == 'com') {
      if (sobra.isNotEmpty) sobra.add(p);
    } else {
      sobra.add(p);
    }
  }
  // tira preposição que sobrou no fim ("uber de")
  while (sobra.isNotEmpty && const ['no', 'na', 'de', 'em', 'com'].contains(semAcento(sobra.last))) {
    sobra.removeLast();
  }
  var desc = sobra.join(' ');
  if (desc.isNotEmpty) desc = desc[0].toUpperCase() + desc.substring(1);
  final chave = semAcento(desc);

  if (entrada) {
    final cat = chave.contains('salario') ? 'salario' : (chave.contains('reembolso') || chave.contains('estorno') ? 'reembolso' : (chave.contains('vend') ? 'vendas' : 'pix'));
    return Rapido(entrada: true, desc: desc, valor: valor, cat: cat, pag: '', data: data);
  }

  // 1º: o que você mais usou para essa mesma descrição
  String? cat;
  var doHist = false;
  if (chave.length >= 3) {
    final votosCat = <String, int>{}, votosPag = <String, int>{};
    String? descHist;
    for (final g in historico) {
      final d = semAcento(g.desc);
      if (d == chave || d.startsWith(chave) || (chave.length >= 4 && d.contains(chave))) {
        votosCat[g.cat] = (votosCat[g.cat] ?? 0) + (d == chave ? 3 : 1);
        votosPag[g.pag] = (votosPag[g.pag] ?? 0) + 1;
        if (d.startsWith(chave) && (descHist == null || g.desc.length < descHist.length)) descHist = g.desc;
      }
    }
    if (votosCat.isNotEmpty) {
      cat = (votosCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
      pag ??= (votosPag.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
      doHist = true;
      // "superm" vira "Supermercado Dia", como você costuma escrever
      if (descHist != null && semAcento(descHist) != chave && chave.length >= 4) desc = descHist;
    }
  }
  // 2º: palavras conhecidas
  if (cat == null) {
    final palavrasFrase = chave.split(' ');
    for (final e in _palavras.entries) {
      if (e.value.any((k) => palavrasFrase.any((p) => p.startsWith(k)))) {
        cat = e.key;
        break;
      }
    }
  }
  return Rapido(entrada: false, desc: desc, valor: valor, cat: cat ?? 'outros', pag: pag ?? 'Pix', data: data, doHistorico: doHist);
}
