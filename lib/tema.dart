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

/// Uma paleta do visual Nuvem (claro, cartões brancos sólidos, cartão
/// principal colorido e menu escuro).
class PaletaNuvem {
  final String id, nome;
  final Map<String, int> c;
  final List<Color> hero; // degradê do cartão principal
  final Color heroTexto2;
  final List<Color> series;
  const PaletaNuvem(this.id, this.nome, this.c, this.hero, this.heroTexto2, this.series);
}

const _baseNuvem = <String, int>{
  'fundo2': 0xFFFFFFFF, 'tinta': 0xFFFFFFFF, 'campo': 0xFFFFFFFF,
  'pos': 0xFF14935C, 'neg': 0xFFD6453D, 'negTexto': 0xFFC8392F, 'saida': 0xFFD6453D, 'alerta': 0xFFC27C14,
};

const paletasNuvem = <PaletaNuvem>[
  PaletaNuvem('oceano', 'Oceano', {
    ..._baseNuvem,
    'fundo': 0xFFEEF3F4, 'branco': 0xFF0E7C8F, 'texto': 0xFF13283A, 'texto2': 0xFF46596A, 'apagado': 0xFF80919C,
    'lavanda': 0xFF0E7C8F, 'lavandaIcone': 0xFF0E7C8F, 'lavandaFundo': 0xFFDCEEF0, 'borda': 0xFFDDE7EA,
    'navApagado': 0x99FFFFFF, 'navFundo': 0xFF0F2A36, 'dica': 0xF20F2A36, 'abasFundo': 0xFFE1EAEC, 'tintaBase': 0xFF13283A,
  }, [Color(0xFF117083), Color(0xFF0E5E70), Color(0xFF0A4757)], Color(0xFFD5ECF0),
      [Color(0xFF0E7C8F), Color(0xFFF0A23B), Color(0xFF2FA26F), Color(0xFFE5704F), Color(0xFF4A78D6), Color(0xFF27B3A3), Color(0xFFB3648F), Color(0xFF8A9AA8)]),
  PaletaNuvem('floresta', 'Floresta', {
    ..._baseNuvem,
    'fundo': 0xFFEFF1EC, 'branco': 0xFF2F7A52, 'texto': 0xFF1C2A21, 'texto2': 0xFF4A584E, 'apagado': 0xFF848F87,
    'lavanda': 0xFF2F7A52, 'lavandaIcone': 0xFF2F7A52, 'lavandaFundo': 0xFFDCEADF, 'borda': 0xFFDFE4DB,
    'navApagado': 0x99FFFFFF, 'navFundo': 0xFF1C2A21, 'dica': 0xF21C2A21, 'abasFundo': 0xFFE3E7DF, 'tintaBase': 0xFF1C2A21,
  }, [Color(0xFF367555), Color(0xFF2B6145), Color(0xFF1F4A34)], Color(0xFFDCEFE2),
      [Color(0xFF2F7A52), Color(0xFFDDA034), Color(0xFF4A93C4), Color(0xFFD86C4A), Color(0xFF8569C0), Color(0xFF58AE87), Color(0xFFBF6585), Color(0xFF8E978F)]),
  PaletaNuvem('marinho', 'Marinho', {
    ..._baseNuvem,
    'fundo': 0xFFEEF1F6, 'branco': 0xFF2F5BD3, 'texto': 0xFF141B2A, 'texto2': 0xFF465066, 'apagado': 0xFF838CA0,
    'lavanda': 0xFF2F5BD3, 'lavandaIcone': 0xFF2F5BD3, 'lavandaFundo': 0xFFDFE7FA, 'borda': 0xFFDDE2EC,
    'navApagado': 0x99FFFFFF, 'navFundo': 0xFF141B2A, 'dica': 0xF2141B2A, 'abasFundo': 0xFFE2E7F0, 'tintaBase': 0xFF141B2A,
  }, [Color(0xFF26458A), Color(0xFF1E3A6E), Color(0xFF152A52)], Color(0xFFDCE5FA),
      [Color(0xFF2F5BD3), Color(0xFFF0A23B), Color(0xFF1F9E68), Color(0xFFE2634A), Color(0xFF8B5CF6), Color(0xFF1EA3B6), Color(0xFFD1588C), Color(0xFF8C95A6)]),
];

PaletaNuvem? paletaNuvem(String id) {
  for (final p in paletasNuvem) {
    if (p.id == id) return p;
  }
  return null;
}

/// Aparência escolhida em Ajustes: 'auto' (segue o celular), 'claro', 'escuro', 'linho' (Linho & Safira) ou 'esmeralda' (Noite & Esmeralda).
final aparencia = ValueNotifier<String>('oceano');

