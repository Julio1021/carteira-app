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

/// Aparência escolhida em Ajustes: 'auto' (segue o celular), 'claro', 'escuro', 'linho' (Linho & Safira) ou 'esmeralda' (Noite & Esmeralda).
final aparencia = ValueNotifier<String>('auto');

Future<void> carregarAparencia() async {
  try {
    final sp = await SharedPreferences.getInstance();
    aparencia.value = sp.getString('aparencia') ?? 'auto';
  } catch (_) {}
}

/// Modo privacidade (esconde os valores). O número em si fica em util/fmt.dart.
final privacidade = ValueNotifier<bool>(false);

Future<void> carregarPrivacidade() async {
  try {
    final sp = await SharedPreferences.getInstance();
    privacidade.value = sp.getBool('privacidade') ?? false;
  } catch (_) {}
}

Future<void> definirPrivacidade(bool v) async {
  privacidade.value = v;
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('privacidade', v);
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
  /// Tema "Linho & Safira" (claro, igual ao do site). Só vale com [claro] = true.
  static bool linho = false;
  /// Tema "Noite & Esmeralda" (escuro, verde-petróleo com detalhes em esmeralda). Só vale com [claro] = false.
  static bool noite = false;
  static bool get _l => claro && linho;
  static bool get _n => !claro && noite;
  static Color _c(int claroHex, Color escuro, [int? linhoHex, int? noiteHex]) =>
      claro ? Color(_l && linhoHex != null ? linhoHex : claroHex) : (noite && noiteHex != null ? Color(noiteHex) : escuro);

  static Color get fundo => _c(0xFFF4F5F9, GE.fundo, 0xFFF3EFE7, 0xFF081114);
  static Color get fundo2 => _c(0xFFFFFFFF, GE.fundo2, 0xFFFFFFFF, 0xFF0F1C20);
  /// Cor "invertida" de destaque (fundo de chip/botão selecionado).
  static Color get branco => _c(0xFF12131C, GE.branco, 0xFF2448C8, 0xFF34D8AC);
  /// Texto sobre [branco].
  static Color get tinta => _c(0xFFFFFFFF, GE.tinta, 0xFFFFFFFF, 0xFF04231B);
  static Color get texto => _c(0xFF12131C, GE.texto, 0xFF161C2D, 0xFFEAF6F2);
  static Color get texto2 => _c(0xFF4A4E63, GE.texto2, 0xFF454C5E, 0xFFB7CDC6);
  static Color get apagado => _c(0xFF7A7E93, GE.apagado, 0xFF6B7183, 0xFF7E9A92);
  static Color get lavanda => _c(0xFF4F57D6, GE.lavanda, 0xFF2448C8, 0xFF4FE3C1);
  static Color get pos => _c(0xFF12935A, GE.pos, 0xFF11764A, 0xFF7BE8A4);
  static Color get neg => _c(0xFFE0445E, GE.neg, 0xFFC23B2A);
  static Color get alerta => _c(0xFFB7791F, GE.alerta, 0xFFB07A1F, 0xFFF6C667);
  static Color get borda => _c(0x1C12131C, GE.borda, 0xFFE6E0D5, 0x1FA7F3D0);
  static Color get vidro => v(0x10);
  static Color get vidro2 => v(0x18);
  static Color get posEscuro => GE.posEscuro;
  static Color get negEscuro => GE.negEscuro;
  /// Vermelho para texto (mais suave no escuro).
  static Color get negTexto => _c(0xFFD63A55, const Color(0xFFFF8DA0), 0xFFC23B2A);
  static Color get lavandaIcone => _c(0xFF4F57D6, const Color(0xFFC9CDFB), 0xFF2448C8, 0xFF8AF0DA);
  static Color get lavandaFundo => _c(0x1A4F57D6, const Color(0x29B9BFF6), 0xFFE8EDFB, 0x2634D8AC);
  static Color get saida => _c(0xFFE0445E, const Color(0xFFFF7A8C), 0xFFC23B2A);
  static Color get navApagado => _c(0xFF9A9DB0, const Color(0xFF80849B), 0xFF6B7183, 0xFF6F8B84);
  static Color get navFundo => _c(0xF5FFFFFF, const Color(0xEB1E1F2C), 0xF0FFFFFF, 0xEB10201F);
  static Color get dica => _c(0xF212131C, const Color(0xF2232434), 0xF2161C2D, 0xF2142A2B);
  /// Fundo das abas (Lançamentos | Análise etc.) e dos campos.
  static Color get abasFundo => _c(0x0F12131C, const Color(0x10FFFFFF), 0xFFEFEAE0, 0x14A7F3D0);
  static Color get campo => _c(0x0912131C, const Color(0x0DFFFFFF), 0xFFFFFFFF, 0x0FA7F3D0);

  /// Película translúcida: branca no escuro, tinta no claro.
  static Color v(int alfa) => claro ? Color((((alfa * .75).round()) << 24) | (_l ? 0x161C2D : 0x12131C)) : Color((alfa << 24) | 0xFFFFFF);
  /// Sombra: preta no escuro, azulada e bem mais leve no claro.
  static Color sombra(int alfa) => claro ? Color((((alfa * (_l ? .26 : .32)).round()) << 24) | (_l ? 0x161C2D : 0x1E223C)) : Color(alfa << 24);

  static LinearGradient get gradCartao => claro
      ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFFFFF), Color(0xFFFDFDFF)])
      : (noite
          ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x17A7F3D0), Color(0x0AA7F3D0)])
          : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x12FFFFFF), Color(0x09FFFFFF)]));
  /// Cartões de destaque das telas (resumos). No claro ficam brancos com um toque de cor.
  static LinearGradient get gradHero => claro
      ? (_l
          ? const LinearGradient(begin: Alignment(-1, -1), end: Alignment(1, 1), colors: [Color(0xFFFFFFFF), Color(0xFFF8F5EF)])
          : const LinearGradient(begin: Alignment(-1, -1), end: Alignment(1, 1), colors: [Color(0xFFFFFFFF), Color(0xFFEEF0FB)]))
      : (noite ? const LinearGradient(begin: Alignment(-1, -1), end: Alignment(1, 1), colors: [Color(0xFF14403A), Color(0xFF0F2B2B), Color(0xFF0B1D20)], stops: [0, .52, 1]) : GE.gradHero);
  static LinearGradient get gradLavanda => GE.gradLavanda;

  static const coresSerieEscuro = [Color(0xFFB9BFF6), Color(0xFF4FD98C), Color(0xFFFF8A7A), Color(0xFF6EC1FF), Color(0xFFF5C26B), Color(0xFFF28DC0), Color(0xFF5ED6C8), Color(0xFF9AA0BC)];
  static const coresSerieClaro = [Color(0xFF4F57D6), Color(0xFF12935A), Color(0xFFE8664F), Color(0xFF2C8FD9), Color(0xFFD69A2D), Color(0xFFD35A9E), Color(0xFF1FA595), Color(0xFF8A8FA8)];
  /// Cores dos gráficos do tema Linho & Safira (as mesmas do site).
  static const coresSerieLinho = [Color(0xFF2448C8), Color(0xFFD98A1E), Color(0xFF11885A), Color(0xFFC8553D), Color(0xFF7C4DCC), Color(0xFF1A8FA8), Color(0xFFD14D86), Color(0xFF7A7F8C)];
  /// Cor única para "quanto você aplicou"/linhas de referência em todos os gráficos.
  static Color get neutroSerie => claro ? const Color(0xFF9AA0BC) : const Color(0xFF7D839F);
  static const coresSerieNoite = [Color(0xFF4FE3C1), Color(0xFFF6C667), Color(0xFF6EA8FF), Color(0xFFFF8A7A), Color(0xFFB79CFF), Color(0xFF8EE36B), Color(0xFFF28DC0), Color(0xFF8AA39C)];
  static List<Color> get coresSerie => claro ? (_l ? coresSerieLinho : coresSerieClaro) : (_n ? coresSerieNoite : coresSerieEscuro);
}

