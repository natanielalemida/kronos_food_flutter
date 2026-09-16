import 'package:flutter/material.dart';
import '../models/pedido_model.dart';
import '../utils/ifood_event_utils.dart';
import 'darcapio/order_style.dart';
import 'order_delivery_info.dart';

class OrderPaymentInfo extends StatelessWidget {
  final PedidoModel order;
  final String status;
  const OrderPaymentInfo(
      {super.key, required this.order, required this.status});
  @override
  Widget build(BuildContext context) => OrderPanel(
      title: 'Pagamento',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (IfoodEventUtils.isPlacedEvent(status))
          const Text(
              'As informações de pagamento serão exibidas após o aceite do pedido.',
              style: TextStyle(fontSize: 13, color: OrderStyle.muted))
        else ...[
          for (var i = 0; i < order.payments.methods.length; i++) ...[
            if (i > 0)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: OrderStyle.line)),
            _method(order.payments.methods[i]),
          ],
          if (order.payments.prepaid > 0) ...[
            const SizedBox(height: 16),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: OrderStyle.softTeal,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                    '${order.payments.prepaid == order.total.orderAmount ? 'Pago online' : 'Pré-pago parcial'}: '
                    '${OrderStyle.money(order.payments.prepaid)}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: OrderStyle.teal,
                        fontWeight: FontWeight.w600))),
          ],
          if (order.customer.documentNumber.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Documento na nota: ${order.customer.documentNumber}',
                style: const TextStyle(fontSize: 12, color: OrderStyle.ink)),
          ],
        ],
      ]));
  Widget _method(PaymentMethod method) {
    final offline = method.type.toUpperCase() == 'OFFLINE';
    final pickup = OrderDeliveryInfo.isPickupOrCounter(order);
    final change = method.cash.changeFor ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(_label(method.method),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: OrderStyle.ink))),
        const SizedBox(width: 10),
        Text(OrderStyle.money(method.value),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: OrderStyle.ink)),
      ]),
      if (method.card.brand.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(method.card.brand,
                style: const TextStyle(fontSize: 12, color: OrderStyle.muted))),
      const SizedBox(height: 10),
      Align(
          alignment: Alignment.centerLeft,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                  color:
                      offline ? const Color(0xFFFFF5E4) : OrderStyle.softTeal,
                  borderRadius: BorderRadius.circular(5)),
              child: Text(
                  offline
                      ? (pickup
                          ? 'Pagamento na retirada'
                          : 'Pagamento na entrega')
                      : 'Pagamento online',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: offline
                          ? const Color(0xFFA37629)
                          : OrderStyle.teal)))),
      if (offline && method.method.toUpperCase() == 'CASH') ...[
        const SizedBox(height: 16),
        if (change > 0) ...[
          _amount('Receber em dinheiro', change),
          const SizedBox(height: 10),
          _amount('Troco', change - method.value),
        ] else
          const Text('Sem troco solicitado.',
              style: TextStyle(fontSize: 12, color: OrderStyle.muted)),
      ],
      if (offline)
        const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Confira o pagamento ao entregar o pedido.',
                style: TextStyle(
                    fontSize: 11, height: 1.5, color: OrderStyle.muted))),
    ]);
  }

  Widget _amount(String label, num value) => Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: OrderStyle.muted))),
        Text(OrderStyle.money(value),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OrderStyle.ink))
      ]);
  String _label(String method) => switch (method.toUpperCase()) {
        'CREDIT' => 'Cartão de crédito',
        'DEBIT' => 'Cartão de débito',
        'CASH' => 'Dinheiro',
        'PIX' => 'Pix',
        'MEAL_VOUCHER' => 'Vale-refeição',
        'FOOD_VOUCHER' => 'Vale-alimentação',
        _ => method.isEmpty ? 'Forma de pagamento' : method,
      };
}
