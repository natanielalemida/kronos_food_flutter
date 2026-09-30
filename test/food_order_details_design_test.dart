import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/components/darcapio/order_details.dart';
import 'package:kronos_food/components/darcapio/order_style.dart';
import 'package:kronos_food/components/food_order_progress.dart';
import 'package:kronos_food/components/ifood_order_details_view.dart';
import 'package:kronos_food/components/order_timeline.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';

PedidoModel previewIfoodOrder(
        {String status = 'CFM',
        bool pickup = false,
        String deliveredBy = 'MERCHANT'}) =>
    PedidoModel.fromKronos({
      'Id': 'preview-ifood',
      'DisplayId': '8275',
      'Status': status,
      'CreatedAt': '2026-09-15T14:29:00',
      'OrderType': pickup ? 'TAKEOUT' : 'DELIVERY',
      'SalesChannel': 'IFOOD',
      'Customer': {
        'Name': 'Mariana Costa',
        'Phone': {'Number': '0800 705 6070', 'Localizer': '26277959'}
      },
      'Delivery': {
        'DeliveredBy': deliveredBy,
        'NomeEntregador': 'Carlos Silva',
        'DeliveryAddress': {
          'StreetName': 'Rua das Palmeiras',
          'StreetNumber': '120',
          'Neighborhood': 'Centro',
          'City': 'Fortaleza',
          'PostalCode': '60000-000',
          'Complement': 'Apartamento 302',
          'Reference': 'Portaria ao lado da padaria'
        }
      },
      'Items': [
        {
          'Name': 'X-burger artesanal',
          'Quantity': 1,
          'UnitPrice': 24.9,
          'TotalPrice': 29.9,
          'Observations': 'Sem cebola. Entregar na portaria, por favor.',
          'Options': [
            {'Name': 'Bacon extra', 'Quantity': 1, 'Price': 5.0}
          ]
        },
        {
          'Name': 'Água mineral 500 ml',
          'Quantity': 2,
          'UnitPrice': 4.0,
          'TotalPrice': 8.0
        },
      ],
      'Total': {
        'SubTotal': 37.9,
        'DeliveryFee': pickup ? 0.0 : 5.0,
        'AdditionalFees': 1.0,
        'Benefits': 3.0,
        'OrderAmount': pickup ? 35.9 : 40.9
      },
      'Benefits': [
        {
          'Value': 3.0,
          'SponsorshipValues': [
            {'Name': 'IFOOD', 'Value': 3.0}
          ]
        }
      ],
      'Payments': {
        'Pending': pickup ? 35.9 : 40.9,
        'Methods': [
          {
            'Method': 'CASH',
            'Type': 'OFFLINE',
            'Value': pickup ? 35.9 : 40.9,
            'Cash': {'ChangeFor': 50.0}
          }
        ]
      },
      'Events': [
        {'Id': 'e1', 'Code': 'CFM', 'CreatedAt': '2026-09-15T14:30:00'}
      ],
    });

DarcapioOrder previewDarcapioOrder(
        {String status = 'em_preparo', bool pickup = false}) =>
    DarcapioOrder(
      id: 'preview-darcapio',
      status: status,
      customer: 'Mariana Costa',
      payment: 'Dinheiro',
      version: 4,
      delivery: 42,
      total: 42.9,
      created: DateTime(2026, 9, 15, 14, 29),
      pickup: pickup,
      needsChange: true,
      changeFor: 50,
      deliveryFee: pickup ? 0 : 5,
      courierName: 'Carlos Silva',
      address: {
        'Rua': 'Rua das Palmeiras',
        'Numero': '120',
        'Bairro': 'Centro',
        'Cidade': 'Fortaleza',
        'Uf': 'CE',
        'Cep': '60000-000',
        'Complemento': 'Apartamento 302'
      },
      items: [
        {
          'Descricao': 'X-burger artesanal',
          'Quantidade': 1,
          'ValorUnitario': 29.9,
          'Observacao': 'Sem cebola. Entregar na portaria, por favor.'
        },
        {
          'Descricao': 'Água mineral 500 ml',
          'Quantidade': 2,
          'ValorUnitario': 4.0
        },
      ],
      actions: const [
        DarcapioAction('pronto_entrega', 'Pronto para entrega'),
        DarcapioAction('cancelar', 'Cancelar pedido')
      ],
    );

