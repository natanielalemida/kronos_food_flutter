import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/darcapio_repository.dart';
import '../../models/food_order_entry.dart';
import '../food_source_badge.dart';
import '../food_order_heading.dart';
import 'order_style.dart';
import '../food_order_progress.dart';
import 'delivery_map.dart';

class DarcapioOrderDetails extends StatelessWidget {
  final DarcapioOrder order;
  final bool busy;
  final bool blocked;
  final ValueChanged<DarcapioAction> onAction;
  final VoidCallback? onBack;
  final VoidCallback? onChat;
  final DarcapioRepository? repository;
  const DarcapioOrderDetails(
      {super.key,
      required this.order,
      required this.busy,
      required this.blocked,
      required this.onAction,
      this.onBack,
      this.repository,
      this.onChat});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final compact = bounds.maxWidth < 650;
        final inset = compact ? 16.0 : 28.0;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: PageStorageKey('darcapio-detail-${order.id}'),
                  padding: EdgeInsets.all(inset),
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (onBack != null)
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                        onPressed: onBack,
                                        icon: const Icon(Icons.arrow_back,
                                            size: 18),
                                        label: const Text('Voltar à lista'))),
                              FoodOrderHeading(
                                  number:
                                      order.delivery.toString().padLeft(4, '0'),
                                  source: FoodOrderSource.darcapio,
                                  status: order.status,
                                  statusLabel: order.label),
                              const SizedBox(height: 14),
                              if (onChat != null)
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                        onPressed: busy ? null : onChat,
                                        icon: const Icon(Icons.forum_outlined),
                                        label: const Text(
                                            'Conversar com o cliente · Solicitações'))),
                              Wrap(spacing: 20, runSpacing: 8, children: [
                                OrderMeta(
                                    Icons.calendar_today_outlined,
                                    DateFormat("dd/MM/yyyy 'às' HH:mm")
                                        .format(order.created)),
                                OrderMeta(
                                    order.pickup
                                        ? Icons.storefront_outlined
                                        : Icons.delivery_dining,
                                    order.pickup ? 'Retirada' : 'Entrega'),
                                OrderMeta(Icons.sync_rounded,
                                    'Sincronizado no ERP · Delivery #${order.delivery.toString().padLeft(4, '0')}'),
                                const FoodSourceBadge(FoodOrderSource.darcapio),
                              ]),
                              const SizedBox(height: 24),
                              if (order.status == 'recebido_erp' ||
                                  order.cancellationReason != null) ...[
                                Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                        color: order.status == 'cancelado'
                                            ? const Color(0xFFFFEEEE)
                                            : const Color(0xFFFFF6E7),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Text(order.status == 'cancelado'
                                        ? order.cancellationReason!
                                        : 'Aceite em até 10 minutos após o envio. Sem aceite, o pedido será cancelado automaticamente.')),
                                const SizedBox(height: 20),
                              ],
                              fulfillment(),
                              const SizedBox(height: 20),
                              timeline(),
                              const SizedBox(height: 24),
                              if (bounds.maxWidth >= 920)
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 3, child: items()),
                                      const SizedBox(width: 20),
                                      Expanded(
                                          flex: 2,
                                          child: Column(children: [
                                            customer(),
                                            const SizedBox(height: 20),
                                            payment()
                                          ])),
                                    ])
                              else ...[
                                items(),
                                const SizedBox(height: 16),
                                customer(),
                                const SizedBox(height: 16),
                                payment(),
                              ],
                              const SizedBox(height: 12),
                            ]),
                      )),
                ),
              ),
              actionBar(compact, inset),
            ]);
      });

  Widget fulfillment() {
    final color =
        order.pickup ? const Color(0xFF9B570F) : const Color(0xFF285CB0);
    final dispatched =
        ['saiu_para_entrega', 'concluido'].contains(order.status);
    final courier = order.courierName?.trim();
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
                  order.pickup
                      ? Icons.storefront_outlined
                      : Icons.delivery_dining,
                  size: 30,
                  color: color)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(order.pickup ? 'RETIRADA' : 'ENTREGA',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: color)),
                const SizedBox(height: 5),
                Text(
                    order.pickup
                        ? 'O cliente vem buscar este pedido no balcão.'
                        : 'Entrega própria · Entregador da loja',
                    style: const TextStyle(
                        fontSize: 14,
                        color: OrderStyle.ink,
                        fontWeight: FontWeight.w600)),
                if (!order.pickup) ...[
                  const SizedBox(height: 10),
                  Text(
                      courier?.isNotEmpty == true
                          ? 'Entregador: $courier'
                          : dispatched
                              ? 'Entregador não informado neste pedido.'
                              : 'Selecione o entregador ao despachar o pedido.',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: courier?.isNotEmpty == true
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: color)),
                ],
              ])),
        ]));
  }

  Widget timeline() {
    if (order.status == 'cancelado') {
      return FoodOrderProgress(progress: 0, cancelled: true, steps: [
        FoodOrderProgressStep(
            label: 'Recebido',
            icon: Icons.receipt_long_outlined,
            color: OrderStyle.statusColor('recebido_erp'),
            time: order.created),
        FoodOrderProgressStep(
            label: 'Cancelado',
            icon: Icons.cancel_outlined,
            color: OrderStyle.statusColor('cancelado')),
      ]);
    }
    final steps = [
      ('Recebido', Icons.receipt_long_outlined, 'recebido_erp'),
      ('Aceito', Icons.check_circle_outline, 'aceito'),
      ('Em preparo', Icons.soup_kitchen_outlined, 'em_preparo'),
      ('Pronto', Icons.takeout_dining_outlined, 'pronto_entrega'),
      if (!order.pickup)
        ('Em entrega', Icons.delivery_dining, 'saiu_para_entrega'),
      ('Concluído', Icons.task_alt, 'concluido'),
    ];
    final stage = switch (order.status) {
      'recebido_erp' => 0,
      'aceito' => 1,
      'em_preparo' => 2,
      'pronto_retirada' || 'pronto_entrega' => 3,
      'saiu_para_entrega' => 4,
      'concluido' => steps.length - 1,
      _ => -1,
    };
    if (stage < 0) return const SizedBox.shrink();
    return FoodOrderProgress(
      progress: (stage + 1) / steps.length,
      steps: [
        for (var i = 0; i < steps.length; i++)
          FoodOrderProgressStep(
              label: steps[i].$1,
              icon: steps[i].$2,
              color: OrderStyle.statusColor(steps[i].$3),
              reached: i <= stage,
              time: i == 0 ? order.created : null),
      ],
    );
  }

  Widget items() => OrderPanel(
        title: 'Itens do pedido',
        icon: Icons.restaurant_menu,
        caption:
            '${order.items.length} ${order.items.length == 1 ? 'item' : 'itens'}',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var index = 0; index < order.items.length; index++) ...[
            if (index > 0)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(height: 1, color: OrderStyle.line)),
            item(order.items[index]),
          ],
          if (order.items.isEmpty)
            const Text('Os itens deste pedido ainda não foram informados.',
                style: TextStyle(color: OrderStyle.muted)),
          const SizedBox(height: 22),
          const Divider(height: 1, color: OrderStyle.line),
          const SizedBox(height: 16),
          amountLine('Subtotal dos itens', order.total - order.deliveryFee),
          if (!order.pickup) ...[
            const SizedBox(height: 10),
            amountLine('Taxa de entrega', order.deliveryFee)
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: OrderStyle.canvas,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Expanded(
                  child: Text('Total do pedido',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: OrderStyle.ink))),
              Text(OrderStyle.money(order.total),
                  style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: OrderStyle.teal,
                      letterSpacing: -.5)),
            ]),
          ),
        ]),
      );

  Widget item(Map<String, dynamic> item) {
    final quantity = darcapioField(item, 'quantidade');
    final unitPrice = darcapioField(item, 'valorUnitario');
    final description =
        darcapioField(item, 'descricao')?.toString() ?? 'Item do pedido';
    final note = darcapioField(item, 'observacao')?.toString().trim() ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: OrderStyle.canvas,
                borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.lunch_dining_outlined,
                color: OrderStyle.muted, size: 22)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${quantity ?? 1}× $description',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OrderStyle.ink,
                  height: 1.5)),
          if (unitPrice is num) ...[
            const SizedBox(height: 3),
            Text('${OrderStyle.money(unitPrice)} / un.',
                style: const TextStyle(fontSize: 12, color: OrderStyle.muted))
          ],
          for (final addition
              in darcapioField(item, 'adicionais') as List? ?? [])
            Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text('+ ${darcapioField(addition, 'descricao')}',
                    style: const TextStyle(
                        fontSize: 12, color: OrderStyle.muted))),
        ])),
      ]),
      if (note.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 13),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF8E8),
              borderRadius: BorderRadius.circular(8)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.edit_note, size: 18, color: Color(0xFFAF8133)),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Observação: $note',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8E6B30), height: 1.5))),
          ]),
        ),
    ]);
  }

  Widget customer() {
    final address = order.address;
    String value(String key) =>
        darcapioField(address, key)?.toString().trim() ?? '';
    final street = [value('rua'), value('numero')]
        .where((text) => text.isNotEmpty)
        .join(', ');
    final city = [
      value('bairro'),
      [value('cidade'), value('uf')]
          .where((text) => text.isNotEmpty)
          .join(' / ')
    ].where((text) => text.isNotEmpty).join(' · ');
    return OrderPanel(
        title: 'Cliente e ${order.pickup ? 'retirada' : 'entrega'}',
        icon: Icons.person_outline,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(
                radius: 20,
                backgroundColor: OrderStyle.softTeal,
                child: Text(
                    order.customer.isEmpty
                        ? '?'
                        : order.customer.characters.first.toUpperCase(),
                    style: const TextStyle(
                        color: OrderStyle.teal,
                        fontWeight: FontWeight.w700,
                        fontSize: 16))),
            const SizedBox(width: 12),
            Expanded(
                child: Text(order.customer,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: OrderStyle.ink,
                        height: 1.5))),
          ]),
          const SizedBox(height: 18),
          const Divider(height: 1, color: OrderStyle.line),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
                order.pickup
                    ? Icons.storefront_outlined
                    : Icons.location_on_outlined,
                size: 20,
                color: OrderStyle.teal),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(order.pickup ? 'Retirada' : 'Entrega',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: OrderStyle.ink)),
                  const SizedBox(height: 6),
                  if (order.pickup)
                    const Text('O cliente retira o pedido no balcão.',
                        style: TextStyle(
                            fontSize: 12, color: OrderStyle.muted, height: 1.6))
                  else ...[
                    if (street.isNotEmpty)
                      Text(street,
                          style: const TextStyle(
                              fontSize: 13,
                              color: OrderStyle.ink,
                              height: 1.6)),
                    if (city.isNotEmpty)
                      Text(city,
                          style: const TextStyle(
                              fontSize: 12,
                              color: OrderStyle.muted,
                              height: 1.6)),
                    if (value('cep').isNotEmpty)
                      Text('CEP ${value('cep')}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: OrderStyle.muted,
                              height: 1.6)),
                    if (value('complemento').isNotEmpty)
                      Text(value('complemento'),
                          style: const TextStyle(
                              fontSize: 12,
                              color: OrderStyle.muted,
                              height: 1.6)),
                  ],
                ])),
          ]),
          if (!order.pickup && repository != null)
            DarcapioDeliveryMapView(orderId: order.id, repository: repository!),
        ]));
  }

  Widget payment() => OrderPanel(
      title: 'Pagamento',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(order.payment,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: OrderStyle.ink,
                height: 1.5)),
        const SizedBox(height: 10),
        Align(
            alignment: Alignment.centerLeft,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF5E4),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(
                    order.pickup
                        ? 'Pagamento na retirada'
                        : 'Pagamento na entrega',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFA37629),
                        fontWeight: FontWeight.w600)))),
        const SizedBox(height: 18),
        if (order.needsChange && order.changeFor != null) ...[
          amountLine('Receber em dinheiro', order.changeFor!),
          const SizedBox(height: 12),
          amountLine('Troco', order.changeFor! - order.total),
        ] else
          const Text('Sem troco solicitado.',
              style: TextStyle(fontSize: 12, color: OrderStyle.muted)),
        const SizedBox(height: 16),
        const Text('Confira o pagamento ao entregar o pedido.',
            style:
                TextStyle(fontSize: 11, color: OrderStyle.muted, height: 1.5)),
      ]));

  Widget amountLine(String label, num value) => Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: OrderStyle.muted))),
        const SizedBox(width: 12),
        Text(OrderStyle.money(value),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OrderStyle.ink)),
      ]);

  Widget actionBar(bool compact, double inset) => Container(
        padding: EdgeInsets.symmetric(horizontal: inset, vertical: 18),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: OrderStyle.line))),
        child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 14,
            spacing: 20,
            children: [
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        order.actions.isEmpty
                            ? 'Status do pedido'
                            : 'Próxima etapa',
                        style: const TextStyle(
                            color: OrderStyle.muted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(order.label,
                        style: const TextStyle(
                            color: OrderStyle.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
              if (order.actions.isNotEmpty)
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final action in order.actions)
                    SizedBox(
                      width: compact ? 240 : 260,
                      child: FilledButton.icon(
                        onPressed:
                            busy || blocked ? null : () => onAction(action),
                        style: FilledButton.styleFrom(
                            backgroundColor: action.action == 'cancelar'
                                ? const Color(0xFFFFEBEE)
                                : OrderStyle.teal,
                            foregroundColor: action.action == 'cancelar'
                                ? const Color(0xFFB42318)
                                : Colors.white,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9))),
                        icon: Icon(
                            action.requiresCode
                                ? Icons.verified_outlined
                                : Icons.arrow_forward,
                            size: 18),
                        label: Text(
                            busy ? 'Aguardando confirmação...' : action.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                ]),
            ]),
      );
}

class DarcapioOrderEmpty extends StatelessWidget {
  const DarcapioOrderEmpty({super.key});

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: OrderStyle.line)),
                child: const Icon(Icons.receipt_long_outlined,
                    size: 38, color: OrderStyle.teal)),
            const SizedBox(height: 24),
            const Text('Vamos atender o próximo pedido?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: OrderStyle.ink,
                    letterSpacing: -.3)),
            const SizedBox(height: 10),
            const Text(
                'Selecione um pedido da lista para conferir os itens\ne acompanhar cada etapa do atendimento.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, height: 1.7, color: OrderStyle.muted)),
          ])));
}
