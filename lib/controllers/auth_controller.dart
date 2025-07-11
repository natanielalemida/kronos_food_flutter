import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kronos_food/components/primeiro_acesso_dialog.dart';
import 'package:kronos_food/controllers/main_controller.dart';
import 'package:kronos_food/pages/pedidos_page.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/service/preferences_service.dart';

class AuthController extends ChangeNotifier {
  final dio = Dio();
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

  // Função para verificar tokens do iFood no backend
  Future<bool> checkIfoodTokens(String kronosToken) async {
    try {
      final serverIp = await preferenceService.getServerIp() ?? 'localhost';
      final codigoEmpresa = await preferenceService.getCompanyCode() ?? '1';
      // Construir a URL para a API
      final url = '$serverIp/delivery/externo/configuracao';

      // Fazer requisição para o endpoint
      final response = await dio
          .get(
            url,
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                "Auth": kronosToken,
                "Empresa": codigoEmpresa,
              },
            ),
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['Status'] != 1) {
          debugPrint('Erro na resposta: ${data['Mensagem']}');
          return false;
        }
        var resultado = data['Resultado'];

        // Verificar se o servidor retornou tokens válidos
        if (resultado['RefreshToken'] != null &&
            resultado['RefreshToken'].isNotEmpty &&
            resultado['AccessToken'] != null &&
            resultado['AccessToken'].isNotEmpty) {
          // Salvar os tokens no repositório
          await authRepository.saveConfig({
            'accessToken': resultado['AccessToken'],
            'refreshToken': resultado['RefreshToken'],
            'dataHoraToken': resultado['DataHoraToken']
          });

          // Atualizar o mainController com os novos tokens
          mainController.setConfig({
            'accessToken': resultado['AccessToken'],
            'refreshToken': resultado['RefreshToken'],
          });
          return true;
        }
      }

      // Tokens não encontrados ou inválidos
      return false;
    } catch (e) {
      debugPrint('Erro ao verificar tokens do iFood: $e');
      return false;
    }
  }

  Future<bool> authenticate(bool isRefresh, String authCode, String verifyCode,
      String refreshToken) async {
    try {
      var tokenData = await authRepository.authenticate(
        isRefresh,
        authCode,
        verifyCode,
        refreshToken,
      );

      // Save the token data to the preferences
      if (tokenData['refreshToken'] != null &&
          tokenData['accessToken'] != null) {
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

  // Novo método para autenticar e retornar os tokens obtidos
  Future<Map<String, dynamic>> authenticateAndGetTokens(bool isRefresh,
      String authCode, String verifyCode, String refreshToken) async {
    try {
      var tokenData = await authRepository.authenticate(
        isRefresh,
        authCode,
        verifyCode,
        refreshToken,
      );

      // Save the token data to the preferences
      if (tokenData['refreshToken'] != null &&
          tokenData['accessToken'] != null) {
        await authRepository.saveConfig(tokenData);

        // Configurar o mainController
        mainController.setConfig(tokenData);

        // Atualizar estado
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

      return {}; // Retorna mapa vazio em caso de erro
    }
  }

  Future<void> firstLogin(BuildContext context) async {
    var authCredentials = await authRepository.getUserCode();
    if (context.mounted) {
      await showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return PrimeiroAcessoDialog(
                authController: this, credentials: authCredentials);
          });
    }
    return;
  }

  Future<dynamic> kronosLogin(String usuario, String senha, int codApp,
      int numTermninal, int codigoEmpresa) async {
    final serverIp = await preferenceService.getServerIp() ?? 'localhost';
    var body = {
      'login': usuario,
      'senha': senha,
      'aplicacao': codApp,
      'numeroterminal': numTermninal,
      'codigoempresa': codigoEmpresa
    };

    var response = await dio.post('$serverIp/usuario/login',
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
        data: body);

    return response.data;
  }

  // Novo método para login direto do usuário
  Future<Object> loginUser(
      BuildContext context, String username, String password) async {
    final companyCode = await preferenceService.getCompanyCode() ?? '1';
    isAuthenticating.value = true;
    haveError.value = false;
    notifyListeners();

    var user =
        await kronosLogin(username, password, 9, 1, int.parse(companyCode));

    if (user['Status'] == 1) {
      //salve o kronosToken no estado: user['Resultado']['Usuario']['Hash'] ?? '';
      //esse token será usado para buscar os dados do ifood no backend
      String token = user['Resultado']['Usuario']['Hash'] ?? '';
      int codigoUser = user['Resultado']['Usuario']['Codigo'];
      await authRepository.saveKronosToken(token);
      await authRepository.saveCodeUser(codigoUser.toString());
      try {
        // Verificar se temos tokens do iFood disponíveis no backend
        final hasIfoodTokens = await checkIfoodTokens(token);
        if (hasIfoodTokens) {
          // Se temos tokens, podemos ir direto para a tela de pedidos
          isAuthenticating.value = false;
          isAuthenticated.value = true;
          notifyListeners();

          return true;
        } else {
          // Se não temos tokens, precisamos fazer o primeiro acesso
          if (context.mounted) {
            await firstLogin(context);
          }

          isAuthenticating.value = false;
          notifyListeners();
          return isAuthenticated
              .value; // Retorna se a autenticação foi bem sucedida no primeiro acesso
        }
      } catch (err) {
        haveError.value = true;
        errorMsg.value = err.toString();
        isAuthenticating.value = false;
        notifyListeners();
        return false;
      }
    }

    return false;
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

    // Corrige valor no formato brasileiro para double
    var valor = double.tryParse(valorSuprimentoAbertura.replaceAll(',', '.'));

    // Converte string "dd/MM/yyyy HH:mm" para DateTime
    DateTime dataConvertida;
    try {
      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
      dataConvertida = dateFormat.parse(dataAbertura);
    } catch (e) {
      haveError.value = true;
      isAuthenticating.value = false;
      notifyListeners();
      throw FormatException("Data inválida: $dataAbertura");
    }

    var data = {
      "Codigo": codigo,
      "DataAbertura": dataConvertida.toIso8601String(),
      "ValorSuprimentoAbertura": valor
    };

    try {
      var response = await dio.post('$serverIp/caixa/abrir',
          options: Options(
            headers: {
              'Auth': kronosToken,
              'Empresa': codigoEmpresa,
              'Terminal': terminalCode
            },
          ),
          data: data);

      if (response.statusCode == 200) {
        var body = response.data;

        if (body['Status'] == 1) {
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

    var response = await dio.get('$serverIp/caixa/',
        options: Options(
          headers: {
            'Auth': kronosToken,
            'Empresa': codigoEmpresa,
            'Terminal': terminalCode
          },
        ));

    if (response.statusCode == 200) {
      var body = response.data;

      if (body['Status'] == 1) {
        await preferenceService.saveCodCaixa(jsonEncode({
          "Codigo": body["Resultado"]["Codigo"],
          "ValorSupProximoCaixa": body["Resultado"]["ValorSupProximoCaixa"]
        }));
        if (body['Resultado']['Situacao'] != 1) {
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
      var config = await authRepository.getConfig();
      //remover access token após concluir implementação do first login
      if (config['refreshToken'] != null) {
        var isAuthenticated =
            await authenticate(true, "", "", config['refreshToken']);
        if (!isAuthenticated && context.mounted) {
          await firstLogin(context);
        } else {
          if (context.mounted) {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const PedidosPage()));
          }
        }
      } else {
        if (context.mounted) await firstLogin(context);
      }
    } catch (err) {
      haveError.value = true;
      errorMsg.value = err.toString();
      isAuthenticating.value = false;
      notifyListeners();
    }
  }
}
