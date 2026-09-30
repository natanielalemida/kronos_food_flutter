import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/components/darcapio/order_details.dart';
import 'package:kronos_food/pages/food_orders_view.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kronos_food/models/food_store_identity.dart';

DarcapioOrder order(String status, int version,
        {List<DarcapioAction> actions = const [], bool pickup = true}) =>
    DarcapioOrder(
        id: '00000000-0000-0000-0000-000000000123',
        status: status,
        customer: 'Cliente de teste',
        payment: 'Dinheiro',
        version: version,
        delivery: 123,
        total: 27.9,
        created: DateTime(2026, 9, 11, 15),
        pickup: pickup,
        actions: actions,
        items: [
          {
            'Descricao': 'X-burger artesanal',
            'Quantidade': 1,
            'Adicionais': [],
            'Observacao': 'Sem cebola'
          }
        ]);

class FakeDarcapio extends DarcapioRepository {
  DarcapioOrder current = order('recebido_erp', 1,
      actions: [const DarcapioAction('aceitar', 'Aceitar pedido')]);
  int accepted = 0;
  String? receivedCode;
  String? receivedReason;
  int? receivedCourier;
  Object? advanceFailure;
  Completer<void>? pendingAdvance;
  List<DarcapioCourier> availableCouriers = [
    const DarcapioCourier(77, 'Ana entregadora'),
    const DarcapioCourier(78, 'João entregador')
  ];
  FakeDarcapio() : super(client: Dio());
  @override
  Future<int> useExistingSession() async => 1;
  @override
  Future<FoodStoreIdentity> storeIdentity() async =>
      const FoodStoreIdentity(company: 1, name: 'Loja de teste');
  @override
  Future<List<DarcapioOrder>> list() async => [current];
  @override
  Future<List<Map<String, dynamic>>> conversationSummaries() async => [];
  @override
  Future<List<DarcapioCourier>> couriers() async => availableCouriers;
  @override
  Future<void> advance(DarcapioOrder value, DarcapioAction action,
      {String? code, int? courierCode, String? reason}) async {
    accepted++;
    receivedCode = code;
    receivedReason = reason;
    receivedCourier = courierCode;
    if (pendingAdvance != null) await pendingAdvance!.future;
    if (advanceFailure != null) throw advanceFailure!;
    current = order('em_preparo', 2,
        actions: [const DarcapioAction('pronto', 'Marcar como pronto')]);
  }
}

