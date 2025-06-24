import 'package:flutter/material.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/models/pedido_model.dart';
import '../controllers/pedidos_controller.dart';
// Import components
import 'package:kronos_food/components/order_list_section.dart';
import 'package:kronos_food/components/order_details.dart';

class PedidosPage extends StatefulWidget {
  const PedidosPage({super.key});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  late PedidosController controller;
  // Controla o estado de expansão de cada seção
  final Map<String, bool> _isExpanded = {
    Consts.statusPlaced: true,
    Consts.statusConfirmed: true,
    Consts.statusDispatched: true,
    Consts.statusConcluded: true,
    Consts.statusCancelled: true,
  };

  @override
  void initState() {
    controller = PedidosController();
    controller.init(context);
    controller.addListener(() => setState(() {}));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          if (controller.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: Colors.red,
                ),
              ),
            );
          } else if (controller.haveError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 64),
                    const SizedBox(height: 24),
                    Text(
                      "Ocorreu um erro",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        controller.errorMsg,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        controller.init(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return Scaffold(
              appBar: AppBar(
                title: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.network(
                        'https://logodownload.org/wp-content/uploads/2017/05/ifood-logo-0.png',
                        height: 24,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.restaurant_menu,
                              color: Colors.white);
                        },
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Gerenciador de Pedidos",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              ListenableBuilder(
                                  listenable: controller.merchantStatus,
                                  builder: (context, child) {
                                    return Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: controller
                                            .getMerchantStatusColor(controller
                                                .merchantStatus.value),
                                      ),
                                    );
                                  }),
                              const SizedBox(width: 4),
                              Text(
                                controller.loja.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                backgroundColor: Consts.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Atualizar todos os pedidos',
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Atualizando pedidos...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        await controller.getPedidos();
                      },
                    ),
                  ),
                ],
              ),
              body: ValueListenableBuilder<PedidoModel?>(
                  valueListenable: controller.selectedPedido,
                  builder: (context, value, c) {
                    return Container(
                      color: Colors.grey[50],
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 320,
                            child: OrderListSection(
                              onTabChanged: () {
                                setState(() {
                                  controller.selectedPedido.value = null;
                                });
                              },
                              orderTimming: controller.orderTimming,
                              pedidosMap: controller.pedidosMap,
                              isExpanded: _isExpanded,
                              onExpansionChanged: (value, statusCode) {
                                setState(() {
                                  _isExpanded[statusCode] = value;
                                });
                              },
                              onOrderSelected: (order, status) {
                                controller.selectedPedido.value = order;
                              },
                              selectedOrderId: value?.id,
                            ),
                          ),
                          Expanded(
                            child: value != null
                                ? OrderDetails(
                                    controller: controller,
                                    onAcceptOrder: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Aceitação em implementação')),
                                      );
                                    },
                                    onCancelOrder: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Cancelamento em implementação')),
                                      );
                                    },
                                    onRefreshPolling: () =>
                                        controller.getPedidos(),
                                    onActionComplete: () {
                                      setState(() {
                                        controller.loadSavedPedidos();
                                        if (value != null) {
                                          controller
                                              .getPedidoDetails(value!.id)
                                              .then((updatedOrder) {
                                            if (updatedOrder != null &&
                                                mounted) {
                                              setState(() {
                                                value = updatedOrder;
                                                if (updatedOrder
                                                    .status.isNotEmpty) {}
                                              });
                                            }
                                          });
                                        }
                                      });
                                    },
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.receipt_long_outlined,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          "Nenhum pedido selecionado",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          "Selecione um pedido da lista para visualizar os detalhes",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  }),
            );
          }
        });
  }

  String _getStatusText(String status) {
    switch (status) {
      case Consts.statusPlaced:
        return "Pendente";
      case Consts.statusConfirmed:
        return "Confirmado";
      case Consts.statusDispatched:
        return "Despachado";
      case Consts.statusConcluded:
        return "Concluído";
      case Consts.statusCancelled:
        return "Cancelado";
      default:
        return status;
    }
  }
}
