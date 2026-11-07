import 'package:flutter/material.dart';

import '../dados/modelos.dart';
import '../dados/planejar.dart';
import '../dados/resumo.dart';
import '../tema.dart';
import '../util/fmt.dart';
import '../widgets/comum.dart';
import '../widgets/formulario.dart';
import 'cartoes.dart';
import 'contas.dart';
import 'emprestimos.dart';

class TelaPlanejar extends StatelessWidget {
  final VoidCallback irLimites;
  const TelaPlanejar({super.key, required this.irLimites});

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ccs = cartoes(repo);
    final emps = emprestimos(repo);
    final emAberto = emps.where((e) => !dadosEmprestimo(repo, e).quitado).toList();
    final meta = repo.metaSobra;
    final r = ResumoMes.de(repo, ymDe(hojeIso()));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 130), children: [
      const CartaoRecebimentos(),
      const SizedBox(height: 14),
      const CartaoContas(),
      const SizedBox(height: 14),
      _Link(
        icone: Icons.credit_card_rounded,
        titulo: 'Cartões de crédito',
        sub: ccs.isEmpty ? 'Cadastre seus cartões e acompanhe as faturas' : '${ccs.length} cartão(ões) · faturas e parcelas',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaCartoes())),
      ),
      const SizedBox(height: 10),
      _Link(
        icone: Icons.track_changes_rounded,
        titulo: 'Meta de sobra do mês',
        sub: meta > 0 ? 'Guardar ${brl(meta)} por mês · este mês: ${brl(r.sobra)}' : 'Defina quanto quer que sobre no mês',
        progresso: meta > 0 ? r.sobra / meta : null,
        onTap: () => _editarMeta(context, meta),
      ),
      const SizedBox(height: 10),
      _Link(
        icone: Icons.tune_rounded,
        titulo: 'Limites de gastos',
        sub: r.limiteTotal > 0 ? '${brl(r.gastoComLimite)} de ${brl(r.limiteTotal)} em ${mesLongo(r.ym).toLowerCase()}' : 'Defina quanto quer gastar por categoria',
        onTap: irLimites,
      ),
      const SizedBox(height: 10),
      _Link(
        icone: Icons.handshake_rounded,
        titulo: 'Dinheiro emprestado',
        sub: emAberto.isEmpty
            ? (emps.isEmpty ? 'Controle o que você emprestou e as parcelas' : 'Tudo recebido')
            : '${emAberto.length} em aberto · faltam ${brl(emAberto.fold<double>(0, (a, e) => a + dadosEmprestimo(repo, e).falta))}',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaEmprestimos())),
      ),
    ]);
  }

  Future<void> _editarMeta(BuildContext context, double atual) async {
    final c = TextEditingController(text: atual > 0 ? valorCampo(atual) : '');
    final v = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Quanto você quer que sobre por mês?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Quando o que entrou menos o que saiu chegar nesse valor, o app mostra que você bateu a meta.', style: TextStyle(color: G.texto2)),
          const SizedBox(height: 12),
          CampoValor(c, autofocus: true, rotulo: 'Meta'),
        ]),
        actions: [
          if (atual > 0) TextButton(onPressed: () => Navigator.pop(d, 0.0), child: Text('Tirar meta', style: TextStyle(color: G.neg))),
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, lerValor(c.text) ?? 0), child: const Text('Salvar')),
        ],
      ),
    );
    if (v == null || !context.mounted) return;
    await RepoScope.ler(context).definirMeta(v < 0 ? 0 : (v * 100).round() / 100);
  }
}

class _Link extends StatelessWidget {
  final IconData icone;
  final String titulo, sub;
  final double? progresso;
  final VoidCallback onTap;
  const _Link({required this.icone, required this.titulo, required this.sub, required this.onTap, this.progresso});
  @override
  Widget build(BuildContext context) {
    return Cartao(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: G.lavandaFundo, borderRadius: BorderRadius.circular(14)),
          child: Icon(icone, color: G.lavandaIcone),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(color: G.apagado, fontSize: 12.5)),
            if (progresso != null) ...[
              const SizedBox(height: 8),
              Barra(progresso!, cor: progresso! >= 1 ? G.pos : G.lavanda, altura: 5),
            ],
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: G.apagado),
      ]),
    );
  }
}

/// Salário e vale: quando caem, se já caíram e o valor esperado.
class CartaoRecebimentos extends StatelessWidget {
  const CartaoRecebimentos({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final ag = agendaRecebimentos(repo);
    final rendas = {for (final r in repo.rendas) r.id: r};
    return Cartao(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const CabecalhoCartao('Próximos recebimentos'),
        if (ag.isNotEmpty) ...[
          Row(children: [
            for (final x in ag)
              Expanded(
                child: Column(children: [
                  Text(dataCurta(x.data), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(x.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: G.apagado, fontSize: 11.5)),
                  const SizedBox(height: 8),
                  Icon(x.recebido ? Icons.check_circle_rounded : (x.atrasado ? Icons.error_rounded : Icons.radio_button_unchecked_rounded),
                      color: x.recebido ? G.pos : (x.atrasado ? G.neg : G.lavanda), size: 20),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: G.v(0x14), borderRadius: BorderRadius.circular(99)),
                    child: Text(brl(x.valor), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: x.recebido ? G.pos : G.lavanda)),
                  ),
                ]),
              ),
          ]),
          const SizedBox(height: 14),
        ],
        CaixaLista([
          for (final t in tiposRenda) _LinhaRenda(tipo: t, r: rendas[t.id]),
        ]),
      ]),
    );
  }
}

