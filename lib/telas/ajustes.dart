import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dados/drive.dart';
import '../tema.dart';
import 'abertura.dart';
import '../widgets/movimento.dart';
import '../widgets/comum.dart';
import '../widgets/formulario.dart';
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
        Widget op(String v, String t, List<Color> amostra) {
          final on = modo == v;
          return Expanded(
            child: Toque(
              escala: .95,
              child: Material(
                color: on ? G.lavandaFundo : Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: on ? G.lavanda : G.borda, width: on ? 1.6 : 1)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => definirAparencia(v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: Column(children: [
                      // amostra de cores do tema
                      SizedBox(
                        height: 26,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (var i = 0; i < amostra.length; i++)
                            Align(
                              widthFactor: .7,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(color: amostra[i], shape: BoxShape.circle, border: Border.all(color: G.borda, width: 1.5)),
                              ),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: on ? G.lavanda : G.texto2)),
                    ]),
                  ),
                ),
              ),
            ),
          );
        }

        final texto = switch (modo) {
          'auto' => 'Segue o tema do celular: Pérola de dia, Grafite quando o celular estiver no modo escuro.',
          'claro' => 'Pérola: fundo claro com o cartão principal grafite.',
          'linho' => 'Linho & Safira: fundo cor de linho e cartão principal azul safira, igual ao site.',
          _ => 'Grafite: tudo escuro, com detalhes em lavanda.',
        };
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            op('auto', 'Automático', const [Color(0xFFF4F5F9), Color(0xFF101119)]),
            const SizedBox(width: 8),
            op('claro', 'Pérola', const [Color(0xFFF4F5F9), Color(0xFF353950), Color(0xFF4F57D6)]),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            op('linho', 'Linho & Safira', const [Color(0xFFF3EFE7), Color(0xFF2448C8), Color(0xFFB07A1F)]),
            const SizedBox(width: 8),
            op('escuro', 'Grafite', const [Color(0xFF101119), Color(0xFF353950), Color(0xFFB9BFF6)]),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(texto, style: TextStyle(color: G.apagado, fontSize: 12)),
          ),
        ]);
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
              'Guarda tudo numa pasta oculta do seu próprio Drive e mantém este celular e o site do GitHub iguais. Ninguém além de você tem acesso.',
              style: TextStyle(color: G.texto2, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            if (esc != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: G.lavandaFundo, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('O Drive já tem ${esc.noDrive} registros e este celular tem ${esc.noCelular}. O que fazer?', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: () => rodar(() => sd.sincronizar(primeira: true, modo: 'juntar')), child: const Text('Juntar os dois (recomendado)')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => rodar(() => sd.sincronizar(primeira: true, modo: 'drive')), child: const Text('Usar só o que está no Drive')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => rodar(() => sd.sincronizar(primeira: true, modo: 'aparelho')), child: const Text('Usar só o deste celular')),
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
                    if (await confirmar(context, 'Desligar a sincronização?', 'Os dados continuam neste celular e no Drive; só param de se atualizar.', sim: 'Desligar', perigo: false)) {
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
