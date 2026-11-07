import 'package:carteira/dados/demo.dart';
import 'package:carteira/dados/repo.dart';
import 'package:carteira/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('abre o Início, troca de aba e abre o formulário de gasto', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    await t.pumpWidget(AppCarteira(repo: Repo.memoria(dadosDemo())));
    await t.pumpAndSettle();

    expect(find.text('Início'), findsWidgets);
    expect(find.text('Entrou'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Últimos lançamentos'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Últimos lançamentos'), findsOneWidget);

    await t.tap(find.text('Extrato').last);
    await t.pumpAndSettle();
    expect(find.text('Buscar no mês'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Lançar'));
    await t.pumpAndSettle();
    expect(find.text('O que você quer registrar?'), findsOneWidget);

    await t.tap(find.text('Gasto').last);
    await t.pumpAndSettle();
    expect(find.text('Novo gasto'), findsOneWidget);
  });
}