/// Cores do cartão principal (Início e Patrimônio): grafite no Escuro e no
/// Pérola; azul safira em degradê no Linho & Safira, como no site.
class GH {
  static bool get safira => G.claro && G.linho;
  static bool get esmeralda => !G.claro && G.noite;
  /// Cartão principal colorido (texto branco e blocos de vidro).
  static bool get colorido => safira || esmeralda;
  static const gradSafira = LinearGradient(
    begin: Alignment(-1, -1),
    end: Alignment(1, 1),
    colors: [Color(0xFF1F3FB5), Color(0xFF2A52D6), Color(0xFF3B6BE8)],
    stops: [0, .55, 1],
  );
  static const gradEsmeralda = LinearGradient(
    begin: Alignment(-1, -1),
    end: Alignment(1, 1),
    colors: [Color(0xFF075E4F), Color(0xFF0C8068), Color(0xFF17AE8A)],
    stops: [0, .5, 1],
  );
  static LinearGradient get gradHero => safira ? gradSafira : (esmeralda ? gradEsmeralda : GE.gradHero);
  static Color get texto => colorido ? const Color(0xFFFFFFFF) : GE.texto;
  static Color get texto2 => safira ? const Color(0xFFE4EBFF) : (esmeralda ? const Color(0xFFDDF7EE) : GE.texto2);
  static Color get apagado => safira ? const Color(0xC7E4EBFF) : (esmeralda ? const Color(0xC7DDF7EE) : GE.apagado);
  static Color get alerta => colorido ? const Color(0xFFFFD58A) : GE.alerta;
  static Color get lavanda => safira ? const Color(0xFF2448C8) : (esmeralda ? const Color(0xFF0B6B58) : GE.lavanda);
  static Color get chipInvest => colorido ? const Color(0xFFFFFFFF) : const Color(0x33B9BFF6);
  static Color get sombra => safira ? const Color(0x8C1F3FB5) : (esmeralda ? const Color(0x800C8068) : G.sombra(0xCC));
  /// Blocos Entrou/Saiu: vidro branco translúcido nos cartões coloridos.
  static bool get vidro => colorido;
  static const vidroFundo = Color(0x21FFFFFF);
  static const vidroBorda = Color(0x38FFFFFF);
  static Color get posIcone => safira ? const Color(0xFF11764A) : (esmeralda ? const Color(0xFF0B6B58) : GE.posEscuro);
  static Color get negIcone => safira ? const Color(0xFFC23B2A) : (esmeralda ? const Color(0xFFC8243F) : GE.negEscuro);
}

