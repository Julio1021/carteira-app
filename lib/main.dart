import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'dados/demo.dart';
import 'dados/repo.dart';
import 'tema.dart';
import 'telas/ajustes.dart';
import 'telas/extrato.dart';
import 'telas/inicio.dart';
import 'telas/lancar.dart';
import 'telas/limites.dart';
import 'telas/cartoes.dart';
import 'telas/emprestimos.dart';
import 'telas/planejar.dart';
import 'telas/patrimonio.dart';
import 'util/fmt.dart';
import 'widgets/comum.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: G.fundo,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final demo = kIsWeb && Uri.base.queryParameters['demo'] == '1';
  final repo = demo ? Repo.memoria(dadosDemo()) : Repo();
  if (!demo) await repo.carregar();
  runApp(AppCarteira(repo: repo));
}

class AppCarteira extends StatelessWidget {
  final Repo repo;
  const AppCarteira({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return RepoScope(
      repo: repo,
      child: MaterialApp(
        title: 'Diário da Carteira',
        debugShowCheckedModeBanner: false,
        theme: temaGrafite(),
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
  int subPat = 0;

  static const _titulos = ['Início', 'Extrato', 'Planejar', 'Patrimônio'];

  @override
  void initState() {
    super.initState();
    // Só para gerar prints na versão web de demonstração: ?demo=1&aba=1&tela=lancar
    if (kIsWeb && Uri.base.queryParameters['demo'] == '1') {
      final q = Uri.base.queryParameters;
      aba = (int.tryParse(q['aba'] ?? '') ?? 0).clamp(0, 3).toInt();
      subPat = (int.tryParse(q['sub'] ?? '') ?? 0).clamp(0, 3).toInt();
      final tela = q['tela'];
      if (tela != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (tela == 'lancar') abrirFormLanc(context);
          if (tela == 'entrada') abrirFormLanc(context, entrada: true);
          if (tela == 'menu') abrirMenuLancar(context);
          if (tela == 'limites') _abrirLimites();
          if (tela == 'ajustes') Navigator.of(context).pushNamed('/ajustes');
          if (tela == 'cartoes') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaCartoes()));
          if (tela == 'cartao') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaCartao(id: 'cc_demo')));
          if (tela == 'emprestimos') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaEmprestimos()));
        });
      }
    }
  }

  void _irAba(int i, {String filtro = 'tudo'}) {
    HapticFeedback.selectionClick();
    setState(() {
      aba = i;
      filtroExtrato = filtro;
    });
  }

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
      TelaExtrato(ym: ym, onMes: (m) => setState(() => ym = m), filtroInicial: filtroExtrato),
      TelaPlanejar(irLimites: _abrirLimites),
      TelaPatrimonio(key: ValueKey('pat$subPat'), subInicial: subPat),
    ];
    return PopScope(
      canPop: aba == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _irAba(0);
      },
      child: Scaffold(
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            _Cabecalho(titulo: _titulos[aba]),
            Expanded(child: IndexedStack(index: aba, children: telas)),
          ]),
        ),
        bottomNavigationBar: _MenuBaixo(aba: aba, onAba: _irAba, onMais: () => abrirMenuLancar(context)),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  final String titulo;
  const _Cabecalho({required this.titulo});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.asset('assets/icone.png', width: 42, height: 42, errorBuilder: (_, __, ___) => const SizedBox(width: 42, height: 42))),
        Expanded(
          child: Column(children: [
            const Text('DIÁRIO DA CARTEIRA', style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: G.apagado, fontWeight: FontWeight.w700)),
            Text(titulo, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ]),
        ),
        IconButton(
          tooltip: 'Ajustes',
          onPressed: () => Navigator.of(context).pushNamed('/ajustes'),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0x10FFFFFF),
            side: const BorderSide(color: G.borda),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            fixedSize: const Size(42, 42),
          ),
          icon: const Icon(Icons.settings_outlined),
        ),
      ]),
    );
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
        child: InkResponse(
          onTap: () => onAba(i),
          radius: 36,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(on ? icOn : ic, color: on ? G.branco : const Color(0xFF80849B)),
              const SizedBox(height: 3),
              Text(t, maxLines: 1, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: on ? G.branco : const Color(0xFF80849B))),
              const SizedBox(height: 3),
              AnimatedContainer(duration: const Duration(milliseconds: 200), width: on ? 18 : 0, height: 3, decoration: BoxDecoration(color: G.branco, borderRadius: BorderRadius.circular(3))),
            ]),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: SizedBox(
          height: 78,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
            Container(
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xEB1E1F2C),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x14FFFFFF)),
                boxShadow: const [BoxShadow(color: Color(0xD9000000), blurRadius: 40, offset: Offset(0, 22), spreadRadius: -16)],
              ),
              child: Row(children: [
                item(0, Icons.home_outlined, Icons.home_rounded, 'Início'),
                item(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Extrato'),
                const SizedBox(width: 74),
                item(2, Icons.event_note_outlined, Icons.event_note_rounded, 'Planejar'),
                item(3, Icons.show_chart_rounded, Icons.show_chart_rounded, 'Patrimônio'),
              ]),
            ),
            Positioned(
              top: -14,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [const BoxShadow(color: Color(0xE6000000), blurRadius: 30, offset: Offset(0, 16), spreadRadius: -10), BoxShadow(color: G.fundo, spreadRadius: 6)],
                ),
                child: Material(
                  color: G.branco,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onMais();
                    },
                    child: const SizedBox(width: 62, height: 62, child: Icon(Icons.add_rounded, color: G.tinta, size: 32, semanticLabel: 'Lançar')),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
