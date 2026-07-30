import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/models/event_model.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/models/print_model.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/repositories/kronos_repository.dart';
import 'package:kronos_food/service/order_actions_service.dart';
import 'package:kronos_food/controllers/pedidos_controller.dart';
import 'package:kronos_food/utils/ifood_event_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PedidoActionsButtons extends StatefulWidget {
  final PedidosController controller;
  final Function onActionComplete;
  final Function? onRefreshPolling;

  const PedidoActionsButtons({
    super.key,
    required this.onActionComplete,
    required this.controller,
    this.onRefreshPolling,
  });

  @override
  State<PedidoActionsButtons> createState() => _PedidoActionsButtonsState();
}

class _PedidoActionsButtonsState extends State<PedidoActionsButtons> {
  final KronosRepository _kronosRepository = KronosRepository();
  late OrderActionsService _actionsService;
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastPedidoId;
  String? _lastPedidoStatus;

  @override
  void initState() {
    super.initState();
    _actionsService = OrderActionsService(AuthRepository());
    _captureSelectedPedidoState();
    widget.controller.selectedPedido.addListener(_handleSelectedPedidoChanged);
  }

  @override
  void didUpdateWidget(PedidoActionsButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.selectedPedido
          .removeListener(_handleSelectedPedidoChanged);
      widget.controller.selectedPedido
          .addListener(_handleSelectedPedidoChanged);
      _captureSelectedPedidoState();
      _clearErrorMessage();
    }
  }

  @override
  void dispose() {
    widget.controller.selectedPedido
        .removeListener(_handleSelectedPedidoChanged);
    super.dispose();
  }

  void _captureSelectedPedidoState() {
    final pedido = widget.controller.selectedPedido.value;
    _lastPedidoId = pedido?.id;
    _lastPedidoStatus = pedido?.status;
  }

  void _handleSelectedPedidoChanged() {
    final pedido = widget.controller.selectedPedido.value;
    final pedidoId = pedido?.id;
    final pedidoStatus = pedido?.status;
    final changed =
        pedidoId != _lastPedidoId || pedidoStatus != _lastPedidoStatus;

    _lastPedidoId = pedidoId;
    _lastPedidoStatus = pedidoStatus;

    if (changed) {
      _clearErrorMessage();
    }
  }

  void _clearErrorMessage() {
    if (!mounted || _errorMessage == null) return;
    setState(() => _errorMessage = null);
  }

  String? _visibleErrorMessage() {
    if (_errorMessage == null) return null;

    final status =
        widget.controller.selectedPedido.value?.status.toUpperCase() ?? "";
    final isConfirmed = status.contains("CFM") ||
        status.contains("CONFIRMED") ||
        status.contains("STP");
    final isKronosSyncError = _errorMessage!.contains("Object reference") ||
        _errorMessage!.contains("Erro na resposta");

    if (isConfirmed && isKronosSyncError) return null;

    return _errorMessage;
  }

  String _formatActionError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  String? _statusCodeForAction(String actionName) {
    if (actionName.contains('Entrega') || actionName.contains('Concluir')) {
      return 'CON';
    }
    if (actionName.contains('Confirma')) return 'CFM';
    if (actionName.contains('Pronto')) return 'RTP';
    if (actionName.contains('Despachar')) return 'DSP';
    if (actionName.contains('Cancelamento')) return 'CAN';
    return null;
  }

  String _merchantDeliveryNotice(PedidoModel pedido) {
    final status = IfoodEventUtils.normalize(pedido.status);

    if (status.contains('DSP') || status.contains('DISPATCHED')) {
      return 'Este pedido esta em entrega propria. A conclusao vem do iFood/cliente; o app apenas acompanha o status.';
    }

    if (status.contains('CON') || status.contains('CONCLUDED')) {
      return 'Este pedido de entrega propria ja foi concluido.';
    }

    if (status.contains('RTP') ||
        status.contains('READY_TO_PICKUP') ||
        status.contains('READY TO PICKUP')) {
      return 'Este pedido esta pronto para entrega propria. Use o despacho proprio quando a entrega sair.';
    }

    return 'Este pedido veio como entrega propria (MERCHANT). Use despacho proprio ou gere um pedido com Entrega iFood para testar mapa, entregador parceiro e codigo de coleta.';
  }

  bool _canRequestCancellation(PedidoModel? pedido) {
    if (pedido == null) return false;

    final status = IfoodEventUtils.normalize(pedido.status);
    final eventCodes = pedido.events
        .map((event) => IfoodEventUtils.normalize(
            event.code.isNotEmpty ? event.code : event.fullCode))
        .toList();
    final isMerchantDelivery =
        IfoodEventUtils.isMerchantDelivery(pedido.delivery.deliveredBy);
    final isInRoute = IfoodEventUtils.isInRouteEvent(status) ||
        eventCodes.any(IfoodEventUtils.isInRouteEvent);

    if (status.contains('HSD') || status.contains('HANDSHAKE')) return false;
    if (IfoodEventUtils.isFinishedEvent(status)) return false;
    if (eventCodes.any(IfoodEventUtils.isFinishedEvent)) return false;
    if (isInRoute && !isMerchantDelivery) return false;

    return status.contains('PLC') ||
        status.contains('PLACED') ||
        status.contains('CFM') ||
        status.contains('CONFIRMED') ||
        status.contains('STP') ||
        status.contains('PREPARATION') ||
        IfoodEventUtils.isReadyEvent(status) ||
        (isMerchantDelivery && isInRoute);
  }

  Future<void> _performAction(Future<bool> Function() action, String actionName,
      int? Codigo, String? NomeEntregador) async {
    if (_isLoading) return;

    developer.log("action: $actionName");

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await action();

      if (result) {
        final statusCode = _statusCodeForAction(actionName);
        final currentPedido = widget.controller.selectedPedido.value;

        if (statusCode != null && currentPedido != null) {
          setState(() {
            currentPedido.status = statusCode;
            if (NomeEntregador != null) {
              currentPedido.delivery.nomeEntregador = NomeEntregador;
            }
          });

          await _addEventForStatus(statusCode, Codigo);
          await widget.controller.atualizarPedido(currentPedido);
          widget.controller.queuePedidoCacheSave(currentPedido);
          widget.controller.selectedPedido.value = null;
          widget.controller.selectedPedido.value = currentPedido;
        }

        if (statusCode == 'CFM') {
          unawaited(_refreshAfterAction(actionName));
        } else {
          await _refreshAfterAction(actionName);
        }

        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted && statusCode == null) {
          setState(() {
            if (actionName == 'Confirmação') {
              widget.controller.selectedPedido.value?.status = 'CFM';
            } else if (actionName == 'Pronto para Retirada') {
              widget.controller.selectedPedido.value?.status = 'RTP';
            } else if (actionName == 'Despachar Pedido') {
              widget.controller.selectedPedido.value?.status = 'DSP';
            } else if (actionName == 'Confirmar Entrega') {
              widget.controller.selectedPedido.value?.status = 'CON';
            } else if (actionName == 'Concluir Pedido') {
              widget.controller.selectedPedido.value?.status = 'CON';
            } else if (actionName == 'Cancelamento') {
              widget.controller.selectedPedido.value?.status = 'CAN';
            } else {
              widget.controller.selectedPedido.value?.status =
                  widget.controller.selectedPedido.value?.status ?? '';
            }
          });

          if (actionName == 'Confirmação') {
            await _addEventForStatus('CFM', null);
          } else if (actionName == 'Pronto para Retirada') {
            await _addEventForStatus('RTP', null);
          } else if (actionName == 'Despachar Pedido') {
            await _addEventForStatus('DSP', Codigo);
          } else if (actionName == 'Confirmar Entrega') {
            await _addEventForStatus('CON', null);
          } else if (actionName == 'Concluir Pedido') {
            await _addEventForStatus('CON', null);
          } else if (actionName == 'Cancelamento') {
            await _addEventForStatus('CAN', null);
          }

          if (NomeEntregador != null) {
            widget.controller.selectedPedido.value?.delivery.nomeEntregador =
                NomeEntregador;
          }

          final currentPedido = widget.controller.selectedPedido.value;
          widget.controller.selectedPedido.value = null;
          widget.controller.selectedPedido.value = currentPedido;
          await widget.controller.atualizarPedido(currentPedido!);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$actionName realizada com sucesso!')),
        );
      } else {
        setState(() {
          _errorMessage = 'Falha ao realizar $actionName. Tente novamente.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro: ${_formatActionError(e)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshAfterAction(String actionName) async {
    try {
      if (widget.onRefreshPolling != null) {
        await widget.onRefreshPolling!();
      } else {
        await widget.controller.getPedidos();
      }

      final actionCompleteResult = widget.onActionComplete();
      if (actionCompleteResult is Future) {
        await actionCompleteResult;
      }
    } catch (e, stack) {
      developer.log(
        'Atualizacao pos-acao $actionName falhou: $e',
        stackTrace: stack,
      );
    }
  }

  Future<void> _showDeliveryPersonModal() async {
    final pedido = widget.controller.selectedPedido.value;
    if (pedido == null ||
        !IfoodEventUtils.isMerchantDelivery(pedido.delivery.deliveredBy)) {
      return;
    }

    var service = KronosRepository();
    var deliveryPersons = await service.getEntregadores();

    if (deliveryPersons.isEmpty) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Aviso'),
          content: const Text('Nenhum entregador disponível no momento.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return; // Sai da função
    }

    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>>? filteredDeliveryPersons =
        List.from(deliveryPersons);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Selecione o entregador",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {
                        filteredDeliveryPersons = deliveryPersons
                            .where((person) {
                              final name =
                                  person['Referencia'].toString().toLowerCase();
                              final code =
                                  person['Codigo'].toString().toLowerCase();
                              final search = value.toLowerCase();
                              return name.contains(search) ||
                                  code.contains(search);
                            })
                            .cast<Map<String, dynamic>>()
                            .toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Pesquisar por nome ou código',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredDeliveryPersons!.isEmpty
                        ? const Center(
                            child: Text('Nenhum entregador encontrado'))
                        : ListView.builder(
                            itemCount: filteredDeliveryPersons!.length,
                            itemBuilder: (context, index) {
                              final person = filteredDeliveryPersons![index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.delivery_dining,
                                    color: Colors.orange,
                                  ),
                                  title: Text(person['Referencia']),
                                  subtitle: Text('Código: ${person['Codigo']}'),
                                  onTap: () {
                                    Navigator.pop(context, person);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                    ),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((selectedPerson) async {
      searchController.dispose();

      if (selectedPerson != null && mounted) {
        developer.log(
          "Entregador selecionado: ${selectedPerson['Referencia']} (ID: ${selectedPerson['Codigo']})",
        );

        pedido.delivery.nomeEntregador = selectedPerson['Referencia'];
        widget.controller.selectedPedido.value?.delivery.nomeEntregador =
            selectedPerson['Referencia'];

        await _performAction(
            () => _actionsService.dispatchOrder(pedido.id),
            'Despachar Pedido',
            selectedPerson['Codigo'],
            selectedPerson['Referencia']);
      }
    });
  }

  Future<void> _showCancellationDialog() async {
    if (_isLoading) return;

    final pedido = widget.controller.selectedPedido.value;
    if (pedido == null || !_canRequestCancellation(pedido)) {
      setState(() {
        _errorMessage =
            'Cancelamento direto indisponivel para este status. Finalize o fluxo do pedido ou trate a excecao pelo painel iFood.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cancellationReasons = await _actionsService.getCancellationReasons(
          pedido.id);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (cancellationReasons.isEmpty) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancelamento indisponivel'),
            content: const Text(
              'O iFood nao retornou motivos validos de cancelamento para este pedido agora (HTTP 204). Isso normalmente acontece quando o pedido ja esta em um status em que o iFood nao permite cancelamento direto pela API, ou quando homologacao nao libera motivos para esse cenario.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final reason = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Motivo do cancelamento",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Selecione o motivo para cancelar este pedido:",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: cancellationReasons.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final reason = cancellationReasons[index];
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(reason),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.cancel_outlined,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reason['description'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'Código: ${reason['cancelCodeId']}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.grey.shade200,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        ),
      );

      if (reason != null) {
        final textController = TextEditingController();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Detalhes adicionais'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Motivo: ${reason['description']}'),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Detalhes (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Voltar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirmar Cancelamento'),
              ),
            ],
          ),
        );
        var statusBefore = widget.controller.selectedPedido.value?.status;
        if (confirmed == true) {
          await _performAction(
              () => _actionsService
                      .requestCancellation(
                    widget.controller.selectedPedido.value?.id ?? "",
                    reason['cancelCodeId'].toString(),
                    cancellationDescription: textController.text.isNotEmpty
                        ? textController.text
                        : null,
                  )
                      .then((value) {
                    if (value) {
                      widget.controller.selectedPedido.value?.status = 'CAN';
                      if (mounted) {
                        setState(() {
                          widget.controller.selectedPedido.value?.status =
                              'CAN';
                        });
                      }

                      debugPrint('✅ Notificação: $statusBefore');

                      // if (statusBefore!.contains("PLC") ||
                      //     statusBefore.contains("PLACED")) {
                      //   return true;
                      // }

                      var service = KronosRepository();
                      service
                          .cancelarPedido(
                              widget.controller.selectedPedido.value?.id,
                              reason['description'])
                          .then((value) {
                        return true;
                      });

                      return true;
                    } else {
                      return false;
                    }
                  }),
              'Cancelamento',
              null,
              null);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Erro ao obter motivos de cancelamento: ${e.toString()}';
      });
    }
  }

  bool _isOrderWithoutDelivery(PedidoModel? pedido) {
    if (pedido == null) return false;

    final deliveredBy = pedido.delivery.deliveredBy;
    if (IfoodEventUtils.isIfoodDelivery(deliveredBy) ||
        IfoodEventUtils.isMerchantDelivery(deliveredBy)) {
      return false;
    }

    final salesChannel = IfoodEventUtils.normalize(pedido.salesChannel);
    final orderType = IfoodEventUtils.normalize(pedido.orderType);
    final address = pedido.delivery.deliveryAddress;
    final hasAddress = address.streetName.trim().isNotEmpty ||
        address.streetNumber.trim().isNotEmpty ||
        address.neighborhood.trim().isNotEmpty ||
        address.city.trim().isNotEmpty ||
        address.postalCode.trim().isNotEmpty;

    return salesChannel.contains('TOTEM') ||
        orderType.contains('TAKEOUT') ||
        !hasAddress;
  }

  Future<bool> _completeOrderOnKronos(PedidoModel? pedido) async {
    if (pedido == null) return false;

    try {
      await _kronosRepository.sendConfirmar(pedido);
      return true;
    } catch (e, stack) {
      developer.log(
        'Falha ao finalizar pedido ${pedido.id} no Kronos: $e',
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> _addEventForStatus(String statusCode, int? Codigo) async {
    if (widget.controller.selectedPedido.value == null) return;

    final pedido = widget.controller.selectedPedido.value!;

    var instace = KronosRepository();
    if (statusCode == 'DSP') {
      var result = await instace.sendDespachar(pedido, Codigo);
      if (!result) return;
    }

    // if (statusCode == 'CFM') {
    //   await instace.addPedidoToCache(pedido);
    // }

    final prefs = await SharedPreferences.getInstance();
    final autoPrintEnabled = prefs.getBool(Consts.autoPrintKey) ?? false;

    if (statusCode == 'CFM' && autoPrintEnabled) {
      final pedidoToPrint = widget.controller.selectedPedido.value;
      unawaited(
        printReceiptOnceForStatus(pedidoToPrint, 'CFM').catchError((e, stack) {
          developer.log(
            'Impressao automatica do aceite falhou: $e',
            stackTrace: stack,
          );
        }),
      );
    }

    debugPrint('✅ Notificação ativada: ${statusCode}');

    final hasEvent = pedido.events.any((e) => e.code == statusCode);

    if (!hasEvent) {
      final newEvent = EventModel(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        code: statusCode,
        orderId: pedido.id,
        createdAt: DateTime.now(),
        salesChannel: pedido.salesChannel,
        merchantId: pedido.merchant.id,
      );

      pedido.events.add(newEvent);
      developer
          .log("✅ Evento adicionado localmente para o status: $statusCode");
    }
  }

  List<Widget> _buildActionButtons() {
    final buttons = <Widget>[];
    final status =
        widget.controller.selectedPedido.value?.status.toUpperCase() ?? "";

    if (status.contains("CAN") || status.contains("CANCELLED")) {
      return [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, color: Colors.red.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                "Este pedido foi cancelado e não pode ser alterado.",
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        )
      ];
    }

    if (status.contains("PLC") || status.contains("PLACED")) {
      buttons.add(
        ElevatedButton(
          onPressed: () async {
            await _performAction(() async {
              var sucess = await _actionsService.confirmOrder(
                  widget.controller.selectedPedido.value?.id ?? "");
              if (sucess) {
                final pedido = widget.controller.selectedPedido.value;
                if (pedido != null) {
                  pedido.status = 'CFM';
                  unawaited(
                    _kronosRepository.savePedidoToKronos(pedido).catchError(
                      (e, stack) {
                        developer.log(
                          'Pedido ${pedido.id} confirmado no iFood, mas a sincronizacao com Kronos falhou: $e',
                          stackTrace: stack,
                        );
                        return false;
                      },
                    ),
                  );
                }
              }
              return sucess;
            }, 'Confirmação', null, null);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text('Confirmar Pedido'),
        ),
      );
    }

    if (status.contains("CFM") ||
        status.contains("CONFIRMED") ||
        status.contains("STP")) {
      final pedido = widget.controller.selectedPedido.value;
      final isMerchantDelivery = IfoodEventUtils.isMerchantDelivery(
          pedido?.delivery.deliveredBy ?? '');

      buttons.add(
        ElevatedButton(
          onPressed: () async {
            if (isMerchantDelivery) {
              await _showDeliveryPersonModal();
            } else {
              await _performAction(
                  () => _actionsService.readyToPickup(pedido?.id ?? ''),
                  'Pronto para Retirada',
                  null,
                  null);
            }
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: isMerchantDelivery ? Colors.orange : Colors.teal,
              foregroundColor: Colors.white),
          child: Text(isMerchantDelivery
              ? 'Despachar entrega propria'
              : 'Marcar como Pronto'),
        ),
      );
    }

    if (status.contains("RTP") ||
        status.contains("READY_TO_PICKUP") ||
        status.contains("READY TO PICKUP")) {
      final pedido = widget.controller.selectedPedido.value;
      final isWithoutDelivery = _isOrderWithoutDelivery(pedido);

      if (isWithoutDelivery) {
        buttons.add(
          ElevatedButton.icon(
            onPressed: () async {
              await _performAction(
                () => _completeOrderOnKronos(pedido),
                'Concluir Pedido',
                null,
                null,
              );
            },
            icon: const Icon(Icons.done_all, size: 18),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            label: const Text('Concluir Pedido'),
          ),
        );
      } else if (IfoodEventUtils.isMerchantDelivery(
          pedido?.delivery.deliveredBy ?? '')) {
        buttons.add(
          ElevatedButton(
            onPressed: () async {
              await _showDeliveryPersonModal();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Despachar entrega propria'),
          ),
        );
      } else {
        buttons.add(
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delivery_dining,
                    color: Colors.teal.shade700, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    IfoodEventUtils.readyLabel(
                      pedido?.delivery.deliveredBy ?? '',
                      pedido?.orderType ?? '',
                    ),
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (_canRequestCancellation(widget.controller.selectedPedido.value)) {
      buttons.add(
        ElevatedButton(
          onPressed: _showCancellationDialog,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Cancelar Pedido'),
        ),
      );
    }

    if (buttons.isEmpty) {
      return [
        const Text(
          "Não há ações disponíveis para este pedido no estado atual.",
          style: TextStyle(fontStyle: FontStyle.italic),
        )
      ];
    }

    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    final visibleErrorMessage = _visibleErrorMessage();
    final pedido = widget.controller.selectedPedido.value;
    final isIfoodOwnDelivery = pedido != null &&
        IfoodEventUtils.isIfoodSalesChannel(pedido.salesChannel) &&
        IfoodEventUtils.isMerchantDelivery(pedido.delivery.deliveredBy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isIfoodOwnDelivery)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _merchantDeliveryNotice(pedido),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (visibleErrorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              visibleErrorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: _buildActionButtons(),
          ),
      ],
    );
  }
}
