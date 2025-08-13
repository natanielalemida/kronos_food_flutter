import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kronos_food/components/order_group.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/controllers/pedidos_controller.dart';
import 'package:kronos_food/models/pedido_model.dart';

class OrderListSection extends StatefulWidget {
  final ValueNotifier<OrderTimming> orderTimming;
  final Map<String, List<PedidoModel>> pedidosMap;
  final Function(PedidoModel, String) onOrderSelected;
  final void Function() onTabChanged;
  final String? selectedOrderId;

  const OrderListSection({
    super.key,
    required this.onTabChanged,
    required this.orderTimming,
    required this.pedidosMap,
    required this.onOrderSelected,
    this.selectedOrderId,
  });

  @override
  State<OrderListSection> createState() => _OrderListSectionState();
}

class _OrderListSectionState extends State<OrderListSection> {
  late Map<String, bool> isExpanded;

  @override
  void initState() {
    super.initState();
    isExpanded = {
      Consts.statusDispute: false,
      Consts.statusPlaced: false,
      Consts.statusConfirmed: false,
      Consts.statusDispatched: false,
      Consts.statusConcluded: false,
      Consts.statusCancelled: false,
    };
  }

  void _handleExpansionChanged(bool expanded, String statusCode) {
    setState(() {
      // Fecha todos os grupos
      isExpanded.updateAll((key, value) => false);

      // Abre o selecionado se for expandir
      if (expanded) {
        isExpanded[statusCode] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListenableBuilder(
        listenable: widget.orderTimming,
        builder: (context, child) {
          final totalScheduledOrders = widget.pedidosMap.values.fold<int>(
            0,
            (sum, list) =>
                sum + list.where((p) => p.orderTiming == "SCHEDULED").length,
          );

          final totalImmediateOrders = widget.pedidosMap.values.fold<int>(
            0,
            (sum, list) =>
                sum + list.where((p) => p.orderTiming == "IMMEDIATE").length,
          );

          final scheduledOrders = widget.pedidosMap.values
              .fold<List<PedidoModel>>([], (list, element) {
            list.addAll(element.where((e) => e.orderTiming == "SCHEDULED"));
            return list;
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu),
                    SizedBox(width: 8),
                    Text(
                      'Pedidos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Filtros Agora / Agendados
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFilterButton(
                        label: 'Agora',
                        count: totalImmediateOrders,
                        isActive: widget.orderTimming.value ==
                            OrderTimming.immediate,
                        onTap: () {
                          if (widget.orderTimming.value !=
                              OrderTimming.immediate) {
                            widget.onTabChanged();
                            widget.orderTimming.value = OrderTimming.immediate;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterButton(
                        label: 'Agendados',
                        count: totalScheduledOrders,
                        isActive: widget.orderTimming.value ==
                            OrderTimming.scheduled,
                        onTap: () {
                          if (widget.orderTimming.value !=
                              OrderTimming.scheduled) {
                            widget.onTabChanged();
                            widget.orderTimming.value = OrderTimming.scheduled;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (widget.orderTimming.value ==
                        OrderTimming.scheduled) ...[
                      ...scheduledOrders.map((order) {
                        final isSelected =
                            order.id == widget.selectedOrderId;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => widget.onOrderSelected(
                              order,
                              "SCHEDULED",
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.grey.withOpacity(0.08)
                                    : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected
                                        ? Colors.grey
                                        : Colors.transparent,
                                    width: 4,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "#${order.displayId}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isSelected
                                                ? Colors.grey
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 12,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Pedido agendado",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (order.schedule
                                                    .deliveryDateTimeStart !=
                                                null &&
                                            order.schedule
                                                    .deliveryDateTimeEnd !=
                                                null) ...[
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 12,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Horário Agend: ${DateFormat('HH:mm').format(order.schedule.deliveryDateTimeStart!)} - ${DateFormat('HH:mm').format(order.schedule.deliveryDateTimeEnd!)}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "R\$ ${order.total.orderAmount.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (order.items.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            "${order.items.length} ${order.items.length == 1 ? 'item' : 'itens'}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      })
                    ] else ...[
                      if ((widget.pedidosMap[Consts.statusDispute]?.length ??
                              0) >
                          0)
                        _buildOrderGroup(
                          title: 'Urgencias',
                          statusCode: Consts.statusDispute,
                          color: const Color.fromARGB(255, 214, 180, 28),
                          icon: Icons.fast_forward,
                        ),
                      if ((widget.pedidosMap[Consts.statusPlaced]?.length ??
                              0) >
                          0)
                        _buildOrderGroup(
                          title: 'Pendentes',
                          statusCode: Consts.statusPlaced,
                          color: Colors.orange,
                          icon: Icons.access_time,
                        ),
                      _buildOrderGroup(
                        title: 'Confirmados',
                        statusCode: Consts.statusConfirmed,
                        color: Colors.blue,
                        icon: Icons.check_circle_outline,
                      ),
                      _buildOrderGroup(
                        title: 'Despachados',
                        statusCode: Consts.statusDispatched,
                        color: Colors.purple,
                        icon: Icons.local_shipping,
                      ),
                      _buildOrderGroup(
                        title: 'Concluídos',
                        statusCode: Consts.statusConcluded,
                        color: Colors.green,
                        icon: Icons.done_all,
                      ),
                      _buildOrderGroup(
                        title: 'Cancelados',
                        statusCode: Consts.statusCancelled,
                        color: Colors.red,
                        icon: Icons.cancel,
                      ),
                    ]
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderGroup({
    required String title,
    required String statusCode,
    required Color color,
    required IconData icon,
  }) {
    return OrderGroup(
      orderTimming: widget.orderTimming.value,
      title: title,
      orders: widget.pedidosMap[statusCode] ?? [],
      color: color,
      statusCode: statusCode,
      isExpanded: isExpanded[statusCode] ?? false,
      onExpansionChanged: (value) =>
          _handleExpansionChanged(value, statusCode),
      onOrderSelected: widget.onOrderSelected,
      selectedOrderId: widget.selectedOrderId,
      icon: icon,
    );
  }

  Widget _buildFilterButton({
    required String label,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? Consts.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Consts.primaryColor : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Consts.primaryColor : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Consts.primaryColor : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
