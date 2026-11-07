import 'package:flutter/material.dart';

/// Paleta "Grafite": a mesma do visual novo do site.
class G {
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
  static const vidro = Color(0x10FFFFFF);
  static const vidro2 = Color(0x18FFFFFF);
  static const posEscuro = Color(0xFF15924F);
  static const negEscuro = Color(0xFFC8243F);

  static const gradCartao = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x12FFFFFF), Color(0x09FFFFFF)],
  );
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

ThemeData temaGrafite() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: G.branco,
      onPrimary: G.tinta,
      secondary: G.lavanda,
      onSecondary: G.tinta,
      surface: G.fundo2,
      onSurface: G.texto,
      error: G.neg,
      onError: Colors.white,
    ),
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
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: G.texto,
    ),
    dividerTheme: const DividerThemeData(color: G.borda, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x0DFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: G.borda)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: G.borda)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: G.lavanda, width: 1.4)),
      labelStyle: const TextStyle(color: G.apagado),
      hintStyle: const TextStyle(color: Color(0xFF6E728A)),
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
        backgroundColor: const Color(0x0FFFFFFF),
        side: const BorderSide(color: G.borda),
        minimumSize: const Size(40, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: G.lavanda, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0x0DFFFFFF),
      selectedColor: G.branco,
      side: const BorderSide(color: G.borda),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: G.texto2),
      secondaryLabelStyle: const TextStyle(fontWeight: FontWeight.w700, color: G.tinta),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      showCheckmark: false,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: G.fundo2,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0x33FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: G.fundo2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: G.branco,
      contentTextStyle: const TextStyle(color: G.tinta, fontWeight: FontWeight.w700),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? G.tinta : G.apagado),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? G.lavanda : const Color(0x22FFFFFF)),
    ),
    datePickerTheme: const DatePickerThemeData(backgroundColor: G.fundo2, surfaceTintColor: Colors.transparent),
  );
}
