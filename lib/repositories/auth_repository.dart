// import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:kronos_food/controllers/main_controller.dart';
import 'package:kronos_food/consts.dart';

class AuthRepository {
  final Dio dio = Dio();
  final PreferencesService _preferencesService = PreferencesService();
  final MainController _mainController = MainController();

  Future<Map<String, dynamic>> getConfig() async {
    return await _preferencesService.getConfig();
  }

  // Save config to preferences
  Future<void> saveConfig(Map<String, dynamic> config) async {
    await _preferencesService.saveConfig(config);
  }

  Future<void> saveKronosToken(String token) async {
    await _preferencesService.saveKronosToken(token);
  }

  Future<void> saveCodeUser(String code) async {
    await _preferencesService.saveCodeUser(code);
  }

  // Save tokens to preferences
  // Future<void> saveTokens(String refreshToken, String accessToken) async {
  //   await _preferencesService.saveRefreshToken(refreshToken);
  //   await _preferencesService.saveAccessToken(accessToken);
  // }

  // Verifica e atualiza o token se necessário
  Future<String?> getValidAccessToken() async {
    bool isExpired = await _preferencesService.isTokenExpired();

    // Se o token não estiver expirado, retorne o token atual
    if (!isExpired) {
      return await _preferencesService.getAccessToken();
    }

    // Se estiver expirado, atualize usando o refresh token
    try {
      String? refreshToken = await _preferencesService.getRefreshToken();
      if (refreshToken == null) {
        return null; // Não tem refresh token, precisa de nova autenticação
      }

      // Chama o método authenticate com isRefresh=true para usar refreshToken
      Map<String, dynamic> tokenData =
          await authenticate(true, "", "", refreshToken);

      // Salva o novo token nos preferences

      final dateTime = DateTime.now();
      final expiresIn = tokenData['expiresIn'] ?? 21600;
      final expirationTime = dateTime.add(Duration(seconds: expiresIn));

      await _saveTokensToBackend(
          tokenData['accessToken'], tokenData['refreshToken'], expirationTime);

      await saveConfig({
        'accessToken': tokenData['accessToken'],
        'refreshToken': tokenData['refreshToken'],
        'dataHoraToken': expirationTime.toIso8601String()
      });

      // Atualiza o mainController com os novos tokens
      _mainController.setConfig(tokenData);

      return tokenData['accessToken'];
    } catch (e) {
      print("Erro ao atualizar token: $e");
      return null;
    }
  }

  Future<bool> _saveTokensToBackend(
      String accessToken, String refreshToken, DateTime dataHoraToken) async {
    try {
      var serverIp = await _preferencesService.getServerIp();
      var kronosToken = await _preferencesService.getKronosToken();
      final codigoEmpresa = await _preferencesService.getCompanyCode() ?? '1';
      // Construir a URL para a API
      final url = '$serverIp/delivery/externo/configuracao';

      // Fazer requisição para o endpoint
      final response = await dio
          .put(
            url,
            data: {
              'AccessToken': accessToken,
              'RefreshToken': refreshToken,
              'DataHoraToken': dataHoraToken.toIso8601String()
            },
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                "Auth": kronosToken ?? "",
                "Empresa": codigoEmpresa,
              },
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getUserCode() async {
    var response = await dio.post(
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
      var body = response.data;
      return body;
    } else {
      throw Exception("Failed to authenticate");
    }
  }

  Future<Map<String, dynamic>> authenticate(bool isRefresh, String authCode,
      String verifyCode, String refreshToken) async {
    var headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    var body = {
      'grantType': "authorization_code",
      'clientId': Consts.clientId,
      'clientSecret': Consts.clientSecret,
      "authorizationCode": authCode,
      "authorizationCodeVerifier": verifyCode
    };

    if (isRefresh) {
      body['grantType'] = "refresh_token";
      body["refreshToken"] = refreshToken;
    }

    var response = await dio.post("${Consts.authUrl}/oauth/token",
        options: Options(
          headers: headers,
        ),
        data: body);

    if (response.statusCode == 200) {
      var body = response.data;
      return body;
    } else {
      throw Exception(response.data);
    }
  }
}