void main() {
  for (final pickup in [false, true]) {
    testWidgets(
        'Código incorreto permanece em destaque e permite corrigir na ${pickup ? 'retirada' : 'entrega'}',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final request = RequestOptions(path: '/status');
      final fake = FakeDarcapio()
        ..current = order(pickup ? 'pronto_retirada' : 'saiu_para_entrega', 5,
            pickup: pickup,
            actions: [
              DarcapioAction(
                  'concluir', 'Confirmar ${pickup ? 'retirada' : 'entrega'}',
                  requiresCode: true)
            ])
        ..advanceFailure = DioException(
            requestOptions: request,
            response: Response(requestOptions: request, statusCode: 400, data: {
              'codigo': 'codigo_incorreto',
              'mensagem':
                  'Código incorreto. Confira com o cliente. A etapa não foi alterada.'
            }));
      await tester.pumpWidget(MaterialApp(
          home: FoodOrdersView(
              repository: fake,
              initialOrderKey:
                  'darcapio-order-00000000-0000-0000-0000-000000000123')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.text('Confirmar ${pickup ? 'retirada' : 'entrega'}'));
      await tester.pumpAndSettle();
      final input = find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(input, '111111');
      await tester.pump();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Código incorreto'), findsOneWidget);
      expect(tester.widget<TextField>(input).decoration!.errorText, isNotNull);
      expect(
          (tester.widget<TextField>(input).decoration!.focusedErrorBorder!
                  as OutlineInputBorder)
              .borderSide
              .color,
          const Color(0xFFB42318));
      expect(find.text('Darcapio · conectado'), findsOneWidget);
      expect(find.text('Darcapio · desconectado'), findsNothing);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(fake.current.version, 5);

      fake.advanceFailure = null;
      fake.pendingAdvance = Completer<void>();
      await tester.enterText(input, '123456');
      await tester.pump();
      await tester.tap(find.text('Conferir novamente'));
      await tester.pump();
      expect(find.text('Conferindo código…'), findsOneWidget);
      expect(tester.widget<TextField>(input).readOnly, isTrue);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Conferindo código…'))
              .onPressed,
          isNull);
      expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Voltar'))
              .onPressed,
          isNull);
      expect(fake.accepted, 2);
      fake.pendingAdvance!.complete();
      await tester.pumpAndSettle();
      expect(fake.receivedCode, '123456');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Darcapio · conectado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'Bloqueio por tentativas exige voltar e atualizar sem marcar código incorreto',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final request = RequestOptions(path: '/status');
    final fake = FakeDarcapio()
      ..current = order('saiu_para_entrega', 5, pickup: false, actions: [
        const DarcapioAction('concluir', 'Confirmar entrega',
            requiresCode: true)
      ])
      ..advanceFailure = DioException(
          requestOptions: request,
          response: Response(requestOptions: request, statusCode: 429, data: {
            'codigo': 'codigo_bloqueado',
            'mensagem':
                'Muitas tentativas incorretas. Aguarde 15 minutos e confira o código com o cliente.'
          }));
    await tester.pumpWidget(MaterialApp(
        home: FoodOrdersView(
            repository: fake,
            initialOrderKey:
                'darcapio-order-00000000-0000-0000-0000-000000000123')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar entrega'));
    await tester.pumpAndSettle();
    final input = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(input, '111111');
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aguarde 15 minutos'), findsOneWidget);
    expect(find.text('Código incorreto'), findsNothing);
    expect(tester.widget<TextField>(input).readOnly, isTrue);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirmar'))
            .onPressed,
        isNull);
    expect(fake.current.version, 5);
    await tester.tap(find.text('Voltar e atualizar pedido'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Darcapio · conectado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test('Motivo de cancelamento automático é preservado na resposta do Service',
      () {
    final parsed = DarcapioOrder.fromJson({
      'PedidoId': 'prazo-teste',
      'CodigoDelivery': 1,
      'Situacao': 'cancelado',
      'VersaoStatus': 2,
      'CriadoEm': '2026-09-15T12:00:00Z',
      'Pedido': {'Total': 50, 'Retirada': true, 'Itens': []},
      'Historico': [
        {'Situacao': 'recebido_erp'},
        {
          'Situacao': 'cancelado',
          'Motivo': 'Cancelado automaticamente: sem aceite em 10 minutos.'
        }
      ]
    });
    expect(parsed.cancellationReason,
        'Cancelado automaticamente: sem aceite em 10 minutos.');
    expect(parsed.actions, isEmpty);
  });
  testWidgets(
      'Despacho exige seleção e envia o código do entregador confirmado',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = FakeDarcapio()
      ..current = order('pronto_entrega', 4, pickup: false, actions: [
        const DarcapioAction('despachar', 'Selecionar entregador e despachar',
            requiresCourier: true)
      ]);
    await tester.pumpWidget(MaterialApp(
        home: FoodOrdersView(
            repository: fake,
            initialOrderKey:
                'darcapio-order-00000000-0000-0000-0000-000000000123')));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(DarcapioOrderDetails),
            matching: find.text('ENTREGA')),
        findsOneWidget);
    await tester.tap(find.text('Selecionar entregador e despachar'));
    await tester.pumpAndSettle();
    final confirm =
        find.widgetWithText(FilledButton, 'Confirmar saída para entrega');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(fake.accepted, 0);
    await tester.tap(find.text('João entregador'));
    await tester.pump();
    expect(fake.accepted, 0);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(fake.receivedCourier, 78);
    expect(fake.accepted, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'Sem entregadores o despacho fica bloqueado e voltar não muda o pedido',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = FakeDarcapio()
      ..availableCouriers = []
      ..current = order('pronto_entrega', 4, pickup: false, actions: [
        const DarcapioAction('despachar', 'Selecionar entregador e despachar',
            requiresCourier: true)
      ]);
    await tester.pumpWidget(MaterialApp(
        home: FoodOrdersView(
            repository: fake,
            initialOrderKey:
                'darcapio-order-00000000-0000-0000-0000-000000000123')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar entregador e despachar'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Nenhum entregador disponível.'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(
                FilledButton, 'Confirmar saída para entrega'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(fake.accepted, 0);
    expect(fake.current.status, 'pronto_entrega');
    await tester.pumpWidget(const SizedBox());
  });
  test('Origem do ERP exige HTTPS sem credenciais na URL', () {
    expect(DarcapioRepository.validateServer('https://erp.example/arc').scheme,
        'https');
    expect(DarcapioRepository.validateServer('http://127.0.0.1:5942/arc').host,
        '127.0.0.1');
    for (final url in [
      'http://erp.example/arc',
      'https://user:pass@erp.example/arc',
      'https://erp.example/arc?token=x',
      'https://erp.example'
    ]) {
      expect(() => DarcapioRepository.validateServer(url), throwsStateError);
    }
  });
  test('Food não infere ações a partir do status', () {
    expect(order('recebido_erp', 1).actions, isEmpty);
    final parsed = DarcapioOrder.fromJson({
      'PedidoId': 'pedido',
      'Situacao': 'etapa_do_service',
      'ClienteNome': 'Maria',
      'VersaoStatus': 2,
      'CodigoDelivery': 42,
      'CriadoEm': '2026-09-11T15:00:00Z',
      'AcoesPermitidas': [
        {
          'Acao': 'operacao_service',
          'Rotulo': 'Ação autorizada',
          'ExigeCodigo': true
        }
      ],
      'Pedido': {
        'Total': 27.9,
        'Retirada': false,
        'TaxaEntrega': 5,
        'PrecisaTroco': true,
        'TrocoPara': 50,
        'Endereco': {'Rua': 'Rua de Teste'},
        'Itens': [
          {'Descricao': 'Lanche'}
        ]
      }
    });
    expect(parsed.actions.single.action, 'operacao_service');
    expect(parsed.actions.single.requiresCode, true);
    expect(parsed.pickup, false);
    expect(parsed.deliveryFee, 5);
    expect(parsed.changeFor, 50);
    expect(parsed.address?['Rua'], 'Rua de Teste');
  });
  test('Reutiliza sessão e empresa sem outro POST de login', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PreferencesService();
    await prefs.saveServerIp('https://localhost:5943/arc');
    await prefs.saveCompanyCode('1');
    await prefs.saveKronosToken('session-test-only');
    final dio = Dio();
    final calls = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls.add(options);
      handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: []));
    }));
    final repo = DarcapioRepository(client: dio);
    await repo.list();
    expect(
        calls.single.path, 'https://localhost:5943/arc/darcapio/food/pedidos');
    expect(calls.single.method, 'GET');
    expect(calls.single.headers['Auth'], 'session-test-only');
    expect(calls.single.headers['Empresa'], '1');
    repo.dispose();
  });
  testWidgets(
      'Abre com a sessão Food, sem formulário de login, e confirma ação do Service',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = FakeDarcapio();
    await tester
        .pumpWidget(MaterialApp(home: FoodOrdersView(repository: fake)));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.byKey(
        const ValueKey('darcapio-order-00000000-0000-0000-0000-000000000123')));
    await tester.pumpAndSettle();
    expect(find.text('1× X-burger artesanal'), findsOneWidget);
    expect(find.text('Observação: Sem cebola'), findsOneWidget);
    expect(find.text('Sincronizado no ERP · Delivery #0123'), findsOneWidget);
    await tester.tap(find.text('Aceitar pedido'));
    await tester.pumpAndSettle();
    expect(fake.accepted, 0);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(fake.accepted, 1);
    expect(find.text('Marcar como pronto'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Código digitado é enviado ao Service, nunca comparado no Food',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = FakeDarcapio()
      ..current = order('saiu_para_entrega', 5, pickup: false, actions: [
        const DarcapioAction('concluir', 'Confirmar entrega',
            requiresCode: true)
      ]);
    await tester
        .pumpWidget(MaterialApp(home: FoodOrdersView(repository: fake)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('darcapio-order-00000000-0000-0000-0000-000000000123')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar entrega'));
    await tester.pumpAndSettle();
    expect(fake.accepted, 0);
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '123456');
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(fake.receivedCode, '123456');
    expect(fake.accepted, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
