import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/categorias.dart';
import '../dados/limites.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/painel.dart';

/// Limites de gastos: um teto geral para o mês e limites por categoria
/// (registros "orc" do site), com sobra para o mês seguinte, ritmo e histórico.
class TelaLimites extends StatelessWidget {
  final String ym;
  const TelaLimites({super.key, required this.ym});

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final r = ResumoMes.de(repo, ym);
    final lm = r.lim;
    final med = mediaGastos(repo, ym);
    final cats = [...categoriasGasto.where((c) => c.id != 'cartao')]..sort((a, b) {
        final la = lm.cat.containsKey(a.id) ? 1 : 0, lb = lm.cat.containsKey(b.id) ? 1 : 0;
        if (la != lb) return lb - la;
        final ga = (r.porCategoria[a.id] ?? 0) + (med.cat[a.id] ?? 0), gb = (r.porCategoria[b.id] ?? 0) + (med.cat[b.id] ?? 0);
        return gb.compareTo(ga);
      });
    final hist = historicoLimite(repo, ym);
    return Scaffold(
      appBar: AppBar(title: const Text('Limites de gastos', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 40),
        children: [
          _Resumo(r: r),
          const SizedBox(height: 18),
          const TituloSecao('Limite geral'),
          Cartao(
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              InkWell(
                onTap: () => editarLimiteGeral(context, mediaTotal: med.total),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: G.lavandaFundo, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.account_balance_wallet_rounded, color: G.lavandaIcone, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Teto do mês', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          lm.geral == null
                              ? (med.total > 0 ? 'Você gasta em média ${brl(med.total)} por mês' : 'Toque para definir quanto quer gastar no mês')
                              : (lm.sobraGeral > 0 ? 'Mais ${brl(lm.sobraGeral)} que sobrou do mês passado' : 'Vale para tudo o que sair no mês'),
                          style: TextStyle(fontSize: 12.5, color: G.apagado),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(lm.geral == null ? 'Definir' : brl(lm.geralBase),
                        style: TextStyle(fontWeight: FontWeight.w800, color: lm.geral == null ? G.lavanda : G.texto)),
                    Icon(Icons.chevron_right_rounded, color: G.apagado),
                  ]),
                ),
              ),
              Divider(height: 1, color: G.borda),
              SwitchListTile(
                value: lm.acumula,
                onChanged: (v) => _salvarGeral(context, acumula: v),
                contentPadding: const EdgeInsets.fromLTRB(14, 2, 10, 2),
                title: const Text('Levar a sobra para o mês seguinte', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('O que não gastar do limite (geral e de cada categoria) soma no mês seguinte, até metade do limite.', style: TextStyle(fontSize: 12, color: G.apagado)),
              ),
            ]),
          ),
          if (lm.categoriasPassamGeral)
            Dica('A soma dos limites por categoria (${brl(lm.somaCategorias)}) passa do limite geral (${brl(lm.geralBase)}).', icone: Icons.warning_amber_rounded),
          const SizedBox(height: 18),
          TituloSecao('Por categoria', direita: lm.catBase.isEmpty ? null : Text('${lm.catBase.length} com limite', style: TextStyle(fontSize: 11.5, color: G.apagado))),
          _ListaCategorias(
            linhas: [
              for (final c in cats)
                _LinhaLimite(cat: c, gasto: r.porCategoria[c.id] ?? 0, limite: lm.cat[c.id], base: lm.catBase[c.id], media: med.cat[c.id] ?? 0, ym: ym),
            ],
          ),
          if (hist.isNotEmpty) ...[
            const SizedBox(height: 18),
            TituloSecao(lm.geral != null ? 'Histórico · limite geral' : 'Histórico · categorias com limite'),
            Cartao(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final m in hist.reversed) _LinhaHistorico(m: m),
                Rodape('Comparado com os limites de hoje. ${hist.where((m) => m.dentro).length} de ${hist.length} meses dentro.'),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Categorias com limite ou com gastos primeiro; as paradas ficam num "mostrar mais".
class _ListaCategorias extends StatefulWidget {
  final List<_LinhaLimite> linhas;
  const _ListaCategorias({required this.linhas});
  @override
  State<_ListaCategorias> createState() => _ListaCategoriasState();
}

class _ListaCategoriasState extends State<_ListaCategorias> {
  bool todas = false;
  @override
  Widget build(BuildContext context) {
    bool ativa(_LinhaLimite l) => l.limite != null || l.gasto > 0 || l.media > 0;
    final principais = widget.linhas.where(ativa).toList();
    final resto = widget.linhas.where((l) => !ativa(l)).toList();
    return CaixaLista([
      ...principais,
      if (todas) ...resto,
      if (resto.isNotEmpty)
        InkWell(
          onTap: () => setState(() => todas = !todas),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(todas ? 'Mostrar menos' : 'Outras ${resto.length} categorias sem gastos', style: TextStyle(color: G.lavanda, fontWeight: FontWeight.w700, fontSize: 13)),
              Icon(todas ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: G.lavanda, size: 20),
            ]),
          ),
        ),
    ]);
  }
}

