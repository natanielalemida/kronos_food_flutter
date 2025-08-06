import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:kronos_food/models/event_model.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:kronos_food/components/order_delivery_info.dart';
import 'package:kronos_food/components/order_items.dart';
import 'package:kronos_food/components/order_payment_info.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  String versaoDoMeuSistema = '';
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
    _loadVersion();
    _initializeRepository();
  }

  Future<void> _initializeRepository() async {
    final authRepository = AuthRepository();
    final token = await authRepository.getValidAccessToken();
    _orderRepository = OrderRepository(Consts.baseUrl, token ?? '');
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      versaoDoMeuSistema = '${info.version}+${info.buildNumber}';
    });
  }

  List<Map<String, dynamic>> extractDiscountDetails(List<Benefit> benefits) {
    final List<Map<String, dynamic>> discountDetails = [];
    for (final benefit in benefits) {
      for (final sponsorship in benefit.sponsorshipValues) {
        if (sponsorship.value > 0) {
          discountDetails.add({
            'name': sponsorship.name,
            'value': sponsorship.value,
            'description': sponsorship.description,
          });
        }
      }
    }
    return discountDetails;
  }

  Future<Uint8List> _generateReceipt(PdfPageFormat format) async {
    final pdf = pw.Document();
    final pedido = widget.controller.selectedPedido.value;
    if (pedido == null) return Uint8List(0);

    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  '**** PEDIDO #${pedido.displayId} ****',
                  style: pw.TextStyle(font: fontBold, fontSize: 11),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  pedido.orderType == "TAKEOUT" ? 'RETIRADA' : pedido.orderType,
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
              ),
              // ... (restante do código existente de geração de PDF)
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  Future<void> printReceiptWithDefault() async {
    await Printing.layoutPdf(
      onLayout: (_) => _generateReceipt(PdfPageFormat.roll80),
    );
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

  Future<void> _submitDisputeResponse() async {
    if (_selectedResponseOption == null) return;

    try {
      final authRepository = AuthRepository();
      final token = await authRepository.getValidAccessToken();
      if (token == null) throw Exception("Token inválido");

      final orderRepository = OrderRepository(Consts.baseUrl, token);
      String action;
      String? body;

      switch (_selectedResponseOption) {
        case 1:
          action =
              'disputes/${widget.controller.selectedPedido.value!.metadata?.disputeId}/accept';
          break;
        case 2:
          action =
              'disputes/${widget.controller.selectedPedido.value!.metadata?.disputeId}/propose_partial_refund';
          body = jsonEncode({
            'amount': _partialRefundController.text.isNotEmpty
                ? (double.parse(_partialRefundController.text) * 100)
                : 0
          });
          break;
        case 3:
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

  @override
  Widget build(BuildContext context) {
    if (widget.controller.selectedPedido.value == null) {
      return const Center(child: Text("Nenhum pedido selecionado"));
    }

    final status =
        widget.controller.selectedPedido.value?.status.toUpperCase() ?? '';
    final isHsd = status == 'HSD';

    return Stack(
      children: [
        Container(
          color: Colors.grey[50],
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isHsd)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.white),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Este pedido está em disputa (HSD)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _toggleDisputePanel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.orange[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          child: const Text(
                            'Responder',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isHsd) const SizedBox(height: 16),
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
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon:
                                const Icon(Icons.print, color: Colors.black54),
                            onPressed: printReceiptWithDefault,
                            tooltip: 'Imprimir',
                          ),
                        ],
                      ),
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
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              const SizedBox(width: 8),
                              Text("•",
                                  style: TextStyle(color: Colors.grey[700])),
                              const SizedBox(width: 8),
                              Text(
                                "Localizador",
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.controller.selectedPedido.value?.customer
                                        .phone.localizer ??
                                    "",
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              const SizedBox(width: 8),
                              Text("•",
                                  style: TextStyle(color: Colors.grey[700])),
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
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.controller.selectedPedido.value!
                                          .schedule.deliveryDateTimeStart !=
                                      null &&
                                  widget.controller.selectedPedido.value!
                                          .schedule.deliveryDateTimeEnd !=
                                      null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  "Horário Agendado: ${DateFormat('HH:mm').format(widget.controller.selectedPedido.value!.schedule.deliveryDateTimeStart!)} - ${DateFormat('HH:mm').format(widget.controller.selectedPedido.value!.schedule.deliveryDateTimeEnd!)}",
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone,
                                  size: 18, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                "${widget.controller.selectedPedido.value?.customer.phone.number ?? ""} ID: ${widget.controller.selectedPedido.value?.customer.phone.localizer ?? ""}",
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.controller.selectedPedido.value?.status !=
                        "SCHEDULED" &&
                    widget.controller.selectedPedido.value != null) ...[
                  OrderTimeline(
                    order: widget.controller.selectedPedido.value!,
                  ),
                ],
                const SizedBox(height: 20),
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
                const SizedBox(height: 24),
              ],
            ),
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
                      Text(
                        'Você tem ${widget.controller.selectedPedido.value?.metadata?.timeoutAction == "REJECT_CANCELLATION" ? "até ${DateFormat('HH:mm').format(DateTime.parse(widget.controller.selectedPedido.value?.metadata?.expiresAt.toIso8601String() ?? '').toLocal())}" : "tempo limitado"} para responder',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Caso não responda, ${widget.controller.selectedPedido.value?.customer.name} pode ${widget.controller.selectedPedido.value?.metadata?.timeoutAction == "REJECT_CANCELLATION" ? "recusar o cancelamento automaticamente" : "recorrer ao iFood"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
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
                            if (widget.controller.selectedPedido.value?.metadata
                                    ?.details.evidences?.isNotEmpty ??
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
                                          child:
                                              Text('Erro ao carregar imagens'));
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
                                          onTap: () =>
                                              _showFullScreenImage(imageBase64),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.memory(
                                              base64Decode(
                                                  imageBase64.split(',').last),
                                              width: 120,
                                              height: 120,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
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
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 8, top: 2),
                                  child: Text(
                                    'Motivo: ${item.reason}',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 12),
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
                        title:
                            'Aceitar reembolso de R\$ ${widget.controller.selectedPedido.value?.total.orderAmount}',
                        subtitle: 'Cliente receberá o valor total desse pedido',
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
                          onPressed: _selectedResponseOption != null
                              ? _submitDisputeResponse
                              : null,
                          icon: const Icon(Icons.send),
                          label: const Text('Enviar resposta'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
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

  String _formatTime(DateTime dateTime) {
    dateTime = dateTime.toLocal();
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }
}
