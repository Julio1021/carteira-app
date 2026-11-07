import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paleta "Grafite" fixa (tema escuro). Usada também no cartão principal,
/// que continua escuro no tema claro ("Pérola").
class GE {
  static const fundo = Color(0xFF101119);
  static const fundo2 = Color(0xFF181924);
  static const branco = Color(0xFFF4F5FA);
  static const tinta = Color(0xFF12131C);
  static const texto = Color(0xFFF4F5FA);
  static const texto2 = Color(0xFFC9CCDB);
  static const apagado = Color(0xFF8C90A6);
  static const lavanda = Color(0xFFB9BFF6);
  static const pos = Color(0xFF4FD98C);
  static const neg = Color(0xFFFF6B81);
  static const alerta = Color(0xFFF5C26B);
  static const borda = Color(0x16FFFFFF);
  static const posEscuro = Color(0xFF15924F);
  static const negEscuro = Color(0xFFC8243F);
  static const gradHero = LinearGradient(
    begin: Alignment(-1, -1),
    end: Alignment(1, 1),
    colors: [Color(0xFF353950), Color(0xFF262839), Color(0xFF1C1D2A)],
    stops: [0, .52, 1],
  );
  static const gradLavanda = LinearGradient(
    begin: Alignment(-1, -1),
    end: Alignment(1, 1),
    colors: [Color(0xFFBCC0DD), Color(0xFF9A9FBE), Color(0xFF7C819F)],
    stops: [0, .48, 1],
  );
}

/// Aparência escolhida em Ajustes: 'auto' (segue o celular), 'claro' ou 'escuro'.
final aparencia = ValueNotifier<String>('auto');

Future<void> carregarAparencia() async {
  try {
    final sp = await SharedPreferences.getInstance();
    aparencia.value = sp.getString('aparencia') ?? 'auto';
  } catch (_) {}
}

Future<void> definirAparencia(String v) async {
  aparencia.value = v;
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('aparencia', v);
  } catch (_) {}
}

/// Cores do tema atual. [claro] = true usa a paleta "Pérola".
class G {
  static bool claro = false;
  static Color _c(int claroHex, Color escuro) => claro ? Color(claroHex) : escuro;

  static Color get fundo => _c(0xFFF4F5F9, GE.fundo);
  static Color get fundo2 => _c(0xFFFFFFFF, GE.fundo2);
  /// Cor "invertida" de destaque (fundo de chip/botão selecionado).
  static Color get branco => _c(0xFF12131C, GE.branco);
  /// Texto sobre [branco].
  static Color get tinta => _c(0xFFFFFFFF, GE.tinta);
  static Color get texto => _c(0xFF12131C, GE.texto);
  static Color get texto2 => _c(0xFF4A4E63, GE.texto2);
  static Color get apagado => _c(0xFF7A7E93, GE.apagado);
  static Color get lavanda => _c(0xFF4F57D6, GE.lavanda);
  static Color get pos => _c(0xFF12935A, GE.pos);
  static Color get neg => _c(0xFFE0445E, GE.neg);
  static Color get alerta => _c(0xFFB7791F, GE.alerta);
  static Color get borda => _c(0x1412131C, GE.borda);
  static Color get vidro => v(0x10);
  static Color get vidro2 => v(0x18);
  static Color get posEscuro => GE.posEscuro;
  static Color get negEscuro => GE.negEscuro;
  /// Vermelho para texto (mais suave no escuro).
  static Color get negTexto => _c(0xFFD63A55, const Color(0xFFFF8DA0));
  static Color get lavandaIcone => _c(0xFF4F57D6, const Color(0xFFC9CDFB));
  static Color get lavandaFundo => _c(0x1A4F57D6, const Color(0x29B9BFF6));
  static Color get saida => _c(0xFFE0445E, const Color(0xFFFF7A8C));
  static Color get navApagado => _c(0xFF9A9DB0, const Color(0xFF80849B));
  static Color get navFundo => _c(0xF5FFFFFF, const Color(0xEB1E1F2C));
  static Color get dica => _c(0xF212131C, const Color(0xF2232434));

