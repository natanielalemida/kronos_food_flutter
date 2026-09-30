import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/controllers/pedidos_controller.dart';
import 'package:kronos_food/components/food_source_badge.dart';
import 'package:kronos_food/models/food_order_entry.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/pages/food_orders_view.dart';
import 'package:kronos_food/pages/pedidos_page.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'darcapio_test.dart' show FakeDarcapio, order;

class UnavailableIfoodController extends ValueNotifier<List<dynamic>>
    implements PedidosController {
  UnavailableIfoodController({this.pending = false}) : super([]);

  final bool pending;
  final Completer<void> connection = Completer<void>();
  @override
  bool isLoading = false;
  @override
  bool haveError = false;
  @override
  String errorMsg = '';
  @override
  Map<String, List<PedidoModel>> pedidosMap = {};
  @override
  final merchantStatus = ValueNotifier<MerchantStatus>(MerchantStatus.error);
  @override
  ValueNotifier<PedidoModel?> selectedPedido = ValueNotifier(null);

  @override
  Future<void> init(BuildContext context) async {
    isLoading = true;
    notifyListeners();
    if (pending) await connection.future;
    isLoading = false;
    haveError = true;
    errorMsg = 'Token de acesso inválido ou expirado';
    notifyListeners();
  }

  @override
  Future<void> setAutoAcceptEnabled(bool enabled) async {}
  @override
  Future<void> setAutoPrintEnabled(bool enabled) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UnavailableDarcapio extends DarcapioRepository {
  UnavailableDarcapio() : super(client: Dio());

  @override
  Future<int> useExistingSession() async => 1;
  @override
  Future<List<DarcapioOrder>> list() async =>
      throw StateError('Darcapio indisponível. Tente novamente.');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openFood(
    WidgetTester tester,
    PedidosController ifood,
    DarcapioRepository darcapio,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: PedidosPage(controller: ifood, darcapioRepository: darcapio),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Darcapio orders and actions work when iFood login fails',
      (tester) async {
    final ifood = UnavailableIfoodController();
    final darcapio = FakeDarcapio();
    await openFood(tester, ifood, darcapio);

    expect(ifood.haveError, isTrue);
    expect(find.text('iFood · desconectado'), findsOneWidget);
    expect(find.text('Não foi possível conectar ao iFood'), findsNothing);
    expect(
        find.byKey(const ValueKey(
            'darcapio-order-00000000-0000-0000-0000-000000000123')),
        findsOneWidget);
    await tester.tap(find.byKey(
        const ValueKey('darcapio-order-00000000-0000-0000-0000-000000000123')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Imprimir pedido'), findsOneWidget);
    await tester.tap(find.text('Aceitar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(darcapio.accepted, 1);
    expect(find.text('Marcar como pronto'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('New Darcapio order can be accepted from its card',
      (tester) async {
    final darcapio = FakeDarcapio()
      ..current = order('recebido_erp', 1, actions: const [
        DarcapioAction('aceitar', 'Aceitar pedido'),
        DarcapioAction('cancelar', 'Cancelar pedido'),
      ]);
    await openFood(tester, UnavailableIfoodController(), darcapio);

    final card = find.byKey(ValueKey('darcapio-order-${darcapio.current.id}'));
    expect(find.descendant(of: card, matching: find.text('Aceitar')),
        findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Recusar')),
        findsOneWidget);

    await tester.tap(find.byKey(
        ValueKey('darcapio-order-${darcapio.current.id}-accept-action')));
    await tester.pumpAndSettle();
    expect(find.text('Aceitar pedido'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(darcapio.accepted, 1);
    expect(darcapio.receivedReason, isNull);
    expect(
        find.byKey(
            ValueKey('darcapio-order-${darcapio.current.id}-accept-action')),
        findsNothing);
    expect(find.descendant(of: card, matching: find.text('Em preparo')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('New Darcapio order can be refused from its card with a reason',
      (tester) async {
    final darcapio = FakeDarcapio()
      ..current = order('recebido_erp', 1, actions: const [
        DarcapioAction('aceitar', 'Aceitar pedido'),
        DarcapioAction('cancelar', 'Cancelar pedido'),
      ]);
    await openFood(tester, UnavailableIfoodController(), darcapio);

    await tester.tap(find.byKey(
        ValueKey('darcapio-order-${darcapio.current.id}-reject-action')));
    await tester.pumpAndSettle();
    expect(find.text('Motivo do cancelamento'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Motivo do cancelamento'),
        'Loja sem estoque para atender');
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(darcapio.accepted, 1);
    expect(darcapio.receivedReason, 'Loja sem estoque para atender');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Pending iFood never blocks Darcapio or clears selected orders',
      (tester) async {
    final ifood = UnavailableIfoodController(pending: true);
    await openFood(tester, ifood, FakeDarcapio());

    expect(find.text('iFood · conectando'), findsOneWidget);
    await tester.tap(find.byKey(
        const ValueKey('darcapio-order-00000000-0000-0000-0000-000000000123')));
    await tester.pumpAndSettle();
    expect(find.text('1× X-burger artesanal'), findsOneWidget);
    ifood.connection.complete();
    await tester.pumpAndSettle();
    expect(find.text('1× X-burger artesanal'), findsOneWidget);

    expect(find.text('iFood · desconectado'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Darcapio'), findsNothing);
    expect(find.text('1× X-burger artesanal'), findsOneWidget);
    expect(find.text('Não foi possível conectar ao iFood'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Darcapio errors stay visible when both integrations fail',
      (tester) async {
    await openFood(
      tester,
      UnavailableIfoodController(),
      UnavailableDarcapio(),
    );

    expect(
        find.text('Darcapio indisponível. Tente novamente.'), findsOneWidget);
    expect(find.text('Não foi possível conectar ao iFood'), findsNothing);
    expect(find.text('Aceitar pedido'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Orders from both channels appear together with source badges',
      (tester) async {
    final darcapio = FakeDarcapio();
    final ifood = UnavailableIfoodController();
    // Same raw ID and order number must remain two distinct entries.
    final ifoodOrder = PedidoModel.fromKronos({
      'Id': darcapio.current.id,
      'DisplayId': '0123',
      'Status': 'PLC',
      'CreatedAt': '2026-09-11T15:01:00',
      'Customer': {'Name': 'Cliente iFood'},
    });
    ifood.pedidosMap = {
      'PLC': [ifoodOrder]
    };
    await openFood(tester, ifood, darcapio);

    expect(
        find.byKey(ValueKey('ifood-order-${ifoodOrder.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('darcapio-order-${darcapio.current.id}')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('food-order-group-Aguardando aceite')),
        findsOneWidget);
    expect(find.text('#0123'), findsNWidgets(2));
    expect(find.byType(FoodSourceBadge), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'ifood');
    await tester.pumpAndSettle();
    expect(
        find.byKey(ValueKey('ifood-order-${ifoodOrder.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('darcapio-order-${darcapio.current.id}')),
        findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (size, kanban) in [
    (const Size(1200, 900), false),
    (const Size(400, 850), false),
    (const Size(1200, 900), true),
  ]) {
    testWidgets('Mixed selection routes each payload at $size, kanban: $kanban',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final darcapio = FakeDarcapio();
      final ifood = PedidoModel.fromKronos({
        'Id': darcapio.current.id,
        'DisplayId': '0123',
        'Status': 'PLC',
        'CreatedAt': '2026-09-11T15:01:00',
      });
      PedidoModel? selectedIfood;
      int ifoodActions = 0;
      await tester.pumpWidget(MaterialApp(
          home: FoodOrdersView(
        repository: darcapio,
        ifoodOrders: [ifood],
        ifoodConnected: true,
        kanban: kanban,
        onIfoodSelected: (order) => selectedIfood = order,
        ifoodDetailsBuilder: (order) => Center(
            child: TextButton(
          onPressed: () => ifoodActions++,
          child: const Text('Ação iFood de teste'),
        )),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('ifood-order-${ifood.id}')));
      await tester.pumpAndSettle();
      expect(selectedIfood, same(ifood));
      await tester.tap(find.text('Ação iFood de teste'));
      expect(ifoodActions, 1);
      expect(darcapio.accepted, 0);

      if (size.width < 860 || kanban) {
        await tester.tap(find.text('Voltar à lista'));
        await tester.pumpAndSettle();
      }
      final darcapioCard =
          find.byKey(ValueKey('darcapio-order-${darcapio.current.id}'));
      await tester.ensureVisible(darcapioCard);
      await tester.pumpAndSettle();
      await tester.tap(darcapioCard);
      await tester.pumpAndSettle();
      expect(find.text('Ação iFood de teste'), findsNothing);
      await tester.tap(find.text('Aceitar pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(darcapio.accepted, 1);
      expect(ifoodActions, 1);
      expect(find.text('Marcar como pronto'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('Combined entries retain channel identity and group iFood statuses', () {
    final darcapio = FakeDarcapio();
    final ifood = PedidoModel.fromKronos({
      'Id': darcapio.current.id,
      'DisplayId': '123',
      'Status': 'CFM',
      'CreatedAt': '2026-09-11T16:00:00',
    });
    final entries = FoodOrderEntry.combine([ifood, ifood], [darcapio.current]);
    expect(entries.length, 2);
    expect(entries.first.source, FoodOrderSource.ifood);
    expect(entries.first.status, 'em_preparo');
    expect(entries.last.source, FoodOrderSource.darcapio);
    expect(entries.last.status, 'recebido_erp');
  });

  testWidgets('Kanban is a global view for iFood and Darcapio orders',
      (tester) async {
    final darcapio = FakeDarcapio();
    final ifood = PedidoModel.fromKronos({
      'Id': 'ifood-123',
      'DisplayId': '999',
      'Status': 'PLC',
      'CreatedAt': '2026-09-11T16:00:00',
    });

    await tester.pumpWidget(MaterialApp(
      home: FoodOrdersView(
        repository: darcapio,
        ifoodOrders: [ifood],
        kanban: true,
        ifoodConnected: true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ifood-order-ifood-123')), findsOneWidget);
    expect(
        find.byKey(const ValueKey(
            'darcapio-order-00000000-0000-0000-0000-000000000123')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('food-order-group-Aguardando aceite')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
