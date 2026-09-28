import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/components/food_order_list.dart';
import 'package:kronos_food/models/food_order_entry.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/pages/food_orders_view.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'darcapio_test.dart' show FakeDarcapio, order;

DarcapioOrder snapshot(String status, int number, {bool pickup = false}) =>
    DarcapioOrder.fromJson({
      'pedidoId': 'darcapio-$number',
      'codigoDelivery': number,
      'situacao': status,
      'versaoStatus': 1,
      'criadoEm': '2026-09-14T17:00:00',
      'clienteNome': 'Cliente $number',
      'formaPagamento': 'Dinheiro',
      'pedido': {'retirada': pickup, 'total': 50, 'itens': []},
      'acoesPermitidas': [],
    });

void expectInGroup(Finder card, String title) {
  expect(
      find.descendant(
          of: find.byKey(ValueKey('food-order-group-$title')), matching: card),
      findsOneWidget);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final kanban in [false, true]) {
    testWidgets('Etapa define a coluna em ambos os canais; kanban: $kanban',
        (tester) async {
      tester.view.physicalSize = Size(kanban ? 2800 : 370, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const stages = [
        ('recebido_erp', 'PLC', 'Novos pedidos'),
        ('aceito', 'CFM', 'Em preparo'),
        ('em_preparo', 'CFM', 'Em preparo'),
        ('pronto_entrega', 'RTP', 'Prontos'),
        ('saiu_para_entrega', 'DSP', 'Em entrega'),
        ('concluido', 'CON', 'Concluídos'),
        ('cancelado', 'CAN', 'Cancelados'),
      ];
      final darcapio = [
        for (var i = 0; i < stages.length; i++) snapshot(stages[i].$1, i),
        snapshot('recebido_erp', 40, pickup: true),
        snapshot('pronto_retirada', 41, pickup: true),
      ];
      final ifood = [
        for (var i = 0; i < stages.length; i++)
          PedidoModel.fromKronos({
            'Id': 'ifood-$i',
            'DisplayId': '$i',
            'Status': stages[i].$2,
            'OrderType': 'DELIVERY',
            'OrderTiming': 'IMMEDIATE',
            'CreatedAt': '2026-09-14T17:00:00',
          }),
      ];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: FoodOrderList(
        orders: FoodOrderEntry.combine(ifood, darcapio),
        selectedId: null,
        onSelected: (_) {},
        connected: true,
        kanban: kanban,
      ))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      for (var i = 0; i < stages.length; i++) {
        for (final source in ['darcapio', 'ifood']) {
          final card = find.byKey(ValueKey('$source-order-$source-$i'));
          if (kanban) {
            await tester.ensureVisible(card);
          } else {
            await tester.scrollUntilVisible(card, 400,
                scrollable: find
                    .descendant(
                        of: find.byType(ListView),
                        matching: find.byType(Scrollable))
                    .first);
          }
          await tester.pumpAndSettle();
          expectInGroup(card, stages[i].$3);
        }
      }
      for (final (number, group) in [(40, 'Novos pedidos'), (41, 'Prontos')]) {
        final card = find.byKey(ValueKey('darcapio-order-darcapio-$number'));
        if (kanban) {
          await tester.ensureVisible(card);
        } else {
          await tester.scrollUntilVisible(card, number == 40 ? -400 : 400,
              scrollable: find
                  .descendant(
                      of: find.byType(ListView),
                      matching: find.byType(Scrollable))
                  .first);
        }
        await tester.pumpAndSettle();
        expectInGroup(card, group);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Atualização move pedido novo para pronto e em entrega; kanban: $kanban',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeDarcapio()
        ..current = order('recebido_erp', 1, pickup: false);
      final card =
          find.byKey(ValueKey('darcapio-order-${repository.current.id}'));
      await tester.pumpWidget(MaterialApp(
          home: FoodOrdersView(
        repository: repository,
        kanban: kanban,
      )));
      await tester.pumpAndSettle();
      expectInGroup(card, 'Novos pedidos');
      expect(find.text('Aguardando aceite'), findsOneWidget);
      expect(find.text('ENTREGA'), findsOneWidget);

      repository.current = order('pronto_entrega', 4, pickup: false);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expectInGroup(card, 'Prontos');
      expect(find.text('Novos pedidos'), findsNothing);
      expect(find.text('Pronto para entrega'), findsOneWidget);

      repository.current = order('saiu_para_entrega', 5, pickup: false);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expectInGroup(card, 'Em entrega');
      expect(find.text('Prontos'), findsNothing);
      expect(find.text('Saiu para entrega'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
