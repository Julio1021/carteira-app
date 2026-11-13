import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/drive.dart';
import '../tema.dart';
import '../tela_cheia.dart';
import 'abertura.dart';
import '../widgets/movimento.dart';
import '../widgets/comum.dart';
import '../widgets/formulario.dart';
import 'importar.dart';
import 'inicio_nuvem.dart';

class TelaAjustes extends StatefulWidget {
  const TelaAjustes({super.key});
  @override
  State<TelaAjustes> createState() => _TelaAjustesState();
}

class _TelaAjustesState extends State<TelaAjustes> {
  bool ocupado = false;

  Future<void> _importar() async {
    final repo = RepoScope.ler(context);
    setState(() => ocupado = true);
    try {
      final f = await FilePicker.pickFile(type: FileType.any);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final res = await repo.importar(utf8.decode(bytes, allowMalformed: true));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Backup importado'),
          content: Text(
            '${res.novos} registro(s) novo(s), ${res.atualizados} atualizado(s) e ${res.iguais} que já estavam iguais.'
            '${res.ignorados > 0 ? '\n${res.ignorados} item(ns) não reconhecido(s) foram ignorados.' : ''}',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Ok'))],
        ),
      );
    } on FormatException catch (e) {
      if (mounted) avisar(context, e.message);
    } catch (e) {
      if (mounted) avisar(context, 'Não consegui ler esse arquivo.');
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> _exportar() async {
    final repo = RepoScope.ler(context);
    final bytes = Uint8List.fromList(utf8.encode(repo.exportar()));
    try {
      final caminho = await FilePicker.saveFile(
        dialogTitle: 'Salvar backup',
        fileName: repo.nomeBackup(),
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
      if (!mounted) return;
      if (caminho != null || kIsWeb) avisar(context, 'Backup salvo: ${repo.totalRegistros} registros.');
    } catch (_) {
      if (mounted) avisar(context, 'Não consegui salvar o backup neste aparelho.');
    }
  }

  Future<void> _apagarTudo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Apagar todos os dados?'),
        content: const Text('Tudo o que está neste aparelho será apagado. Exporte um backup antes, se quiser guardar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: G.neg, foregroundColor: Colors.white), onPressed: () => Navigator.pop(c, true), child: const Text('Apagar tudo')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await RepoScope.ler(context).limparTudo();
    if (mounted) avisar(context, 'Dados apagados.');
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    Widget item(IconData i, String t, String s, VoidCallback? f, {Color? cor}) => ListTile(
          onTap: ocupado ? null : f,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: G.v(0x14), borderRadius: BorderRadius.circular(13)),
            child: Icon(i, color: cor ?? G.texto),
          ),
          title: Text(t, style: TextStyle(fontWeight: FontWeight.w600, color: cor)),
          subtitle: Text(s, style: TextStyle(color: G.apagado, fontSize: 12.5)),
          trailing: Icon(Icons.chevron_right_rounded, color: G.apagado),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 40), children: [
        if (ocupado) const LinearProgressIndicator(minHeight: 2),
        Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 8), child: Text('Aparência', style: TextStyle(color: G.apagado, fontWeight: FontWeight.w600))),
        const _Nome(),
        const SizedBox(height: 14),
        const _Aparencia(),
        const SizedBox(height: 12),
        const _AberturaAjuste(),
        if (!kIsWeb) ...[const SizedBox(height: 12), const _TelaCheiaAjuste()],
        const SizedBox(height: 18),
        Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text('Sincronização', style: TextStyle(color: G.apagado, fontWeight: FontWeight.w600))),
        const _CartaoDrive(),
        const SizedBox(height: 18),
        Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text('Seus dados', style: TextStyle(color: G.apagado, fontWeight: FontWeight.w600))),
        CaixaLista([
          item(Icons.file_upload_outlined, 'Importar backup', 'Traga o arquivo .json exportado do app antigo ou deste app', _importar),
          item(Icons.file_download_outlined, 'Exportar backup', 'Salva uma cópia de tudo (${repo.totalRegistros} registros)', _exportar),
        ]),
        const SizedBox(height: 18),
        Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text('Importar do banco', style: TextStyle(color: G.apagado, fontWeight: FontWeight.w600))),
        CaixaLista([
          item(Icons.account_balance_outlined, 'Extrato da conta (OFX)', 'Gastos e entradas do Inter, Nubank, Mercado Pago…', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaImportarExtrato()))),
          item(Icons.picture_as_pdf_outlined, 'Investimentos do Inter (PDF)', 'Extrato de movimentações: aplicações e resgates', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaImportarInter()))),
        ]),
        const SizedBox(height: 18),
        Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text('Em breve', style: TextStyle(color: G.apagado, fontWeight: FontWeight.w600))),
        CaixaLista([
          item(Icons.cloud_sync_outlined, 'Sincronizar com o Google Drive', 'O mesmo arquivo do site, para celular e PC ficarem iguais', null),
        ]),
        const SizedBox(height: 18),
        CaixaLista([
          item(Icons.delete_forever_outlined, 'Apagar dados deste aparelho', 'Não mexe no Drive nem em backups salvos', _apagarTudo, cor: G.neg),
        ]),
        const SizedBox(height: 24),
        Center(child: Text('Diário da Carteira · versão 0.1', style: TextStyle(color: G.apagado, fontSize: 12))),
      ]),
    );
  }
}


