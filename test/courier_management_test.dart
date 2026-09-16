import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/controllers/couriers_controller.dart';
import 'package:kronos_food/models/courier_management.dart';
import 'package:kronos_food/pages/couriers_page.dart';
import 'package:kronos_food/pages/food_orders_view.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'darcapio_test.dart' show FakeDarcapio;

class FakeCouriers extends FakeDarcapio {
  CourierAccessState state = CourierAccessState.notConnected;
  int invitations = 0, revocations = 0;
  Object? failure;
  Completer<void>? waiting;
  @override
  Future<CourierManagement> courierManagement() async {
    if (waiting != null) await waiting!.future;
    if (failure != null) throw failure!;
    return CourierManagement(
        storeName: 'Loja B',
        storeUrl: 'https://loja.test',
        couriers: [
          CourierAccess(code: 9, name: 'Carlos', state: state, activeOrders: 6),
        ]);
  }

  @override
  Future<CourierInvite> inviteCourier(int code) async {
    invitations++;
    state = CourierAccessState.invitePending;
    return CourierInvite(
        code: 'ABCDEF0123456789ABCDEF01',
        storeUrl: 'https://loja.test',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)));
  }

  @override
  Future<void> revokeCourier(int code) async {
    revocations++;
    state = CourierAccessState.revoked;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> page(WidgetTester tester, FakeCouriers repository,
      {double width = 1200}) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(MaterialApp(home: CouriersPage(repository: repository)));
    await tester.pumpAndSettle();
  }

  testWidgets('gera convite, copia e remove o código após pareamento',
      (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final repository = FakeCouriers();
    await page(tester, repository);
    expect(find.text('6 entregas em andamento'), findsOneWidget);
    await tester.tap(find.text('Gerar convite'));
    await tester.pumpAndSettle();
    expect(repository.invitations, 1);
    expect(find.text('ABCDEF0123456789ABCDEF01'), findsOneWidget);
    await tester.tap(find.text('Copiar convite'));
    await tester.pumpAndSettle();
    expect(clipboard, 'ABCDEF0123456789ABCDEF01');
    repository.state = CourierAccessState.connected;
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('Celular conectado'), findsOneWidget);
    expect(find.text('ABCDEF0123456789ABCDEF01'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('novo convite exige confirmação e encerrar não afeta pedidos',
      (tester) async {
    final repository = FakeCouriers()..state = CourierAccessState.connected;
    await page(tester, repository);
    await tester.tap(find.text('Novo convite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(repository.invitations, 0);
    await tester.tap(find.text('Encerrar acesso'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Os pedidos continuam atribuídos'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Encerrar acesso'));
    await tester.pumpAndSettle();
    expect(repository.revocations, 1);
    expect(find.text('Acesso encerrado'), findsOneWidget);
    expect(find.text('6 entregas em andamento'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('layout estreito e erro de permissão sem ações', (tester) async {
    final repository = FakeCouriers();
    await page(tester, repository, width: 460);
    expect(tester.takeException(), isNull);
    repository.failure = DioException(
        requestOptions: RequestOptions(path: '/entregadores'),
        response: Response(
            requestOptions: RequestOptions(path: '/entregadores'),
            statusCode: 403,
            data: {'mensagem': 'Acesso restrito aos administradores.'}));
    await tester.tap(find.byTooltip('Atualizar entregadores'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso restrito aos administradores.'), findsOneWidget);
    expect(find.text('Gerar convite'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('atalho da tela de pedidos abre gestão e permite voltar',
      (tester) async {
    final repository = FakeCouriers();
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(MaterialApp(home: FoodOrdersView(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Entregadores'));
    await tester.pumpAndSettle();
    expect(find.text('Sua equipe na rua'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Gerenciador de pedidos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test('mutação espera consulta anterior e impede convite duplicado', () async {
    final repository = FakeCouriers()..waiting = Completer<void>();
    final controller = CouriersController(repository);
    final load = controller.reload();
    const courier = CourierAccess(
        code: 9, name: 'Carlos', state: CourierAccessState.notConnected);
    final first = controller.generate(courier);
    await controller.generate(courier);
    expect(repository.invitations, 0);
    repository.waiting!.complete();
    await load;
    await first;
    expect(repository.invitations, 1);
    expect(controller.invite, isNotNull);
    controller.dispose();
  });
  test('repositório envia tudo ao Service com sessão e empresa', () async {
    final prefs = PreferencesService();
    await prefs.saveServerIp('https://erp.test/arc');
    await prefs.saveKronosToken('session');
    await prefs.saveCompanyCode('2');
    final paths = <String>[];
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        paths.add('${options.method} ${options.uri}');
        expect(options.headers['Auth'], 'session');
        expect(options.headers['Empresa'], '2');
        handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: options.method == 'GET'
                ? {
                    'storeName': 'B',
                    'storeUrl': 'https://loja.test',
                    'couriers': []
                  }
                : options.method == 'POST'
                    ? {
                        'storeUrl': 'https://loja.test',
                        'invite': {
                          'code': 'code',
                          'expiresAt': DateTime.now()
                              .add(const Duration(minutes: 15))
                              .toIso8601String()
                        }
                      }
                    : null));
      }));
    final repository = DarcapioRepository(client: dio);
    await repository.courierManagement();
    await repository.inviteCourier(9);
    await repository.revokeCourier(9);
    expect(paths, [
      'GET https://erp.test/arc/darcapio/food/entregadores',
      'POST https://erp.test/arc/darcapio/food/entregadores/9/convite',
      'DELETE https://erp.test/arc/darcapio/food/entregadores/9/acesso'
    ]);
  });
}
