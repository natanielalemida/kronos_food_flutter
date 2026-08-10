import 'package:dio/dio.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/controllers/main_controller.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:kronos_food/utils/app_logger.dart';

class AuthRepository {
  final Dio dio = AppLogger.createDio(source: 'AuthRepository');
  final PreferencesService _preferencesService = PreferencesService();
  final MainController _mainController = MainController();

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

    try {
      final tokenData = await authenticateWithClientCredentials();
      await saveConfig(tokenData);
      _mainController.setConfig(tokenData);
      return tokenData['accessToken'];
    } catch (e) {
      print("Erro ao atualizar token: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> getUserCode() async {
    final response = await dio.post(
      "${Consts.authUrl}/oauth/userCode",
      options: Options(
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
      data: {
        'clientId': Consts.clientId,
      },
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data as Map);
    } else {
      throw Exception("Failed to authenticate");
    }
  }

  Future<Map<String, dynamic>> authenticateWithClientCredentials() async {
    final response = await dio.post(
      "${Consts.authUrl}/oauth/token",
      options: Options(
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
      data: {
        'grantType': "client_credentials",
        'clientId': Consts.clientId,
        'clientSecret': Consts.clientSecret,
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
    if (isRefresh && refreshToken.isEmpty) {
      return authenticateWithClientCredentials();
    }

    final body = <String, dynamic>{
      'grantType': isRefresh ? "refresh_token" : "authorization_code",
      'clientId': Consts.clientId,
      'clientSecret': Consts.clientSecret,
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
      return _normalizeTokenData(response.data);
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
