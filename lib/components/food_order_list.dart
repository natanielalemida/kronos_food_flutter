import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/food_order_entry.dart';
import 'food_source_badge.dart';
import 'food_fulfillment_badge.dart';
import 'darcapio/order_style.dart';
import 'food_order_brand.dart';
import '../repositories/darcapio_repository.dart';

class FoodOrderList extends StatefulWidget {
  final List<FoodOrderEntry> orders;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final bool connected;
  final bool kanban;
  final Map<String, String> attention;
  final bool actionsEnabled;
  final bool initialShowAll;
  final bool automaticUpdates;
  final String searchHint;
  final void Function(FoodOrderEntry, DarcapioAction)? onOrderAction;
  const FoodOrderList(
      {super.key,
      required this.orders,
      required this.selectedId,
      required this.onSelected,
      required this.connected,
      this.kanban = false,
      this.attention = const {},
      this.actionsEnabled = true,
      this.initialShowAll = false,
      this.automaticUpdates = true,
      this.searchHint = 'Buscar nome ou nº do pedido',
      this.onOrderAction});

  @override
  State<FoodOrderList> createState() => _FoodOrderListState();
}

class _FoodOrderListState extends State<FoodOrderList> {
  final search = TextEditingController();
  late bool showAll = widget.initialShowAll;
  final Set<String> collapsed = {};

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.orders
        .where((order) => !['concluido', 'cancelado'].contains(order.status))
        .length;
    final query = search.text.trim().toLowerCase();
    final visible = widget.orders
        .where((order) =>
            (showAll || !['concluido', 'cancelado'].contains(order.status)) &&
            (query.isEmpty ||
                '${order.customer} ${order.displayId} ${order.source.label}'
                    .toLowerCase()
                    .contains(query)))
        .toList();
    final knownStatuses = OrderStyle.groups.expand((group) => group.$2).toSet();
    final ungrouped = visible
        .where((order) => !knownStatuses.contains(order.status))
        .toList();

