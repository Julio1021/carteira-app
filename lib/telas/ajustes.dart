import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tema.dart';
import '../widgets/comum.dart';

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
            decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(13)),
            child: Icon(i, color: cor ?? G.texto),
          ),
          title: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: cor)),
          subtitle: Text(s, style: const TextStyle(color: G.apagado, fontSize: 12.5)),
          trailing: const Icon(Icons.chevron_right_rounded, color: G.apagado),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 40), children: [
        if (ocupado) const LinearProgressIndicator(minHeight: 2),
        const Padding(padding: EdgeInsets.fromLTRB(4, 8, 4, 8), child: Text('Seus dados', style: TextStyle(color: G.apagado, fontWeight: FontWeight.w700))),
        CaixaLista([
          item(Icons.file_upload_outlined, 'Importar backup', 'Traga o arquivo .json exportado do app antigo ou deste app', _importar),
          item(Icons.file_download_outlined, 'Exportar backup', 'Salva uma cópia de tudo (${repo.totalRegistros} registros)', _exportar),
        ]),
        const SizedBox(height: 18),
        const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text('Em breve', style: TextStyle(color: G.apagado, fontWeight: FontWeight.w700))),
        CaixaLista([
          item(Icons.cloud_sync_outlined, 'Sincronizar com o Google Drive', 'O mesmo arquivo do site, para celular e PC ficarem iguais', null),
        ]),
        const SizedBox(height: 18),
        CaixaLista([
          item(Icons.delete_forever_outlined, 'Apagar dados deste aparelho', 'Não mexe no Drive nem em backups salvos', _apagarTudo, cor: G.neg),
        ]),
        const SizedBox(height: 24),
        const Center(child: Text('Diário da Carteira · versão 0.1', style: TextStyle(color: G.apagado, fontSize: 12))),
      ]),
    );
  }
}
