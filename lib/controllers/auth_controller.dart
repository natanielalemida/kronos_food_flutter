import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kronos_food/controllers/main_controller.dart';
import 'package:kronos_food/pages/pedidos_page.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:kronos_food/utils/app_logger.dart';

class AuthController extends ChangeNotifier {
  final dio = AppLogger.createDio(source: 'AuthController');
  static final AuthController _instance = AuthController._internal();
  AuthController._internal();
  factory AuthController() {
    return _instance;
  }

  var mainController = MainController();
  final authRepository = AuthRepository();
  final isAuthenticated = ValueNotifier(false);
  final isAuthenticating = ValueNotifier(true);
  final haveError = ValueNotifier(false);
  final errorMsg = ValueNotifier("");
  final preferenceService = PreferencesService();

  dynamic _readApiField(dynamic body, String field) {
    if (body is! Map) return null;
    if (body.containsKey(field)) return body[field];

    final lowerField = field.toLowerCase();
    if (body.containsKey(lowerField)) return body[lowerField];

    for (final entry in body.entries) {
      if (entry.key.toString().toLowerCase() == lowerField) {
        return entry.value;
      }
    }

    return null;
  }

  bool _isOne(dynamic value) => value == 1 || value?.toString() == '1';

  String _messageFromResponse(dynamic data) {
    final mensagens =
        _readApiField(data, 'Mensagens') ?? _readApiField(data, 'mensagens');

    if (mensagens is List && mensagens.isNotEmpty) {
      final parts = mensagens
          .map((item) =>
              _readApiField(item, 'conteudo') ??
              _readApiField(item, 'Conteudo') ??
              item)
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) return parts.join(' | ');
    }

    final mensagem =
        _readApiField(data, 'Mensagem') ?? _readApiField(data, 'mensagem');
    if (mensagem != null && mensagem.toString().trim().isNotEmpty) {
      return mensagem.toString().trim();
    }

