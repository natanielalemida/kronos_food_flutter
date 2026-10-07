import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_receipt.dart';

Future<void> printOrderReceipt(OrderReceipt receipt) async {
  final info = await PackageInfo.fromPlatform();
  final bytes = await generateOrderReceipt(receipt,
      version: '${info.version}+${info.buildNumber}');
  await Printing.layoutPdf(
    name: 'Pedido ${receipt.source} ${receipt.number}',
    format: PdfPageFormat.roll80,
    dynamicLayout: false,
    onLayout: (_) async => bytes,
  );
}

/// O mesmo cupom de 80 mm é usado na impressão manual dos dois canais.
Future<Uint8List> generateOrderReceipt(OrderReceipt receipt,
    {required String version, pw.Font? font, pw.Font? boldFont}) async {
  final regular = font ?? await PdfGoogleFonts.robotoRegular();
  final bold = boldFont ?? await PdfGoogleFonts.robotoBold();
  final pdf = pw.Document();
  pw.Widget text(String value, {double size = 8, bool strong = false}) =>
      pw.Text(value,
          style: pw.TextStyle(font: strong ? bold : regular, fontSize: size));
  pw.Widget title(String value) =>
      pw.Center(child: text(value, size: 9, strong: true));
  pw.Widget line(String label, String value,
          {bool strong = false, double size = 8}) =>
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: text(label, size: size, strong: strong)),
        pw.SizedBox(width: 5),
        text(value, size: size, strong: strong),
      ]);
  String money(double value) => 'R\$ ${value.toStringAsFixed(2)}';
  String date(DateTime value) => DateFormat('dd/MM/yyyy HH:mm').format(value);
  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.roll80,
    build: (_) => pw.Padding(
      padding: const pw.EdgeInsets.only(right: 4 * PdfPageFormat.mm),
      child:
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Center(
            child: text('**** PEDIDO #${receipt.number} ****',
                size: 11, strong: true)),
        pw.Center(child: text(receipt.fulfillment, size: 9)),
        pw.Center(child: text(receipt.source, size: 8)),
        pw.SizedBox(height: 2),
        if (receipt.store.isNotEmpty) text(receipt.store, size: 9),
        text('Data: ${date(receipt.created)}'),
        if (receipt.expectedDelivery != null)
          text('Entrega: ${date(receipt.expectedDelivery!)}'),
        text('Cliente: ${receipt.customer}'),
        if (receipt.customerOrdersLabel != null)
          text(receipt.customerOrdersLabel!, strong: true),
        if (receipt.phone.isNotEmpty) text('Tel: ${receipt.phone}'),
        if (receipt.pickupCode.trim().isNotEmpty)
          text('Codigo de coleta: ${receipt.pickupCode.trim()}',
              size: 9, strong: true),
        pw.Divider(thickness: .8),
        title('ITENS DO PEDIDO'),
        pw.SizedBox(height: 2),
        for (final item in receipt.items) ...[
          line('${item.quantity}x ${item.name.toUpperCase()}',
              money(item.unitPrice),
              strong: true),
          for (final option in item.options)
            pw.Padding(
                padding: const pw.EdgeInsets.only(left: 5),
                child: line(option.label, '+${money(option.value)}', size: 7)),
          if (item.observations.trim().isNotEmpty)
            text('Obs: ${item.observations}', size: 7),
          pw.Divider(thickness: .8),
        ],
        title('TOTAL'),
        line('Itens', money(receipt.subtotal)),
        line('Taxa Entrega', money(receipt.deliveryFee)),
        if (receipt.additionalFees != 0)
          line('Taxa Adicional', money(receipt.additionalFees)),
        for (final discount in receipt.discounts)
          line('Desconto', '${discount.label} - ${money(discount.value)}'),
        line('TOTAL', money(receipt.total), strong: true),
        pw.Divider(thickness: .8),
        title('PAGAMENTO'),
        if (receipt.prepaid > 0) line('Total Online', money(receipt.prepaid)),
        if (receipt.pending > 0) ...[
          text(receipt.pickup
              ? 'A RECEBER NA RETIRADA'
              : 'A RECEBER NA ENTREGA'),
          for (final method in receipt.paymentMethods)
            line('- ${method.label}', money(method.value)),
          if (receipt.changeFor != null &&
              receipt.changeFor! >= receipt.pending) ...[
            line('Troco para', money(receipt.changeFor!)),
            line('Troco', money(receipt.changeFor! - receipt.pending)),
          ],
        ],
        if (receipt.documentLines.isNotEmpty) ...[
          pw.Divider(thickness: .8),
          title('INFORMAÇÕES ADICIONAIS'),
          ...receipt.documentLines.map((value) => text(value)),
        ],
        if (receipt.deliveryLines.isNotEmpty) ...[
          pw.Divider(thickness: .8),
          title('ENTREGA PEDIDO #${receipt.number}'),
          ...receipt.deliveryLines.map((value) => text(value)),
        ],
        pw.SizedBox(height: 6),
        text('Impresso por: KRONOS ERP $version'),
      ]),
    ),
  ));
  return pdf.save();
}
