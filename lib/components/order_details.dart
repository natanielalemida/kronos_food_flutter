import 'package:flutter/material.dart';
import 'package:kronos_food/components/order_delivery_info.dart';
import 'package:kronos_food/components/order_items.dart';
import 'package:kronos_food/components/order_payment_info.dart';
import 'package:kronos_food/components/order_timeline.dart';
import 'package:kronos_food/components/pedido_actions_buttons.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/controllers/pedidos_controller.dart';
import 'package:kronos_food/repositories/order_repository.dart';
import 'package:kronos_food/repositories/auth_repository.dart';

class OrderDetails extends StatefulWidget {
  final PedidosController controller;
  final VoidCallback onAcceptOrder;
  final VoidCallback onCancelOrder;
  final VoidCallback? onActionComplete;
  final Function? onRefreshPolling;

  const OrderDetails({
    super.key,
    required this.controller,
    required this.onAcceptOrder,
    required this.onCancelOrder,
    this.onActionComplete,
    this.onRefreshPolling,
  });

  @override
  State<OrderDetails> createState() => _OrderDetailsState();
}

class _OrderDetailsState extends State<OrderDetails> {
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(OrderDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualizar o pedido e status quando o widget for atualizado com novos dados
    // if (oldWidget.order.id != widget.order.id ||
    //     oldWidget.status != widget.status) {
    //   setState(() {
    //     _currentOrder = widget.order;
    //     _currentStatus = widget.status;

    //     // Garantir que pedidos cancelados sejam reconhecidos corretamente
    //     if (_checkIfCancelled(_currentOrder.status)) {
    //       _currentStatus = Consts.statusCancelled;
    //       print(
    //           '🔴 Pedido cancelado detectado em didUpdateWidget: ${_currentOrder.id}');
    //     }
    //   });
    // }
  }

  // Método auxiliar para verificar se um pedido está cancelado
  bool _checkIfCancelled(String status) {
    final upperStatus = status.toUpperCase();
    return upperStatus.contains('CAN') ||
        upperStatus.contains('CANCELLED') ||
        upperStatus.contains('CANCELLATION') ||
        upperStatus.contains('CANCEL');
  }

  // Método para atualizar o pedido após uma ação
  Future<void> _updateOrderDetails() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      // Obter token válido
      final authRepository = AuthRepository();
      final token = await authRepository.getValidAccessToken();

      if (token == null) {
        throw Exception("Token de acesso inválido ou expirado");
      }

      // Buscar os dados atualizados do pedido
      final orderRepository = OrderRepository(Consts.baseUrl, token);
      final updatedOrder = await orderRepository
          .getPedidoDetails(widget.controller.selectedPedido.value?.id ?? '');

      // Verificar especificamente por status de cancelamento
      final upperStatus = updatedOrder.status.toUpperCase();
      final isCancelled = upperStatus.contains('CAN') ||
          upperStatus.contains('CANCELLED') ||
          upperStatus.contains('CANCELLATION') ||
          upperStatus.contains('CANCEL');

      if (isCancelled) {
        print(
            '🔴 Pedido cancelado detectado: ${updatedOrder.id} - status: ${updatedOrder.status}');
        // Forçar o status para o código de cancelamento do aplicativo
        updatedOrder.statusCode = Consts.statusCancelled;
      }

      // Determinar o novo status mapeado antes da atualização do estado
      String newStatus = isCancelled
          ? Consts.statusCancelled
          : _mapStatusCode(updatedOrder.status);
      print(
          '🔄 Atualizando pedido: status API=${updatedOrder.status}, status mapeado=$newStatus');

      // Atualizar o estado com um novo objeto de pedido (importante para reatividade)
      setState(() {
        widget.controller.selectedPedido.value = updatedOrder;
        _isUpdating = false;
      });

