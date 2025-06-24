import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/controllers/auth_controller.dart';
import 'package:kronos_food/pages/pedidos_page.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:http/http.dart' as http;

class PrimeiroAcessoDialog extends StatefulWidget {
  final AuthController authController;
  final Map<String, dynamic> credentials;
  const PrimeiroAcessoDialog(
      {super.key, required this.authController, required this.credentials});

  @override
  State<PrimeiroAcessoDialog> createState() => _PrimeiroAcessoDialogState();
}

class _PrimeiroAcessoDialogState extends State<PrimeiroAcessoDialog> {
  final dio = Dio();
  final preferencesService = PreferencesService();
  TextEditingController authController = TextEditingController();
  int seconds = 0;
  bool isCodeCopied = false;
  bool isLinkCopied = false;
  bool _isAuthenticating = false;
  Timer? _timer;

  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (seconds == 0) {
          timer.cancel();
        } else {
          setState(() {
            seconds--;
          });
        }
      },
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    seconds = widget.credentials['expiresIn'];
    startTimer();
  }

  // Método para salvar os tokens no backend
  Future<bool> _saveTokensToBackend(
      String accessToken, String refreshToken) async {
    try {
      var serverIp = await preferencesService.getServerIp();
      var kronosToken = await preferencesService.getKronosToken();
      final codigoEmpresa =
          await preferencesService.getCompanyCode() ?? '1';
      // Construir a URL para a API
      final url = '$serverIp/delivery/externo/configuracao';

      // Fazer requisição para o endpoint
      final response = await dio
          .put(
            url,
            data: {'AccessToken': accessToken, 'RefreshToken': refreshToken},
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

      if (kDebugMode) {
        print(
            'Erro ao salvar tokens no backend: ${response.statusCode} - ${response.data}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Exceção ao salvar tokens no backend: $e');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    var authCodeVerifier = widget.credentials['authorizationCodeVerifier'];
    var authCode = widget.credentials['userCode'];
    var portalUrl = widget.credentials['verificationUrl'];

    return AlertDialog(
      backgroundColor: const Color.fromARGB(255, 217, 245, 245),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bem vindo!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E3E3E),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Olá! Parece que é a primeira vez que você acessa o aplicativo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seu código de autenticação é:',
                    style: TextStyle(
                      color: Color(0xFF3E3E3E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          authCode,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier',
                            color: Color(0xFF3E3E3E),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatTime(seconds),
                              style: const TextStyle(
                                color: Consts.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            IconButton(
                              icon: Icon(isCodeCopied ? Icons.done : Icons.copy,
                                  size: 20),
                              onPressed: isCodeCopied
                                  ? null
                                  : () async {
                                      setState(() {
                                        isCodeCopied = true;
                                      });
                                      Clipboard.setData(
                                          ClipboardData(text: authCode));
                                      await Future.delayed(
                                          const Duration(seconds: 2));
                                      setState(() {
                                        isCodeCopied = false;
                                      });
                                    },
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Por favor, acesse o endereço abaixo e insira o código acima.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      portalUrl,
                      style: const TextStyle(
                        color: Color(0xFF3E3E3E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon:
                        Icon(isLinkCopied ? Icons.done : Icons.copy, size: 20),
                    onPressed: isLinkCopied
                        ? null
                        : () async {
                            setState(() {
                              isLinkCopied = true;
                            });
                            Clipboard.setData(ClipboardData(text: portalUrl));
                            await Future.delayed(const Duration(seconds: 2));
                            setState(() {
                              isLinkCopied = false;
                            });
                          },
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                final url =
                    Uri.parse(widget.credentials['verificationUrlComplete']);
                try {
                  await launchUrl(url);
                } catch (err) {
                  if (kDebugMode) {
                    print(err);
                  }
                }
              },
              icon: const Text(
                'Ou clique aqui para acessar',
                style: TextStyle(
                  color: Consts.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              label: const Icon(
                Icons.open_in_new,
                size: 16,
                color: Consts.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Após seguir os passos acima, insira abaixo o código que recebeu:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: authController,
              decoration: InputDecoration(
                label: const Text('Código de verificação'),
                floatingLabelStyle: const TextStyle(
                  color: Consts.primaryColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Consts.primaryColor),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isAuthenticating
                    ? null
                    : () async {
                        setState(() {
                          _isAuthenticating = true;
                        });

                        try {
                          // Realizar autenticação
                          var tokenData = await widget.authController
                              .authenticateAndGetTokens(false,
                                  authController.text, authCodeVerifier, "");

                          if (tokenData.containsKey('accessToken') &&
                              tokenData.containsKey('refreshToken') &&
                              context.mounted) {
                            // Tentar salvar os tokens no backend
                            final tokensSaved = await _saveTokensToBackend(
                                tokenData['accessToken'],
                                tokenData['refreshToken']);

                            if (tokensSaved) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Tokens salvos com sucesso no servidor!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Aviso: Não foi possível salvar os tokens no servidor.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }

                            // Continuar com o fluxo mesmo se não conseguiu salvar no backend
                            if (context.mounted) {
                              Navigator.pop(context);
                              Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const PedidosPage()));
                            }
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Erro na autenticação. Verifique o código inserido.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Erro ao autenticar: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isAuthenticating = false;
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Consts.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isAuthenticating
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.0,
                        ),
                      )
                    : const Text(
                        'Confirmar',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