/// Cartão do topo: quanto já foi do limite, quanto sobra por dia e o ritmo.
class _Resumo extends StatelessWidget {
  final ResumoMes r;
  const _Resumo({required this.r});
  @override
  Widget build(BuildContext context) {
    const branco = Colors.white;
    final t2 = GH.texto2;
    final lim = r.limiteTotal, gasto = r.gastoComLimite;
    final tem = lim > 0;
    final resta = lim - gasto;
    final dias = diasRestantes(r.ym);
    final proj = tem ? projecaoMes(gasto, r.ym) : null;
    final uso = tem ? gasto / lim : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(gradient: GH.gradHero, borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(mesLongo(r.ym), style: TextStyle(color: t2, fontWeight: FontWeight.w600))),
          if (tem)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(99)),
              child: Text(r.temLimiteGeral ? 'Limite geral' : 'Soma das categorias', style: const TextStyle(color: branco, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 6),
        if (!tem) ...[
          const Text('Nenhum limite definido', style: TextStyle(color: branco, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Defina um teto para o mês inteiro, limites por categoria ou os dois.', style: TextStyle(color: t2, fontSize: 13)),
        ] else ...[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: brl(gasto), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.8)),
              TextSpan(text: '  de ${brl(lim)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t2)),
            ]), style: const TextStyle(color: branco)),
          ),
          const SizedBox(height: 10),
          Barra(uso, cor: uso > 1 ? const Color(0xFFFF9C8A) : branco, trilho: const Color(0x33FFFFFF)),
          const SizedBox(height: 12),
          Row(children: [
            _Num(resta >= 0 ? 'Pode gastar' : 'Passou', brl(resta.abs())),
            if (dias > 0 && resta > 0) _Num('Por dia', brl(resta / dias)),
            if (proj != null) _Num('No ritmo, fecha em', brl(proj)),
          ]),
          if (proj != null) ...[
            const SizedBox(height: 10),
            Text(
              proj > lim * 1.005
                  ? 'Mantendo o ritmo, você passa ${brl(proj - lim)} do limite. Para fechar dentro, gaste até ${brl(resta > 0 && dias > 0 ? resta / dias : 0)} por dia.'
                  : 'Mantendo o ritmo, sobram ${brl(lim - proj)} no fim do mês.',
              style: TextStyle(color: t2, fontSize: 12.5, height: 1.35),
            ),
          ],
          if (r.lim.sobraGeral > 0 && r.temLimiteGeral) ...[
            const SizedBox(height: 6),
            Text('Inclui ${brl(r.lim.sobraGeral)} que sobrou de ${mesLongo(ymAdd(r.ym, -1)).split(' ').first.toLowerCase()}.', style: TextStyle(color: t2, fontSize: 12)),
          ],
        ],
      ]),
    );
  }
}

class _Num extends StatelessWidget {
  final String rotulo, valor;
  const _Num(this.rotulo, this.valor);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rotulo, maxLines: 2, style: TextStyle(color: GH.texto2, fontSize: 11, height: 1.2)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
        ]),
      );
}

class _LinhaHistorico extends StatelessWidget {
  final MesLimite m;
  const _LinhaHistorico({required this.m});
  @override
  Widget build(BuildContext context) {
    final frac = m.limite > 0 ? m.gasto / m.limite : 0.0;
    final nome = mesesLongos[int.parse(m.ym.substring(5, 7)) - 1];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 74, child: Text('${nome.substring(0, 3)}/${m.ym.substring(2, 4)}', style: TextStyle(fontWeight: FontWeight.w600, color: G.texto2, fontSize: 13))),
        Expanded(child: Barra(frac, cor: m.dentro ? G.pos : G.neg, altura: 6)),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: Text(brl(m.gasto), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(width: 6),
        Icon(m.dentro ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 17, color: m.dentro ? G.pos : G.neg),
      ]),
    );
  }
}

