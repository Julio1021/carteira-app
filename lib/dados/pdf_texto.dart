import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'inter.dart';

class SenhaPdf implements Exception {
  final bool errada;
  const SenhaPdf(this.errada);
}

/// Extrai as palavras de cada página com a posição (y cresce para cima).
List<List<ItemTexto>> textoDoPdf(Uint8List bytes, {String? senha}) {
  PdfDocument doc;
  try {
    doc = senha == null || senha.isEmpty ? PdfDocument(inputBytes: bytes) : PdfDocument(inputBytes: bytes, password: senha);
  } catch (e) {
    final m = e.toString().toLowerCase();
    if (m.contains('password') || m.contains('encrypt') || m.contains('senha')) throw SenhaPdf(senha != null && senha.isNotEmpty);
    rethrow;
  }
  try {
    final ext = PdfTextExtractor(doc);
    final paginas = <List<ItemTexto>>[];
    for (var i = 0; i < doc.pages.count; i++) {
      final itens = <ItemTexto>[];
      for (final linha in ext.extractTextLines(startPageIndex: i, endPageIndex: i)) {
        for (final w in linha.wordCollection) {
          if (w.text.trim().isEmpty) continue;
          itens.add(ItemTexto(w.text, w.bounds.left, -w.bounds.bottom));
        }
      }
      paginas.add(itens);
    }
    return paginas;
  } finally {
    doc.dispose();
  }
}
