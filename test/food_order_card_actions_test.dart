import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/components/darcapio/order_details.dart';
import 'package:kronos_food/components/food_order_list.dart';
import 'package:kronos_food/models/food_order_entry.dart';
import 'package:kronos_food/pages/food_orders_view.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'darcapio_test.dart' show FakeDarcapio, order;

class CardFlowRepository extends FakeDarcapio {
  final String resultStatus;
  String? actionTaken;
  String? expectedCode;
  CardFlowRepository(this.resultStatus);

  @override
  Future<void> advance(DarcapioOrder value, DarcapioAction action,
      {String? code, int? courierCode, String? reason}) async {
    if (expectedCode != null && code != expectedCode) {
      final request = RequestOptions(path: '/status');
      throw DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: request, statusCode: 400, data: {
            'codigo': 'codigo_incorreto',
            'mensagem': 'Código incorreto. Confira com o cliente.',
          }));
    }
    actionTaken = action.action;
    await super.advance(value, action,
        code: code, courierCode: courierCode, reason: reason);
    current = order(resultStatus, value.version + 1, pickup: value.pickup);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final pickup in [false, true]) {
    testWidgets('Cartão marca pronto após confirmar; retirada: $pickup',
        (tester) async {
      final repository =
          CardFlowRepository(pickup ? 'pronto_retirada' : 'pronto_entrega')
            ..current = order('em_preparo', 2, pickup: pickup, actions: const [
              DarcapioAction('pronto', 'Marcar como pronto'),
              DarcapioAction('cancelar', 'Cancelar pedido'),
            ]);
      await openOrders(tester, repository);
      expect(find.text('Recusar'), findsNothing);
      await tester.tap(find.text('Marcar como pronto'));
      await tester.pumpAndSettle();
      expect(repository.accepted, 0);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(repository.actionTaken, 'pronto');
      expect(repository.current.status,
          pickup ? 'pronto_retirada' : 'pronto_entrega');
      expect(find.text('Pronto'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    for (final details in [false, true]) {
      if (pickup) continue;
      testWidgets(
          'Entrega conclui sem código conforme contrato Food; detalhes: $details',
          (tester) async {
        final repository = CardFlowRepository('concluido')
          ..current = order(pickup ? 'pronto_retirada' : 'saiu_para_entrega', 4,
              pickup: pickup,
              actions: [
                DarcapioAction.fromJson({
                  'Acao': 'concluir',
                  'Rotulo': pickup ? 'Confirmar retirada' : 'Confirmar entrega',
                  'ExigeCodigo': false,
                }),
              ]);
        await openOrders(tester, repository, details: details);
        final label = pickup
            ? 'Confirmar retirada'
            : details
                ? 'Confirmar entrega'
                : 'Marcar como concluído';
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final input = find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField));
        expect(input, findsNothing);
        expect(repository.accepted, 0);
        // Fechar a confirmação não deve finalizar o pedido.
        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();
        expect(repository.accepted, 0);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();
        expect(repository.accepted, 1);
        expect(repository.actionTaken, 'concluir');
        expect(repository.receivedCode, isNull);
        expect(repository.current.status, 'concluido');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('Servidor antigo ainda pode exigir código; retirada: $pickup',
        (tester) async {
      final repository = CardFlowRepository('concluido')
        ..current = order(pickup ? 'pronto_retirada' : 'saiu_para_entrega', 4,
            pickup: pickup,
            actions: [
              DarcapioAction('concluir',
                  pickup ? 'Confirmar retirada' : 'Confirmar entrega',
                  requiresCode: true),
              const DarcapioAction('cancelar', 'Cancelar pedido'),
            ]);
      await openOrders(tester, repository);
      expect(find.text('Recusar'), findsNothing);
      expect(find.text('Marcar em rota de entrega'), findsNothing);
      await tester.tap(
          find.text(pickup ? 'Confirmar retirada' : 'Marcar como concluído'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Confirmar');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(repository.accepted, 0);
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)),
          '123456');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repository.actionTaken, 'concluir');
      expect(repository.receivedCode, '123456');
      expect(repository.current.status, 'concluido');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final requiresCode in [false, true]) {
    for (final details in [false, true]) {
      for (final kanban in [false, true]) {
        testWidgets(
            'Retirada exige código e permite corrigir erro; contrato: $requiresCode; detalhes: $details; kanban: $kanban',
            (tester) async {
          final repository = CardFlowRepository('concluido')
            ..expectedCode = '012345'
            ..current = order('pronto_retirada', 4, pickup: true, actions: [
              DarcapioAction('concluir', 'Confirmar retirada',
                  requiresCode: requiresCode),
            ]);
          await openOrders(tester, repository,
              details: details, kanban: kanban);
          final withdrawalAction = details
              ? find.descendant(
                  of: find.byType(DarcapioOrderDetails),
                  matching: find.text('Confirmar retirada'))
              : find.text('Confirmar retirada');
          await tester.tap(withdrawalAction);
          await tester.pumpAndSettle();
          final input = find.widgetWithText(TextField, 'Código do cliente');
          final confirm = find.widgetWithText(FilledButton, 'Confirmar');
          expect(input, findsOneWidget);
          expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
          await tester.enterText(input, '12345');
          await tester.pump();
          expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
          expect(repository.accepted, 0);
          await tester.tap(find.text('Voltar'));
          await tester.pumpAndSettle();
          expect(repository.accepted, 0);

          await tester.tap(withdrawalAction);
          await tester.pumpAndSettle();
          await tester.enterText(input, '111111');
          await tester.pump();
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(find.text('Código incorreto'), findsOneWidget);
          expect(repository.current.status, 'pronto_retirada');
          expect(repository.accepted, 0);
          await tester.enterText(input, '012345');
          await tester.pump();
          await tester
              .tap(find.widgetWithText(FilledButton, 'Conferir novamente'));
          await tester.pumpAndSettle();
          expect(repository.actionTaken, 'concluir');
          expect(repository.receivedCode, '012345');
          expect(repository.accepted, 1);
          expect(repository.current.status, 'concluido');
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }

  testWidgets('Cartão despacha somente após selecionar o entregador',
      (tester) async {
    final repository = CardFlowRepository('saiu_para_entrega')
      ..current = order('pronto_entrega', 3, pickup: false, actions: const [
        DarcapioAction('despachar', 'Selecionar entregador e despachar',
            requiresCourier: true),
        DarcapioAction('cancelar', 'Cancelar pedido'),
      ]);
    await openOrders(tester, repository);
    expect(find.text('Recusar'), findsNothing);
    await tester.tap(find.text('Marcar em rota de entrega'));
    await tester.pumpAndSettle();
    final confirm =
        find.widgetWithText(FilledButton, 'Confirmar saída para entrega');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(repository.accepted, 0);
    await tester.tap(find.text('João entregador'));
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repository.actionTaken, 'despachar');
    expect(repository.receivedCourier, 78);
    expect(repository.current.status, 'saiu_para_entrega');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Sem próxima ação autorizada, cartão não oferece recusa isolada',
      (tester) async {
    final repository = FakeDarcapio()
      ..current = order('recebido_erp', 1, actions: const [
        DarcapioAction('cancelar', 'Cancelar pedido'),
      ]);
    await openOrders(tester, repository);
    expect(find.text('Recusar'), findsNothing);
    expect(find.text('Aceitar'), findsNothing);
    repository.current = order('em_preparo', 2);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Marcar como pronto'), findsNothing);
    expect(repository.accepted, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Ação de pedido aceito legado segue o servidor e respeita bloqueio',
      (tester) async {
    tester.view.physicalSize = const Size(370, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FoodOrderList(
      orders: [
        FoodOrderEntry.darcapio(order('aceito', 2, actions: const [
          DarcapioAction('pronto', 'Marcar como pronto'),
          DarcapioAction('cancelar', 'Cancelar pedido'),
        ]))
      ],
      selectedId: null,
      onSelected: (_) {},
      connected: false,
      actionsEnabled: false,
      onOrderAction: (_, __) => calls++,
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Recusar'), findsNothing);
    final button = find.widgetWithText(FilledButton, 'Marcar como pronto');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(button);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}

Future<void> openOrders(WidgetTester tester, FakeDarcapio repository,
    {bool details = false, bool kanban = true}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      home: FoodOrdersView(
          repository: repository,
          kanban: kanban,
          initialOrderKey:
              details ? 'darcapio-order-${repository.current.id}' : null)));
  await tester.pumpAndSettle();
}
