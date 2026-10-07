import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/components/ifood_connection_dialog.dart';
import 'package:kronos_food/controllers/pedidos_controller.dart';
import 'package:kronos_food/pages/pedidos_page.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'darcapio_test.dart' show FakeDarcapio;
import 'food_orders_page_test.dart' show UnavailableIfoodController;

class ReconnectedIfoodController extends UnavailableIfoodController {
  int initializations = 0;

  @override
  Future<void> init(BuildContext context) async {
    await super.init(context);
    initializations++;
    if (initializations > 1) {
      haveError = false;
      merchantStatus.value = MerchantStatus.ok;
      notifyListeners();
    }
  }
}

void main() {
  final preferences = PreferencesService();
  late List<RequestOptions> requests;
  late Dio client;
  bool rejectAuthorization = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    rejectAuthorization = false;
    client = Dio();
    client.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      if (options.path.endsWith('/userCode')) {
        handler
            .resolve(Response(requestOptions: options, statusCode: 200, data: {
          'userCode': 'TEST-CODE',
          'authorizationCodeVerifier': 'fake-private-verifier',
          'verificationUrl': 'https://portal.ifood.com.br/apps/code',
          'verificationUrlComplete':
              'https://portal.ifood.com.br/apps/code?c=TEST-CODE',
          'expiresIn': 600,
        }));
      } else if (rejectAuthorization) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 401, data: {
            'error': {'message': 'Invalid authorization code'}
          }),
        ));
      } else {
        handler
            .resolve(Response(requestOptions: options, statusCode: 200, data: {
          'accessToken': 'fake-authorized-access',
          'refreshToken': 'fake-authorized-refresh',
          'expiresIn': 21600,
        }));
      }
    }));
  });

  AuthRepository repository({bool distributed = true}) => AuthRepository(
        client: client,
        preferences: preferences,
        clientId: 'fake-client',
        clientSecret: 'fake-secret',
        distributed: distributed,
      );

  Future<void> openConnection(WidgetTester tester,
      {bool distributed = true}) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
      builder: (context) => Scaffold(
          body: TextButton(
        onPressed: () => showDialog<bool>(
            context: context,
            builder: (_) => IfoodConnectionDialog(
                repository: repository(distributed: distributed))),
        child: const Text('Abrir conexão'),
      )),
    )));
    await tester.tap(find.text('Abrir conexão'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Autorização usa código e verifier, salva renovação e preserva sessão Kronos',
      (tester) async {
    await preferences.saveKronosToken('fake-kronos-session');
    await openConnection(tester);
    expect(find.text('TEST-CODE'), findsOneWidget);
    expect(find.text('fake-private-verifier'), findsNothing);
    expect(await preferences.getAccessToken(), isNull);
    await tester.enterText(find.byType(TextField), '  fake-authorization  ');
    await tester.tap(find.text('Conectar'));
    await tester.pumpAndSettle();
    expect(find.byType(IfoodConnectionDialog), findsNothing);
    expect(requests, hasLength(2));
    expect(requests.last.data['grantType'], 'authorization_code');
    expect(requests.last.data['authorizationCode'], 'fake-authorization');
    expect(requests.last.data['authorizationCodeVerifier'],
        'fake-private-verifier');
    expect(await preferences.getRefreshToken(), 'fake-authorized-refresh');
    expect(await preferences.getAccessToken(), 'fake-authorized-access');
    expect(await preferences.isTokenExpired(), isFalse);
    expect(await preferences.getKronosToken(), 'fake-kronos-session');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Código recusado permite tentar novamente sem substituir tokens anteriores',
      (tester) async {
    rejectAuthorization = true;
    await preferences.saveAccessToken('fake-previous-access');
    await preferences.saveRefreshToken('fake-previous-refresh');
    await openConnection(tester);
    await tester.enterText(find.byType(TextField), 'fake-invalid-code');
    await tester.tap(find.text('Conectar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('O iFood não aceitou'), findsOneWidget);
    expect(find.textContaining('fake-secret'), findsNothing);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            (widget.data?.contains('fake-invalid-code') ?? false)),
        findsNothing);
    expect(await preferences.getAccessToken(), 'fake-previous-access');
    expect(await preferences.getRefreshToken(), 'fake-previous-refresh');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(IfoodConnectionDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Código vazio não envia pedido de token e permite cancelar',
      (tester) async {
    await openConnection(tester);
    await tester.tap(find.text('Conectar'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(
        find.textContaining('Informe o código de autorização'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await preferences.getAccessToken(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Aplicativo centralizado continua conectando somente com as chaves',
      (tester) async {
    await openConnection(tester, distributed: false);
    expect(requests, hasLength(1));
    expect(requests.single.data['grantType'], 'client_credentials');
    expect(find.byType(IfoodConnectionDialog), findsNothing);
    expect(await preferences.getAccessToken(), 'fake-authorized-access');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Renovar código substitui o desafio sem enviar token',
      (tester) async {
    await openConnection(tester);
    await tester.enterText(find.byType(TextField), 'fake-old-code');
    await tester.ensureVisible(find.text('Gerar novo código'));
    await tester.tap(find.text('Gerar novo código'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests.every((request) => request.path.endsWith('/userCode')),
        isTrue);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Botão do painel autoriza e reinicia iFood preservando os pedidos Darcapio',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ReconnectedIfoodController();
    await tester.pumpWidget(MaterialApp(
        home: PedidosPage(
      controller: controller,
      darcapioRepository: FakeDarcapio(),
      ifoodAuthRepository: repository(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('iFood · desconectado'), findsOneWidget);
    final darcapioOrder = find.byKey(
        const ValueKey('darcapio-order-00000000-0000-0000-0000-000000000123'));
    expect(darcapioOrder, findsOneWidget);
    await tester.tap(find.text('Conectar iFood').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(IfoodConnectionDialog),
            matching: find.byType(TextField)),
        'fake-authorization');
    await tester.tap(find.text('Conectar'));
    await tester.pumpAndSettle();
    expect(controller.initializations, 2);
    expect(find.text('iFood · conectado'), findsOneWidget);
    expect(darcapioOrder, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