Future<void> carregarAparencia() async {
  try {
    final sp = await SharedPreferences.getInstance();
    // o visual Nuvem (Oceano) passa a ser o padrão; quem já usava vê ele uma vez
    if (!(sp.getBool('nuvemApresentado') ?? false)) {
      await sp.setBool('nuvemApresentado', true);
      await sp.setString('aparencia', 'oceano');
    }
    aparencia.value = sp.getString('aparencia') ?? 'oceano';
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
  /// Tema "Lilás & Ametista" (claro, fundo lilás bem suave e cartão principal violeta). Só vale com [claro] = true.
  static bool ametista = false;
  static bool get _l => claro && linho;
  static bool get _n => !claro && noite;
  static bool get _a => claro && ametista;
  /// Paleta do visual Nuvem (null quando o tema escolhido é outro). Só vale com [claro] = true.
  static PaletaNuvem? nuvem;
  static PaletaNuvem? get _nv => claro ? nuvem : null;
  static Color? _p(String k) {
    final v = _nv?.c[k];
    return v == null ? null : Color(v);
  }

  static Color _c(int claroHex, Color escuro, [int? linhoHex, int? noiteHex, int? ameHex]) => claro
      ? Color(_a && ameHex != null ? ameHex : (_l && linhoHex != null ? linhoHex : claroHex))
      : (noite && noiteHex != null ? Color(noiteHex) : escuro);

  static Color get fundo => _p('fundo') ?? _c(0xFFF4F5F9, GE.fundo, 0xFFF3EFE7, 0xFF081114, 0xFFF6F3FC);
  static Color get fundo2 => _p('fundo2') ?? _c(0xFFFFFFFF, GE.fundo2, 0xFFFFFFFF, 0xFF0F1C20, 0xFFFFFFFF);
  /// Cor "invertida" de destaque (fundo de chip/botão selecionado).
  static Color get branco => _p('branco') ?? _c(0xFF12131C, GE.branco, 0xFF2448C8, 0xFF34D8AC, 0xFF6B3FD4);
  /// Texto sobre [branco].
  static Color get tinta => _p('tinta') ?? _c(0xFFFFFFFF, GE.tinta, 0xFFFFFFFF, 0xFF04231B, 0xFFFFFFFF);
  static Color get texto => _p('texto') ?? _c(0xFF12131C, GE.texto, 0xFF161C2D, 0xFFEAF6F2, 0xFF1E1633);
  static Color get texto2 => _p('texto2') ?? _c(0xFF4A4E63, GE.texto2, 0xFF454C5E, 0xFFB7CDC6, 0xFF4D4466);
  static Color get apagado => _p('apagado') ?? _c(0xFF7A7E93, GE.apagado, 0xFF6B7183, 0xFF7E9A92, 0xFF7C7394);
  static Color get lavanda => _p('lavanda') ?? _c(0xFF4F57D6, GE.lavanda, 0xFF2448C8, 0xFF4FE3C1, 0xFF6B3FD4);
  static Color get pos => _p('pos') ?? _c(0xFF12935A, GE.pos, 0xFF11764A, 0xFF7BE8A4, 0xFF12885A);
  static Color get neg => _p('neg') ?? _c(0xFFE0445E, GE.neg, 0xFFC23B2A);
  static Color get alerta => _p('alerta') ?? _c(0xFFB7791F, GE.alerta, 0xFFB07A1F, 0xFFF6C667, 0xFFB7791F);
  static Color get borda => _p('borda') ?? _c(0x1C12131C, GE.borda, 0xFFE6E0D5, 0x1FA7F3D0, 0xFFE7E0F3);
  static Color get vidro => v(0x10);
  static Color get vidro2 => v(0x18);
  static Color get posEscuro => GE.posEscuro;
  static Color get negEscuro => GE.negEscuro;
  /// Vermelho para texto (mais suave no escuro).
  static Color get negTexto => _p('negTexto') ?? _c(0xFFD63A55, const Color(0xFFFF8DA0), 0xFFC23B2A);
  static Color get lavandaIcone => _p('lavandaIcone') ?? _c(0xFF4F57D6, const Color(0xFFC9CDFB), 0xFF2448C8, 0xFF8AF0DA, 0xFF6B3FD4);
  static Color get lavandaFundo => _p('lavandaFundo') ?? _c(0x1A4F57D6, const Color(0x29B9BFF6), 0xFFE8EDFB, 0x2634D8AC, 0xFFEEE7FB);
  static Color get saida => _p('saida') ?? _c(0xFFE0445E, const Color(0xFFFF7A8C), 0xFFC23B2A);
  static Color get navApagado => _p('navApagado') ?? _c(0xFF9A9DB0, const Color(0xFF80849B), 0xFF6B7183, 0xFF6F8B84, 0xFF8A82A0);
  static Color get navFundo => _p('navFundo') ?? _c(0xF5FFFFFF, const Color(0xEB1E1F2C), 0xF0FFFFFF, 0xEB10201F, 0xF0FFFFFF);
  static Color get dica => _p('dica') ?? _c(0xF212131C, const Color(0xF2232434), 0xF2161C2D, 0xF2142A2B, 0xF21E1633);
  /// Fundo das abas (Lançamentos | Análise etc.) e dos campos.
  static Color get abasFundo => _p('abasFundo') ?? _c(0x0F12131C, const Color(0x10FFFFFF), 0xFFEFEAE0, 0x14A7F3D0, 0xFFEDE7F7);
  static Color get campo => _p('campo') ?? _c(0x0912131C, const Color(0x0DFFFFFF), 0xFFFFFFFF, 0x0FA7F3D0, 0xFFFFFFFF);

  /// Película translúcida: branca no escuro, tinta no claro.
  static Color v(int alfa) => claro ? Color((((alfa * .75).round()) << 24) | ((_nv?.c['tintaBase'] ?? (_a ? 0xFF1E1633 : (_l ? 0xFF161C2D : 0xFF12131C))) & 0xFFFFFF)) : Color((alfa << 24) | 0xFFFFFF);
  /// Sombra: preta no escuro, azulada e bem mais leve no claro.
  static Color sombra(int alfa) => _nv != null ? Color((((alfa * .22).round()) << 24) | ((_nv!.c['tintaBase']!) & 0xFFFFFF)) : claro ? Color((((alfa * (_l ? .26 : .32)).round()) << 24) | (_l ? 0x161C2D : 0x1E223C)) : Color(alfa << 24);

  static LinearGradient get gradCartao => claro
      ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFFFFF), Color(0xFFFDFDFF)])
      : (noite
          ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x17A7F3D0), Color(0x0AA7F3D0)])
          : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x12FFFFFF), Color(0x09FFFFFF)]));
  /// Cartões de destaque das telas (resumos). No claro ficam brancos com um toque de cor.
  static LinearGradient get gradHero => claro
      ? (_nv != null
          ? const LinearGradient(begin: Alignment(-1, -1), end: Alignment(1, 1), colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)])
          : _a
          ? const LinearGradient(begin: Alignment(-1, -1), end: Alignment(1, 1), colors: [Color(0xFFFFFFFF), Color(0xFFF5EFFD)])
          : _l
          ? const LinearGradient(begin: Alignment(-1, -1), end: Alignment(1, 1), colors: [Color(0xFFFFFFFF), Color(0xFFF8F5EF)])
          : const LinearGradient(begin: Alignment(-1, -1), end: Alignment(1, 1), colors: [Color(0xFFFFFFFF), Color(0xFFEEF0FB)]))
      : (noite ? const LinearGradient(begin: Alignment(-1, -1), end: Alignment(1, 1), colors: [Color(0xFF14403A), Color(0xFF0F2B2B), Color(0xFF0B1D20)], stops: [0, .52, 1]) : GE.gradHero);
  static LinearGradient get gradLavanda => GE.gradLavanda;

  static const coresSerieEscuro = [Color(0xFFB9BFF6), Color(0xFF4FD98C), Color(0xFFFF8A7A), Color(0xFF6EC1FF), Color(0xFFF5C26B), Color(0xFFF28DC0), Color(0xFF5ED6C8), Color(0xFF9AA0BC)];
  static const coresSerieClaro = [Color(0xFF4F57D6), Color(0xFF12935A), Color(0xFFE8664F), Color(0xFF2C8FD9), Color(0xFFD69A2D), Color(0xFFD35A9E), Color(0xFF1FA595), Color(0xFF8A8FA8)];
  /// Cores dos gráficos do tema Linho & Safira (as mesmas do site).
  static const coresSerieLinho = [Color(0xFF2448C8), Color(0xFFD98A1E), Color(0xFF11885A), Color(0xFFC8553D), Color(0xFF7C4DCC), Color(0xFF1A8FA8), Color(0xFFD14D86), Color(0xFF7A7F8C)];
  /// Cor única para "quanto você aplicou"/linhas de referência em todos os gráficos.
  static Color get neutroSerie => _nv != null ? Color(_nv!.series.last.toARGB32()) : claro ? const Color(0xFF9AA0BC) : const Color(0xFF7D839F);
  static const coresSerieNoite = [Color(0xFF4FE3C1), Color(0xFFF6C667), Color(0xFF6EA8FF), Color(0xFFFF8A7A), Color(0xFFB79CFF), Color(0xFF8EE36B), Color(0xFFF28DC0), Color(0xFF8AA39C)];
  static const coresSerieAmetista = [Color(0xFF6B3FD4), Color(0xFFE0832B), Color(0xFF12885A), Color(0xFFD43C7E), Color(0xFF2C8FD9), Color(0xFF1A9FA0), Color(0xFFC8553D), Color(0xFF857D99)];
  static List<Color> get coresSerie => _nv != null ? _nv!.series : claro ? (_a ? coresSerieAmetista : (_l ? coresSerieLinho : coresSerieClaro)) : (_n ? coresSerieNoite : coresSerieEscuro);
}

