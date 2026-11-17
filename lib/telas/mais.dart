// Patrimônio aberto como tela própria (atalhos do Início e da busca).

import 'package:flutter/material.dart';

import 'patrimonio.dart';

/// Patrimônio (investimentos, objetivos e relatórios) aberto como tela própria.
class TelaPatrimonioPagina extends StatelessWidget {
  final int sub;
  const TelaPatrimonioPagina({super.key, this.sub = 0});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Patrimônio')),
        body: TelaPatrimonio(subInicial: sub),
      );
}