class _Aparencia extends StatelessWidget {
  const _Aparencia();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: aparencia,
      builder: (context, modo, _) {
        final texto = switch (modo) {
          'auto' => kIsWeb ? 'Segue o tema do computador: Pérola de dia, Grafite quando ele estiver no modo escuro.' : 'Segue o tema do celular: Pérola de dia, Grafite quando o celular estiver no modo escuro.',
          'claro' => 'Pérola: fundo claro com o cartão principal grafite.',
          'linho' => 'Linho & Safira: fundo cor de linho e cartão principal azul safira, igual ao site.',
          'oceano' => 'Nuvem · Oceano: claro e limpo, cartão principal azul-petróleo e menu escuro flutuante.',
          'floresta' => 'Nuvem · Floresta: claro, cartão principal verde-escuro e detalhes em verde.',
          'marinho' => 'Nuvem · Marinho: claro, cartão principal azul-marinho e detalhes em azul vivo.',
          'ametista' => 'Lilás & Ametista: claro, com fundo lilás bem suave, cartão principal em degradê violeta e detalhes em ametista.',
          'esmeralda' => 'Noite & Esmeralda: escuro em verde-petróleo, cartão principal esmeralda e detalhes em menta e ouro.',
          _ => 'Grafite: tudo escuro, com detalhes em lavanda.',
        };
        const perola = Color(0xFFF4F5F9), grafite = Color(0xFF101119);
        final temas = <_MiniTema>[
          for (final p in paletasNuvem)
            _MiniTema(p.id, p.nome,
                fundo: Color(p.c['fundo']!),
                cartao: Colors.white,
                hero: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: p.hero),
                destaque: Color(p.c['lavanda']!),
                linha: Color(p.c['borda']!),
                nav: Color(p.c['navFundo']!),
                novo: true),
          _MiniTema('auto', 'Automático', fundo: perola, fundoB: grafite, cartao: const Color(0xFFFFFFFF), cartaoB: const Color(0xFF1B1C28), hero: GE.gradHero, destaque: const Color(0xFF4F57D6), linha: const Color(0xFFB9BFF6)),
          _MiniTema('linho', 'Linho & Safira', fundo: const Color(0xFFF3EFE7), cartao: const Color(0xFFFFFFFF), hero: GH.gradSafira, destaque: const Color(0xFF2448C8), linha: const Color(0xFFD9D2C4)),
          _MiniTema('ametista', 'Lilás & Ametista', fundo: const Color(0xFFF6F3FC), cartao: const Color(0xFFFFFFFF), hero: GH.gradAmetista, destaque: const Color(0xFF6B3FD4), linha: const Color(0xFFDDD3F0)),
          _MiniTema('esmeralda', 'Noite & Esmeralda', fundo: const Color(0xFF081114), cartao: const Color(0xFF12252A), hero: GH.gradEsmeralda, destaque: const Color(0xFF34D8AC), linha: const Color(0xFF2A4A47)),
          _MiniTema('claro', 'Pérola', fundo: perola, cartao: const Color(0xFFFFFFFF), hero: GE.gradHero, destaque: const Color(0xFF12131C), linha: const Color(0xFFD9DBE6)),
          _MiniTema('escuro', 'Grafite', fundo: grafite, cartao: const Color(0xFF1B1C28), hero: GE.gradHero, destaque: const Color(0xFFB9BFF6), linha: const Color(0xFF34364A)),
        ];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < temas.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _CartaoTema(temas[i], ligado: modo == temas[i].id),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(texto, style: TextStyle(color: G.apagado, fontSize: 12)),
          ),
        ]);
      },
    );
  }
}

