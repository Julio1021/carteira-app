import 'package:flutter/material.dart';

/// Categoria de gasto ou de entrada. Os ids e cores são os mesmos do site,
/// para os backups e o Drive continuarem compatíveis.
class Categoria {
  final String id;
  final String nome;
  final Color cor;
  final IconData icone;
  const Categoria(this.id, this.nome, this.cor, this.icone);
}

const categoriasGasto = <Categoria>[
  Categoria('moradia', 'Moradia', Color(0xFF8B5A2B), Icons.home_rounded),
  Categoria('contas', 'Contas da casa', Color(0xFF2F8FE8), Icons.bolt_rounded),
  Categoria('mercado', 'Mercado', Color(0xFF14A39A), Icons.shopping_cart_rounded),
  Categoria('alimentacao', 'Alimentação fora', Color(0xFFFF7A00), Icons.restaurant_rounded),
  Categoria('transporte', 'Transporte', Color(0xFF2456C8), Icons.directions_car_rounded),
  Categoria('saude', 'Saúde', Color(0xFFCC092F), Icons.favorite_rounded),
  Categoria('educacao', 'Educação', Color(0xFF820AD1), Icons.school_rounded),
  Categoria('lazer', 'Lazer', Color(0xFFE8467C), Icons.sentiment_very_satisfied_rounded),
  Categoria('compras', 'Compras', Color(0xFFC9A227), Icons.shopping_bag_rounded),
  Categoria('internet', 'Internet e TV', Color(0xFF3F6FD8), Icons.wifi_rounded),
  Categoria('recarga', 'Recarga de celular', Color(0xFFD4467F), Icons.smartphone_rounded),
  Categoria('assinaturas', 'Assinaturas', Color(0xFF00B5D8), Icons.subscriptions_rounded),
  Categoria('pets', 'Pets', Color(0xFF7CC242), Icons.pets_rounded),
  Categoria('cuidados', 'Cuidados pessoais', Color(0xFFB57BFF), Icons.spa_rounded),
  Categoria('impostos', 'Impostos e taxas', Color(0xFF7A7F87), Icons.account_balance_rounded),
  Categoria('cartao', 'Fatura de cartão', Color(0xFF5B6B8A), Icons.credit_card_rounded),
  Categoria('transferencias', 'Pix para pessoas', Color(0xFFA0785A), Icons.swap_horiz_rounded),
  Categoria('outros', 'Outros', Color(0xFF9A8F80), Icons.more_horiz_rounded),
];

const categoriasEntrada = <Categoria>[
  Categoria('salario', 'Salário', Color(0xFF1F9D6B), Icons.work_rounded),
  Categoria('beneficios', 'Vale-alimentação e benefícios', Color(0xFFE8A33A), Icons.restaurant_menu_rounded),
  Categoria('emprestimo', 'Devolução de empréstimo', Color(0xFF6D8FD6), Icons.handshake_rounded),
  Categoria('proprias', 'Transferências das suas contas', Color(0xFF4F8FD6), Icons.sync_alt_rounded),
  Categoria('pix', 'Pix e transferências recebidas', Color(0xFF2BB3A3), Icons.call_received_rounded),
  Categoria('reembolso', 'Reembolsos e estornos', Color(0xFF8A7BD6), Icons.replay_rounded),
  Categoria('rendimentos', 'Rendimentos e cashback', Color(0xFFC9A227), Icons.savings_rounded),
  Categoria('vendas', 'Vendas e serviços', Color(0xFFE0883A), Icons.storefront_rounded),
  Categoria('outros_e', 'Outras entradas', Color(0xFF8F9A92), Icons.add_card_rounded),
];

const formasPagamento = ['Pix', 'Débito', 'Crédito', 'Dinheiro', 'Boleto'];

final Map<String, Categoria> _g = {for (final c in categoriasGasto) c.id: c};
final Map<String, Categoria> _e = {for (final c in categoriasEntrada) c.id: c};

Categoria catGasto(String? id) => _g[id] ?? _g['outros']!;
Categoria catEntrada(String? id) => _e[id] ?? _e['outros_e']!;
