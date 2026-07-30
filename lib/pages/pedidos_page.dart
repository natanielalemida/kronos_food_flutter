import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/components/ifood_chat_dialog.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/pages/config_page.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/repositories/kronos_repository.dart';
import 'package:kronos_food/service/order_actions_service.dart';
import 'package:kronos_food/service/preferences_service.dart';
import '../controllers/pedidos_controller.dart';
import 'package:kronos_food/components/order_list_section.dart';
import 'package:kronos_food/components/order_details.dart';
import 'package:kronos_food/components/order_kanban_board.dart';
import 'package:kronos_food/models/print_model.dart';

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
    Consts.statusReadyToPickup: true,
    Consts.statusDispatched: true,
    Consts.statusConcluded: true,
    Consts.statusCancelled: true,
  };
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Variáveis para os switches
  bool _autoAccept = false;
  bool _autoPrint = false;
  bool _kanbanMode = false;
  final PreferencesService _preferencesService = PreferencesService();
  final OrderActionsService _orderActionsService =
      OrderActionsService(AuthRepository());
  final KronosRepository _kronosRepository = KronosRepository();

  @override
  void initState() {
    super.initState();
    controller = PedidosController();
    controller.addListener(_handleControllerChanged);
    unawaited(controller.init(context));
    _loadPreferences();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _openUrgenciasEPendentes();
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerChanged);
    controller.dispose();
    super.dispose();
  }

  // Carrega as preferências salvas
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final kanbanMode = await _preferencesService.getKanbanMode();
    final autoAccept = prefs.getBool(Consts.autoAcceptKey) ?? false;
    final autoPrint = prefs.getBool(Consts.autoPrintKey) ?? false;
    setState(() {
      _autoAccept = autoAccept;
      _autoPrint = autoPrint;
      _kanbanMode = kanbanMode;
    });
    await controller.setAutoAcceptEnabled(autoAccept);
    await controller.setAutoPrintEnabled(autoPrint);
  }

  // Salva o estado do switch
  Future<void> _savePreference(String key, bool value) async {
    if (key == Consts.autoAcceptKey) {
      await controller.setAutoAcceptEnabled(value);
      return;
    }

    if (key == Consts.autoPrintKey) {
      await controller.setAutoPrintEnabled(value);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _handleOrderActionComplete(PedidoModel? order) {
    setState(() {
      controller.loadSavedPedidos();
      final selectedOrder = order ?? controller.selectedPedido.value;
      if (selectedOrder != null) {
        controller.getPedidoDetails(selectedOrder.id).then((updatedOrder) {
          if (updatedOrder != null && mounted) {
            setState(() {
              controller.selectedPedido.value = updatedOrder;
            });
            _openUrgenciasEPendentes();
          }
        });
      }
    });
  }

  Future<void> _openKanbanOrderDetails(
    PedidoModel order,
    String statusCode,
  ) async {
    controller.selectedPedido.value = order;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;

        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.width * 0.92,
              maxHeight: size.height * 0.9,
            ),
            child: Column(
              children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Consts.primaryColor,
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ValueListenableBuilder<PedidoModel?>(
                          valueListenable: controller.selectedPedido,
                          builder: (context, selectedOrder, _) {
                            final currentOrder = selectedOrder ?? order;
                            final currentStatus =
                                controller.mapApiStatusToCode(
                              currentOrder.status.isEmpty
                                  ? statusCode
                                  : currentOrder.status,
                            );

                            return Text(
                              'Pedido #${currentOrder.displayId} - $currentStatus',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: OrderDetails(
                    controller: controller,
                    onAcceptOrder: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Aceitacao em implementacao'),
                        ),
                      );
                    },
                    onCancelOrder: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cancelamento em implementacao'),
                        ),
                      );
                    },
                    onRefreshPolling: () => controller.getPedidos(),
                    onActionComplete: () => _handleOrderActionComplete(order),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleKanbanOrderAction(
    PedidoModel order,
    String statusCode,
    KanbanOrderAction action,
  ) async {
    switch (action) {
      case KanbanOrderAction.details:
      case KanbanOrderAction.openWorkflow:
        await _openKanbanOrderDetails(order, statusCode);
        break;
      case KanbanOrderAction.accept:
        await _acceptKanbanOrder(order);
        break;
    }
  }

  Future<void> _acceptKanbanOrder(PedidoModel order) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aceitando pedido #${order.displayId}...'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final success = await _orderActionsService.confirmOrder(order.id);
      if (!success) {
        throw Exception('iFood nao confirmou o aceite do pedido.');
      }

      order.status = Consts.statusConfirmed;
      controller.selectedPedido.value = order;
      await controller.atualizarPedido(order);
      controller.queuePedidoCacheSave(order);

      unawaited(_finishAcceptSideEffects(order));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido #${order.displayId} aceito com sucesso.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Falha ao aceitar pedido #${order.displayId}: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _finishAcceptSideEffects(PedidoModel order) async {
    try {
      try {
        await _kronosRepository.savePedidoToKronos(order);
      } catch (e) {
        debugPrint(
          'Pedido ${order.id} confirmado no iFood, mas nao sincronizou com Kronos: $e',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      final autoPrintEnabled = prefs.getBool(Consts.autoPrintKey) ?? false;
      if (autoPrintEnabled) {
        await printReceiptOnceForStatus(order, Consts.statusConfirmed);
      }

      await controller.getPedidos();
    } catch (e) {
      debugPrint('Pos-aceite do pedido ${order.id} falhou: $e');
    }
  }

  Future<void> _openIfoodChat() async {
    final widgetId = await _preferencesService.getIfoodWidgetId();
    final merchantId = await _preferencesService.getIfoodMerchantId();

    if (!mounted) return;

    if (widgetId == null || widgetId.isEmpty) {
      final goToConfig = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Configurar Chat iFood'),
          content: const Text(
            'Informe o Widget ID do iFood nas configuracoes para abrir o chat. Esse ID vem do Portal do Desenvolvedor iFood.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Depois'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Consts.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Abrir configuracoes'),
            ),
          ],
        ),
      );

      if (goToConfig == true && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ConfigPage()),
        );
      }
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IfoodChatDialog(
        merchantId: merchantId,
        widgetId: widgetId,
      ),
    );
  }

  // Abre automaticamente Pendentes/Urgências se houver pedidos novos
  void _openUrgenciasEPendentes() {
    bool hasNewPending =
        controller.pedidosMap[Consts.statusPlaced]?.isNotEmpty ?? false;
    bool hasNewUrgencias =
        controller.pedidosMap[Consts.statusDispatched]?.isNotEmpty ?? false;
    bool hasReadyOrders =
        controller.pedidosMap[Consts.statusReadyToPickup]?.isNotEmpty ?? false;

    if (hasNewPending || hasNewUrgencias || hasReadyOrders) {
      setState(() {
        // Fecha todas as seções
        _isExpanded.updateAll((key, _) => false);

        // Abre apenas Pendentes e Urgências
        if (hasNewPending) _isExpanded[Consts.statusPlaced] = true;
        if (hasReadyOrders) _isExpanded[Consts.statusReadyToPickup] = true;
        if (hasNewUrgencias) _isExpanded[Consts.statusDispatched] = true;
      });
    }
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
                    color: Colors.white.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.3))),
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
                                      color: controller.getMerchantStatusColor(
                                          controller.merchantStatus.value),
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
                  margin: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: 'Abrir chat iFood',
                    onPressed: _openIfoodChat,
                  ),
                ),
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
                      _openUrgenciasEPendentes();
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
                    onChanged: (bool value) async {
                      setState(() {
                        _autoAccept = value;
                      });
                      await _savePreference(Consts.autoAcceptKey, value);
                    },
                    secondary: const Icon(Icons.check_circle_outline),
                    activeThumbColor: Consts.primaryColor,
                  ),
                  SwitchListTile(
                    title: const Text('Imprimir automático'),
                    value: _autoPrint,
                    onChanged: (bool value) async {
                      setState(() {
                        _autoPrint = value;
                      });
                      await _savePreference(Consts.autoPrintKey, value);
                    },
                    secondary: const Icon(Icons.print_outlined),
                    activeThumbColor: Consts.primaryColor,
                  ),
                  SwitchListTile(
                    title: const Text('Modo kanban'),
                    subtitle: const Text('Visualizar pedidos em colunas'),
                    value: _kanbanMode,
                    onChanged: (bool value) {
                      setState(() {
                        _kanbanMode = value;
                        controller.selectedPedido.value = null;
                      });
                      _preferencesService.saveKanbanMode(value);
                    },
                    secondary: const Icon(Icons.view_kanban_outlined),
                    activeThumbColor: Consts.primaryColor,
                  ),
                ],
              ),
            ),
            body: ValueListenableBuilder<PedidoModel?>(
                valueListenable: controller.selectedPedido,
                builder: (context, value, c) {
                  if (_kanbanMode) {
                    return OrderKanbanBoard(
                      onTabChanged: () {
                        setState(() {
                          controller.selectedPedido.value = null;
                        });
                      },
                      orderTimming: controller.orderTimming,
                      pedidosMap: controller.pedidosMap,
                      onOrderSelected: _openKanbanOrderDetails,
                      onOrderAction: _handleKanbanOrderAction,
                      selectedOrderId: value?.id,
                    );
                  }

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
                            isExpanded: _isExpanded,
                            onExpansionChanged: (value, statusCode) {
                              setState(() {
                                // Fecha todas as seções
                                _isExpanded.updateAll((key, _) => false);
                                // Abre apenas a selecionada
                                _isExpanded[statusCode] = value;
                              });
                            },
                            orderTimming: controller.orderTimming,
                            pedidosMap: controller.pedidosMap,
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Aceitação em implementação')),
                                    );
                                  },
                                  onCancelOrder: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
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
                                          if (updatedOrder != null && mounted) {
                                            setState(() {
                                              value = updatedOrder;
                                            });
                                            _openUrgenciasEPendentes();
                                          }
                                        });
                                      }
                                    });
                                  },
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
      },
    );
  }
}
