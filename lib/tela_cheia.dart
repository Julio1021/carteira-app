// Tela cheia no celular: esconder a barra de cima, as duas, ou deixá-las
// transparentes. A escolha fica em Ajustes.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tema.dart';

/// Ligada ou não.
final telaCheia = ValueNotifier<bool>(false);

/// 'topo' (esconde só a barra de cima), 'tudo' (esconde as duas) ou
/// 'transparente' (as barras ficam, mas o app passa por trás).
final telaCheiaTipo = ValueNotifier<String>('tudo');

Future<void> carregarTelaCheia() async {
  try {
    final sp = await SharedPreferences.getInstance();
    telaCheia.value = sp.getBool('telaCheia') ?? false;
    telaCheiaTipo.value = sp.getString('telaCheiaTipo') ?? 'tudo';
  } catch (_) {}
}

Future<void> definirTelaCheia({bool? ligada, String? tipo}) async {
  if (ligada != null) telaCheia.value = ligada;
  if (tipo != null) telaCheiaTipo.value = tipo;
  aplicarBarras();
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('telaCheia', telaCheia.value);
    await sp.setString('telaCheiaTipo', telaCheiaTipo.value);
  } catch (_) {}
}

/// Aplica as cores das barras do sistema e o modo de tela cheia escolhido.
void aplicarBarras() {
  final icones = G.claro ? Brightness.dark : Brightness.light;
  final modo = telaCheia.value ? telaCheiaTipo.value : 'nao';
  final transparente = modo == 'transparente';
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icones,
    statusBarBrightness: G.claro ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: transparente ? Colors.transparent : G.fundo,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: icones,
    systemNavigationBarContrastEnforced: !transparente,
  ));
  if (kIsWeb) return;
  switch (modo) {
    case 'topo':
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: const [SystemUiOverlay.bottom]);
    case 'tudo':
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    case 'transparente':
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    default:
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  }
}
