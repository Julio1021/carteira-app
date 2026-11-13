import 'dart:async';

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'dados/demo.dart';
import 'dados/repo.dart';
import 'dados/analise.dart';
import 'widgets/graficos.dart';
import 'dados/drive.dart';
import 'dados/indices.dart';
import 'tema.dart';
import 'widgets/movimento.dart';
import 'telas/abertura.dart';
import 'telas/ajustes.dart';
import 'telas/extrato.dart';
import 'telas/inicio.dart';
import 'telas/lancar.dart';
import 'telas/limites.dart';
import 'telas/cartoes.dart';
import 'telas/emprestimos.dart';
import 'telas/planejar.dart';
import 'dados/patrimonio.dart';
import 'telas/patrimonio.dart';
import 'telas/avisos.dart';
import 'telas/busca.dart';
import 'telas/importar.dart';
import 'util/fmt.dart';
import 'widgets/comum.dart';
import 'widgets/largo.dart';
import 'widgets/formulario.dart';
import 'telas/descobertas.dart';
import 'telas/objetivos.dart';
import 'telas/retro.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final demo = kIsWeb && Uri.base.queryParameters['demo'] == '1';
  if (demo) {
    aparencia.value = Uri.base.queryParameters['tema'] ?? 'escuro';
    if (Uri.base.queryParameters['oculto'] == '1') {
      privacidade.value = true;
      valoresOcultos = true;
    }
    indicesAtuais.value = indicesExemplo(ymDe(hojeIso()));
  } else {
    await carregarAparencia();
    await carregarAbertura();
    await carregarPrivacidade();
    valoresOcultos = privacidade.value;
  }
  final repo = demo ? Repo.memoria(dadosDemo()) : Repo();
  if (!demo) {
    await repo.carregar();
    syncDrive = SyncDrive(repo);
    unawaited(syncDrive!.iniciar());
  }
  runApp(AppCarteira(repo: repo));
}

/// Liga/desliga o tema claro a partir da escolha em Ajustes e do tema do celular.
bool resolverClaro(String modo, Brightness celular) => modo == 'claro' || modo == 'linho' || (modo == 'auto' && celular == Brightness.light);

void _barrasDoSistema() {
  final icones = G.claro ? Brightness.dark : Brightness.light;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icones,
    statusBarBrightness: G.claro ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: G.fundo,
    systemNavigationBarIconBrightness: icones,
  ));
}

class AppCarteira extends StatefulWidget {
  final Repo repo;
  const AppCarteira({super.key, required this.repo});
  @override
  State<AppCarteira> createState() => _AppCarteiraState();
}

class _AppCarteiraState extends State<AppCarteira> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    aparencia.addListener(_aplicar);
    privacidade.addListener(_privacidade);
    G.claro = resolverClaro(aparencia.value, WidgetsBinding.instance.platformDispatcher.platformBrightness);
    G.linho = aparencia.value == 'linho';
    G.noite = aparencia.value == 'esmeralda';
    _barrasDoSistema();
  }

  @override
  void dispose() {
    aparencia.removeListener(_aplicar);
    privacidade.removeListener(_privacidade);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _aplicar();

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) unawaited(syncDrive?.sincronizar());
  }

  void _aplicar() {
    final claro = resolverClaro(aparencia.value, WidgetsBinding.instance.platformDispatcher.platformBrightness);
    final linho = aparencia.value == 'linho', noite = aparencia.value == 'esmeralda';
    if ((claro == G.claro && linho == G.linho && noite == G.noite) || !mounted) return;
    G.claro = claro;
    G.linho = linho;
    G.noite = noite;
    _barrasDoSistema();
    _refazerTudo();
  }

  /// Modo privacidade: os valores vêm de brl() (estático), então redesenha tudo.
  void _privacidade() {
    valoresOcultos = privacidade.value;
    if (mounted) _refazerTudo();
  }

  void _refazerTudo() {
    setState(() {});
    // As cores e os valores vêm de estáticos: pede para todas as telas abertas se redesenharem.
    void refazer(Element e) {
      e.markNeedsBuild();
      e.visitChildren(refazer);
    }
    (context as Element).visitChildren(refazer);
  }

  @override
  Widget build(BuildContext context) {
    return RepoScope(
      repo: widget.repo,
      child: MaterialApp(
        title: 'Diário da Carteira',
        debugShowCheckedModeBanner: false,
        theme: temaGrafite().copyWith(pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: _TransicaoEstreita(),
          TargetPlatform.linux: _TransicaoEstreita(),
          TargetPlatform.windows: _TransicaoEstreita(),
          TargetPlatform.macOS: _TransicaoEstreita(),
          TargetPlatform.iOS: _TransicaoEstreita(),
          TargetPlatform.fuchsia: _TransicaoEstreita(),
        })),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routes: {
          '/': (_) => const Casca(),
          '/ajustes': (_) => const TelaAjustes(),
        },
      ),
    );
  }
}

