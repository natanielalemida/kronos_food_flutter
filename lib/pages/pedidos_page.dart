import 'dart:async';
import 'dart:io';
import 'food_orders_view.dart';
import 'couriers_page.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/components/ifood_chat_dialog.dart';
import 'package:kronos_food/components/ifood_connection_dialog.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/pages/config_page.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'package:kronos_food/repositories/kronos_repository.dart';
import 'package:kronos_food/service/order_actions_service.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:kronos_food/utils/app_logger.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/pedidos_controller.dart';
import 'package:kronos_food/components/order_details.dart';
import 'package:kronos_food/models/print_model.dart';

class PedidosPage extends StatefulWidget {
  final String? orderIdSelected;
  final PedidosController? controller;
  final DarcapioRepository? darcapioRepository;
  final AuthRepository? ifoodAuthRepository;

  const PedidosPage({
    super.key,
    this.orderIdSelected,
    this.controller,
    this.darcapioRepository,
    this.ifoodAuthRepository,
  });

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  late PedidosController controller;
  // Variáveis para os switches
  bool _autoAccept = false;
  bool _autoPrint = false;
  bool _kanbanMode = false;
  bool _isSharingLogs = false;
  bool _initialSelectionApplied = false;
  bool _connectingIfood = false;
  final PreferencesService _preferencesService = PreferencesService();
  final OrderActionsService _orderActionsService =
      OrderActionsService(AuthRepository());
  final KronosRepository _kronosRepository = KronosRepository();

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? PedidosController();
    controller.addListener(_handleControllerChanged);
    unawaited(controller.init(context));
    _loadPreferences();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    if (!_initialSelectionApplied && widget.orderIdSelected != null) {
      final order = controller.pedidosMap.values
          .expand((orders) => orders)
          .where((order) => order.id == widget.orderIdSelected)
          .firstOrNull;
      if (order != null) {
        _initialSelectionApplied = true;
        controller.selectedPedido.value = order;
      }
    }
    setState(() {});
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
    if (!mounted) return;
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

  Future<void> _connectIfood() async {
    if (_connectingIfood || controller.isLoading) return;
    setState(() => _connectingIfood = true);
    try {
      final authorized = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => IfoodConnectionDialog(
          repository: widget.ifoodAuthRepository ?? AuthRepository(),
        ),
      );
      if (authorized == true && mounted) await controller.init(context);
    } finally {
      if (mounted) setState(() => _connectingIfood = false);
    }
  }

  Future<void> _shareLogs() async {
    if (_isSharingLogs) return;

    setState(() {
      _isSharingLogs = true;
    });

    try {
      await AppLogger.info(
        'Compartilhamento do arquivo de logs solicitado.',
        category: 'DIAGNOSTICS',
        status: 'SHARE_REQUESTED',
      );
      await AppLogger.flush();

      final logPath = await AppLogger.logPath;
      final logFile = File(logPath);
      if (!await logFile.exists() || await logFile.length() == 0) {
        throw const FileSystemException(
          'O arquivo de logs ainda não foi criado.',
        );
      }

      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Compartilhar logs do Kronos Food',
          subject: 'Logs de diagnóstico do Kronos Food',
          text: 'Arquivo de diagnóstico gerado pelo Kronos Food.',
          files: [XFile(logPath, mimeType: 'text/plain')],
        ),
      );

      await AppLogger.status(
        'Painel de compartilhamento de logs finalizado.',
        category: 'DIAGNOSTICS',
        status: 'SHARE_${result.status.name.toUpperCase()}',
        data: {'shareResult': result.status.name},
      );

      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs compartilhados com sucesso.')),
        );
      } else if (result.status == ShareResultStatus.unavailable &&
          Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', logPath]);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'O compartilhamento não está disponível. O arquivo foi selecionado no Explorer.',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      await AppLogger.error(
        'Falha ao compartilhar o arquivo de logs.',
        category: 'DIAGNOSTICS',
        status: 'SHARE_ERROR',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível compartilhar os logs.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharingLogs = false;
        });
      }
    }
  }

  void _handleOrderActionComplete(PedidoModel? order) {
    setState(() {
      controller.loadSavedPedidos();
      final selectedOrder = order ?? controller.selectedPedido.value;
      if (selectedOrder != null) {
        controller.getPedidoDetails(selectedOrder.id).then((updatedOrder) {
          if (updatedOrder != null &&
              mounted &&
              controller.selectedPedido.value?.id == selectedOrder.id) {
            setState(() {
              controller.selectedPedido.value = updatedOrder;
            });
          }
        });
      }
    });
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

  Widget _buildDrawer() => Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Consts.primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Kronos Food',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Gestão da loja e preferências',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delivery_dining_outlined),
              title: const Text('Entregadores'),
              subtitle: const Text('Convidar e gerenciar acessos ao app'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => CouriersPage(
                            repository: widget.darcapioRepository)));
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.link_outlined),
              title: const Text('Conectar iFood'),
              subtitle: const Text('Autorizar ou reconectar a loja'),
              enabled: !_connectingIfood && !controller.isLoading,
              onTap: () {
                Navigator.pop(context);
                unawaited(_connectIfood());
              },
            ),
            SwitchListTile(
              title: const Text('Aceitar automático'),
              subtitle: const Text('Preferência geral de recebimento'),
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
              subtitle: const Text('Preferência geral de impressão'),
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
              subtitle: const Text('Organizar iFood e Darcapio em colunas'),
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
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Compartilhar logs'),
              subtitle: const Text('Enviar arquivo de diagnóstico'),
              trailing: _isSharingLogs
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              enabled: !_isSharingLogs,
              onTap: _isSharingLogs ? null : _shareLogs,
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller.merchantStatus,
        builder: (context, _) => FoodOrdersView(
          repository: widget.darcapioRepository,
          ifoodOrders:
              controller.pedidosMap.values.expand((orders) => orders).toList(),
          ifoodLoading: controller.isLoading,
          onConnectIfood: _connectingIfood ? null : _connectIfood,
          ifoodConnected: !controller.isLoading &&
              !controller.haveError &&
              controller.merchantStatus.value != MerchantStatus.error,
          kanban: _kanbanMode,
          initialOrderKey: widget.orderIdSelected == null
              ? null
              : 'ifood-order-${widget.orderIdSelected!}',
          onIfoodSelected: (order) => controller.selectedPedido.value = order,
          ifoodDetailsBuilder: (order) => OrderDetails(
            key: ValueKey('ifood-details-${order.id}'),
            controller: controller,
            onAcceptOrder: () => _acceptKanbanOrder(order),
            onCancelOrder: () {},
            onRefreshPolling: () => controller.getPedidos(),
            onActionComplete: () => _handleOrderActionComplete(order),
          ),
          onRefreshIfood: () async {
            if (controller.haveError) {
              await controller.init(context);
            } else {
              await controller.getPedidos();
            }
          },
          drawer: _buildDrawer(),
          additionalActions: [
            IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Abrir chat iFood',
                onPressed: _openIfoodChat),
          ],
        ),
      );
}
