// Nome da pessoa (saudação) e o valor curto ("65,4 mil").
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/fmt.dart';

/// Nome para a saudação ("Olá, Júlio"). Vazio = sem nome.
final nomeUsuario = ValueNotifier<String>('');

Future<void> carregarNome() async {
  try {
    final sp = await SharedPreferences.getInstance();
    nomeUsuario.value = sp.getString('nome') ?? '';
  } catch (_) {}
}

Future<void> definirNome(String v) async {
  nomeUsuario.value = v.trim();
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('nome', v.trim());
  } catch (_) {}
}

/// "65,4 mil" (sem o R$), com privacidade.
String curtoBr(double v) {
  if (valoresOcultos) return '••••';
  if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(1).replaceAll('.', ',')} mi';
  return '${(v / 1e3).toStringAsFixed(1).replaceAll('.', ',')} mil';
}

