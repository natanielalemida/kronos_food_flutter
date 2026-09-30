import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/controllers/auth_controller.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalHttpOverrides = HttpOverrides.current;
  setUpAll(() => HttpOverrides.global = null);
  tearDownAll(() => HttpOverrides.global = originalHttpOverrides);

  late HttpServer server;
  late Map<String, dynamic> loginResponse;
  late List<Map<String, dynamic>> loginRequests;
  late List<String?> orderSessions;
  late int ifoodCalls;
  late Interceptor ifoodInterceptor;
  final auth = AuthController();
  final prefs = PreferencesService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    loginRequests = [];
    orderSessions = [];
    ifoodCalls = 0;
    loginResponse = {
      'Status': 1,
      'Resultado': {
        'Usuario': {'Codigo': 91001, 'Hash': 'food-session-test-only'},
      },
    };
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/arc/usuario/login/') {
        loginRequests.add(jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>);
        request.response.write(jsonEncode(loginResponse));
      } else if (request.uri.path ==
          '/arc/darcapio/food/pedidos/movimento-atual') {
        orderSessions.add(request.headers.value('Auth'));
        expect(request.headers.value('Empresa'), '1');
        request.response.write('{"Movimento":null,"Itens":[]}');
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    await prefs.saveServerIp('http://127.0.0.1:${server.port}/arc');
    await prefs.saveCompanyCode('1');
    await prefs.saveTerminalCode('91001');
    ifoodInterceptor = InterceptorsWrapper(onRequest: (options, handler) {
      ifoodCalls++;
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'iFood unavailable in this test',
      ));
    });
    auth.authRepository.dio.interceptors.insert(0, ifoodInterceptor);
  });

  tearDown(() async {
    auth.authRepository.dio.interceptors.remove(ifoodInterceptor);
    await server.close(force: true);
  });

  test('Normal Food login opens Darcapio with the same session without iFood',
      () async {
    expect(await auth.loginUser('operator', 'test-password'), isTrue);
    expect(auth.isAuthenticated.value, isTrue);
    expect(auth.haveError.value, isFalse);
    expect(ifoodCalls, 0);
    expect(loginRequests.single['aplicacao'], 9);
    expect(loginRequests.single['numeroterminal'], 91001);
    expect(loginRequests.single['codigoempresa'], 1);

    final darcapio = DarcapioRepository();
    try {
      expect(await darcapio.list(), isEmpty);
      expect(orderSessions, ['food-session-test-only']);
      expect(loginRequests, hasLength(1));
    } finally {
      darcapio.dispose();
    }
  });

  test('Rejected Food credentials do not create an authenticated session',
      () async {
    auth.isAuthenticated.value = true;
    loginResponse = {
      'Status': 0,
      'Mensagem': 'Usuário ou senha inválidos.',
    };
    expect(await auth.loginUser('operator', 'wrong-password'), isFalse);
    expect(auth.isAuthenticated.value, isFalse);
    expect(auth.haveError.value, isTrue);
    expect(loginRequests, hasLength(1));
    expect(await prefs.getKronosToken(), isNull);
    expect(ifoodCalls, 0);
  });

  test('Food login rejects a successful response without a session token',
      () async {
    loginResponse = {
      'Status': 1,
      'Resultado': {
        'Usuario': {'Codigo': 91001, 'Hash': ''},
      },
    };
    expect(await auth.loginUser('operator', 'test-password'), isFalse);
    expect(auth.isAuthenticated.value, isFalse);
    expect(loginRequests, hasLength(1));
    expect(await prefs.getKronosToken(), isNull);
    expect(ifoodCalls, 0);
  });
}
