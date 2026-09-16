import 'package:flutter/material.dart';
import '../models/pedido_model.dart';
import '../utils/ifood_event_utils.dart';
import 'darcapio/order_style.dart';
import 'food_order_brand.dart';

class OrderDeliveryInfo extends StatelessWidget {
  final PedidoModel order;
  final String status;
  const OrderDeliveryInfo(
      {super.key, required this.order, required this.status});

  static bool isPickupOrCounter(PedidoModel order) {
    if (IfoodEventUtils.normalize(order.orderType).contains('TAKEOUT')) {
      return true;
    }
    final address = order.delivery.deliveryAddress;
    final hasAddress = [
      address.streetName,
      address.streetNumber,
      address.neighborhood,
      address.city,
      address.postalCode
    ].any((value) => value.trim().isNotEmpty);
    return !hasAddress &&
        !IfoodEventUtils.isIfoodDelivery(order.delivery.deliveredBy) &&
        !IfoodEventUtils.isMerchantDelivery(order.delivery.deliveredBy);
  }

  @override
  Widget build(BuildContext context) {
    final pickup = isPickupOrCounter(order);
    final accent = FoodOrderBrand.colorOf(context);
    final address = order.delivery.deliveryAddress;
    return OrderPanel(
        title: 'Cliente e ${pickup ? 'retirada' : 'entrega'}',
        icon: Icons.person_outline,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(
                radius: 20,
                backgroundColor: accent.withValues(alpha: .08),
                child: Text(
                    order.customer.name.isEmpty
                        ? '?'
                        : order.customer.name.characters.first.toUpperCase(),
                    style:
                        TextStyle(color: accent, fontWeight: FontWeight.w700))),
            const SizedBox(width: 12),
            Expanded(
                child: Text(order.customer.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: OrderStyle.ink,
                        height: 1.5))),
          ]),
          if (order.customer.phone.number.isNotEmpty) ...[
            const SizedBox(height: 12),
            OrderMeta(Icons.phone_outlined, order.customer.phone.number),
          ],
          if (order.customer.phone.localizer.isNotEmpty) ...[
            const SizedBox(height: 6),
            OrderMeta(
                Icons.tag, 'Localizador ${order.customer.phone.localizer}'),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1, color: OrderStyle.line),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
                pickup ? Icons.storefront_outlined : Icons.location_on_outlined,
                size: 20,
                color: accent),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(pickup ? 'Retirada na loja' : 'Entrega no endereço',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: OrderStyle.ink)),
                  const SizedBox(height: 6),
                  if (pickup)
                    _line('O cliente retira o pedido no balcão.')
                  else if (IfoodEventUtils.isPlacedEvent(status))
                    _line('O endereço será exibido após o aceite do pedido.')
                  else ...[
                    _line([address.streetName, address.streetNumber]
                        .where((s) => s.isNotEmpty)
                        .join(', ')),
                    _line([address.neighborhood, address.city]
                        .where((s) => s.isNotEmpty)
                        .join(' · ')),
                    if (address.postalCode.isNotEmpty)
                      _line('CEP ${address.postalCode}'),
                    if (address.complement.isNotEmpty)
                      _line(address.complement),
                    if (address.reference.isNotEmpty)
                      _line('Referência: ${address.reference}'),
                  ],
                ])),
          ]),
        ]));
  }

  Widget _line(String text) => Text(text,
      style:
          const TextStyle(fontSize: 12, height: 1.6, color: OrderStyle.muted));
}