/// Monta o tema do app para o modo pedido sem mudar o modo atual.
ThemeData temaDe(bool claro, {bool linho = false, bool noite = false}) {
  final antes = G.claro, antesL = G.linho, antesN = G.noite;
  G.claro = claro;
  G.linho = linho;
  G.noite = noite;
  try {
    return temaGrafite();
  } finally {
    G.claro = antes;
    G.linho = antesL;
    G.noite = antesN;
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
  final t0 = base.textTheme.apply(bodyColor: G.texto, displayColor: G.texto);
  // números com a mesma largura (colunas de valores alinhadas, como num extrato)
  const tab = [FontFeature.tabularFigures()];
  TextStyle? f(TextStyle? e) => e?.copyWith(fontFeatures: tab);
  final t = TextTheme(
    displayLarge: f(t0.displayLarge), displayMedium: f(t0.displayMedium), displaySmall: f(t0.displaySmall),
    headlineLarge: f(t0.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1)),
    headlineMedium: f(t0.headlineMedium), headlineSmall: f(t0.headlineSmall),
    titleLarge: f(t0.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.3)),
    titleMedium: f(t0.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    titleSmall: f(t0.titleSmall),
    bodyLarge: f(t0.bodyLarge), bodyMedium: f(t0.bodyMedium), bodySmall: f(t0.bodySmall),
    labelLarge: f(t0.labelLarge), labelMedium: f(t0.labelMedium), labelSmall: f(t0.labelSmall),
  );
  return base.copyWith(
    textTheme: t,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: G.texto,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.2, color: G.texto, fontFeatures: const [FontFeature.tabularFigures()]),
    ),
    dividerTheme: DividerThemeData(color: G.borda, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: G.campo,
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
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: G.texto,
        backgroundColor: G.claro && G.linho ? Colors.white : G.v(0x0F),
        side: BorderSide(color: G.borda),
        minimumSize: const Size(40, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: G.lavanda, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: G.v(0x0D),
      selectedColor: G.branco,
      side: BorderSide(color: G.borda),
      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: G.texto2),
      secondaryLabelStyle: TextStyle(fontWeight: FontWeight.w600, color: G.tinta),
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
      contentTextStyle: TextStyle(color: G.tinta, fontWeight: FontWeight.w600),
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