      // Feedback para o usuário
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCancelled
              ? 'Pedido CANCELADO atualizado com sucesso'
              : 'Pedido atualizado com sucesso'),
          backgroundColor: isCancelled ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Erro ao atualizar detalhes do pedido: $e');
      setState(() {
        _isUpdating = false;
      });

      // Feedback de erro para o usuário
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Mapeamento de status para códigos usados no app
  String _mapStatusCode(String apiStatus) {
    // Esta função deve usar o mesmo mapeamento que é usado em seu controller
    // Por exemplo:
    final upperStatus = apiStatus.toUpperCase();

    // Verificação específica para cancelamento
    if (upperStatus.contains('CAN') ||
        upperStatus.contains('CANCELLED') ||
        upperStatus.contains('CANCELLATION') ||
        upperStatus.contains('CANCEL')) {
      print(
          '🔴 Status de cancelamento detectado em _mapStatusCode: $apiStatus');
      return Consts.statusCancelled;
    } else if (upperStatus.contains('PLC') || upperStatus.contains('PLACED')) {
      return Consts.statusPlaced;
    } else if (upperStatus.contains('CFM') ||
        upperStatus.contains('CONFIRMED') ||
        upperStatus.contains('STP') ||
        upperStatus.contains('PREPARATION')) {
      return Consts.statusConfirmed;
    } else if (upperStatus.contains('DSP') ||
        upperStatus.contains('DISPATCHED') ||
        upperStatus.contains('DISPATCH')) {
      return Consts.statusDispatched;
    } else if (upperStatus.contains('CON') ||
        upperStatus.contains('CONCLUDED') ||
        upperStatus.contains('COMPLETE')) {
      return Consts.statusConcluded;
    } else {
      return Consts.statusPlaced; // Status padrão se não puder determinar
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.selectedPedido.value == null) {
      return Center(
        child: Text(
          "Nenhum pedido selecionado",
          style: TextStyle(color: Colors.grey[700], fontSize: 16),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          color:
              Colors.grey[50], // Fundo sutilmente cinza para destacar os cards
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header com informações do pedido e botão de atualização
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Text(
                                  widget.controller.selectedPedido.value
                                          ?.displayId ??
                                      '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.controller.selectedPedido.value
                                          ?.customer.name ??
                                      "",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "Feito às ${_formatTime(widget.controller.selectedPedido.value?.createdAt ?? DateTime.now())}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "•",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Localizador",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.controller.selectedPedido.value?.customer
                                        .phone.localizer ??
                                    "",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "•",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      "via ${widget.controller.selectedPedido.value?.salesChannel ?? ""}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // const Icon(Icons.access_time,
                              //     size: 18, color: Colors.grey),
                              // const SizedBox(width: 6),
                              // Text(
                              //   "Entrega prevista: 01:34",
                              //   style: TextStyle(
                              //     fontSize: 14,
                              //     color: Colors.grey[700],
                              //   ),
                              // ),
                              // const SizedBox(width: 16),
                              // const Icon(Icons.star,
                              //     size: 18, color: Colors.amber),
                              // const SizedBox(width: 4),
                              // Text(
                              //   "1º pedido",
                              //   style: TextStyle(
                              //     fontSize: 14,
                              //     color: Colors.grey[700],
                              //   ),
                              // ),
                              // const SizedBox(width: 16),
                              const Icon(Icons.phone,
                                  size: 18, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                "${widget.controller.selectedPedido.value?.customer.phone.number ?? ""} ID: ${widget.controller.selectedPedido.value?.customer.phone.localizer ?? ""}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Timeline do pedido (agora horizontal)
                if (widget.controller.selectedPedido.value?.status !=
                        "SCHEDULED" &&
                    widget.controller.selectedPedido.value != null) ...[
                  OrderTimeline(
                    order: widget.controller.selectedPedido.value!,
                  ),
                ],

                const SizedBox(height: 20),

                // Botões de ação do pedido
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.touch_app, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          const Text(
                            "Ações do Pedido",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PedidoActionsButtons(
                        controller: widget.controller,
                        onRefreshPolling: widget.onRefreshPolling,
                        onActionComplete: () async {
                          await _updateOrderDetails();

                          if (widget.onActionComplete != null) {
                            widget.onActionComplete!();
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Informações da entrega
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: OrderDeliveryInfo(
                    order: widget.controller.selectedPedido.value!,
                    status:
                        widget.controller.selectedPedido.value?.status ?? "",
                  ),
                ),

                const SizedBox(height: 20),

                // Itens do pedido
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: OrderItems(
                    order: widget.controller.selectedPedido.value!,
                  ),
                ),

                const SizedBox(height: 20),

                // Informações de pagamento
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: OrderPaymentInfo(
                    order: widget.controller.selectedPedido.value!,
                    status:
                        widget.controller.selectedPedido.value?.status ?? "",
                  ),
                ),

                // Espaço no final para melhor experiência de rolagem
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // Indicador de carregamento sobreposto com animação de fade
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    dateTime =
        dateTime.toLocal(); // Garantir que a data esteja no fuso horário local
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  String _getStatusText(String status) {
    switch (status) {
      case Consts.statusPlaced:
        return "Novo Pedido";
      case Consts.statusConfirmed:
        return "Confirmado";
      case Consts.statusDispatched:
        return "Em Entrega";
      case Consts.statusConcluded:
        return "Concluído";
      case Consts.statusCancelled:
        return "Cancelado";
      case "SCHEDULED":
        return "Agendado";
      default:
        return "Status Desconhecido";
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case Consts.statusPlaced:
        return Colors.blue;
      case Consts.statusConfirmed:
        return Colors.green;
      case Consts.statusDispatched:
        return Colors.orange;
      case Consts.statusConcluded:
        return Colors.purple;
      case Consts.statusCancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
