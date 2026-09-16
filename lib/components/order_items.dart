import 'package:flutter/material.dart';
import '../models/pedido_model.dart';
import 'darcapio/order_style.dart';
import 'food_order_brand.dart';

class OrderItems extends StatelessWidget {
  final PedidoModel order;
  const OrderItems({super.key, required this.order});
  @override
  Widget build(BuildContext context) => OrderPanel(
      title: 'Itens do pedido',
      icon: Icons.restaurant_menu,
      caption:
          '${order.items.length} ${order.items.length == 1 ? 'item' : 'itens'}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < order.items.length; i++) ...[
          if (i > 0)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1, color: OrderStyle.line)),
          _item(order.items[i]),
        ],
        if (order.items.isEmpty)
          const Text('Os itens deste pedido ainda não foram informados.'),
        const SizedBox(height: 22),
        const Divider(height: 1, color: OrderStyle.line),
        const SizedBox(height: 16),
        _amount('Subtotal dos itens', order.total.subTotal),
        _amount('Taxa de entrega', order.total.deliveryFee),
        if (order.total.additionalFees > 0)
          _amount('Taxas adicionais', order.total.additionalFees),
        for (final benefit in order.benefits)
          for (final sponsorship in benefit.sponsorshipValues)
            if (sponsorship.value > 0)
              _amount(
                  'Desconto · ${sponsorship.name == 'MERCHANT' ? 'Loja' : sponsorship.name}',
                  -sponsorship.value),
        const SizedBox(height: 10),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: OrderStyle.canvas,
                borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              const Expanded(
                  child: Text('Total do pedido',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: OrderStyle.ink))),
              const SizedBox(width: 12),
              Text(OrderStyle.money(order.total.orderAmount),
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: FoodOrderBrand.colorOf(context))),
            ])),
      ]));
  Widget _item(Item item) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: OrderStyle.canvas,
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.lunch_dining_outlined,
                  color: OrderStyle.muted, size: 23)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${item.quantity}× ${item.name}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: OrderStyle.ink)),
                const SizedBox(height: 5),
                Text('${OrderStyle.money(item.unitPrice)} / un.',
                    style:
                        const TextStyle(fontSize: 12, color: OrderStyle.muted)),
                for (final option in item.options)
                  Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                          '+ ${option.name}${option.quantity > 1 ? ' (${option.quantity}×)' : ''}'
                          '${option.price > 0 ? ' · ${OrderStyle.money(option.price)}' : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: OrderStyle.muted))),
              ])),
          const SizedBox(width: 8),
          Text(OrderStyle.money(item.totalPrice),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OrderStyle.ink)),
        ]),
        if (item.observations.isNotEmpty)
          Container(
              margin: const EdgeInsets.only(top: 13),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(8)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.edit_note, size: 18, color: Color(0xFFAF8133)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Observação: ${item.observations}',
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Color(0xFF8E6B30)))),
              ])),
      ]);
  Widget _amount(String label, num value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: OrderStyle.muted))),
        const SizedBox(width: 12),
        Text(OrderStyle.money(value),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: value < 0 ? OrderStyle.teal : OrderStyle.ink)),
      ]));
}
