import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/models/pedido_model.dart';
import '../controllers/pedidos_controller.dart';
import 'package:kronos_food/components/order_list_section.dart';
import 'package:kronos_food/components/order_details.dart';

class PedidosPage extends StatefulWidget {
  final String? orderIdSelected;

  const PedidosPage({super.key, this.orderIdSelected});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  late PedidosController controller;
  final Map<String, bool> _isExpanded = {
    Consts.statusPlaced: true,
    Consts.statusConfirmed: true,
    Consts.statusDispatched: true,
    Consts.statusConcluded: true,
    Consts.statusCancelled: true,
  };
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Variáveis para os switches
  bool _autoAccept = false;
  bool _autoPrint = false;

  @override
  void initState() {
    controller = PedidosController();
    controller.init(context);
    controller.addListener(() => setState(() {}));
    _loadPreferences();
    super.initState();
  }

  // Carrega as preferências salvas
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoAccept = prefs.getBool('auto_accept') ?? false;
      _autoPrint = prefs.getBool('auto_print') ?? false;
    });
  }

  // Salva o estado do switch
  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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
                    const Icon(Icons.error_outline, color: Colors.red, size: 64),
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
              key: _scaffoldKey,
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
                      Image.asset(
                        'assets/images/LOGO-KRONOS-food-icon-sync.png',
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
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
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
              drawer: Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const DrawerHeader(
                      decoration: BoxDecoration(
                        color: Consts.primaryColor,
                      ),
                      child: Text(
                        'Configurações',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Aceitar automático'),
                      value: _autoAccept,
                      onChanged: (bool value) {
                        setState(() {
                          _autoAccept = value;
                        });
                        _savePreference('auto_accept', value);
                      },
                      secondary: const Icon(Icons.check_circle_outline),
                      activeColor: Consts.primaryColor,
                    ),
                    SwitchListTile(
                      title: const Text('Imprimir automático'),
                      value: _autoPrint,
                      onChanged: (bool value) {
                        setState(() {
                          _autoPrint = value;
                        });
                        _savePreference('auto_print', value);
                      },
                      secondary: const Icon(Icons.print_outlined),
                      activeColor: Consts.primaryColor,
                    ),
                  ],
                ),
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
}