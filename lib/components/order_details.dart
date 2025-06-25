import 'dart:typed_data';

import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  void didUpdateWidget(OrderDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _loadVersion() async {
  final info = await PackageInfo.fromPlatform();
  setState(() {
    versaoDoMeuSistema = '${info.version}+${info.buildNumber}'; // Ex: "1.0.0+1"
  });
}

  String _formatPaymentMethod(String method) {
    switch (method.toUpperCase()) {
      case 'CREDIT':
        return 'Cartão de Crédito';
      case 'DEBIT':
        return 'Cartão de Débito';
      case 'CASH':
        return 'Dinheiro';
      case 'PIX':
        return 'PIX';
      case 'MEAL_VOUCHER':
        return 'Vale Refeição';
      case 'FOOD_VOUCHER':
        return 'Vale Alimentação';
      default:
        return method;
    }
  }

  String _formatCardBrand(String brand) {
    if (brand.isEmpty) return '';

    String formattedBrand = brand.toLowerCase();
    switch (formattedBrand) {
      case 'mastercard':
        return 'Mastercard';
      case 'visa':
        return 'Visa';
      case 'elo':
        return 'Elo';
      case 'amex':
      case 'american express':
        return 'American Express';
      case 'hipercard':
        return 'Hipercard';
      default:
        return formattedBrand[0].toUpperCase() + formattedBrand.substring(1);
    }
  }

  Future<Uint8List> _generateReceipt(PdfPageFormat format) async {
    final pdf = pw.Document();
    final pedido = widget.controller.selectedPedido.value;

    if (pedido == null) return Uint8List(0);

    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pw.Widget _receiptLine(String label, double value,
        {required pw.Font font}) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8)),
          pw.Text('R\$ ${value.toStringAsFixed(2)}',
              style: pw.TextStyle(font: font, fontSize: 8)),
        ],
      );
    }

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
                  pedido.orderType,
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(pedido.merchant.name,
                  style: pw.TextStyle(font: font, fontSize: 9)),
              pw.Text(
                'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(pedido.createdAt)}',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
              pw.Text(
                'Entrega: ${DateFormat('dd/MM/yyyy HH:mm').format(pedido.delivery.deliveryDateTime)}',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
              pw.Text('Cliente: ${pedido.customer.name}',
                  style: pw.TextStyle(font: font, fontSize: 8)),
              pw.Text('Tel: ${pedido.customer.phone.number}',
                  style: pw.TextStyle(font: font, fontSize: 8)),

              pw.Divider(thickness: 0.8),
              pw.Center(
                child: pw.Text(
                  'ITENS DO PEDIDO',
                  style: pw.TextStyle(font: fontBold, fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 2),
              ...pedido.items.map((item) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 7,
                          child: pw.Text(
                            '${item.quantity}x ${item.name.toUpperCase()}',
                            style: pw.TextStyle(font: fontBold, fontSize: 8),
                            softWrap: true,
                          ),
                        ),
                        pw.SizedBox(width: 5),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Align(
                            alignment: pw.Alignment.topRight,
                            child: pw.Text(
                              'R\$ ${item.unitPrice.toStringAsFixed(2)}',
                              style: pw.TextStyle(font: font, fontSize: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...item.options.map((opt) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 5),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              flex: 7,
                              child: pw.Text(
                                '${opt.quantity}x ${opt.name}',
                                style: pw.TextStyle(font: font, fontSize: 7),
                                softWrap: true,
                              ),
                            ),
                            pw.SizedBox(width: 5),
                            pw.Expanded(
                              flex: 3,
                              child: pw.Align(
                                alignment: pw.Alignment.topRight,
                                child: pw.Text(
                                  '+R\$ ${opt.addition.toStringAsFixed(2)}',
                                  style: pw.TextStyle(font: font, fontSize: 7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (item.observations != null)
                      pw.Text(
                        'Obs: ${item.observations}',
                        style: pw.TextStyle(font: font, fontSize: 7),
                      ),
                    pw.Divider(thickness: 0.8),
                  ],
                );
              }).toList(),

              // TOTAL
              pw.Center(
                  child: pw.Text('TOTAL',
                      style: pw.TextStyle(font: fontBold, fontSize: 9))),
              _receiptLine('Itens', pedido.total.subTotal, font: font),
              _receiptLine('Taxa Entrega', pedido.total.deliveryFee,
                  font: font),
              _receiptLine('Taxa Adicional', pedido.total.additionalFees,
                  font: font),
              _receiptLine('Desconto', -pedido.total.benefits, font: font),
              _receiptLine('TOTAL', pedido.total.orderAmount, font: fontBold),
              pw.Divider(thickness: 0.8),

              // PAGAMENTO
              pw.Center(
                  child: pw.Text('PAGAMENTO',
                      style: pw.TextStyle(font: fontBold, fontSize: 9))),

              if (pedido.payments.prepaid > 0)
                _receiptLine('Total Online', pedido.payments.prepaid,
                    font: font),

              if (pedido.payments.pending > 0) ...[
                pw.Text('A RECEBER NA ENTREGA',
                    style: pw.TextStyle(font: font, fontSize: 8)),
                ...pedido.payments.methods
                    .where((p) => p.prepaid == false)
                    .map((p) {
                  final methodLabel = _formatPaymentMethod(p.method);
                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('- $methodLabel',
                          style: pw.TextStyle(font: font, fontSize: 8)),
                      pw.Text('R\$ ${p.value.toStringAsFixed(2)}',
                          style: pw.TextStyle(font: font, fontSize: 8)),
                    ],
                  );
                }),
              ],


              // INFORMAÇÕES ADICIONAIS
              if (pedido.customer.documentNumber.isNotEmpty && pedido.delivery.deliveredBy == "MERCHANT") ...[
                pw.SizedBox(height: 2),
                pw.Divider(thickness: 0.8),
         
                     pw.Text('INFORMAÇÕES ADICIONAIS',
                        style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Incluir CPF na Nota Fiscal',
                    style: pw.TextStyle(font: font, fontSize: 8)),
                pw.Text('CPF do Cliente: ${pedido.customer.documentNumber}',
                    style: pw.TextStyle(font: font, fontSize: 8)),
              ],

              // ENTREGA
              if (pedido.delivery.deliveredBy == "MERCHANT") ...[
pw.Divider(thickness: 0.8),
              pw.Center(
                  child: pw.Text('ENTREGA PEDIDO #${pedido.displayId}',
                      style: pw.TextStyle(font: fontBold, fontSize: 9))),
              pw.Text(
                'Entregador: ${pedido.delivery.deliveredBy == "MERCHANT" ? "Entrega própria" : "PARCEIRO IFOOD"}',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
              pw.Text(
                'Endereço: ${pedido.delivery.deliveryAddress.streetName}, ${pedido.delivery.deliveryAddress.streetNumber ?? 'S/N'}',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
                        pw.Text(
                'Comp: ${pedido.delivery.deliveryAddress.complement}',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
              if (pedido.delivery.deliveryAddress.reference != null)
                pw.Text('Ref: ${pedido.delivery.deliveryAddress.reference}',
                    style: pw.TextStyle(font: font, fontSize: 7)),
              pw.Text(
                'Bairro: ${pedido.delivery.deliveryAddress.neighborhood}',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
                        pw.Text(
                'Cidade: ${pedido.delivery.deliveryAddress.city} - ${pedido.delivery.deliveryAddress.state}',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
              pw.Text(
                'CEP: ${pedido.delivery.deliveryAddress.postalCode}',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
              ],
              
              pw.SizedBox(height: 6),
              pw.Text('Impresso por: KRONOS ERP $versaoDoMeuSistema',
                  style: pw.TextStyle(font: font, fontSize: 8)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _receiptLine(String title, double value, {required pw.Font font}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(font: font, fontSize: 9),
        ),
        pw.Text(
          'R\$ ${value.toStringAsFixed(2)}',
          style: pw.TextStyle(font: font, fontSize: 9),
        ),
      ],
    );
  }

  pw.Widget _line(String title, double value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(
          'R\$ ${value >= 0 ? value.toStringAsFixed(2) : '- ${value.abs().toStringAsFixed(2)}'}',
          style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
      ],
    );
  }

  pw.Widget _paymentLine(String label, double value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('▐ $label'),
        pw.Text('▐ R\$ ${value.toStringAsFixed(2)}'),
      ],
    );
  }

  Future<void> printReceipt() async {
    await Printing.layoutPdf(
      onLayout: (_) => _generateReceipt(PdfPageFormat.roll80),
    );
  }

  bool _checkIfCancelled(String status) {
    final upperStatus = status.toUpperCase();
    return upperStatus.contains('CAN') ||
        upperStatus.contains('CANCELLED') ||
        upperStatus.contains('CANCELLATION') ||
        upperStatus.contains('CANCEL');
  }

  Future<void> _updateOrderDetails() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final authRepository = AuthRepository();
      final token = await authRepository.getValidAccessToken();

      if (token == null) {
        throw Exception("Token de acesso inválido ou expirado");
      }

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

      if (isCancelled) {
        updatedOrder.statusCode = Consts.statusCancelled;
      }

      String newStatus = isCancelled
          ? Consts.statusCancelled
          : _mapStatusCode(updatedOrder.status);

      setState(() {
        _isUpdating = false;
      });

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
      setState(() {
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _mapStatusCode(String apiStatus) {
    final upperStatus = apiStatus.toUpperCase();

    if (upperStatus.contains('CAN') ||
        upperStatus.contains('CANCELLED') ||
        upperStatus.contains('CANCELLATION') ||
        upperStatus.contains('CANCEL')) {
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
      return Consts.statusPlaced;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.selectedPedido.value == null) {
      return Center(
        child: Text("Nenhum pedido selecionado"),
      );
    }

    return Stack(
      children: [
        Container(
          color: Colors.grey[50],
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            onPressed: printReceipt,
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
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    dateTime = dateTime.toLocal();
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }
}
