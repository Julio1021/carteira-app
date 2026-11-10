import 'package:carteira/dados/drive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const agora = 1800000000000;
  test('vale a versão mais nova de cada registro', () {
    final j = juntar(
      [
        {'id': 'a', 'v': 'celular', '_u': 200},
        {'id': 'b', 'v': 'só no celular', '_u': 100},
      ],
      {},
      [
        {'id': 'a', 'v': 'drive', '_u': 100},
        {'id': 'c', 'v': 'só no drive', '_u': 100},
      ],
      {},
      agora: agora,
    );
    final m = {for (final d in j.docs) d['id']: d['v']};
    expect(m, {'a': 'celular', 'b': 'só no celular', 'c': 'só no drive'});
  });

  test('apagado vence se foi apagado depois da última alteração', () {
    final j = juntar(
      [
        {'id': 'a', '_u': 100},
      ],
      {},
      [],
      {'a': 150, 'x': 10},
      agora: agora,
    );
    expect(j.docs, isEmpty);
    expect(j.tomb.containsKey('x'), isFalse); // apagados muito antigos saem da lista
    final j2 = juntar([
      {'id': 'a', '_u': 300}
    ], {}, [], {'a': 150}, agora: agora);
    expect(j2.docs.single['id'], 'a');
  });
}