/// Cores do cartão principal (Início e Patrimônio): grafite no Escuro e no
/// Pérola; azul safira em degradê no Linho & Safira, como no site.
class GH {
  static bool get safira => G.claro && G.linho;
  static bool get esmeralda => !G.claro && G.noite;
  /// Cartão principal colorido (texto branco e blocos de vidro).
  static bool get ametista => G.claro && G.ametista;
  static PaletaNuvem? get nuvem => G.claro ? G.nuvem : null;
  static bool get colorido => safira || esmeralda || ametista || nuvem != null;
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
  static const gradAmetista = LinearGradient(
    begin: Alignment(-1, -1),
    end: Alignment(1, 1),
    colors: [Color(0xFF4B25B8), Color(0xFF7A3FDB), Color(0xFFB04FD6)],
    stops: [0, .52, 1],
  );
  static LinearGradient get gradHero => nuvem != null
      ? LinearGradient(begin: const Alignment(-1, -1), end: const Alignment(1, 1), colors: nuvem!.hero, stops: const [0, .5, 1])
      : safira ? gradSafira : (esmeralda ? gradEsmeralda : (ametista ? gradAmetista : GE.gradHero));
  static Color get texto => colorido ? const Color(0xFFFFFFFF) : GE.texto;
  static Color get texto2 => nuvem != null ? nuvem!.heroTexto2 : safira ? const Color(0xFFE4EBFF) : (esmeralda ? const Color(0xFFDDF7EE) : (ametista ? const Color(0xFFEDE4FF) : GE.texto2));
  static Color get apagado => nuvem != null ? nuvem!.heroTexto2.withValues(alpha: .78) : safira ? const Color(0xC7E4EBFF) : (esmeralda ? const Color(0xC7DDF7EE) : (ametista ? const Color(0xC7EDE4FF) : GE.apagado));
  static Color get alerta => colorido ? const Color(0xFFFFD58A) : GE.alerta;
  static Color get lavanda => nuvem != null ? nuvem!.hero[1] : safira ? const Color(0xFF2448C8) : (esmeralda ? const Color(0xFF0B6B58) : (ametista ? const Color(0xFF5B2FC9) : GE.lavanda));
  static Color get chipInvest => colorido ? const Color(0xFFFFFFFF) : const Color(0x33B9BFF6);
  static Color get sombra => nuvem != null ? nuvem!.hero[1].withValues(alpha: .45) : safira ? const Color(0x8C1F3FB5) : (esmeralda ? const Color(0x800C8068) : (ametista ? const Color(0x8C5B2FC9) : G.sombra(0xCC)));
  /// Blocos Entrou/Saiu: vidro branco translúcido nos cartões coloridos.
  static bool get vidro => colorido;
  static const vidroFundo = Color(0x21FFFFFF);
  static const vidroBorda = Color(0x38FFFFFF);
  static Color get posIcone => nuvem != null ? const Color(0xFF14935C) : safira ? const Color(0xFF11764A) : (esmeralda ? const Color(0xFF0B6B58) : (ametista ? const Color(0xFF11764A) : GE.posEscuro));
  static Color get negIcone => nuvem != null ? const Color(0xFFD6453D) : safira ? const Color(0xFFC23B2A) : (esmeralda ? const Color(0xFFC8243F) : (ametista ? const Color(0xFFC23B2A) : GE.negEscuro));
}

/// Monta o tema do app para o modo pedido sem mudar o modo atual.
ThemeData temaDe(bool claro, {bool linho = false, bool noite = false, bool ametista = false, PaletaNuvem? nuvem}) {
  final antes = G.claro, antesL = G.linho, antesN = G.noite, antesA = G.ametista, antesNv = G.nuvem;
  G.nuvem = nuvem;
  G.claro = claro;
  G.linho = linho;
  G.noite = noite;
  G.ametista = ametista;
  try {
    return temaGrafite();
  } finally {
    G.claro = antes;
    G.linho = antesL;
    G.noite = antesN;
    G.ametista = antesA;
    G.nuvem = antesNv;
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
    fontFamily: G.claro && G.nuvem != null ? 'Jakarta' : null,
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
        backgroundColor: G.claro && (G.linho || G.ametista || G.nuvem != null) ? Colors.white : G.v(0x0F),
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
