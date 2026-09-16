// Renderização local dos componentes reais para revisão visual, sem chamar APIs.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/components/darcapio/courier_dispatch_dialog.dart';
import 'package:kronos_food/components/darcapio/order_details.dart';
import 'package:kronos_food/components/darcapio/order_style.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';

void main() {
  testWidgets('Renderiza retirada, entrega e seleção de entregador', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('PreviewFont')..addFont(File('C:/Windows/Fonts/segoeui.ttf').readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
      await font.load();
    });
    final boundary = GlobalKey();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('../.codex-build/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    for (final pickup in [true, false]) {
      tester.view.physicalSize = const Size(1440, 1050); tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(RepaintBoundary(key: boundary, child: MaterialApp(theme: ThemeData(fontFamily: 'PreviewFont', colorSchemeSeed: OrderStyle.teal),
        home: Scaffold(backgroundColor: OrderStyle.canvas, body: DarcapioOrderDetails(
          order: DarcapioOrder(id: 'preview', status: 'pronto_entrega', customer: 'Cliente de teste', payment: 'Dinheiro', version: 4, delivery: 41, total: pickup ? 25.9 : 30.9,
            created: DateTime(2026,9,14,17,30), pickup: pickup, deliveryFee: pickup ? 0 : 5,
            address: pickup ? null : {'Rua':'Rua de teste','Numero':'100','Bairro':'Centro','Cidade':'Fortaleza','Uf':'CE'},
            items: [{'Descricao':'X-burger artesanal','Quantidade':1,'ValorUnitario':25.9}],
            actions: [DarcapioAction(pickup ? 'concluir' : 'despachar', pickup ? 'Confirmar retirada' : 'Selecionar entregador e despachar', requiresCourier: !pickup)]),
          busy: false, blocked: false, onAction: (_) {})))));
      await tester.pumpAndSettle(); await capture(pickup ? 'food-retirada-preview' : 'food-entrega-preview');
    }
    await tester.pumpWidget(RepaintBoundary(key: boundary, child: MaterialApp(theme: ThemeData(fontFamily: 'PreviewFont', colorSchemeSeed: OrderStyle.teal),
      home: Scaffold(backgroundColor: OrderStyle.canvas, body: CourierDispatchDialog(orderNumber: 41, load: () async => [const DarcapioCourier(91981,'Carlos - Teste'), const DarcapioCourier(91982,'Ana - Teste')])))));
    await tester.pumpAndSettle(); await tester.tap(find.text('Ana - Teste')); await tester.pumpAndSettle(); await capture('food-entregador-preview');
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio();
  });
}
