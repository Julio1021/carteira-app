import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/categorias.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';

/// Limites de gastos por categoria (registros "orc" do site).
class TelaLimites extends StatelessWidget {
  final String ym;
  const TelaLimites({super.key, required this.ym});

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final r = ResumoMes.de(repo, ym);
    final cats = [...categoriasGasto]..sort((a, b) {
        final la = r.limites.containsKey(a.id) ? 1 : 0, lb = r.limites.containsKey(b.id) ? 1 : 0;
        if (la != lb) return lb - la;
        return (r.porCategoria[b.id] ?? 0).compareTo(r.porCategoria[a.id] ?? 0);
      });
    return Scaffold(
      appBar: AppBar(title: const Text('Limites de gastos', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 40),
        children: [
          Cartao(
            gradiente: G.gradHero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mesLongo(ym), style: TextStyle(color: G.texto2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(r.limiteTotal > 0 ? '${brl(r.gastoComLimite)} de ${brl(r.limiteTotal)}' : 'Nenhum limite definido',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              if (r.limiteTotal > 0) ...[
                const SizedBox(height: 10),
                Barra(r.usoLimite ?? 0, cor: (r.usoLimite ?? 0) > 1 ? G.neg : G.branco),
              ],
              const SizedBox(height: 10),
              Text('Toque numa categoria para definir quanto quer gastar nela por mês.', style: TextStyle(color: G.texto2, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 14),
          CaixaLista([
            for (final c in cats)
              _LinhaLimite(cat: c, gasto: r.porCategoria[c.id] ?? 0, limite: r.limites[c.id]),
          ]),
        ],
      ),
    );
  }
}

class _LinhaLimite extends StatelessWidget {
  final Categoria cat;
  final double gasto;
  final double? limite;
  const _LinhaLimite({required this.cat, required this.gasto, required this.limite});

  Future<void> _editar(BuildContext context) async {
    final c = TextEditingController(text: limite != null ? valorCampo(limite!) : '');
    final v = await showDialog<double?>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(cat.nome),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: const InputDecoration(prefixText: 'R\$ ', labelText: 'Limite por mês', hintText: '0,00'),
        ),
        actions: [
          if (limite != null) TextButton(onPressed: () => Navigator.pop(d, -1.0), child: Text('Remover', style: TextStyle(color: G.neg))),
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, lerValor(c.text) ?? 0), child: const Text('Salvar')),
        ],
      ),
    );
    if (v == null || !context.mounted) return;
    final repo = RepoScope.ler(context);
    final id = 'orc_${cat.id}';
    if (v <= 0) {
      await repo.apagar(id);
    } else {
      await repo.salvar({...?repo.porId(id), 'kind': 'orc', 'id': id, 'cat': cat.id, 'limite': (v * 100).round() / 100});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final passou = l != null && gasto > l;
    return InkWell(
      onTap: () => _editar(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          IconeCategoria(cat, tam: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cat.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              if (l != null) ...[
                Barra(gasto / l, cor: passou ? G.neg : cat.cor, altura: 5),
                const SizedBox(height: 4),
                Text(passou ? 'Passou ${brl(gasto - l)}' : 'Restam ${brl(l - gasto)}', style: TextStyle(fontSize: 12, color: passou ? G.neg : G.apagado)),
              ] else
                Text(gasto > 0 ? 'Gasto no mês: ${brl(gasto)} · sem limite' : 'Sem limite', style: TextStyle(fontSize: 12, color: G.apagado)),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(brl(gasto), style: const TextStyle(fontWeight: FontWeight.w700)),
            if (l != null) Text('de ${brl(l)}', style: TextStyle(fontSize: 12, color: G.apagado)),
          ]),
        ]),
      ),
    );
  }
}
