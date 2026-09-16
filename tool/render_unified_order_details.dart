// Local visual review of real widgets. No orders or API calls are created.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kronos_food/components/darcapio/order_details.dart';
import 'package:kronos_food/components/darcapio/order_style.dart';
import 'package:kronos_food/components/ifood_order_details_view.dart';
import 'package:kronos_food/components/pedido_actions_buttons.dart';
import 'package:kronos_food/components/food_order_list.dart';
import 'package:kronos_food/components/food_order_brand.dart';
import 'package:kronos_food/models/food_order_entry.dart';
import 'package:kronos_food/models/food_store_identity.dart';
import '../test/food_order_details_design_test.dart'
    show previewIfoodOrder, previewDarcapioOrder;
import '../test/food_orders_page_test.dart' show UnavailableIfoodController;

void main() {
  testWidgets('Preview the unified order details on desktop and narrow windows',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      final font = FontLoader('PreviewFont')
        ..addFont(File('C:/Windows/Fonts/segoeui.ttf')
            .readAsBytes()
            .then(ByteData.sublistView));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(File(
                'C:/Users/natan/AppData/Local/Programs/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf')
            .readAsBytes()
            .then(ByteData.sublistView));
      await icons.load();
    });
    final boundary = GlobalKey();
    final controller = UnavailableIfoodController();
    final order = previewIfoodOrder();
    controller.selectedPedido.value = order;
    for (final size in [const Size(1440, 1050), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final source in ['ifood', 'darcapio']) {
        final detail = source == 'ifood'
            ? IfoodOrderDetailsView(
                order: order,
                onPrint: () {},
                actions: PedidoActionsButtons(
                    controller: controller, onActionComplete: () {}))
            : DarcapioOrderDetails(
                order: previewDarcapioOrder(),
                busy: false,
                blocked: false,
                onAction: (_) {});
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                    fontFamily: 'PreviewFont',
                    colorSchemeSeed: OrderStyle.teal),
                home: Scaffold(
                    backgroundColor: OrderStyle.canvas, body: detail))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final rendered = await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
          final bytes =
              await rendered.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  '../.codex-build/food-unified-$source-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
        await tester.pumpWidget(const SizedBox());
      }
    }
    tester.view.physicalSize = const Size(1440, 1050);
    final sampleOrders = [
      FoodOrderEntry.ifood(order),
      FoodOrderEntry.darcapio(previewDarcapioOrder())
    ];
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'PreviewFont', colorSchemeSeed: OrderStyle.teal),
            home: Scaffold(
                backgroundColor: OrderStyle.canvas,
                body: FoodOrderBrand(
                    source: FoodOrderSource.darcapio,
                    store: const FoodStoreIdentity(company: 2, name: 'Loja B'),
                    child: Row(children: [
                      SizedBox(
                          width: 360,
                          child: FoodOrderList(
                              orders: sampleOrders,
                              selectedId: sampleOrders.first.key,
                              onSelected: (_) {},
                              connected: true)),
                      const VerticalDivider(width: 1),
                      Expanded(
                          child: IfoodOrderDetailsView(
                              order: order,
                              onPrint: () {},
                              actions: PedidoActionsButtons(
                                  controller: controller,
                                  onActionComplete: () {}))),
                    ]))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final rendered = await (boundary.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage();
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      await File('../.codex-build/food-brand-mixed.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      rendered.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    controller.selectedPedido.dispose();
    controller.merchantStatus.dispose();
    controller.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