class _MiniTema {
  final String id, nome;
  final Color fundo, cartao, destaque, linha;
  final Color? fundoB, cartaoB; // segunda metade (Automático)
  final Gradient hero;
  final bool novo;
  final Color? nav; // menu escuro flutuante (Nuvem)
  const _MiniTema(this.id, this.nome, {required this.fundo, required this.cartao, required this.hero, required this.destaque, required this.linha, this.fundoB, this.cartaoB, this.novo = false, this.nav});
}

/// Miniatura de uma tela do app com as cores do tema.
class _CartaoTema extends StatelessWidget {
  final _MiniTema t;
  final bool ligado;
  const _CartaoTema(this.t, {required this.ligado});
  @override
  Widget build(BuildContext context) {
    Widget tela(Color fundo, Color cartao) => Container(
          color: fundo,
          padding: const EdgeInsets.fromLTRB(7, 8, 7, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              height: 40,
              decoration: BoxDecoration(gradient: t.hero, borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 22, height: 4, decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 5),
                Container(width: 46, height: 8, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3))),
              ]),
            ),
            const SizedBox(height: 6),
            for (var k = 0; k < 2; k++)
              Container(
                height: 17,
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(color: cartao, borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: k == 0 ? t.destaque : t.linha, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 5),
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: Container(width: k == 0 ? 30 : 22, height: 4, decoration: BoxDecoration(color: t.linha, borderRadius: BorderRadius.circular(2))))),
                ]),
              ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomCenter,
              child: t.nav != null
                  ? Container(
                      width: 52,
                      height: 14,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(color: t.nav, borderRadius: BorderRadius.circular(99)),
                      alignment: Alignment.center,
                      child: Container(width: 14, height: 8, decoration: BoxDecoration(color: t.destaque, borderRadius: BorderRadius.circular(4))),
                    )
                  : Container(
                      width: 22,
                      height: 13,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(color: t.destaque, borderRadius: BorderRadius.circular(5)),
                    ),
            ),
          ]),
        );
    return Toque(
      escala: .95,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          definirAparencia(t.id);
        },
        child: SizedBox(
          width: 102,
          child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 132,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: ligado ? G.lavanda : G.borda, width: ligado ? 2 : 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: t.fundoB == null
                      ? tela(t.fundo, t.cartao)
                      : Stack(fit: StackFit.expand, children: [
                          tela(t.fundoB!, t.cartaoB ?? t.cartao),
                          ClipPath(clipper: _Diagonal(), child: tela(t.fundo, t.cartao)),
                        ]),
                ),
              ),
              if (ligado)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: G.lavanda, shape: BoxShape.circle, border: Border.all(color: G.fundo, width: 2)),
                    child: Icon(Icons.check_rounded, size: 14, color: G.tinta),
                  ),
                ),
              if (t.novo && !ligado)
                Positioned(
                  right: -4,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: t.destaque, borderRadius: BorderRadius.circular(99)),
                    child: const Text('novo', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
            const SizedBox(height: 7),
            Text(t.nome, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, height: 1.15, color: ligado ? G.lavanda : G.texto2)),
          ]),
        ),
      ),
    );
  }
}

