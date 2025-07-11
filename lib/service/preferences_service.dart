import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kronos_food/consts.dart';

class PreferencesService {
  Future<String?> getServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Consts.serverIpKey);
  }

  Future<String?> getCompanyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Consts.companyCodeKey);
  }

  Future<String?> getTerminalCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Consts.terminalCodeKey);
  }

  Future<Map<String, dynamic>?> getCodCaixaDecoded() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(Consts.codCaixa);

    if (jsonString == null) return null;

    try {
      return jsonDecode(jsonString);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveCodCaixa(String cod) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Consts.codCaixa, cod);
  }

  Future<void> saveServerIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Consts.serverIpKey, ip);
  }

  Future<void> saveCompanyCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Consts.companyCodeKey, code);
  }

  Future<void> saveTerminalCode(String terminalCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Consts.terminalCodeKey, terminalCode);
  }

  Future<void> clearServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Consts.serverIpKey);
  }

  Future<void> clearCompanyCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Consts.companyCodeKey);
  }

  Future<void> clearTerminalCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Consts.terminalCodeKey);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Consts.usernameKey);
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Consts.usernameKey, username);
  }

  Future<void> clearUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Consts.usernameKey);
  }

  Future<String?> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Consts.passwordKey);
  }

  Future<void> savePassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Consts.passwordKey, password);
  }

  Future<void> clearPassword() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Consts.passwordKey);
  }

  Future<void> saveKronosToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Consts.kronosTokenKey, token);
  }

  Future<String?> getKronosToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Consts.kronosTokenKey);
  }

  Future<void> saveCodeUser(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Consts.codeUser, code);
  }

  Future<String?> getCodeUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Consts.codeUser);
  }

  // Save refresh token
  Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Consts.refreshTokenKey, token);
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Consts.refreshTokenKey);
  }

  // Save access token
  Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Consts.accessTokenKey, token);
  }

  // Get access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Consts.accessTokenKey);
  }

  // Save token expiration time
  Future<void> saveExpirationTime(DateTime expirationTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        Consts.expirationTimeKey, expirationTime.toIso8601String());
  }

  // Get token expiration time
  Future<DateTime?> getExpirationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final expirationString = prefs.getString(Consts.expirationTimeKey);
    if (expirationString == null) return null;
    return DateTime.parse(expirationString);
  }

  // Check if token is expired
  Future<bool> isTokenExpired() async {
    final expirationTime = await getExpirationTime();
    if (expirationTime == null) return true;

    final now = DateTime.now();
    // Adicione uma pequena margem para evitar problemas de tempo
    return now.isAfter(expirationTime
        .subtract(const Duration(minutes: Consts.tokenRefreshMarginMinutes)));
  }

  // Save the entire config object
  Future<void> saveConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(config);
    await prefs.setString(Consts.configKey, jsonString);

    if (config.containsKey('dataHoraToken') &&
        config.containsKey('accessToken')) {
      final expiredData = config['dataHoraToken'] as String;
      final expirationTime = DateTime.parse(expiredData);
      await saveExpirationTime(
          expirationTime.add(const Duration(seconds: 21600)));
      await saveAccessToken(config['accessToken']);
    }

    if (config.containsKey('refreshToken')) {
      await saveRefreshToken(config['refreshToken']);
    }
  }

  // Get the config object
  Future<Map<String, dynamic>> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(Consts.configKey);

    if (jsonString == null || jsonString.isEmpty) {
      return {};
    }

    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  // Clear all stored tokens
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Consts.refreshTokenKey);
    await prefs.remove(Consts.accessTokenKey);
    await prefs.remove(Consts.configKey);
    await prefs.remove(Consts.expirationTimeKey);
  }
}