  /// Película translúcida: branca no escuro, tinta no claro.
  static Color v(int alfa) => claro ? Color((((alfa * .75).round()) << 24) | 0x12131C) : Color((alfa << 24) | 0xFFFFFF);
  /// Sombra: preta no escuro, azulada e bem mais leve no claro.
  static Color sombra(int alfa) => claro ? Color((((alfa * .32).round()) << 24) | 0x1E223C) : Color(alfa << 24);

  static LinearGradient get gradCartao => claro
      ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFFFFF), Color(0xFFFDFDFF)])
      : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x12FFFFFF), Color(0x09FFFFFF)]);
  /// Cartões de destaque das telas (resumos). No claro ficam brancos com um toque lavanda.
  static LinearGradient get gradHero => claro
      ? const LinearGradient(begin: Alignment(-1, -1), end: Alignment(1, 1), colors: [Color(0xFFFFFFFF), Color(0xFFEEF0FB)])
      : GE.gradHero;
  static LinearGradient get gradLavanda => GE.gradLavanda;

  static const coresSerieEscuro = [Color(0xFFB9BFF6), Color(0xFF4FD98C), Color(0xFFFF8A7A), Color(0xFF6EC1FF), Color(0xFFF5C26B), Color(0xFFF28DC0), Color(0xFF5ED6C8), Color(0xFF9AA0BC)];
  static const coresSerieClaro = [Color(0xFF4F57D6), Color(0xFF12935A), Color(0xFFE8664F), Color(0xFF2C8FD9), Color(0xFFD69A2D), Color(0xFFD35A9E), Color(0xFF1FA595), Color(0xFF8A8FA8)];
  static List<Color> get coresSerie => claro ? coresSerieClaro : coresSerieEscuro;
}

/// Monta o tema do app para o modo pedido sem mudar o modo atual.
ThemeData temaDe(bool claro) {
  final antes = G.claro;
  G.claro = claro;
  try {
    return temaGrafite();
  } finally {
    G.claro = antes;
  }
}

ThemeData temaGrafite() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: G.claro ? Brightness.light : Brightness.dark,
    colorScheme: (G.claro ? ColorScheme.light : ColorScheme.dark)(
      primary: G.branco,
      onPrimary: G.tinta,
      secondary: G.lavanda,
      onSecondary: G.tinta,
      surface: G.fundo2,
      onSurface: G.texto,
      error: G.neg,
      onError: Colors.white,
    ).copyWith(brightness: G.claro ? Brightness.light : Brightness.dark),
    scaffoldBackgroundColor: G.fundo,
    fontFamily: null,
  );
  final t = base.textTheme.apply(bodyColor: G.texto, displayColor: G.texto);
  return base.copyWith(
    textTheme: t.copyWith(
      headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.3),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: G.texto,
    ),
    dividerTheme: DividerThemeData(color: G.borda, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: G.v(0x0D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: G.borda)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: G.borda)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: G.lavanda, width: 1.4)),
      labelStyle: TextStyle(color: G.apagado),
      hintStyle: TextStyle(color: G.claro ? const Color(0xFF9A9DB0) : const Color(0xFF6E728A)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: G.branco,
        foregroundColor: G.tinta,
        minimumSize: const Size(48, 50),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: G.texto,
        backgroundColor: G.v(0x0F),
        side: BorderSide(color: G.borda),
        minimumSize: const Size(40, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: G.lavanda, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: G.v(0x0D),
      selectedColor: G.branco,
      side: BorderSide(color: G.borda),
      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: G.texto2),
      secondaryLabelStyle: TextStyle(fontWeight: FontWeight.w700, color: G.tinta),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      showCheckmark: false,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: G.fundo2,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: G.v(0x33),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: G.fundo2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: G.branco,
      contentTextStyle: TextStyle(color: G.tinta, fontWeight: FontWeight.w700),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? G.tinta : G.apagado),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? G.lavanda : G.v(0x22)),
    ),
    datePickerTheme: DatePickerThemeData(backgroundColor: G.fundo2, surfaceTintColor: Colors.transparent),
  );
}