void main() {
  testWidgets(
      'Darcapio usa cinco etapas e agrupa pedidos aceitos antigos em preparo',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const labels = [
      'Aguardando aceite',
      'Em preparo',
      'Pronto',
      'Em rota de entrega',
      'Concluído'
    ];
    for (final (status, stage) in [
      ('aguardando_erp', 0),
      ('recebido_erp', 0),
      ('aceito', 1),
      ('em_preparo', 1),
      ('pronto_entrega', 2),
      ('saiu_para_entrega', 3),
      ('concluido', 4),
    ]) {
      final order = previewDarcapioOrder(status: status);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: DarcapioOrderDetails(
        order: order,
        busy: false,
        blocked: false,
        onAction: (_) {},
      ))));
      await tester.pumpAndSettle();
      final progress =
          tester.widget<FoodOrderProgress>(find.byType(FoodOrderProgress));
      expect(progress.steps.map((s) => s.label), labels);
      expect(progress.steps.where((s) => s.reached).length, stage + 1);
      expect(progress.progress, (stage + 1) / 5);
      expect(order.label, labels[stage]);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'Tracking stays available for partner delivery and hidden for pickup',
      (tester) async {
    for (final (pickup, deliveredBy, visible) in [
      (false, 'IFOOD', true),
      (false, 'MERCHANT', false),
      (true, 'IFOOD', false)
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: IfoodOrderDetailsView(
        order: previewIfoodOrder(pickup: pickup, deliveredBy: deliveredBy),
        onPrint: () {},
        actions: const SizedBox(),
        tracking: const Text('Mapa do entregador'),
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Mapa do entregador'),
          visible ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Counter orders keep their pickup information', (tester) async {
    final order = PedidoModel.fromKronos({
      'Id': 'counter',
      'DisplayId': '77',
      'Status': 'CFM',
      'SalesChannel': 'TOTEM',
      'OrderType': 'INDOOR',
      'CreatedAt': '2026-09-15T14:29:00'
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: IfoodOrderDetailsView(
                order: order, onPrint: () {}, actions: const SizedBox()))));
    await tester.pumpAndSettle();
    expect(find.text('RETIRADA'), findsOneWidget);
    expect(find.text('Pedido no totem'), findsOneWidget);
    expect(find.text('ENTREGA'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(1440, 1050),
    const Size(600, 950),
    const Size(390, 844)
  ]) {
    testWidgets('iFood detail preserves information and actions at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var actions = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: IfoodOrderDetailsView(
        order: previewIfoodOrder(),
        onPrint: () {},
        actions: FilledButton(
            onPressed: () => actions++, child: const Text('Despachar pedido')),
      ))));
      await tester.pumpAndSettle();
      expect(find.byType(FoodOrderProgress), findsOneWidget);
      expect(find.text('Pedido #8275'), findsOneWidget);
      expect(find.text('Mariana Costa'), findsOneWidget);
      expect(find.text('Taxas adicionais'), findsOneWidget);
      expect(find.text('Desconto · IFOOD'), findsOneWidget);
      expect(find.text(OrderStyle.money(9.1)), findsOneWidget);
      expect(find.text('Rua das Palmeiras, 120'), findsOneWidget);
      expect(find.textContaining('Sem cebola.'), findsOneWidget);
      await tester.tap(find.text('Despachar pedido'));
      expect(actions, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'Darcapio detail uses shared progress without overflow at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var prints = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: DarcapioOrderDetails(
        order: previewDarcapioOrder(),
        busy: false,
        blocked: false,
        onAction: (_) {},
        onPrint: () => prints++,
      ))));
      await tester.pumpAndSettle();
      expect(find.byType(FoodOrderProgress), findsOneWidget);
      expect(find.byTooltip('Imprimir pedido'), findsOneWidget);
      await tester.tap(find.byTooltip('Imprimir pedido'));
      expect(prints, 1);
      expect(
          tester
              .widget<FoodOrderProgress>(find.byType(FoodOrderProgress))
              .progress,
          .4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'Pickup omits the delivery stage and cancellation never shows completion',
      (tester) async {
    for (final status in ['pronto_retirada', 'cancelado']) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: DarcapioOrderDetails(
        order: previewDarcapioOrder(status: status, pickup: true),
        busy: false,
        blocked: false,
        onAction: (_) {},
      ))));
      await tester.pumpAndSettle();
      final progress =
          tester.widget<FoodOrderProgress>(find.byType(FoodOrderProgress));
      expect(
          progress.steps.any((s) => s.label == 'Em rota de entrega'), isFalse);
      if (status == 'cancelado') expect(progress.progress, 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('iFood shows real event times and reacts to a status update',
      (tester) async {
    for (final (status, value) in [
      ('CFM', .45),
      ('DSP', .85),
      ('CON', 1.0),
      ('CAN', 0.0)
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: OrderTimeline(order: previewIfoodOrder(status: status)))));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FoodOrderProgress>(find.byType(FoodOrderProgress))
              .progress,
          value);
      expect(find.text('14:29'), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Unaccepted iFood orders keep address and payment details hidden',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: IfoodOrderDetailsView(
      order: previewIfoodOrder(status: 'PLC'),
      onPrint: () {},
      actions: const SizedBox(),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Rua das Palmeiras, 120'), findsNothing);
    expect(find.text('Receber em dinheiro'), findsNothing);
    expect(find.textContaining('após o aceite'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
