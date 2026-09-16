import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/controllers/main_controller.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:kronos_food/service/ifood_credential_store.dart';
import 'package:kronos_food/utils/app_logger.dart';

class AuthRepository {
  final Dio dio;
  final PreferencesService _preferencesService;
  final MainController _mainController = MainController();
  final String clientId;
  final String clientSecret;
  final String? Function(String) _readClientSecret;
  final bool distributed;
  static final Map<String, Future<String?>> _pendingRenewals = {};

  AuthRepository({
    Dio? client,
    PreferencesService? preferences,
    this.clientId = Consts.clientId,
    this.clientSecret = Consts.clientSecret,
    String? Function(String)? readClientSecret,
    this.distributed = Consts.ifoodAuthMode == 'distributed',
  })  : dio = client ?? _createAuthClient(),
        _readClientSecret =
            readClientSecret ?? IfoodCredentialStore.readClientSecret,
        _preferencesService = preferences ?? PreferencesService();

  static Dio _createAuthClient() {
    final client = AppLogger.createDio(
      source: 'AuthRepository',
      options: BaseOptions(
        followRedirects: false,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    client.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () =>
          HttpClient()..badCertificateCallback = (_, __, ___) => false,
    );
    return client;
  }

  String _requireCredentials() {
    final secret = clientSecret.isNotEmpty
        ? clientSecret
        : (clientId.isEmpty ? null : _readClientSecret(clientId));
    if (clientId.trim().isEmpty || secret == null || secret.trim().isEmpty) {
      throw StateError(
        'A integração iFood ainda não foi configurada nesta versão do Food. '
        'Informe as credenciais do aplicativo antes de conectar a loja.',
      );
    }
    return secret;
  }

  Future<Map<String, dynamic>> getConfig() async {
    return await _preferencesService.getConfig();
  }

  Future<void> saveConfig(Map<String, dynamic> config) async {
    await _preferencesService.saveConfig(config);
  }

  Future<void> saveKronosToken(String token) async {
    await _preferencesService.saveKronosToken(token);
  }

  Future<void> saveCodeUser(String code) async {
    await _preferencesService.saveCodeUser(code);
  }

  Future<String?> getValidAccessToken() async {
    final isExpired = await _preferencesService.isTokenExpired();
    final currentToken = await _preferencesService.getAccessToken();

    if (!isExpired && currentToken != null && currentToken.isNotEmpty) {
      return currentToken;
    }

    final pending = _pendingRenewals[clientId];
    if (pending != null) return pending;
    final renewal = _renewToken();
    _pendingRenewals[clientId] = renewal;
    try {
      return await renewal;
    } finally {
      if (identical(_pendingRenewals[clientId], renewal)) {
        _pendingRenewals.remove(clientId);
      }
    }
  }

  Future<String?> _renewToken() async {
    try {
      final refreshToken = await _preferencesService.getRefreshToken();
      if (distributed && (refreshToken == null || refreshToken.isEmpty)) {
        return null;
      }
      final tokenData = refreshToken != null && refreshToken.isNotEmpty
          ? await authenticate(true, '', '', refreshToken)
          : await authenticateWithClientCredentials();
      await saveConfig(tokenData);
      _mainController.setConfig(tokenData);
      return tokenData['accessToken'];
    } catch (e) {
      await AppLogger.warning('Não foi possível renovar o acesso ao iFood.',
          category: 'IFOOD_AUTH', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>> getUserCode() async {
    _requireCredentials();
    final response = await dio.post(
      "${Consts.authUrl}/oauth/userCode",
      options: Options(
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
      data: {
        'clientId': clientId,
      },
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data as Map);
    } else {
      throw Exception("Failed to authenticate");
    }
  }

  Future<Map<String, dynamic>> authenticateWithClientCredentials() async {
    final secret = _requireCredentials();
    if (distributed) {
      throw StateError(
        'Autorize o aplicativo no Portal do Parceiro iFood para conectar a loja.',
      );
    }
    final response = await dio.post(
      "${Consts.authUrl}/oauth/token",
      options: Options(
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
      data: {
        'grantType': "client_credentials",
        'clientId': clientId,
        'clientSecret': secret,
      },
    );

    if (response.statusCode == 200) {
      return _normalizeTokenData(response.data);
    } else {
      throw Exception(response.data);
    }
  }

  Future<Map<String, dynamic>> authenticate(bool isRefresh, String authCode,
      String verifyCode, String refreshToken) async {
    final secret = _requireCredentials();
    if (isRefresh && refreshToken.isEmpty) {
      return authenticateWithClientCredentials();
    }

    final body = <String, dynamic>{
      'grantType': isRefresh ? "refresh_token" : "authorization_code",
      'clientId': clientId,
      'clientSecret': secret,
    };

    if (isRefresh) {
      body["refreshToken"] = refreshToken;
    } else {
      body["authorizationCode"] = authCode;
      body["authorizationCodeVerifier"] = verifyCode;
    }

    final response = await dio.post(
      "${Consts.authUrl}/oauth/token",
      options: Options(
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
      data: body,
    );

    if (response.statusCode == 200) {
      final tokens = _normalizeTokenData(response.data);
      if (isRefresh && !tokens.containsKey('refreshToken')) {
        tokens['refreshToken'] = refreshToken;
      }
      return tokens;
    } else {
      throw Exception(response.data);
    }
  }

  Map<String, dynamic> _normalizeTokenData(dynamic data) {
    final body = Map<String, dynamic>.from(data as Map);
    final accessToken = body['accessToken'] ?? body['access_token'];
    final expiresIn = body['expiresIn'] ?? body['expires_in'] ?? 3600;

    if (accessToken == null || accessToken.toString().isEmpty) {
      throw Exception("Token do iFood nao retornado");
    }

    return {
      'accessToken': accessToken.toString(),
      'expiresIn': expiresIn is int
          ? expiresIn
          : int.tryParse(expiresIn.toString()) ?? 3600,
      if (body['refreshToken'] != null || body['refresh_token'] != null)
        'refreshToken':
            (body['refreshToken'] ?? body['refresh_token']).toString(),
      if (body['tokenType'] != null || body['token_type'] != null)
        'tokenType': (body['tokenType'] ?? body['token_type']).toString(),
    };
  }
}
