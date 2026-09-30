import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/pages/darcapio_order_history_page.dart';
import 'package:kronos_food/pages/food_orders_view.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'darcapio_test.dart' show FakeDarcapio, order;

class MovementRepository extends FakeDarcapio {
  bool closed = false;
  int code = 1;
  final historyCalls = <(int, int)>[];
  @override
  Future<List<DarcapioOrder>> list() async {
    currentMovement = closed
        ? null
        : DarcapioCashMovement(
            code: code, opened: DateTime(2026, 9, 29, 15), isOpen: true);
    return closed || code != 1 ? [] : [current];
  }

  @override
  Future<List<DarcapioCashMovement>> movements({int? code}) async => [
        DarcapioCashMovement(
            code: 1,
            opened: DateTime(2026, 9, 29, 15),
            closed: DateTime(2026, 9, 30, 3),
            isOpen: false),
      ].where((m) => code == null || m.code == code).toList();
  @override
  Future<DarcapioOrderPage> history(int movement, {int page = 0}) async {
    historyCalls.add((movement, page));
    return DarcapioOrderPage(
        page: page,
        size: 100,
        total: 201,
        orders: [order(page == 0 ? 'concluido' : 'cancelado', 3)]);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Atualização acompanha fechamento e nova abertura sem filtrar o iFood',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MovementRepository();
    final ifood = PedidoModel.fromKronos({
      'Id': 'ifood-test',
      'DisplayId': 'IFOOD1',
      'Status': 'PLC',
      'Customer': {'Name': 'Cliente iFood'}
    });
    await tester.pumpWidget(MaterialApp(
        home: FoodOrdersView(repository: repo, ifoodOrders: [ifood])));
    await tester.pumpAndSettle();
    final darcapioCard =
        find.byKey(ValueKey('darcapio-order-${repo.current.id}'));
    expect(darcapioCard, findsOneWidget);
    expect(find.text('Darcapio · Movimento #1'), findsOneWidget);
    await tester.tap(darcapioCard);
    await tester.pumpAndSettle();
    repo.closed = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(darcapioCard, findsNothing);
    expect(find.text('Darcapio · Sem caixa aberto'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('ifood-order-ifood-test')), findsOneWidget);
    expect(find.text('Aceitar pedido'), findsNothing);
    repo.closed = false;
    repo.code = 2;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Darcapio · Movimento #2'), findsOneWidget);
    expect(darcapioCard, findsNothing);
    expect(
        find.byKey(const ValueKey('ifood-order-ifood-test')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Histórico mostra concluídos, pagina e abre detalhes sem ações',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MovementRepository();
    var printed = 0;
    await tester.pumpWidget(MaterialApp(
        home: DarcapioOrderHistoryPage(
            repository: repo,
            onPrint: (_) async {
              printed++;
            })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Movimento #1'));
    await tester.pumpAndSettle();
    expect(find.text('Somente consulta'), findsOneWidget);
    expect(find.text('201 pedidos · Página 1 de 3'), findsOneWidget);
    final card = find.byKey(ValueKey('darcapio-order-${repo.current.id}'));
    expect(card, findsOneWidget);
    await tester.tap(find.byTooltip('Próxima página'));
    await tester.pumpAndSettle();
    expect(repo.historyCalls, [(1, 0), (1, 1)]);
    expect(find.text('201 pedidos · Página 2 de 3'), findsOneWidget);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Imprimir pedido'), findsOneWidget);
    expect(find.text('Aceitar'), findsNothing);
    expect(find.text('Recusar'), findsNothing);
    await tester.tap(find.byTooltip('Imprimir pedido'));
    await tester.pumpAndSettle();
    expect(printed, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'Contrato usa movimento informado pelo servidor e filtra histórico pelo código',
      () async {
    final prefs = PreferencesService();
    await prefs.saveServerIp('https://localhost:5943/arc');
    await prefs.saveCompanyCode('1');
    await prefs.saveKronosToken('test-token');
    final requests = <RequestOptions>[];
    var closed = false;
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
        requests.add(request);
        handler.resolve(Response(
            requestOptions: request,
            statusCode: 200,
            data: request.path.endsWith('movimento-atual')
                ? {
                    'Movimento': closed
                        ? null
                        : {
                            'Codigo': 17,
                            'DataAbertura': '2026-09-29T15:00:00',
                            'Aberto': true
                          },
                    'Itens': []
                  }
                : {'Pagina': 2, 'Tamanho': 100, 'Total': 205, 'Itens': []}));
      }));
    final repo = DarcapioRepository(client: dio);
    await repo.list();
    expect(repo.currentMovement!.code, 17);
    closed = true;
    await repo.list();
    expect(repo.currentMovement, isNull);
    final page = await repo.history(12, page: 2);
    expect(page.total, 205);
    expect(page.hasNext, isFalse);
    expect(requests.last.queryParameters,
        {'movimentoCaixa': 12, 'pagina': 2, 'tamanho': 100});
    expect(requests.every((r) => r.headers['Empresa'] == '1'), isTrue);
    repo.dispose();
  });

  test('Relatório do movimento contém status, valores e escapa células CSV',
      () {
    final value = DarcapioOrder(
        id: 'test',
        status: 'concluido',
        customer: '=SUM(1;2) "cliente"',
        payment: 'Dinheiro',
        version: 1,
        delivery: 5,
        total: 27.9,
        created: DateTime(2026, 9, 30, 2),
        items: []);
    final csv = darcapioMovementCsv(17, [value]);
    expect(csv, contains('"17";"5";"30/09/2026 02:00"'));
    expect(csv, contains('"\'=SUM(1;2) ""cliente"""'));
    expect(csv, contains('"Retirada";"Concluído";"27,90"'));
  });
}
