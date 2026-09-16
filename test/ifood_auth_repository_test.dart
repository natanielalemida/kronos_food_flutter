import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Dio client;
  late List<Map<String, dynamic>> requests;
  final preferences = PreferencesService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    client = Dio();
    client.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(Map<String, dynamic>.from(options.data as Map));
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'accessToken': 'fake-new-token', 'expiresIn': 21600},
      ));
    }));
  });

  AuthRepository repository(
          {bool distributed = true, String id = 'fake-client'}) =>
      AuthRepository(
        client: client,
        preferences: preferences,
        clientId: id,
        clientSecret: 'fake-secret',
        distributed: distributed,
      );

  test('Missing credentials fail before sending an empty client ID', () async {
    await expectLater(repository(id: '').getUserCode(), throwsStateError);
    expect(requests, isEmpty);
  });

  test('Distributed first access does not attempt client credentials',
      () async {
    expect(await repository().getValidAccessToken(), isNull);
    await expectLater(
        repository().authenticateWithClientCredentials(), throwsStateError);
    expect(requests, isEmpty);
  });

  test('Distributed renewal uses and preserves the existing refresh token',
      () async {
    await preferences.saveRefreshToken('fake-refresh');
    expect(await repository().getValidAccessToken(), 'fake-new-token');
    expect(requests.single['grantType'], 'refresh_token');
    expect(requests.single['refreshToken'], 'fake-refresh');
    expect(await preferences.getRefreshToken(), 'fake-refresh');
    expect(await preferences.isTokenExpired(), isFalse);
  });

  test('Centralized first access keeps the client credentials flow', () async {
    expect(await repository(distributed: false).getValidAccessToken(),
        'fake-new-token');
    expect(requests.single['grantType'], 'client_credentials');
  });

  test('A valid cached token does not generate another OAuth request',
      () async {
    await preferences
        .saveConfig({'accessToken': 'fake-current-token', 'expiresIn': 21600});
    expect(await repository().getValidAccessToken(), 'fake-current-token');
    expect(requests, isEmpty);
  });

  test('Parallel requests share one token renewal', () async {
    await preferences.saveRefreshToken('fake-refresh');
    final release = Completer<void>();
    client.interceptors.insert(0, InterceptorsWrapper(
      onRequest: (options, handler) async {
        await release.future;
        handler.next(options);
      },
    ));
    final first = repository().getValidAccessToken();
    final second = repository().getValidAccessToken();
    release.complete();
    expect(await Future.wait([first, second]),
        ['fake-new-token', 'fake-new-token']);
    expect(requests, hasLength(1));
  });

  test('Authorization code is exchanged with its verifier', () async {
    final result = await repository()
        .authenticate(false, 'fake-authorization-code', 'fake-verifier', '');
    expect(result['accessToken'], 'fake-new-token');
    expect(requests.single['grantType'], 'authorization_code');
    expect(requests.single['authorizationCode'], 'fake-authorization-code');
    expect(requests.single['authorizationCodeVerifier'], 'fake-verifier');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(Consts.accessTokenKey), isNull);
  });

  test('Renewal resolves the installed credential for the configured client',
      () async {
    await preferences.saveRefreshToken('fake-refresh');
    final localRepository = AuthRepository(
      client: client,
      preferences: preferences,
      clientId: 'fake-local-client',
      clientSecret: '',
      distributed: true,
      readClientSecret: (id) {
        expect(id, 'fake-local-client');
        return 'fake-local-secret';
      },
    );
    expect(await localRepository.getValidAccessToken(), 'fake-new-token');
    expect(requests.single['clientSecret'], 'fake-local-secret');
    expect(requests.single['grantType'], 'refresh_token');
  });

  test('Missing installed credential does not send the refresh token',
      () async {
    await preferences.saveRefreshToken('fake-refresh');
    final localRepository = AuthRepository(
      client: client,
      preferences: preferences,
      clientId: 'fake-local-client',
      clientSecret: '',
      distributed: true,
      readClientSecret: (_) => null,
    );
    expect(await localRepository.getValidAccessToken(), isNull);
    expect(requests, isEmpty);
    expect(await preferences.getRefreshToken(), 'fake-refresh');
  });
}