Future<void> _salvarGeral(BuildContext context, {double? valor, bool? acumula}) async {
  final repo = RepoScope.ler(context);
  final atual = repo.limiteGeral;
  await repo.salvar({
    ...?atual?.d,
    'kind': 'limgeral',
    'id': 'limgeral',
    'valor': valor ?? atual?.valor ?? 0,
    'acumula': acumula ?? atual?.acumula ?? false,
  });
}

/// Pergunta o limite geral (com a média como sugestão) e salva.
Future<void> editarLimiteGeral(BuildContext context, {required double mediaTotal}) async {
  final repo = RepoScope.ler(context);
  final atual = repo.limiteGeral?.valor ?? 0;
  final v = await pedirLimite(context, titulo: 'Limite geral do mês', atual: atual > 0 ? atual : null, media: mediaTotal,
      explica: 'Um teto para tudo o que sair no mês, somando todas as categorias.');
  if (v == null || !context.mounted) return;
  await _salvarGeral(context, valor: v < 0 ? 0 : v);
}

/// Janela para digitar um limite. Devolve o valor, -1 para remover ou null se cancelou.
Future<double?> pedirLimite(BuildContext context, {required String titulo, double? atual, double media = 0, String? explica}) {
  final c = TextEditingController(text: atual != null ? valorCampo(atual) : '');
  final sug = media > 0 ? redondo(media) : 0.0;
  return showDialog<double?>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titulo),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (explica != null) ...[Text(explica, style: TextStyle(color: G.apagado, fontSize: 13)), const SizedBox(height: 12)],
        TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: const InputDecoration(prefixText: 'R\$ ', labelText: 'Limite por mês', hintText: '0,00'),
          onSubmitted: (t) => Navigator.pop(d, lerValor(t) ?? 0),
        ),
        if (sug > 0) ...[
          const SizedBox(height: 12),
          Text('Sua média nos últimos meses: ${brl(media)}', style: TextStyle(color: G.apagado, fontSize: 12.5)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final (rot, v) in [('Igual à média', sug), ('10% a menos', redondo(media * .9))])
              ActionChip(
                label: Text('$rot · ${brl(v)}'),
                labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: G.lavanda),
                onPressed: () => c.text = valorCampo(v),
              ),
          ]),
        ],
      ]),
      actions: [
        if (atual != null) TextButton(onPressed: () => Navigator.pop(d, -1.0), child: Text('Remover', style: TextStyle(color: G.neg))),
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(d, lerValor(c.text) ?? 0), child: const Text('Salvar')),
      ],
    ),
  );
}

class _LinhaLimite extends StatelessWidget {
  final Categoria cat;
  final double gasto, media;
  final double? limite, base;
  final String ym;
  const _LinhaLimite({required this.cat, required this.gasto, required this.limite, required this.base, required this.media, required this.ym});

  Future<void> _editar(BuildContext context) async {
    final v = await pedirLimite(context, titulo: cat.nome, atual: base, media: media);
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
    final proj = l != null ? projecaoMes(gasto, ym) : null;
    String sub;
    Color corSub = G.apagado;
    if (l == null) {
      sub = media > 0 ? 'Sem limite · média de ${brl(media)}/mês' : (gasto > 0 ? 'Sem limite · ${brl(gasto)} no mês' : 'Sem limite');
    } else if (passou) {
      sub = 'Passou ${brl(gasto - l)}';
      corSub = G.neg;
    } else if (proj != null && proj > l * 1.05) {
      sub = 'Restam ${brl(l - gasto)} · no ritmo, passa ${brl(proj - l)}';
      corSub = G.alerta;
    } else {
      sub = 'Restam ${brl(l - gasto)}${base != null && l > base! + .005 ? ' · com ${brl(l - base!)} de sobra' : ''}';
    }
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
                Barra(gasto / l, cor: passou ? G.neg : (gasto / l >= .8 ? G.alerta : cat.cor), altura: 5),
                const SizedBox(height: 4),
              ],
              Text(sub, style: TextStyle(fontSize: 12, color: corSub)),
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
