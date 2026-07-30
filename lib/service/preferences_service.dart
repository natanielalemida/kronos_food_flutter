import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kronos_food/consts.dart';

class PreferencesService {
  static String normalizeServerUrl(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    if (url.isEmpty) return url;

    if (!url.toLowerCase().startsWith('http://') &&
        !url.toLowerCase().startsWith('https://')) {
      url = 'http://$url';
    }

    var uri = Uri.tryParse(url);
    if (uri != null && uri.host.toLowerCase().contains('kronoserp.com.br')) {
      final pathSegments = uri.pathSegments;
      if ((uri.port == 80 || uri.port == 443) &&
          pathSegments.isNotEmpty &&
          RegExp(r'^\d+$').hasMatch(pathSegments.first)) {
        final parsedPort = int.tryParse(pathSegments.first);
        final remainingSegments = pathSegments.skip(1).toList();
        uri = uri.replace(
          port: parsedPort,
          pathSegments: remainingSegments,
        );
        url = uri.toString();
      }
    }

    uri = Uri.tryParse(url);
    if (uri != null && uri.host.toLowerCase().contains('kronoserp.com.br')) {
      if (uri.port == 6000 && uri.scheme == 'https') {
        uri = uri.replace(scheme: 'http');
      }
      if (uri.port == 6000 && uri.pathSegments.isEmpty) {
        uri = uri.replace(path: '/arc');
      }
      url = uri.toString();
    }

    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }

  Future<String?> getServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    final serverIp = prefs.getString(Consts.serverIpKey);
    if (serverIp == null || serverIp.isEmpty) return serverIp;
    return normalizeServerUrl(serverIp);
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
    await prefs.setString(Consts.serverIpKey, normalizeServerUrl(ip));
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

  Future<String> getIfoodMerchantId() async {
    final prefs = await SharedPreferences.getInstance();
    final merchantId = prefs.getString(Consts.ifoodMerchantIdKey)?.trim();
    if (merchantId == null || merchantId.isEmpty) {
      return Consts.merchantId;
    }
    return merchantId;
  }

  Future<void> saveIfoodMerchantId(String merchantId) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedMerchantId = merchantId.trim();
    if (normalizedMerchantId.isEmpty) {
      await prefs.remove(Consts.ifoodMerchantIdKey);
      return;
    }
    await prefs.setString(Consts.ifoodMerchantIdKey, normalizedMerchantId);
  }

  Future<void> clearIfoodMerchantId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Consts.ifoodMerchantIdKey);
  }

  Future<String?> getIfoodWidgetId() async {
    final prefs = await SharedPreferences.getInstance();
    final widgetId = prefs.getString(Consts.ifoodWidgetIdKey)?.trim();
    if (widgetId == null || widgetId.isEmpty) return Consts.ifoodWidgetId;
    return widgetId;
  }

  Future<void> saveIfoodWidgetId(String widgetId) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedWidgetId = widgetId.trim();
    if (normalizedWidgetId.isEmpty) {
      await prefs.remove(Consts.ifoodWidgetIdKey);
      return;
    }
    await prefs.setString(Consts.ifoodWidgetIdKey, normalizedWidgetId);
  }

  Future<void> clearIfoodWidgetId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Consts.ifoodWidgetIdKey);
  }

  Future<bool> getKanbanMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(Consts.kanbanModeKey) ?? false;
  }

  Future<void> saveKanbanMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Consts.kanbanModeKey, enabled);
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

    if (config.containsKey('expiresIn') && config.containsKey('accessToken')) {
      final expiresInSeconds = config['expiresIn'] is int
          ? config['expiresIn'] as int
          : int.tryParse(config['expiresIn'].toString()) ?? 3600;
      final expirationTime =
          DateTime.now().add(Duration(seconds: expiresInSeconds));
      await saveExpirationTime(expirationTime);
      await saveAccessToken(config['accessToken']);
    } else if (config.containsKey('dataHoraToken') &&
        config.containsKey('accessToken')) {
      final expiredData = config['dataHoraToken'] as String;
      final expirationTime = DateTime.parse(expiredData);
      await saveExpirationTime(expirationTime);
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