class _LinhaRenda extends StatelessWidget {
  final TipoRenda tipo;
  final Renda? r;
  const _LinhaRenda({required this.tipo, required this.r});

  @override
  Widget build(BuildContext context) {
    final repo = RepoScope.of(context);
    final rr = r;
    final ym = ymDe(hojeIso());
    final st = rr != null && rr.valor > 0 ? statusRenda(repo, rr, ym) : null;
    final regra = rr == null ? '' : (rr.regra == 'util' ? 'último dia útil' : 'todo dia ${rr.dia}');
    return InkWell(
      onTap: () => abrirFolha(context, FormRenda(tipo: tipo, r: rr)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Icon(tipo.id == 'rd_salario' ? Icons.work_rounded : Icons.restaurant_menu_rounded, color: G.lavanda),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tipo.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                rr == null || rr.valor <= 0
                    ? 'Toque para informar o valor e o dia'
                    : st!.rec != null
                        ? 'Recebido em ${dataCurta(st.rec!.data)} · cai $regra'
                        : (st.dias < 0 ? 'Ainda não recebido (era ${dataCurta(st.data)})' : 'Cai em ${dataCurta(st.data)} · $regra'),
                style: TextStyle(color: st != null && st.rec == null && st.dias < 0 ? G.alerta : G.apagado, fontSize: 12.5),
              ),
              if (tipo.id == 'rd_salario' && rr != null && rr.mesSeguinte)
                Text('Conta como dinheiro do mês seguinte', style: TextStyle(color: G.lavanda, fontSize: 12)),
            ]),
          ),
          if (rr != null && rr.valor > 0) ...[
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(brl(rr.valor), style: const TextStyle(fontWeight: FontWeight.w800)),
              if (st != null && st.rec == null && st.dias <= 0)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(10, 28), padding: const EdgeInsets.symmetric(horizontal: 6)),
                  onPressed: () async {
                    await repo.salvar({
                      'kind': 'entrada',
                      'id': novoId('e'),
                      'desc': tipo.nome,
                      'valor': rr.valor,
                      'data': st.data,
                      'cat': tipo.cat,
                      'rd': tipo.id,
                      'criado': DateTime.now().millisecondsSinceEpoch,
                    });
                    if (context.mounted) avisar(context, '${tipo.nome} de ${brl(rr.valor)} lançado nas entradas.');
                  },
                  child: const Text('Marcar recebido', style: TextStyle(fontSize: 12.5)),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class FormRenda extends StatefulWidget {
  final TipoRenda tipo;
  final Renda? r;
  const FormRenda({super.key, required this.tipo, this.r});
  @override
  State<FormRenda> createState() => _FormRendaState();
}

class _FormRendaState extends State<FormRenda> {
  late final valorC = TextEditingController(text: widget.r != null && widget.r!.valor > 0 ? valorCampo(widget.r!.valor) : '');
  late String regra = widget.r?.regra ?? widget.tipo.regra;
  late int dia = widget.r?.dia ?? widget.tipo.dia;
  late bool mesSeg = widget.r?.mesSeguinte ?? false;

  @override
  void dispose() {
    valorC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sal = widget.tipo.id == 'rd_salario';
    return CorpoFolha([
      TituloFolha(widget.tipo.nome),
      const SizedBox(height: 12),
      CampoValor(valorC, rotulo: 'Valor que você recebe', grande: true),
      const Rotulo('Quando cai'),
      Opcoes<String>(itens: const [('util', 'Último dia útil do mês'), ('dia', 'Num dia fixo')], valor: regra, onMudar: (v) => setState(() => regra = v)),
      if (regra == 'dia') ...[const SizedBox(height: 12), CampoDia(dia: dia, rotulo: 'Dia do mês', onMudar: (v) => setState(() => dia = v))],
      if (sal)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: mesSeg,
          onChanged: (v) => setState(() => mesSeg = v),
          title: const Text('Salário conta no mês seguinte', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('O salário que cai no fim do mês vira dinheiro do mês seguinte no resumo.', style: TextStyle(color: G.apagado, fontSize: 12.5)),
        ),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: () async {
          final v = lerValor(valorC.text);
          if (v == null || v <= 0) {
            avisar(context, 'Informe o valor, como 3.500,00.');
            return;
          }
          await RepoScope.ler(context).salvar({
            ...?widget.r?.d,
            'kind': 'renda',
            'id': widget.tipo.id,
            'nome': widget.tipo.nome,
            'valor': (v * 100).round() / 100,
            'regra': regra,
            'dia': regra == 'util' ? null : dia,
            if (sal) 'mesSeg': mesSeg,
          });
          if (!context.mounted) return;
          Navigator.pop(context);
          avisar(context, '${widget.tipo.nome} salvo: cai ${regra == 'util' ? 'no último dia útil do mês' : 'todo dia $dia'}.');
        },
        child: const Text('Salvar'),
      ),
    ]);
  }
}