class _Diagonal extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(_Diagonal o) => false;
}

class _AberturaAjuste extends StatelessWidget {
  const _AberturaAjuste();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([aberturaLigada, aberturaValor]),
      builder: (context, _) => Container(
        decoration: BoxDecoration(color: G.v(0x07), borderRadius: BorderRadius.circular(18), border: Border.all(color: G.borda)),
        child: Column(children: [
          SwitchListTile(
            value: aberturaLigada.value,
            onChanged: (v) => definirAbertura(ligada: v),
            title: const Text('Animação de abertura', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('A carteira, as moedas e o gráfico do seu patrimônio ao abrir o app. Toque na tela para pular.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
          ),
          if (aberturaLigada.value)
            SwitchListTile(
              value: aberturaValor.value,
              onChanged: (v) => definirAbertura(valor: v),
              title: const Text('Mostrar o valor do patrimônio', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Desligado, ninguém vê seu saldo quando você abre o app em público.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
            ),
        ]),
      ),
    );
  }
}


class _CartaoDrive extends StatelessWidget {
  const _CartaoDrive();
  @override
  Widget build(BuildContext context) {
    final sd = syncDrive;
    if (sd == null) {
      return Cartao(child: Text('A sincronização com o Google Drive fica disponível no app instalado.', style: TextStyle(color: G.apagado)));
    }
    return ListenableBuilder(
      listenable: sd,
      builder: (context, _) {
        final esc = sd.escolha;
        final (cor, icone, status) = switch (sd.estado) {
          EstadoDrive.desligado => (G.apagado, Icons.cloud_off_rounded, 'Desligada'),
          EstadoDrive.sincronizando => (G.lavanda, Icons.sync_rounded, 'Sincronizando…'),
          EstadoDrive.pendente => (G.lavanda, Icons.cloud_upload_outlined, 'Salvando no Drive…'),
          EstadoDrive.entrar => (G.alerta, Icons.login_rounded, 'Precisa entrar de novo com o Google'),
          EstadoDrive.erro => (G.neg, Icons.cloud_off_rounded, sd.erro.isEmpty ? 'Erro ao sincronizar' : sd.erro),
          EstadoDrive.pronto => (G.pos, Icons.cloud_done_rounded, 'Sincronizado ${sd.quando}'),
        };
        Future<void> rodar(Future<String?> Function() f) async {
          final m = await f();
          if (context.mounted && m != null) avisar(context, m);
          if (context.mounted && m == null && sd.escolha == null && sd.ligado) avisar(context, 'Pronto: sincronizado com o seu Drive.');
        }

        return Cartao(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: cor.withValues(alpha: .14), borderRadius: BorderRadius.circular(13)),
                child: sd.estado == EstadoDrive.sincronizando
                    ? Padding(padding: const EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2.4, color: cor))
                    : Icon(icone, color: cor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Google Drive', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  Text(status, style: TextStyle(color: cor, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  if (sd.email != null && sd.ligado) Text(sd.email!, style: TextStyle(color: G.apagado, fontSize: 12)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              'Guarda tudo numa pasta oculta do seu próprio Drive e mantém celular, computador e site iguais. Ninguém além de você tem acesso.',
              style: TextStyle(color: G.texto2, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            if (esc != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: G.lavandaFundo, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('O Drive já tem ${esc.noDrive} registros e ${kIsWeb ? 'este navegador' : 'este celular'} tem ${esc.noCelular}. O que fazer?', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: () => rodar(() => sd.sincronizar(primeira: true, modo: 'juntar')), child: const Text('Juntar os dois (recomendado)')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => rodar(() => sd.sincronizar(primeira: true, modo: 'drive')), child: const Text('Usar só o que está no Drive')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => rodar(() => sd.sincronizar(primeira: true, modo: 'aparelho')), child: Text(kIsWeb ? 'Usar só o deste navegador' : 'Usar só o deste celular')),
                ]),
              ),
            ] else if (!sd.ligado)
              FilledButton.icon(onPressed: () => rodar(sd.conectar), icon: const Icon(Icons.cloud_sync_rounded), label: const Text('Conectar ao Google Drive'))
            else
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: sd.estado == EstadoDrive.sincronizando ? null : () => rodar(() => sd.sincronizar(interativo: true)),
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sincronizar agora'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    if (await confirmar(context, 'Desligar a sincronização?', 'Os dados continuam aqui e no Drive; só param de se atualizar.', sim: 'Desligar', perigo: false)) {
                      await sd.desconectar();
                    }
                  },
                  child: const Text('Desligar'),
                ),
              ]),
          ]),
        );
      },
    );
  }
}

