import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/components/darcapio/order_conversation.dart';
import 'package:kronos_food/components/darcapio/order_style.dart';
import '../test/order_conversation_test.dart' show ConversationFake;

void main() {
  testWidgets('Renderiza atendimento do Food', (tester) async {
    await tester.runAsync(() async {final font = FontLoader('PreviewFont')..addFont(File('C:/Windows/Fonts/segoeui.ttf').readAsBytes().then((bytes) => ByteData.sublistView(bytes))); await font.load();});
    tester.view.physicalSize = const Size(1100, 950); tester.view.devicePixelRatio = 1;
    final boundary = GlobalKey(); final repo = ConversationFake();
    await tester.pumpWidget(RepaintBoundary(key: boundary, child: MaterialApp(theme: ThemeData(fontFamily: 'PreviewFont', colorSchemeSeed: OrderStyle.teal), home: Scaffold(body: OrderConversation(repository: repo, orderId: repo.current.id, customer: 'Cliente de teste', onCancel: () async {})))));
    await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
    await tester.runAsync(() async {final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(); final bytes = await image.toByteData(format: ui.ImageByteFormat.png); await File('../.codex-build/food-atendimento-preview.png').writeAsBytes(bytes!.buffer.asUint8List()); image.dispose();});
    await tester.pumpWidget(const SizedBox()); tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio();
  });
}
