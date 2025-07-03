import 'package:flutter/material.dart';
import 'package:kronos_food/components/order_group.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/controllers/pedidos_controller.dart';
import 'package:kronos_food/models/pedido_model.dart';

class OrderListSection extends StatelessWidget {
  final ValueNotifier<OrderTimming> orderTimming;
  final Map<String, List<PedidoModel>> pedidosMap;
  final Map<String, bool> isExpanded;
  final Function(bool, String) onExpansionChanged;
  final Function(PedidoModel, String) onOrderSelected;
  final void Function() onTabChanged;
  final String? selectedOrderId;

  const OrderListSection({
    super.key,
    required this.onTabChanged,
    required this.orderTimming,
    required this.pedidosMap,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onOrderSelected,
    this.selectedOrderId,
  });

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
        listenable: orderTimming,
        builder: (context, child) {
          final totalScheduledOrders = pedidosMap.values.fold<int>(
              0,
              (sum, list) =>
                  sum + list.where((p) => p.orderTiming == "SCHEDULED").length);

          final totalImmediateOrders = pedidosMap.values.fold<int>(
              0,
              (sum, list) =>
                  sum + list.where((p) => p.orderTiming == "IMMEDIATE").length);

          final scheduledOrders =
              pedidosMap.values.fold<List<PedidoModel>>([], (list, element) {
            list.addAll(element.where((e) => e.orderTiming == "SCHEDULED"));
            return list;
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho com título
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

              // Filtros de pedidos (Agora/Agendados)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFilterButton(
                        label: 'Agora',
                        count: totalImmediateOrders,
                        isActive: orderTimming.value == OrderTimming.immediate,
                        onTap: () {
                          if (orderTimming.value != OrderTimming.immediate) {
                            onTabChanged();
                            orderTimming.value = OrderTimming.immediate;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterButton(
                        label: 'Agendados',
                        count: totalScheduledOrders,
                        isActive: orderTimming.value == OrderTimming.scheduled,
                        onTap: () {
                          if (orderTimming.value != OrderTimming.scheduled) {
                            onTabChanged();
                            orderTimming.value = OrderTimming.scheduled;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // Lista de grupos de pedidos
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (orderTimming.value == OrderTimming.scheduled) ...[
                      ...scheduledOrders.map((order) {
                        final isSelected = order.id == selectedOrderId;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onOrderSelected(order, "SCHEDULED"),
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
                                  // Número e horário do pedido
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
                                      ],
                                    ),
                                  ),

                                  // Valor do pedido
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
                      // Sempre mostra todos os grupos, mesmo vazios
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

  // Método auxiliar para construir os grupos de pedidos
  Widget _buildOrderGroup({
    required String title,
    required String statusCode,
    required Color color,
    required IconData icon,
  }) {
    return OrderGroup(
      orderTimming: orderTimming.value,
      title: title,
      orders: pedidosMap[statusCode] ?? [],
      color: color,
      statusCode: statusCode,
      isExpanded: isExpanded[statusCode] ?? true,
      onExpansionChanged: (value) => onExpansionChanged(value, statusCode),
      onOrderSelected: onOrderSelected,
      selectedOrderId: selectedOrderId,
      icon: icon,
    );
  }

  // Widget para os botões de filtro
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