/// Tela cheia: liga/desliga e escolhe como as barras do Android se comportam.
class _TelaCheiaAjuste extends StatelessWidget {
  const _TelaCheiaAjuste();
  @override
  Widget build(BuildContext context) {
    const opcoes = <(String, IconData, String, String)>[
      ('tudo', Icons.fullscreen_rounded, 'Esconder tudo', 'Some a barra de cima e os botões de baixo. Deslize da borda para vê-los por alguns segundos.'),
      ('topo', Icons.vertical_align_top_rounded, 'Esconder só a barra de cima', 'Somem a hora, a bateria e as notificações; os botões de baixo continuam.'),
      ('transparente', Icons.layers_outlined, 'Barras transparentes', 'A hora e a bateria continuam visíveis, mas o app passa por trás, sem faixa preta.'),
    ];
    return AnimatedBuilder(
      animation: Listenable.merge([telaCheia, telaCheiaTipo]),
      builder: (context, _) => Container(
        decoration: BoxDecoration(color: G.v(0x07), borderRadius: BorderRadius.circular(18), border: Border.all(color: G.borda)),
        child: Column(children: [
          SwitchListTile(
            value: telaCheia.value,
            onChanged: (v) => definirTelaCheia(ligada: v),
            title: const Text('Tela cheia', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('O app ocupa mais da tela do celular. Escolha abaixo como.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
          ),
          if (telaCheia.value)
            for (final (id, icone, nome, sub) in opcoes)
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  definirTelaCheia(tipo: id);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 14, 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icone, size: 20, color: telaCheiaTipo.value == id ? G.lavanda : G.texto2)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nome, style: TextStyle(fontWeight: FontWeight.w600, color: telaCheiaTipo.value == id ? G.lavanda : G.texto)),
                        Text(sub, style: TextStyle(color: G.apagado, fontSize: 12, height: 1.3)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Icon(telaCheiaTipo.value == id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 20, color: telaCheiaTipo.value == id ? G.lavanda : G.apagado),
                  ]),
                ),
              ),
        ]),
      ),
    );
  }
}

/// Nome para a saudação do Início.
class _Nome extends StatefulWidget {
  const _Nome();
  @override
  State<_Nome> createState() => _NomeState();
}

class _NomeState extends State<_Nome> {
  late final c = TextEditingController(text: nomeUsuario.value);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: c,
        textCapitalization: TextCapitalization.words,
        onChanged: definirNome,
        decoration: const InputDecoration(labelText: 'Seu nome', hintText: 'Para a saudação do Início', prefixIcon: Icon(Icons.person_outline_rounded)),
      );
}