/// Estrutura do app: cabeçalho, abas e menu de baixo com o botão + no centro.
class Casca extends StatefulWidget {
  const Casca({super.key});
  @override
  State<Casca> createState() => _CascaState();
}

class _CascaState extends State<Casca> {
  int aba = 0;
  String ym = ymDe(hojeIso());
  String filtroExtrato = 'tudo';
  String? catExtrato;
  int subPat = 0;
  bool analiseDemo = false;
  bool abrindo = false;
  double? congelarAbertura;
  bool _decidiuAbertura = false;

  static const _titulos = ['Início', 'Extrato', 'Planejar', 'Patrimônio'];

  @override
  void initState() {
    super.initState();
    // Só para gerar prints na versão web de demonstração: ?demo=1&aba=1&tela=lancar
    if (kIsWeb && Uri.base.queryParameters['demo'] == '1') {
      final q = Uri.base.queryParameters;
      aba = (int.tryParse(q['aba'] ?? '') ?? 0).clamp(0, 3).toInt();
      subPat = (int.tryParse(q['sub'] ?? '') ?? 0).clamp(0, 4).toInt();
      analiseDemo = q['analise'] == '1';
      final ab = double.tryParse(q['abertura'] ?? '');
      if (ab != null) {
        abrindo = true;
        congelarAbertura = ab >= 1 ? null : ab;
      }
      _decidiuAbertura = true;
      final tela = q['tela'];
      if (tela != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (tela == 'lancar') abrirFormLanc(context);
          if (tela == 'entrada') abrirFormLanc(context, entrada: true);
          if (tela == 'menu') abrirMenuLancar(context);
          if (tela == 'invest') abrirFormLanc(context, investido: true);
          if (tela == 'grafico') {
            final h = historicoMeses(RepoScope.ler(context), ym, 12);
            abrirGraficoCheio(
              context,
              'Entrou × Saiu × Investiu',
              (alt) => GraficoBarras(
                rotulos: [for (final m in h) mesLongo(m.ym).substring(0, 3).toLowerCase()],
                valores: [for (final m in h) [m.entrou, m.saiu, m.investiu > 0 ? m.investiu : 0.0]],
                cores: [G.pos, G.saida, G.lavanda],
                nomes: const ['Entrou', 'Saiu', 'Investiu'],
                formatoY: curto,
                altura: alt,
              ),
            );
          }
          if (tela == 'ativo') {
            final c = calcularCarteira(RepoScope.ler(context));
            if (c.posicoes.isNotEmpty) Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaAtivo(id: c.posicoes.first.a.id)));
          }
          if (tela == 'retro') abrirRetro(context, mesDaRetro(RepoScope.ler(context), ym), inicial: int.tryParse(q['slide'] ?? '') ?? 0, parado: true);
          if (tela == 'rapido') abrirMenuLancar(context, rapidoInicial: 'superm 86,40 débito');
          if (tela == 'objetivo') abrirFolha(context, const FormObjetivo());
          if (tela == 'limites') _abrirLimites();
          if (tela == 'ajustes') Navigator.of(context).pushNamed('/ajustes');
          if (tela == 'busca') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaBusca(inicial: 'mercado')));
          if (tela == 'importar') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaImportarExtrato()));
          if (tela == 'avisos') abrirAvisos(context, (c) => _irAba(1, filtro: 'saidas', cat: c));
          if (tela == 'cartoes') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaCartoes()));
          if (tela == 'cartao') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaCartao(id: 'cc_demo')));
          if (tela == 'emprestimos') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaEmprestimos()));
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decidiuAbertura) return;
    _decidiuAbertura = true;
    abrindo = aberturaLigada.value && !MediaQuery.of(context).disableAnimations;
  }

  void _irAba(int i, {String filtro = 'tudo', String? cat}) {
    HapticFeedback.selectionClick();
    setState(() {
      aba = i;
      filtroExtrato = filtro;
      catExtrato = cat;
    });
  }

  /// Atalhos do teclado (computador). Não atrapalham quem está digitando num campo.
  KeyEventResult _tecla(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = HardwareKeyboard.instance;
    if (k.isControlPressed && e.logicalKey == LogicalKeyboardKey.keyK) {
      _buscar();
      return KeyEventResult.handled;
    }
    if (k.isControlPressed || k.isAltPressed || k.isMetaPressed) return KeyEventResult.ignored;
    final c = FocusManager.instance.primaryFocus?.context;
    if (c != null && c.findAncestorWidgetOfExactType<EditableText>() != null) return KeyEventResult.ignored;
    final acao = switch (e.logicalKey) {
      LogicalKeyboardKey.keyN => () => abrirMenuLancar(context),
      LogicalKeyboardKey.slash => _buscar,
      LogicalKeyboardKey.digit1 => () => _irAba(0),
      LogicalKeyboardKey.digit2 => () => _irAba(1),
      LogicalKeyboardKey.digit3 => () => _irAba(2),
      LogicalKeyboardKey.digit4 => () => _irAba(3),
      _ => null,
    };
    if (acao == null) return KeyEventResult.ignored;
    acao();
    return KeyEventResult.handled;
  }

  void _buscar() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaBusca()));

  void _abrirLimites() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaLimites(ym: ym)));

  @override
  Widget build(BuildContext context) {
    final telas = <Widget>[
      TelaInicio(
        ym: ym,
        onMes: (m) => setState(() => ym = m),
        irExtrato: () => _irAba(1),
        irLimites: _abrirLimites,
        irExtratoFiltro: (f) => _irAba(1, filtro: f),
        irPlanejar: () => _irAba(2),
      ),
      TelaExtrato(ym: ym, onMes: (m) => setState(() => ym = m), filtroInicial: filtroExtrato, catInicial: catExtrato, analiseInicial: analiseDemo),
      TelaPlanejar(irLimites: _abrirLimites),
      TelaPatrimonio(key: ValueKey('pat$subPat'), subInicial: subPat),
    ];
    final largo = telaLarga(context);
    final telasVisiveis = largo
        ? [telas[0], Centralizar(max: 1180, child: telas[1]), Centralizar(child: telas[2]), telas[3]]
        : telas;
    final corpo = Column(children: [
      _Cabecalho(titulo: _titulos[aba], inicio: aba == 0, largo: largo, verCategoria: (c) => _irAba(1, filtro: 'saidas', cat: c)),
      Expanded(child: _Abas(aba: aba, children: telasVisiveis)),
    ]);
    return PopScope(
      canPop: aba == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _irAba(0);
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _tecla,
          child: largo
              ? Scaffold(
                  body: Row(children: [
                    MenuLateral(aba: aba, onAba: _irAba, onNovo: () => abrirMenuLancar(context), onAjustes: () => Navigator.of(context).pushNamed('/ajustes')),
                    Expanded(child: SafeArea(left: false, child: corpo)),
                  ]),
                )
              : Scaffold(
                  extendBody: true,
                  body: SafeArea(bottom: false, child: corpo),
                  bottomNavigationBar: _MenuBaixo(aba: aba, onAba: _irAba, onMais: () => abrirMenuLancar(context)),
                ),
      ),
    ).envolverAbertura(
      abrindo,
      congelarAbertura,
      () => setState(() => abrindo = false),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  final String titulo;
  final bool largo, inicio;
  final void Function(String cat) verCategoria;
  const _Cabecalho({required this.titulo, required this.verCategoria, this.largo = false, this.inicio = false});
  @override
  Widget build(BuildContext context) {
    final estilo = IconButton.styleFrom(
      backgroundColor: G.v(0x10),
      side: BorderSide(color: G.borda),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      fixedSize: const Size(38, 38),
      minimumSize: const Size(38, 38),
      padding: EdgeInsets.zero,
    );
    void buscar() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaBusca()));
    // olho: esconde/mostra todos os valores do app
    final olho = ValueListenableBuilder<bool>(
      valueListenable: privacidade,
      builder: (_, oculto, __) => IconButton(
        tooltip: oculto ? 'Mostrar valores' : 'Esconder valores',
        onPressed: () {
          HapticFeedback.selectionClick();
          definirPrivacidade(!oculto);
        },
        style: estilo,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
          child: Icon(oculto ? Icons.visibility_off_outlined : Icons.visibility_outlined, key: ValueKey(oculto), size: 21),
        ),
      ),
    );
    final agora = DateTime.now();
    if (largo) {
      // computador: título à esquerda, campo de busca e avisos à direita
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 18, 24, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(inicio ? saudacao(agora) : titulo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.5)),
              if (inicio) Text(dataPorExtenso(agora), style: TextStyle(color: G.apagado, fontSize: 13)),
            ]),
          ),
          SizedBox(
            width: 300,
            child: Material(
              color: G.v(0x0C),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: buscar,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: G.borda)),
                  child: Row(children: [
                    Icon(Icons.search_rounded, size: 19, color: G.apagado),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Buscar lançamentos', style: TextStyle(color: G.apagado, fontSize: 13.5))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: G.borda)),
                      child: Text('/', style: TextStyle(color: G.apagado, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          olho,
          const SizedBox(width: 6),
          BotaoAvisos(verCategoria: verCategoria),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.asset('assets/icone.png', width: 38, height: 38, errorBuilder: (_, __, ___) => const SizedBox(width: 38, height: 38))),
        Expanded(
          child: inicio
              ? Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(saudacao(agora), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -.3)),
                    Text(
                      '${diasSemana[agora.weekday - 1].toLowerCase()}, ${agora.day} de ${mesesAbr[agora.month - 1]}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: G.apagado, fontSize: 11.5),
                    ),
                  ]),
                )
              : Column(children: [
                  Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.2)),
                ]),
        ),
        olho,
        const SizedBox(width: 6),
        IconButton(tooltip: 'Buscar', onPressed: buscar, style: estilo, icon: const Icon(Icons.search_rounded, size: 21)),
        const SizedBox(width: 6),
        BotaoAvisos(verCategoria: verCategoria),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Ajustes',
          onPressed: () => Navigator.of(context).pushNamed('/ajustes'),
          style: estilo,
          icon: const Icon(Icons.settings_outlined, size: 21),
        ),
      ]),
    );
  }
}

