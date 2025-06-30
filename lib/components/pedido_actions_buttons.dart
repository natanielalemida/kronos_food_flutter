import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:kronos_food/models/event_model.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/repositories/kronos_repository.dart';
import 'package:kronos_food/service/order_actions_service.dart';
import 'package:kronos_food/controllers/pedidos_controller.dart';

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
  final PedidosController _pedidosController = PedidosController();

  @override
  void initState() {
    super.initState();
    _actionsService = OrderActionsService(AuthRepository());
    widget.controller.selectedPedido.value?.status ?? "";
  }

  @override
  void didUpdateWidget(PedidoActionsButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _performAction(
      Future<bool> Function() action, String actionName, int? Codigo) async {
    if (_isLoading) return;

    developer.log("action: ${actionName}");

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await action();

      if (result) {
        if (widget.onRefreshPolling != null) {
          await widget.onRefreshPolling!();
        } else {
          await _pedidosController.getPedidos();
        }

        widget.onActionComplete();

        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() {
            if (actionName == 'Confirmação') {
              widget.controller.selectedPedido.value?.status = 'CFM';
            } else if (actionName == 'Despachar Pedido') {
              widget.controller.selectedPedido.value?.status = 'DSP';
            } else if (actionName == 'Cancelamento') {
              widget.controller.selectedPedido.value?.status = 'CAN';
            } else {
              widget.controller.selectedPedido.value?.status =
                  widget.controller.selectedPedido.value?.status ?? '';
            }
          });

          if (actionName == 'Confirmação') {
            await _addEventForStatus('CFM', null);
          } else if (actionName == 'Despachar Pedido') {
            await _addEventForStatus('DSP', Codigo);
          } else if (actionName == 'Cancelamento') {
            await _addEventForStatus('CAN', null);
          }

          final currentPedido = widget.controller.selectedPedido.value;
          widget.controller.selectedPedido.value = null;
          widget.controller.selectedPedido.value = currentPedido;
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
        _errorMessage = 'Erro: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

 Future<void> _showDeliveryPersonModal() async {
  final pedido = widget.controller.selectedPedido.value;
  if (pedido == null || pedido.delivery.deliveredBy != "MERCHANT") return;

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
                      filteredDeliveryPersons =
                          deliveryPersons.where((person) {
                        final name = person['Referencia'].toString().toLowerCase();
                        final code = person['Codigo'].toString().toLowerCase();
                        final search = value.toLowerCase();
                        return name.contains(search) || code.contains(search);
                      }).cast<Map<String, dynamic>>().toList();
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
                      ? const Center(child: Text('Nenhum entregador encontrado'))
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

      await _performAction(
        () => _actionsService.dispatchOrder(pedido.id),
        'Despachar Pedido',
        selectedPerson['Codigo'],
      );
    }
  });
}


  Future<void> _showCancellationDialog() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cancellationReasons = await _actionsService.getCancellationReasons(
          widget.controller.selectedPedido.value?.id ?? '');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

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

        if (confirmed == true) {
          await _performAction(
            () => _actionsService
                .requestCancellation(
              widget.controller.selectedPedido.value?.id ?? "",
              reason['cancelCodeId'],
              cancellationDescription:
                  textController.text.isNotEmpty ? textController.text : null,
            )
                .then((value) {
              if (value) {
                widget.controller.selectedPedido.value?.status = 'CAN';
                if (mounted) {
                  setState(() {
                    widget.controller.selectedPedido.value?.status = 'CAN';
                  });
                }

                var service = KronosRepository();
                service.cancelarPedido(widget.controller.selectedPedido.value,
                    reason['description']);
                return true;
              } else {
                return false;
              }
            }),
            'Cancelamento',
            null
          );
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

  Future<void> _addEventForStatus(String statusCode, int? Codigo) async {
    if (widget.controller.selectedPedido.value == null) return;

    final pedido = widget.controller.selectedPedido.value!;

    var instace = KronosRepository();
    if (statusCode == 'DSP') {
      var result = await instace.sendDespachar(pedido, Codigo);
      if (!result) return;
    }

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
            await _performAction(
              () async {
                var sucess = await _actionsService.confirmOrder(
                    widget.controller.selectedPedido.value?.id ?? "");
                if (sucess) {
                  await _kronosRepository.savePedidoToKronos(
                      widget.controller.selectedPedido.value!);
                }
                return sucess;
              },
              'Confirmação',
              null
            );
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
      buttons.add(
        ElevatedButton(
          onPressed: () async {
            final pedido = widget.controller.selectedPedido.value;
            if (pedido?.delivery?.deliveredBy == "MERCHANT") {
              await _showDeliveryPersonModal();
            } else {
              await _performAction(
                () => _actionsService.dispatchOrder(pedido?.id ?? ''),
                'Despachar Pedido', null
              );
            }
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange, foregroundColor: Colors.white),
          child: const Text('Despachar Pedido'),
        ),
      );
    }

    if (!status.contains("CON") &&
        !status.contains("CONCLUDED") &&
        !status.contains("CAN") &&
        !status.contains("CANCELLED")) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              _errorMessage!,
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
