// Aba "Mais": tudo o que não precisa ficar sempre à vista no Início.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tema.dart';
import '../widgets/comum.dart';
import '../widgets/largo.dart';
import 'busca.dart';
import 'cartoes.dart';
import 'emprestimos.dart';
import 'importar.dart';
import 'inicio_nuvem.dart' show nomeUsuario;
import 'patrimonio.dart';
import 'retro.dart';

/// Patrimônio (investimentos, objetivos e relatórios) aberto como tela própria.
class TelaPatrimonioPagina extends StatelessWidget {
  final int sub;
  const TelaPatrimonioPagina({super.key, this.sub = 0});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Investimentos')),
        body: TelaPatrimonio(subInicial: sub),
      );
}

class TelaMais extends StatelessWidget {
  final String ym;
  const TelaMais({super.key, required this.ym});

  @override
  Widget build(BuildContext context) {
    void ir(Widget t) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => t));
    final grupos = <(String, List<(IconData, String, String?, VoidCallback)>)>[
      ('Seu dinheiro', [
        (Icons.trending_up_rounded, 'Investimentos', 'Patrimônio, ativos e objetivos', () => ir(const TelaPatrimonioPagina())),
        (Icons.insert_chart_outlined_rounded, 'Relatórios', 'Evolução e rendimento mês a mês', () => ir(const TelaPatrimonioPagina(sub: 3))),
        (Icons.credit_card_rounded, 'Cartões de crédito', 'Faturas e limites', () => ir(const TelaCartoes())),
        (Icons.handshake_outlined, 'Empréstimos', 'Dinheiro emprestado a receber', () => ir(const TelaEmprestimos())),
      ]),
      ('Ferramentas', [
        (Icons.search_rounded, 'Buscar lançamentos', null, () => ir(const TelaBusca())),
        (Icons.upload_file_rounded, 'Importar extrato do banco', 'OFX ou CSV', () => ir(const TelaImportarExtrato())),
        (Icons.auto_awesome_rounded, 'Retrospectiva', 'Como foi o mês passado', () => abrirRetro(context, mesDaRetro(RepoScope.ler(context), ym))),
      ]),
      ('App', [
        (Icons.tune_rounded, 'Ajustes', 'Tema, nome, tela cheia, backup e Drive', () => Navigator.of(context).pushNamed('/ajustes')),
      ]),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 120),
      children: [
        Centralizar(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ValueListenableBuilder<String>(
              valueListenable: nomeUsuario,
              builder: (_, nome, __) => Cartao(
                onTap: () => Navigator.of(context).pushNamed('/ajustes'),
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: G.lavandaFundo,
                    child: Text(nome.isEmpty ? '?' : nome.trim()[0].toUpperCase(), style: TextStyle(color: G.lavandaIcone, fontWeight: FontWeight.w700, fontSize: 17)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nome.isEmpty ? 'Diário da Carteira' : nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(nome.isEmpty ? 'Toque para pôr seu nome' : 'Seu perfil e preferências', style: TextStyle(color: G.apagado, fontSize: 12.5)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: G.apagado),
                ]),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: privacidade,
              builder: (_, oculto, __) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Cartao(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    value: oculto,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      definirPrivacidade(v);
                    },
                    secondary: Icon(oculto ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: G.texto2),
                    title: const Text('Esconder valores', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('Para usar o app em público', style: TextStyle(color: G.apagado, fontSize: 12.5)),
                  ),
                ),
              ),
            ),
            for (final (titulo, itens) in grupos) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                child: Text(titulo, style: TextStyle(color: G.apagado, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              Cartao(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < itens.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 56, color: G.borda),
                    ListTile(
                      onTap: itens[i].$4,
                      leading: Icon(itens[i].$1, color: G.texto2),
                      title: Text(itens[i].$2, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: itens[i].$3 == null ? null : Text(itens[i].$3!, style: TextStyle(color: G.apagado, fontSize: 12.5)),
                      trailing: Icon(Icons.chevron_right_rounded, color: G.apagado),
                    ),
                  ],
                ]),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}
