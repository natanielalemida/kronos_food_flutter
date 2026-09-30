import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kronos_food/models/pedido_model.dart';
import '../models/order_receipt.dart';
import '../service/order_receipt_service.dart';
import 'package:kronos_food/components/ifood_order_details_view.dart';
import 'package:kronos_food/components/order_ifood_tracking.dart';

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
  bool _printingReceipt = false;
  bool _showDisputePanel = false;
  int? _selectedResponseOption;
  final TextEditingController _partialRefundController =
      TextEditingController();
  final TextEditingController _rejectionReasonController =
      TextEditingController();
  late OrderRepository _orderRepository;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    widget.controller.selectedPedido.addListener(_handleSelectedPedidoChanged);
  }

  @override
  void didUpdateWidget(OrderDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.selectedPedido
          .removeListener(_handleSelectedPedidoChanged);
      widget.controller.selectedPedido
          .addListener(_handleSelectedPedidoChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.selectedPedido
        .removeListener(_handleSelectedPedidoChanged);
    _partialRefundController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  void _handleSelectedPedidoChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _initializeRepository() async {
    final authRepository = AuthRepository();
    final token = await authRepository.getValidAccessToken();
    _orderRepository = OrderRepository(Consts.baseUrl, token ?? '');
  }

  Future<void> printReceiptWithDefault() async {
    final order = widget.controller.selectedPedido.value;
    if (order == null || _printingReceipt) return;
    setState(() => _printingReceipt = true);
    try {
      await printOrderReceipt(OrderReceipt.fromIfood(order));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Não foi possível imprimir o pedido. Confira a impressora e tente novamente.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _printingReceipt = false);
    }
  }

  Future<void> _updateOrderDetails() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      final authRepository = AuthRepository();
      final token = await authRepository.getValidAccessToken();
      if (token == null) throw Exception("Token inválido");

      final orderRepository = OrderRepository(Consts.baseUrl, token);
      final updatedOrder = await orderRepository
          .getPedidoDetails(widget.controller.selectedPedido.value?.id ?? '');

      if (updatedOrder.status.isEmpty) {
        updatedOrder.status =
            widget.controller.selectedPedido.value?.status ?? '';
      }

      final upperStatus = updatedOrder.status.toUpperCase();
      final isCancelled = upperStatus.contains('CAN') ||
          upperStatus.contains('CANCELLED') ||
          upperStatus.contains('CANCELLATION') ||
          upperStatus.contains('CANCEL');

      if (isCancelled) updatedOrder.statusCode = Consts.statusCancelled;

      final currentOrder = widget.controller.selectedPedido.value;
      if (currentOrder != null && currentOrder.id == updatedOrder.id) {
        for (final event in currentOrder.events) {
          final hasEvent = updatedOrder.events.any((current) =>
              current.id.isNotEmpty && current.id == event.id ||
              (current.id.isEmpty &&
                  current.code == event.code &&
                  current.fullCode == event.fullCode &&
                  current.createdAt == event.createdAt));

          if (!hasEvent) {
            updatedOrder.events.add(event);
          }
        }

        updatedOrder.status = widget.controller.mapApiStatusToCode(
          updatedOrder.status.isEmpty
              ? currentOrder.status
              : updatedOrder.status,
        );
        await widget.controller.atualizarPedido(updatedOrder);
        widget.controller.selectedPedido.value = updatedOrder;
      }

      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCancelled
              ? 'Pedido CANCELADO atualizado com sucesso'
              : 'Pedido atualizado com sucesso'),
          backgroundColor: isCancelled ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleDisputePanel() {
    setState(() {
      _showDisputePanel = !_showDisputePanel;
      _selectedResponseOption = null;
      _partialRefundController.clear();
      _rejectionReasonController.clear();
    });
  }

  void _showFullScreenImage(String imageBase64) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 3.0,
          child: Image.memory(
            base64Decode(imageBase64.split(',').last),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  bool _isTimeExpired(DateTime? expiresAt) {
    if (expiresAt == null) return false;
    return DateTime.now().toLocal().isAfter(expiresAt.toLocal());
  }

  Future<void> _submitDisputeResponse() async {
    if (_selectedResponseOption == null ||
        _isTimeExpired(
            widget.controller.selectedPedido.value?.metadata?.expiresAt)) {
      return;
    }

    try {
      final authRepository = AuthRepository();
      final token = await authRepository.getValidAccessToken();
      if (token == null) throw Exception("Token inválido");

      final orderRepository = OrderRepository(Consts.baseUrl, token);
      String action;
      String? body;

      switch (_selectedResponseOption) {
        case 1: // Aceitar reembolso
          // Soma os valores dos itens com problemas
          final totalAmount = calcularValorTotalReembolso(
            widget.controller.selectedPedido.value?.metadata?.details.items,
            widget.controller.selectedPedido.value?.metadata?.details
                .garnishItems,
          );

          action =
              'disputes/${widget.controller.selectedPedido.value!.metadata?.disputeId}/accept';
          body = jsonEncode({
            'amount': (totalAmount * 100).toInt() // Convertendo para centavos
          });
          break;
        case 3: // Recusar
          action =
              'disputes/${widget.controller.selectedPedido.value!.metadata?.disputeId}/reject';
          body = jsonEncode({'reason': _rejectionReasonController.text});
          break;
        default:
          action =
              'disputes/${widget.controller.selectedPedido.value!.metadata?.disputeId}/accept';
      }

      var result = await orderRepository.respondToDispute(action, body);

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resposta enviada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      var finalPedido = widget.controller.selectedPedido.value;
      if (_selectedResponseOption == 3) {
        var pedidosContoller = PedidosController();
        finalPedido?.status = 'CON';
        await pedidosContoller.alterarStatus(finalPedido);
      }

      setState(() {
        widget.controller.loadSavedPedidos();
      });

      _toggleDisputePanel();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double calcularValorTotalReembolso(
      List<DisputedItem>? itens, List<DisputedGarnishItem>? garnishItems) {
    double total = 0;

    if (itens != null) {
      total += itens.fold<double>(
        0,
        (sum, item) =>
            sum + (double.parse(item.amount.value) / 100) * item.quantity,
      );
    }

    if (garnishItems != null) {
      total += garnishItems.fold<double>(
        0,
        (sum, item) =>
            sum + (double.parse(item.amount.value) / 100) * item.quantity,
      );
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.selectedPedido.value == null) {
      return const Center(child: Text("Nenhum pedido selecionado"));
    }

    final valor = calcularValorTotalReembolso(
      widget.controller.selectedPedido.value?.metadata?.details.items,
      widget.controller.selectedPedido.value?.metadata?.details.garnishItems,
    );

    final status =
        widget.controller.selectedPedido.value?.status.toUpperCase() ?? '';
    final selectedOrder = widget.controller.selectedPedido.value!;
    final isHsd = status == 'HSD';
    final isTimeExpired = _isTimeExpired(
        widget.controller.selectedPedido.value?.metadata?.expiresAt);

    return Stack(
      children: [
        IfoodOrderDetailsView(
          order: selectedOrder,
          onPrint: printReceiptWithDefault,
          printing: _printingReceipt,
          tracking: OrderIfoodTracking(order: selectedOrder),
          alert: isHsd
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF5E4),
                      borderRadius: BorderRadius.circular(12)),
                  child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        const Text(
                            'O cliente abriu uma solicitação sobre este pedido.',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        FilledButton(
                            onPressed:
                                isTimeExpired ? null : _toggleDisputePanel,
                            child: Text(isTimeExpired
                                ? 'Tempo esgotado'
                                : 'Responder solicitação')),
                      ]),
                )
              : null,
          actions: PedidoActionsButtons(
            controller: widget.controller,
            onRefreshPolling: widget.onRefreshPolling,
            onActionComplete: () async {
              await _updateOrderDetails();
              widget.onActionComplete?.call();
            },
          ),
        ),
        // Painel de Resposta à Disputa
        if (_showDisputePanel)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Material(
              elevation: 12,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.4,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Problemas no pedido #${widget.controller.selectedPedido.value?.displayId}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: _toggleDisputePanel,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildCountdownTimer(widget.controller.selectedPedido
                          .value?.metadata?.expiresAt),
                      const SizedBox(height: 2),
                      Text(
                        'Caso não responda, ${widget.controller.selectedPedido.value?.customer.name} pode ${widget.controller.selectedPedido.value?.metadata?.timeoutAction == "REJECT_CANCELLATION" ? "recusar o cancelamento automaticamente" : "recorrer ao iFood"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),

                      if (isTimeExpired)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'O tempo para responder expirou. Você não pode mais enviar uma resposta.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),

                      if (!isTimeExpired) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cliente solicitou ${widget.controller.selectedPedido.value?.metadata?.action == "CANCELLATION" ? "cancelamento" : "reembolso"} do pedido',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                  'Motivo: ${widget.controller.selectedPedido.value?.metadata?.message}'),
                              const SizedBox(height: 6),
                              Text(
                                'Tipo: ${widget.controller.selectedPedido.value?.metadata?.handshakeType?.replaceAll("_", " ").toLowerCase()}',
                                style: TextStyle(color: Colors.grey),
                              ),
                              if (widget
                                      .controller
                                      .selectedPedido
                                      .value
                                      ?.metadata
                                      ?.details
                                      .evidences
                                      ?.isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'Evidências enviadas pelo cliente:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 120,
                                  child: FutureBuilder<List<String>>(
                                    future: Future.wait(widget
                                        .controller
                                        .selectedPedido
                                        .value!
                                        .metadata!
                                        .details
                                        .evidences
                                        .map((evidence) async =>
                                            await _orderRepository
                                                .getImage(evidence.url) ??
                                            '')),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                            child: CircularProgressIndicator());
                                      }

                                      if (snapshot.hasError) {
                                        return Center(
                                            child: Text(
                                                'Erro ao carregar imagens'));
                                      }

                                      final images = snapshot.data ?? [];

                                      return ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: images.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(width: 8),
                                        itemBuilder: (context, index) {
                                          final imageBase64 = images[index];
                                          return GestureDetector(
                                            onTap: () => _showFullScreenImage(
                                                imageBase64),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.memory(
                                                base64Decode(imageBase64
                                                    .split(',')
                                                    .last),
                                                width: 120,
                                                height: 120,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    width: 120,
                                                    height: 120,
                                                    color: Colors.grey[200],
                                                    child: const Icon(
                                                        Icons.broken_image,
                                                        color: Colors.grey),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Itens com problemas
                        if (widget.controller.selectedPedido.value?.metadata
                                ?.details.items.isNotEmpty ??
                            false) ...[
                          const Text(
                            'Itens com problemas:',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...widget.controller.selectedPedido.value!.metadata!
                              .details.items
                              .map((item) {
                            final itemValue =
                                double.parse(item.amount.value) / 100;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ${item.quantity}x Item #${item.index} (R\$${itemValue.toStringAsFixed(2)})',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(left: 8, top: 2),
                                    child: Text(
                                      'Motivo: ${item.reason}',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // Itens de guarnição com problemas
                        if (widget.controller.selectedPedido.value?.metadata
                                ?.details.garnishItems.isNotEmpty ??
                            false) ...[
                          const Text(
                            'Itens de guarnição com problemas:',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...widget.controller.selectedPedido.value!.metadata!
                              .details.garnishItems
                              .map((item) {
                            final itemValue =
                                double.parse(item.amount.value) / 100;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ${item.quantity}x Guarnição #${item.index} (R\$${itemValue.toStringAsFixed(2)})',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(left: 8, top: 2),
                                    child: Text(
                                      'Motivo: ${item.reason}',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // Título
                        const Text('Escolha uma das opções pra responder:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        _radioCard(
                          value: 1,
                          title: valor == 0
                              ? 'Aceitar reembolso'
                              : 'Aceitar reembolso de R\$ ${valor.toStringAsFixed(2)}',
                          subtitle: valor == 0
                              ? ''
                              : 'Cliente receberá o valor total desse pedido',
                        ),
                        _radioCard(
                          value: 3,
                          title:
                              'Recusar ${widget.controller.selectedPedido.value?.metadata?.action == "CANCELLATION" ? "cancelamento" : "reembolso"}',
                          subtitle:
                              'Cliente ainda pode solicitar uma análise do iFood',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Conte para o cliente por qual motivo você vai recusar o ${widget.controller.selectedPedido.value?.metadata?.action == "CANCELLATION" ? "cancelamento" : "reembolso"}'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _rejectionReasonController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Descreva o motivo*',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text.rich(
                                TextSpan(
                                  text: 'Saiba como ',
                                  style: TextStyle(
                                      color: Colors.blue[700], fontSize: 12),
                                  children: const [
                                    TextSpan(
                                      text:
                                          'essa justificativa pode ajudar sua loja a prevenir cancelamentos.',
                                      style: TextStyle(color: Colors.black87),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: !isTimeExpired &&
                                    _selectedResponseOption != null
                                ? _submitDisputeResponse
                                : null,
                            icon: const Icon(Icons.send),
                            label: isTimeExpired
                                ? const Text('Tempo esgotado')
                                : const Text('Enviar resposta'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isTimeExpired
                                  ? Colors.grey
                                  : Colors.orange[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _radioCard({
    required int value,
    required String title,
    required String subtitle,
    Widget? child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: _selectedResponseOption == value
              ? Colors.red
              : Colors.grey.shade300,
          width: _selectedResponseOption == value ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: _selectedResponseOption == value
            ? Colors.red.shade50
            : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Radio<int>(
                value: value,
                groupValue: _selectedResponseOption,
                onChanged: (v) => setState(() => _selectedResponseOption = v),
                activeColor: Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style:
                            TextStyle(color: Colors.grey[700], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (child != null && _selectedResponseOption == value) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }

  String _formatRemainingTime(DateTime? expiresAt) {
    if (expiresAt == null) return "tempo limitado";

    final now = DateTime.now().toLocal();
    final difference = expiresAt.toLocal().difference(now);

    if (difference.isNegative) return "tempo esgotado";

    final minutes = difference.inMinutes;
    final seconds = difference.inSeconds.remainder(60);

    return "$minutes minutos e ${seconds.toString().padLeft(2, '0')} segundos";
  }

  Widget _buildCountdownTimer(DateTime? expiresAt) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        return Text(
          _formatRemainingTime(expiresAt),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _isTimeExpired(expiresAt) ? Colors.red : Colors.orange,
          ),
        );
      },
    );
  }
}