    return ColoredBox(
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Row(children: [
            const Text('Pedidos',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: OrderStyle.ink,
                    letterSpacing: -.5)),
            const SizedBox(width: 10),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: OrderStyle.softTeal,
                    borderRadius: BorderRadius.circular(6)),
                child: Text('$active',
                    style: const TextStyle(
                        color: OrderStyle.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
            const Spacer(),
            const Icon(Icons.receipt_long_outlined,
                size: 22, color: OrderStyle.muted),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              hintStyle: const TextStyle(color: OrderStyle.muted, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: OrderStyle.muted),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: () => setState(search.clear),
                      icon: const Icon(Icons.close, size: 17)),
              isDense: true,
              filled: true,
              fillColor: OrderStyle.canvas,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: OrderStyle.teal)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Row(children: [
            Expanded(
                child: filter('Em andamento', active, !showAll,
                    () => setState(() => showAll = false))),
            const SizedBox(width: 8),
            Expanded(
                child: filter('Todos', widget.orders.length, showAll,
                    () => setState(() => showAll = true))),
          ]),
        ),
        const Divider(height: 1, color: OrderStyle.line),
        Expanded(
          child: visible.isEmpty
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.inbox_outlined,
                            color: OrderStyle.muted, size: 36),
                        SizedBox(height: 12),
                        Text('Nenhum pedido nesta lista.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: OrderStyle.muted))
                      ])))
              : widget.kanban
                  ? ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: [
                          for (final section in sections(visible, ungrouped))
                            SizedBox(
                                width: 330,
                                child: SingleChildScrollView(child: section)),
                        ])
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: sections(visible, ungrouped)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: OrderStyle.line))),
          child: Row(children: [
            Icon(
                !widget.automaticUpdates
                    ? Icons.history
                    : widget.connected
                        ? Icons.sync
                        : Icons.sync_problem,
                size: 15,
                color: widget.connected ? OrderStyle.teal : OrderStyle.muted),
            const SizedBox(width: 8),
            Text(
                !widget.automaticUpdates
                    ? 'Consulta do movimento'
                    : widget.connected
                        ? 'Atualização automática'
                        : 'Aguardando conexão',
                style: const TextStyle(fontSize: 11, color: OrderStyle.muted)),
          ]),
        ),
      ]),
    );
  }

  List<Widget> sections(
          List<FoodOrderEntry> visible, List<FoodOrderEntry> ungrouped) =>
      [
        for (final group in OrderStyle.groups)
          if (visible.any((order) => group.$2.contains(order.status)))
            groupSection(
                group.$1,
                group.$3,
                visible
                    .where((order) => group.$2.contains(order.status))
                    .toList()),
        if (ungrouped.isNotEmpty)
          groupSection('Outros pedidos', Icons.receipt_outlined, ungrouped),
      ];

  Widget filter(String label, int count, bool selected, VoidCallback onTap) =>
      Material(
        color: selected ? OrderStyle.softTeal : OrderStyle.canvas,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? OrderStyle.teal
                                : OrderStyle.muted))),
                const SizedBox(width: 6),
                Text('$count',
                    style: TextStyle(
                        fontSize: 11,
                        color: selected ? OrderStyle.teal : OrderStyle.muted)),
              ]),
            )),
      );

  Widget groupSection(
      String title, IconData icon, List<FoodOrderEntry> orders) {
    final color = OrderStyle.statusColor(orders.first.status);
    final expanded = !collapsed.contains(title);
    return Column(
        key: ValueKey('food-order-group-$title'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() =>
                expanded ? collapsed.add(title) : collapsed.remove(title)),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 20, 12),
                child: Row(children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(title,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color))),
                  Text('${orders.length}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(width: 8),
                  Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: OrderStyle.muted),
                ])),
          ),
          if (expanded)
            for (final order in orders) orderCard(order),
          const SizedBox(height: 4),
        ]);
  }

  Widget orderCard(FoodOrderEntry order) {
    final selected = order.key == widget.selectedId;
    final accent = FoodOrderBrand.colorFor(order.source);
    final accept = actionOf(order, 'aceitar');
    final reject = actionOf(order, 'cancelar');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        key: ValueKey(order.key),
        color: Color.alphaBlend(
            accent.withValues(alpha: selected ? .09 : .025), Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
                color: selected ? accent : accent.withValues(alpha: .22),
                width: selected ? 1.4 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onSelected(order.key),
          child: Container(
              decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: accent, width: 4))),
              child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Text('#${order.displayId}',
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(OrderStyle.money(order.total),
                              style: const TextStyle(
                                  color: OrderStyle.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              FoodFulfillmentBadge(pickup: order.pickup),
                              FoodSourceBadge(order.source)
                            ]),
                        const SizedBox(height: 8),
                        if (widget.attention[order.darcapioOrder?.id]
                            case final String notice)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('● $notice',
                                  style: const TextStyle(
                                      color: Color(0xFFB54708),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700))),
                        Text(order.customer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: OrderStyle.ink, fontSize: 13)),
                        const SizedBox(height: 11),
                        Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OrderStatusBadge(
                                  label: order.statusLabel,
                                  status: order.status),
                              OrderMeta(
                                  Icons.schedule,
                                  DateFormat('dd/MM · HH:mm')
                                      .format(order.created)),
                            ]),
                        if (accept != null || reject != null) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: OrderStyle.line),
                          const SizedBox(height: 10),
                          Row(children: [
                            if (reject != null)
                              Expanded(
                                  child: OutlinedButton.icon(
                                      key: ValueKey(
                                          '${order.key}-reject-action'),
                                      onPressed: widget.actionsEnabled &&
                                              widget.onOrderAction != null
                                          ? () => widget.onOrderAction!(
                                              order, reject)
                                          : null,
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Recusar'),
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFFB42318),
                                          side: const BorderSide(
                                              color: Color(0xFFF0B6B2)),
                                          visualDensity:
                                              VisualDensity.compact))),
                            if (reject != null && accept != null)
                              const SizedBox(width: 8),
                            if (accept != null)
                              Expanded(
                                  child: FilledButton.icon(
                                      key: ValueKey(
                                          '${order.key}-accept-action'),
                                      onPressed: widget.actionsEnabled &&
                                              widget.onOrderAction != null
                                          ? () => widget.onOrderAction!(
                                              order, accept)
                                          : null,
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Aceitar'),
                                      style: FilledButton.styleFrom(
                                          backgroundColor: OrderStyle.teal,
                                          visualDensity:
                                              VisualDensity.compact))),
                          ]),
                        ],
                      ]))),
        ),
      ),
    );
  }

  DarcapioAction? actionOf(FoodOrderEntry order, String code) {
    for (final action in order.darcapioOrder?.actions ?? const []) {
      if (action.action == code) return action;
    }
    return null;
  }
}
