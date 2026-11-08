import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tema.dart';
import 'abertura.dart';
import '../widgets/comum.dart';
import 'importar.dart';

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
        const _Aparencia(),
        const SizedBox(height: 12),
        const _AberturaAjuste(),
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
        Widget op(String v, IconData i, String t) {
          final on = modo == v;
          return Expanded(
            child: Material(
              color: on ? G.branco : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => definirAparencia(v),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(children: [
                    Icon(i, size: 20, color: on ? G.tinta : G.texto2),
                    const SizedBox(height: 4),
                    Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: on ? G.tinta : G.texto2)),
                  ]),
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: G.v(0x07), borderRadius: BorderRadius.circular(18), border: Border.all(color: G.borda)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              op('auto', Icons.brightness_auto_rounded, 'Automático'),
              const SizedBox(width: 4),
              op('claro', Icons.light_mode_rounded, 'Claro'),
              const SizedBox(width: 4),
              op('escuro', Icons.dark_mode_rounded, 'Escuro'),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                modo == 'auto' ? 'Segue o tema do celular: claro de dia, escuro quando o celular estiver no modo escuro.' : (modo == 'claro' ? 'Tema claro (Pérola).' : 'Tema escuro (Grafite).'),
                style: TextStyle(color: G.apagado, fontSize: 12),
              ),
            ),
          ]),
        );
      },
    );
  }
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
