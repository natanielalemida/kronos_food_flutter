import 'package:flutter/material.dart';
import 'package:kronos_food/controllers/pedidos_controller.dart';
import 'package:kronos_food/models/pedido_model.dart';

class OrderGroup extends StatelessWidget {
  final OrderTimming orderTimming;
  final String title;
  final List<PedidoModel> orders;
  final Color color;
  final String statusCode;
  final bool isExpanded;
  final Function(bool) onExpansionChanged;
  final Function(PedidoModel, String) onOrderSelected;
  final String? selectedOrderId;

  const OrderGroup({
    super.key,
    required this.orderTimming,
    required this.title,
    required this.orders,
    required this.color,
    required this.statusCode,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onOrderSelected,
    this.selectedOrderId,
  });

  @override
  Widget build(BuildContext context) {
    // Filtrar pedidos com base no tipo de agendamento selecionado
    var filteredOrders = orders
        .where((order) =>
            order.orderTiming ==
            (orderTimming == OrderTimming.immediate
                ? "IMMEDIATE"
                : "SCHEDULED"))
        .toList();

    // Se não houver pedidos, não mostrar nada
    if (filteredOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com controle de expansão
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom: Radius.circular(isExpanded ? 0 : 12),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom: Radius.circular(isExpanded ? 0 : 12),
              ),
              child: InkWell(
                onTap: () => onExpansionChanged(!isExpanded),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom: Radius.circular(isExpanded ? 0 : 12),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(12),
                      bottom: Radius.circular(isExpanded ? 0 : 12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "$title (${filteredOrders.length})",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: color,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: color,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Lista expansível de pedidos
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: !isExpanded
                ? const SizedBox.shrink()
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredOrders.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.grey.shade100,
                        ),
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index];
                          final isSelected = order.id == selectedOrderId;

                          // Calcular tempo desde a criação do pedido
                          final now = DateTime.now();
                          final difference = now.difference(order.createdAt);
                          final minutes = difference.inMinutes;
                          final hours = difference.inHours;

                          String timeAgo;
                          if (hours > 0) {
                            timeAgo = '$hours h';
                          } else {
                            timeAgo = '$minutes min';
                          }

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onOrderSelected(order, statusCode),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withOpacity(0.08)
                                      : Colors.transparent,
                                  border: Border(
                                    left: BorderSide(
                                      color: isSelected
                                          ? color
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
                                          Column(
                                            children: [
                                              if (order.orderType ==
                                                  "TAKEOUT") ...[
                                                Text(
                                                  "#${order.displayId} - RETIRADA",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: isSelected
                                                        ? color
                                                        : Colors.black87,
                                                  ),
                                                ),
                                              ] else ...[
                                                Text(
                                                  "#${order.displayId}",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: isSelected
                                                        ? color
                                                        : Colors.black87,
                                                  ),
                                                ),
                                              ]
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          if (statusCode == "PLC") ...[
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "${_formatTime(order.createdAt)} ($timeAgo)",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ] else if (statusCode == "CFM") ...[
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  size: 12,
                                                  color: Colors.blue[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "Entregar até ${_formatTime(order.delivery.deliveryDateTime)}",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blue[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ] else if (statusCode == "DSP") ...[
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.delivery_dining,
                                                  size: 12,
                                                  color: Colors.purple[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "Em entrega",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.purple[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),

                                    // Valor do pedido
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
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
                        },
                      ),
                    ),
                  ),
          ),

          // Espaço entre grupos
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    // Converter para horário local para evitar diferenças de fuso horário
    final localDateTime = dateTime.toLocal();
    return "${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}";
  }
}
