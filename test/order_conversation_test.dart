import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/components/darcapio/order_conversation.dart';
import 'package:kronos_food/pages/food_orders_view.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'darcapio_test.dart' show FakeDarcapio, order;

class ConversationFake extends FakeDarcapio {
  final sent = <Map<String, dynamic>>[];
  final request = {
    'id': '00000000-0000-0000-0000-000000000222',
    'tipo': 'cancelamento',
    'texto': 'Escolhi a retirada por engano.'
  };
  @override
  Future<Map<String, dynamic>> conversation(String order,
          {int? before}) async =>
      {
        'mensagens': [
          {
            'id': request['id'],
            'sequencia': 1,
            'autor': 'cliente',
            'tipo': 'cancelamento',
            'situacao': 'pendente',
            'texto': request['texto'],
            'criadoEm': '2026-09-15T01:00:00Z',
            'temFoto': false
          }
        ],
        'pendentes': [request],
        'temAnteriores': false,
      };
  @override
  Future<void> conversationPost(
      String order, String path, Map<String, dynamic> data) async {
    sent.add({'path': path, ...data});
  }
}

void main() {
  testWidgets('Cancelamento exige motivo e o envia ao Service', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeDarcapio()
      ..current = order('em_preparo', 3,
          actions: [const DarcapioAction('cancelar', 'Cancelar pedido')]);
    await tester.pumpWidget(MaterialApp(
        home: FoodOrdersView(
            repository: repo,
            initialOrderKey: 'darcapio-order-${repo.current.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar pedido'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirmar'))
            .onPressed,
        isNull);
    await tester.enterText(
        find.widgetWithText(TextField, 'Motivo do cancelamento'),
        'Cliente desistiu do pedido.');
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(repo.receivedReason, 'Cliente desistiu do pedido.');
    expect(repo.accepted, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'Chat mostra solicitação, marca leitura e envia resposta pelo Service',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = ConversationFake();
    var cancelCalls = 0;
    var viewCalls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OrderConversation(
                repository: repo,
                orderId: repo.current.id,
                customer: 'Cliente teste',
                getOrder: () => repo.current,
                onViewOrder: () => viewCalls++,
                onCancel: () async {
                  cancelCalls++;
                }))));
    await tester.pumpAndSettle();
    expect(find.text('Cliente solicitou cancelamento'), findsOneWidget);
    expect(find.text('Pedido #0123'), findsOneWidget);
    expect(find.text('Retirada na loja'), findsOneWidget);
    expect(find.textContaining('X-burger'), findsOneWidget);
    await tester.tap(find.text('Ver pedido'));
    expect(viewCalls, 1);
    expect(repo.sent.any((p) => p['path'] == 'lida'), isTrue);
    await tester.enterText(
        find.widgetWithText(TextField, 'Mensagem ao cliente'),
        'Vamos conferir seu pedido.');
    await tester.pump();
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(repo.sent.singleWhere((p) => p['path'] == 'mensagens')['texto'],
        'Vamos conferir seu pedido.');
    await tester.tap(find.text('Aceitar cancelamento'));
    await tester.pumpAndSettle();
    expect(cancelCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Recusar solicitação exige resposta e não cancela a venda',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = ConversationFake();
    var cancelCalls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OrderConversation(
                repository: repo,
                orderId: repo.current.id,
                customer: 'Cliente teste',
                onCancel: () async {
                  cancelCalls++;
                }))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recusar solicitação'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirmar resposta'))
            .onPressed,
        isNull);
    await tester.enterText(
        find.widgetWithText(TextField, 'Explique ao cliente'),
        'Vamos combinar a entrega pelo chat.');
    await tester.pump();
    await tester.tap(find.text('Confirmar resposta'));
    await tester.pumpAndSettle();
    expect(
        repo.sent.singleWhere(
            (p) => p['path'].toString().endsWith('/resposta'))['decisao'],
        'recusada');
    expect(cancelCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