/// Transição padrão das telas, que no computador também deixa a tela aberta
/// numa coluna central (a tela principal fica de fora).
class _TransicaoEstreita extends PageTransitionsBuilder {
  const _TransicaoEstreita();
  static const _base = FadeForwardsPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final c = route.isFirst ? child : Estreito(child: child);
    return _base.buildTransitions(route, context, animation, secondaryAnimation, c);
  }
}

class _MenuBaixo extends StatelessWidget {
  final int aba;
  final ValueChanged<int> onAba;
  final VoidCallback onMais;
  const _MenuBaixo({required this.aba, required this.onAba, required this.onMais});

  @override
  Widget build(BuildContext context) {
    Widget item(int i, IconData ic, IconData icOn, String t) {
      final on = aba == i;
      return Expanded(
        child: Toque(
          escala: .9,
          child: InkResponse(
            onTap: () => onAba(i),
            radius: 36,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  width: on ? 48 : 32,
                  height: 28,
                  decoration: BoxDecoration(color: on ? G.lavandaFundo : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Icon(on ? icOn : ic, key: ValueKey(on), color: on ? G.lavanda : G.navApagado, size: 22),
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(fontSize: 10.5, fontWeight: on ? FontWeight.w700 : FontWeight.w600, color: on ? G.texto : G.navApagado),
                  child: Text(t, maxLines: 1),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: G.sombra(0xD9), blurRadius: 34, offset: Offset(0, 16), spreadRadius: -14)],
          ),
          // vidro fosco: o conteúdo passa desfocado por trás da barra
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
          decoration: BoxDecoration(
            color: G.navFundo.withValues(alpha: G.claro ? .80 : .74),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: G.v(0x14)),
          ),
          child: Row(children: [
            item(0, Icons.home_outlined, Icons.home_rounded, 'Início'),
            item(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Extrato'),
            // botão de lançar, alinhado com os outros itens
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Toque(
                escala: .88,
                child: Material(
                  color: G.branco,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onMais();
                    },
                    child: SizedBox(width: 50, height: 44, child: Icon(Icons.add_rounded, color: G.tinta, size: 28, semanticLabel: 'Lançar')),
                  ),
                ),
              ),
            ),
            item(2, Icons.event_note_outlined, Icons.event_note_rounded, 'Planejar'),
            item(3, Icons.show_chart_rounded, Icons.show_chart_rounded, 'Patrimônio'),
          ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


extension _ComAbertura on Widget {
  Widget envolverAbertura(bool abrindo, double? congelar, VoidCallback onFim) {
    if (!abrindo) return this;
    return Stack(children: [
      this,
      Positioned.fill(child: Material(type: MaterialType.transparency, child: Abertura(onFim: onFim, congelar: congelar))),
    ]);
  }
}


/// Abas com troca suave (a aba nova aparece com fade + leve deslize), mantendo o estado de cada uma.
class _Abas extends StatelessWidget {
  final int aba;
  final List<Widget> children;
  const _Abas({required this.aba, required this.children});
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      for (var i = 0; i < children.length; i++)
        Positioned.fill(
          child: Offstage(
            offstage: i != aba,
            child: TickerMode(enabled: i == aba, child: _Aparece(ativo: i == aba, child: children[i])),
          ),
        ),
    ]);
  }
}

class _Aparece extends StatefulWidget {
  final bool ativo;
  final Widget child;
  const _Aparece({required this.ativo, required this.child});
  @override
  State<_Aparece> createState() => _ApareceState();
}

class _ApareceState extends State<_Aparece> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280), value: 1);

  @override
  void didUpdateWidget(covariant _Aparece old) {
    super.didUpdateWidget(old);
    if (widget.ativo && !old.ativo && !semAnimacao(context)) c.forward(from: 0);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      child: widget.child,
      builder: (_, child) {
        final v = Curves.easeOutCubic.transform(c.value);
        return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child));
      },
    );
  }
}
