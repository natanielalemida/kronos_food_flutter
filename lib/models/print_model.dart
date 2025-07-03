import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> printReceipt(pedido) async {
  final version = await _loadVersion();
  final pdfBytes = await _generateReceipt(PdfPageFormat.roll80, pedido, version);
  
  final printers = await Printing.listPrinters();
  
  final printer = printers.firstWhere(
    (p) => p.isDefault, 
    orElse: () => printers.first,
  );
  
  await Printing.directPrintPdf(
    printer: printer,
    onLayout: (_) => pdfBytes,
  );
}
Future<String> _loadVersion() async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
}

Future<Uint8List> _generateReceipt(
    PdfPageFormat format, pedido, version) async {
  final pdf = pw.Document();
  ;

  if (pedido == null) return Uint8List(0);

  final font = await PdfGoogleFonts.robotoRegular();
  final fontBold = await PdfGoogleFonts.robotoBold();

  pw.Widget _receiptLine(String label, double value, {required pw.Font font}) {
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
                pedido.orderType == "TAKEOUT" ? 'RETIRADA' : pedido.orderType,
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
            _receiptLine('Taxa Entrega', pedido.total.deliveryFee, font: font),
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
              _receiptLine('Total Online', pedido.payments.prepaid, font: font),

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
            if (pedido.customer.documentNumber.isNotEmpty &&
                pedido.delivery.deliveredBy == "MERCHANT") ...[
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
            pw.Text('Impresso por: KRONOS ERP $version',
                style: pw.TextStyle(font: font, fontSize: 8)),
          ],
        );
      },
    ),
  );

  return pdf.save();
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
