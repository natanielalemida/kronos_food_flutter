import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/food_order_entry.dart';
import '../models/pedido_model.dart';
import '../utils/ifood_event_utils.dart';
import 'darcapio/order_style.dart';
import 'food_source_badge.dart';
import 'food_order_brand.dart';
import 'food_order_heading.dart';
import 'order_delivery_info.dart';
import 'order_items.dart';
import 'order_payment_info.dart';
import 'order_timeline.dart';

/// Layout shared with the Darcapio detail pattern; actions keep iFood's contract.
class IfoodOrderDetailsView extends StatelessWidget {
  final PedidoModel order;
  final Widget actions;
  final Widget? tracking;
  final Widget? alert;
  final VoidCallback onPrint;
  final bool printing;
  const IfoodOrderDetailsView(
      {super.key,
      required this.order,
      required this.actions,
      required this.onPrint,
      this.printing = false,
      this.tracking,
      this.alert});

  @override
  Widget build(BuildContext context) {
    final entry = FoodOrderEntry.ifood(order);
    final pickup = OrderDeliveryInfo.isPickupOrCounter(order);
    return FoodOrderBrand(
        source: FoodOrderSource.ifood,
        store: FoodOrderBrand.storeOf(context),
        child: LayoutBuilder(builder: (context, bounds) {
          final compact = bounds.maxWidth < 650;
          final inset = compact ? 16.0 : 28.0;
          final side =
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            OrderDeliveryInfo(order: order, status: order.status),
            const SizedBox(height: 20),
            OrderPaymentInfo(order: order, status: order.status),
          ]);
          return ColoredBox(
              color: OrderStyle.canvas,
              child: Column(children: [
                Expanded(
                    child: SingleChildScrollView(
                  key: PageStorageKey('ifood-detail-${order.id}'),
                  padding: EdgeInsets.all(inset),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FoodOrderHeading(
                                number: order.displayId,
                                source: FoodOrderSource.ifood,
                                status: entry.status,
                                statusLabel: entry.statusLabel,
                                onPrint: onPrint,
                                printing: printing),
                            const SizedBox(height: 16),
                            Wrap(spacing: 20, runSpacing: 8, children: [
                              OrderMeta(
                                  Icons.calendar_today_outlined,
                                  DateFormat("dd/MM/yyyy 'às' HH:mm")
                                      .format(order.createdAt.toLocal())),
                              OrderMeta(
                                  pickup
                                      ? Icons.storefront_outlined
                                      : Icons.delivery_dining,
                                  pickup ? 'Retirada' : 'Entrega'),
                              if (order.customer.phone.localizer.isNotEmpty)
                                OrderMeta(Icons.tag,
                                    'Localizador ${order.customer.phone.localizer}'),
                              const FoodSourceBadge(FoodOrderSource.ifood),
                              if (IfoodEventUtils.normalize(order.salesChannel)
                                  .contains('TOTEM'))
                                const OrderMeta(Icons.point_of_sale_outlined,
                                    'Pedido no totem'),
                            ]),
                            if (order.schedule.deliveryDateTimeStart !=
                                null) ...[
                              const SizedBox(height: 12),
                              OrderMeta(
                                  Icons.event_available_outlined,
                                  'Agendado: ${DateFormat('dd/MM HH:mm').format(order.schedule.deliveryDateTimeStart!.toLocal())}'
                                  '${order.schedule.deliveryDateTimeEnd == null ? '' : ' até ${DateFormat('HH:mm').format(order.schedule.deliveryDateTimeEnd!.toLocal())}'}'),
                            ],
                            const SizedBox(height: 24),
                            if (alert != null) ...[
                              alert!,
                              const SizedBox(height: 20)
                            ],
                            _fulfillment(pickup),
                            const SizedBox(height: 20),
                            OrderTimeline(order: order),
                            const SizedBox(height: 24),
                            if (bounds.maxWidth >= 920)
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        flex: 3,
                                        child: OrderItems(order: order)),
                                    const SizedBox(width: 20),
                                    Expanded(flex: 2, child: side),
                                  ])
                            else ...[
                              OrderItems(order: order),
                              const SizedBox(height: 20),
                              side
                            ],
                            if (tracking != null &&
                                !pickup &&
                                IfoodEventUtils.isIfoodDelivery(
                                    order.delivery.deliveredBy)) ...[
                              const SizedBox(height: 20),
                              Container(
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      border:
                                          Border.all(color: OrderStyle.line),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: tracking!),
                            ],
                          ]),
                    ),
                  ),
                )),
                Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(horizontal: inset, vertical: 16),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        border:
                            Border(top: BorderSide(color: OrderStyle.line))),
                    child: compact
                        ? actions
                        : Row(children: [
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Situação atual',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: OrderStyle.muted)),
                                  const SizedBox(height: 5),
                                  Text(entry.statusLabel,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: OrderStyle.ink)),
                                ]),
                            const SizedBox(width: 24),
                            Expanded(child: actions),
                          ])),
              ]));
        }));
  }

  Widget _fulfillment(bool pickup) {
    final color = pickup ? const Color(0xFF9B570F) : const Color(0xFF285CB0);
    final partner = IfoodEventUtils.isIfoodDelivery(order.delivery.deliveredBy);
    final courier = order.delivery.nomeEntregador.trim();
    return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: .25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Icon(
                  pickup ? Icons.storefront_outlined : Icons.delivery_dining,
                  size: 30,
                  color: color)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(pickup ? 'RETIRADA' : 'ENTREGA',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: color)),
                const SizedBox(height: 5),
                Text(
                    pickup
                        ? 'O cliente vem buscar este pedido no balcão.'
                        : partner
                            ? 'Entrega iFood · Entregador parceiro'
                            : 'Entrega própria · Entregador da loja',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: OrderStyle.ink)),
                if (!pickup && (courier.isNotEmpty || !partner)) ...[
                  const SizedBox(height: 10),
                  Text(
                      courier.isNotEmpty
                          ? 'Entregador: $courier'
                          : 'Selecione o entregador ao despachar o pedido.',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ],
              ])),
        ]));
  }
}
