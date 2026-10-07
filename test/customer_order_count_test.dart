import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/components/customer_order_count.dart';
import 'package:kronos_food/components/food_order_list.dart';
import 'package:kronos_food/components/darcapio/order_details.dart';
import 'package:kronos_food/components/ifood_order_details_view.dart';
import 'package:kronos_food/models/food_order_entry.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/models/order_receipt.dart';
import 'package:kronos_food/models/print_model.dart';
import 'package:kronos_food/pages/darcapio_order_history_page.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'package:kronos_food/service/order_receipt_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'food_order_details_design_test.dart'
    show previewIfoodOrder, previewDarcapioOrder;
import 'order_receipt_test.dart' show deliveryOrder;

void main() {
  setUpAll(() async {
    for (final (family, variable) in [
      ('Roboto', 'KRONOS_COUNT_PREVIEW_FONT'),
      ('MaterialIcons', 'KRONOS_COUNT_ICON_FONT')
    ]) {
      final path = Platform.environment[variable];
      if (path != null) {
        final loader = FontLoader(family)
          ..addFont(Future.value(
              ByteData.sublistView(await File(path).readAsBytes())));
        await loader.load();
      }
    }
  });
  test('iFood preserva o valor recebido e distingue ausência de zero', () {
    for (final count in [null, 0, 1, 18]) {
      final customer = Customer.fromJson({'ordersCountOnMerchant': count});
      expect(customer.ordersCountOnMerchant, count);
      expect(
          Customer.fromKronos(customer.toMap()).ordersCountOnMerchant, count);
      final entry =
          FoodOrderEntry.ifood(previewIfoodOrder(customerOrdersCount: count));
      expect(entry.customerOrdersCount, count);
      expect(
          OrderReceipt.fromIfood(entry.ifoodOrder!).customerOrdersCount, count);
    }
    expect(Customer.fromJson({}).ordersCountOnMerchant, isNull);
    expect(
        Customer.fromJson({'ordersCountOnMerchant': -1}).ordersCountOnMerchant,
        isNull);
  });

  test('Darcapio lê contagem do servidor nos dois formatos; legado omite', () {
    for (final lowercase in [false, true]) {
      final order = deliveryOrder(lowercase: lowercase, customerOrdersCount: 8);
      expect(order.customerOrdersCount, 8);
      expect(FoodOrderEntry.darcapio(order).customerOrdersCount, 8);
      expect(OrderReceipt.fromDarcapio(order).customerOrdersLabel,
          '8 pedidos na loja');
    }
    expect(deliveryOrder().customerOrdersCount, isNull);
    final csv = darcapioMovementCsv(
        1, [deliveryOrder(customerOrdersCount: 8), deliveryOrder()]);
    expect(csv.split('\r\n')[1], endsWith(';"8"'));
    expect(csv.split('\r\n')[2], endsWith(';""'));
  });

  testWidgets('Singular, zero e contagem ausente', (tester) async {
    for (final count in [null, 0, 1, 8]) {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: CustomerOrderCount(count: count))));
      expect(find.text('$count ${count == 1 ? 'pedido' : 'pedidos'} na loja'),
          count == null ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  for (final kanban in [false, true]) {
    testWidgets('Cards dos dois canais exibem contagem; kanban: $kanban',
        (tester) async {
      tester.view.physicalSize = const Size(680, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
              body: RepaintBoundary(
                  key: key,
                  child: MediaQuery(
                    data: const MediaQueryData(
                        textScaler: TextScaler.linear(1.4)),
                    child: FoodOrderList(
                      orders: [
                        FoodOrderEntry.ifood(
                            previewIfoodOrder(customerOrdersCount: 1)),
                        FoodOrderEntry.darcapio(
                            previewDarcapioOrder(customerOrdersCount: 8)),
                      ],
                      selectedId: null,
                      onSelected: (_) {},
                      connected: true,
                      kanban: kanban,
                    ),
                  )))));
      await tester.pumpAndSettle();
      expect(find.text('1 pedido na loja'), findsOneWidget);
      expect(find.text('8 pedidos na loja'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await savePreview(tester, key, kanban ? 'cards-kanban' : 'cards-lista');
    });
  }

  for (final ifood in [false, true]) {
    for (final width in [430.0, 1440.0]) {
      testWidgets('Detalhe mostra contagem; iFood: $ifood; largura: $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final detail = ifood
            ? IfoodOrderDetailsView(
                order: previewIfoodOrder(customerOrdersCount: 8),
                actions: const SizedBox(),
                onPrint: () {})
            : DarcapioOrderDetails(
                busy: false,
                blocked: false,
                onAction: (_) {},
                order: previewDarcapioOrder(customerOrdersCount: 8));
        await tester.pumpWidget(MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: Scaffold(
                body: RepaintBoundary(
                    key: key,
                    child: ColoredBox(
                        color: const Color(0xFFF4F6F8), child: detail)))));
        await tester.pumpAndSettle();
        expect(find.text('8 pedidos na loja'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (width == 1440)
          await savePreview(
              tester, key, '${ifood ? 'ifood' : 'darcapio'}-detalhe');
      });
    }
  }

  test('Gera cupons manual e automático com a contagem dos canais', () async {
    final ifood = previewIfoodOrder(customerOrdersCount: 8);
    final receipts = <String, List<int>>{
      'darcapio': await generateOrderReceipt(
          OrderReceipt.fromDarcapio(deliveryOrder(customerOrdersCount: 1)),
          version: 'teste',
          font: pw.Font.helvetica(),
          boldFont: pw.Font.helveticaBold()),
      'ifood-manual': await generateOrderReceipt(OrderReceipt.fromIfood(ifood),
          version: 'teste',
          font: pw.Font.helvetica(),
          boldFont: pw.Font.helveticaBold()),
      'ifood-automatico': await generateIfoodReceipt(
          PdfPageFormat.roll80, ifood, 'teste',
          regularFont: pw.Font.helvetica(), boldFont: pw.Font.helveticaBold()),
    };
    for (final entry in receipts.entries) {
      expect(String.fromCharCodes(entry.value.take(5)), '%PDF-');
      final preview = Platform.environment['KRONOS_COUNT_PREVIEW_DIR'];
      if (preview != null) {
        await Directory(preview).create(recursive: true);
        await File('$preview/${entry.key}-cupom.pdf').writeAsBytes(entry.value);
      }
    }
  });
}

Future<void> savePreview(
    WidgetTester tester, GlobalKey key, String name) async {
  final preview = Platform.environment['KRONOS_COUNT_PREVIEW_DIR'];
  if (preview == null) return;
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final screenshot = await boundary.toImage(pixelRatio: 1);
    final bytes = await screenshot.toByteData(format: ui.ImageByteFormat.png);
    await Directory(preview).create(recursive: true);
    await File('$preview/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    screenshot.dispose();
  });
}