    if (data != null) return data.toString();
    return 'Sem detalhes retornados pelo servidor.';
  }

  String _friendlyLoginMessage(String message, {String? terminalCode}) {
    final clean = message.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();

    if (clean.contains('An error occurred while saving the entity changes')) {
      final terminalMatch =
          RegExp(r'terminalCode"?:"?(\d+)', caseSensitive: false)
              .firstMatch(clean);
      final terminal = terminalMatch?.group(1);

      if (clean.contains('FK_RegistroLogin_Terminal_CodigoTerminal') ||
          clean.contains('CodigoTerminal')) {
        final terminalLabel = terminal ?? terminalCode;
        return terminalLabel == null
            ? 'Terminal nao cadastrado no Kronos. Ajuste o terminal nas Configuracoes ou cadastre esse terminal no backend.'
            : 'Terminal $terminalLabel nao cadastrado no Kronos. Ajuste o terminal nas Configuracoes ou cadastre esse terminal no backend.';
      }

      return 'Erro no servidor Kronos ao salvar dados no banco. Verifique o log do backend/banco. Detalhe: $clean';
    }

    return clean;
  }

  String _formatDioError(DioException error, String context) {
    final statusCode = error.response?.statusCode;
    final detail = _messageFromResponse(error.response?.data);
    final base = statusCode == null
        ? 'Falha de rede no $context: ${error.message ?? error.type.name}'
        : 'Falha no $context: HTTP $statusCode - $detail';
    return _friendlyLoginMessage(base);
  }

  Future<bool> authenticate(bool isRefresh, String authCode, String verifyCode,
      String refreshToken) async {
    try {
      final tokenData = await authRepository.authenticate(
        isRefresh,
        authCode,
        verifyCode,
        refreshToken,
      );

      if (tokenData['accessToken'] != null) {
        await authRepository.saveConfig(tokenData);
      }

      mainController.setConfig(tokenData);
      return true;
    } catch (err) {
      haveError.value = true;
      errorMsg.value = err.toString();
      isAuthenticating.value = false;
      isAuthenticated.value = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> authenticateAndGetTokens(bool isRefresh,
      String authCode, String verifyCode, String refreshToken) async {
    try {
      final tokenData = await authRepository.authenticate(
        isRefresh,
        authCode,
        verifyCode,
        refreshToken,
      );

      if (tokenData['accessToken'] != null) {
        await authRepository.saveConfig(tokenData);
        mainController.setConfig(tokenData);
        isAuthenticated.value = true;
        isAuthenticating.value = false;
        notifyListeners();
      }

      return tokenData;
    } catch (err) {
      haveError.value = true;
      errorMsg.value = err.toString();
      isAuthenticating.value = false;
      isAuthenticated.value = false;
      notifyListeners();

      return {};
    }
  }

  Future<void> firstLogin(BuildContext context) async {
    final tokenData = await authRepository.authenticateWithClientCredentials();
    await authRepository.saveConfig(tokenData);
    mainController.setConfig(tokenData);
    isAuthenticating.value = false;
    isAuthenticated.value = true;
    notifyListeners();
  }

  Future<dynamic> kronosLogin(String usuario, String senha, int codApp,
      int numTermninal, int codigoEmpresa) async {
    final serverIp =
        await preferenceService.getServerIp() ?? 'http://localhost:5000';
    final body = {
      'login': usuario,
      'senha': senha,
      'aplicacao': codApp,
      'numeroterminal': numTermninal,
      'codigoempresa': codigoEmpresa
    };

    final response = await _postKronosLogin('$serverIp/usuario/login', body);

    if (response.statusCode != 200) {
      final message =
          'Erro no login Kronos: HTTP ${response.statusCode} - ${_messageFromResponse(response.data)}';
      await AppLogger.error(
        'Login Kronos retornou HTTP diferente de 200',
        data: {
          'url': '$serverIp/usuario/login',
          'statusCode': response.statusCode,
          'response': response.data,
          'login': usuario,
          'aplicacao': codApp,
          'numeroterminal': numTermninal,
          'codigoempresa': codigoEmpresa,
        },
      );
      throw Exception(_friendlyLoginMessage(
        message,
        terminalCode: numTermninal.toString(),
      ));
    }

    if (response.data is! Map) {
      await AppLogger.error(
        'Login Kronos retornou resposta invalida',
        data: {
          'url': '$serverIp/usuario/login',
          'statusCode': response.statusCode,
          'response': response.data,
        },
      );
      throw Exception("Resposta invalida do servidor Kronos.");
    }

    return response.data;
  }

  Future<Response<dynamic>> _postKronosLogin(
      String url, Map<String, dynamic> body) async {
    final response = await dio.post(
      url,
      options: Options(
        headers: {'Content-Type': 'application/json'},
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
      data: body,
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 307 ||
        statusCode == 308) {
      final location = response.headers.value('location');
      if (location == null || location.isEmpty) {
        throw Exception("Servidor redirecionou o login sem informar destino.");
      }

      final redirectedUrl = Uri.parse(url).resolve(location).toString();
      return dio.post(
        redirectedUrl,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
        data: body,
      );
    }

    return response;
  }

  Future<Object> loginUser(
      BuildContext context, String username, String password) async {
    final companyCode = await preferenceService.getCompanyCode() ?? '1';
    final terminalCode = await preferenceService.getTerminalCode() ?? '1';
    isAuthenticating.value = true;
    haveError.value = false;
    errorMsg.value = "";
    notifyListeners();

    try {
      final terminal = int.tryParse(terminalCode) ?? 1;
      final company = int.tryParse(companyCode) ?? 1;
      final user = await kronosLogin(username, password, 9, terminal, company);

      final userStatus = _readApiField(user, 'Status');
      if (!_isOne(userStatus)) {
        haveError.value = true;
        final message = _friendlyLoginMessage(
          _messageFromResponse(user),
          terminalCode: terminalCode,
        );
        errorMsg.value = message;
        await AppLogger.error(
          'Login Kronos recusado',
          data: {
            'status': userStatus,
            'message': message,
            'response': user,
            'companyCode': companyCode,
            'terminalCode': terminalCode,
          },
        );
        return false;
      }

      final resultado = _readApiField(user, 'Resultado');
      final usuario = _readApiField(resultado, 'Usuario');
      final token = _readApiField(usuario, 'Hash') ?? '';
      final codigoUser = _readApiField(usuario, 'Codigo');
      await authRepository.saveKronosToken(token);
      await authRepository.saveCodeUser(codigoUser.toString());

      final tokenData =
          await authRepository.authenticateWithClientCredentials();
      await authRepository.saveConfig(tokenData);
      mainController.setConfig(tokenData);

      isAuthenticated.value = true;
      return true;
    } catch (err, stackTrace) {
      haveError.value = true;
      errorMsg.value = err is DioException
          ? _formatDioError(err, 'login')
          : _friendlyLoginMessage(err.toString(), terminalCode: terminalCode);
      isAuthenticated.value = false;
      await AppLogger.error(
        'Falha inesperada no login',
        error: err,
        stackTrace: stackTrace,
        data: {
          'companyCode': companyCode,
          'terminalCode': terminalCode,
        },
      );
      return false;
    } finally {
      isAuthenticating.value = false;
      notifyListeners();
    }
  }

  Future<Object> abrirCaixa(BuildContext context, int codigo,
      String dataAbertura, String valorSuprimentoAbertura) async {
    final serverIp = await preferenceService.getServerIp() ?? 'localhost';
    final codigoEmpresa = await preferenceService.getCompanyCode() ?? '1';
    final terminalCode = await preferenceService.getTerminalCode() ?? '1';
    final kronosToken = await preferenceService.getKronosToken();

    isAuthenticating.value = true;
    haveError.value = false;
    notifyListeners();

    final valor = double.tryParse(valorSuprimentoAbertura.replaceAll(',', '.'));

    DateTime dataConvertida;
    try {
      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
      dataConvertida = dateFormat.parse(dataAbertura);
    } catch (e) {
      haveError.value = true;
      isAuthenticating.value = false;
      notifyListeners();
      throw FormatException("Data invalida: $dataAbertura");
    }

    final data = {
      "Codigo": codigo,
      "DataAbertura": dataConvertida.toIso8601String(),
      "ValorSuprimentoAbertura": valor
    };

    try {
      final response = await dio.post(
        '$serverIp/caixa/abrir',
        options: Options(
          headers: {
            'Auth': kronosToken,
            'Empresa': codigoEmpresa,
            'Terminal': terminalCode
          },
        ),
        data: data,
      );

      if (response.statusCode == 200) {
        final body = response.data;

        if (_isOne(_readApiField(body, 'Status'))) {
          return true;
        }
      }
    } catch (e) {
      haveError.value = true;
    } finally {
      isAuthenticating.value = false;
      notifyListeners();
    }

    return false;
  }

  Future<bool> getCodCaixa(BuildContext context) async {
    final serverIp = await preferenceService.getServerIp() ?? 'localhost';
    final codigoEmpresa = await preferenceService.getCompanyCode() ?? '1';
    final terminalCode = await preferenceService.getTerminalCode() ?? '1';
    final kronosToken = await preferenceService.getKronosToken();

    isAuthenticating.value = true;
    haveError.value = false;
    notifyListeners();

    final response = await dio.get(
      '$serverIp/caixa/',
      options: Options(
        headers: {
          'Auth': kronosToken,
          'Empresa': codigoEmpresa,
          'Terminal': terminalCode
        },
      ),
    );

    if (response.statusCode == 200) {
      final body = response.data;

      if (_isOne(_readApiField(body, 'Status'))) {
        final resultado = _readApiField(body, 'Resultado');
        await preferenceService.saveCodCaixa(jsonEncode({
          "Codigo": _readApiField(resultado, 'Codigo'),
          "ValorSupProximoCaixa":
              _readApiField(resultado, 'ValorSupProximoCaixa')
        }));
        if (!_isOne(_readApiField(resultado, 'Situacao'))) {
          return false;
        }

        return true;
      }
    }

    return false;
  }

  Future<void> init(BuildContext context) async {
    notifyListeners();
    try {
      final token = await authRepository.getValidAccessToken();
      if ((token == null || token.isEmpty) && context.mounted) {
        await firstLogin(context);
      }

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const PedidosPage()),
        );
      }
    } catch (err) {
      haveError.value = true;
      errorMsg.value = err.toString();
      isAuthenticating.value = false;
      notifyListeners();
    }
  }
}
