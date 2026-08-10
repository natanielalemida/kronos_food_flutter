import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:kronos_food/utils/app_logger.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  late String? _serverIp;
  late String? _companyCode;
  late String? _terminalCode;
  late String? _ifoodMerchantId;
  late String? _ifoodWidgetId;
  final preferencesService = PreferencesService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _companyCodeController = TextEditingController();
  final TextEditingController _terminalController = TextEditingController();
  final TextEditingController _serverIpController = TextEditingController();
  final TextEditingController _ifoodMerchantIdController =
      TextEditingController();
  final TextEditingController _ifoodWidgetIdController =
      TextEditingController();
  bool _isSaving = false;
  bool _isTestingConnection = false;
  bool? _connectionOk;
  String? _connectionResult;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    _serverIp = await preferencesService.getServerIp();
    _companyCode = await preferencesService.getCompanyCode();
    _terminalCode = await preferencesService.getTerminalCode();
    _ifoodMerchantId = await preferencesService.getIfoodMerchantId();
    _ifoodWidgetId = await preferencesService.getIfoodWidgetId();
    setState(() {
      _companyCodeController.text = _companyCode ?? '';
      _terminalController.text = _terminalCode ?? '1';
      _serverIpController.text = _serverIp ?? '';
      _ifoodMerchantIdController.text = _ifoodMerchantId ?? Consts.merchantId;
      _ifoodWidgetIdController.text = _ifoodWidgetId ?? Consts.ifoodWidgetId;
    });
  }

  Future<void> _salvarConfiguracoes() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        await preferencesService.saveServerIp(_serverIpController.text);
        await preferencesService.saveCompanyCode(_companyCodeController.text);
        await preferencesService.saveTerminalCode(_terminalController.text);
        await preferencesService
            .saveIfoodMerchantId(_ifoodMerchantIdController.text);
        await preferencesService
            .saveIfoodWidgetId(_ifoodWidgetIdController.text);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configurações salvas com sucesso!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(20),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar configurações: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(20),
            ),
          );
        }
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _normalizeServerUrl(String value) {
    return PreferencesService.normalizeServerUrl(value);
  }

  Future<void> _testarConexao() async {
    final serverUrl = _normalizeServerUrl(_serverIpController.text);
    final uri = Uri.tryParse(serverUrl);

    if (serverUrl.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty) {
      setState(() {
        _connectionOk = false;
        _connectionResult = 'Informe um endereco de servidor valido.';
      });
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionOk = null;
      _connectionResult = null;
    });

    try {
      final dio = AppLogger.createDio(
        source: 'ConfigPage.connectionTest',
        options: BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final response = await dio.get(
        serverUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
        ),
      );

      final statusCode = response.statusCode ?? 0;
      final ok = statusCode > 0 && statusCode < 500;

      if (!mounted) return;
      setState(() {
        _serverIpController.text = serverUrl;
        _connectionOk = ok;
        _connectionResult = ok
            ? 'Conexao OK. Servidor respondeu HTTP $statusCode.'
            : 'Servidor respondeu HTTP $statusCode.';
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _connectionOk = false;
        _connectionResult = 'Falha na conexao: ${e.message ?? e.type.name}.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectionOk = false;
        _connectionResult = 'Falha na conexao: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Widget _buildConnectionResult() {
    final ok = _connectionOk == true;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:
            ok ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok
              ? Colors.green.withOpacity(0.25)
              : Colors.red.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            color: ok ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _connectionResult ?? '',
              style: TextStyle(
                color: ok ? Colors.green[800] : Colors.red[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header moderno com botão voltar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Consts.primaryColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Botão Voltar
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Configurações do Sistema',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Colors.white),
                    onPressed: () {
                      // Ação para ajuda
                    },
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo principal
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Card principal
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Título e descrição
                                const Text(
                                  'Configurações de Conexão',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Configure os parâmetros de conexão com o servidor do sistema',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Divisor visual
                                Divider(color: Colors.grey[200], height: 1),
                                const SizedBox(height: 32),

                                // Grupo de campos
                                Column(
                                  children: [
                                    // Campo do servidor
                                    _buildFormField(
                                      icon: Icons.cloud,
                                      label: 'Endereço do Servidor',
                                      hint:
                                          'Ex: http://servidor:5000 ou 192.168.1.100',
                                      controller: _serverIpController,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Por favor, insira o endereço do servidor';
                                        }
                                        final lowercaseValue =
                                            value.toLowerCase();
                                        if (lowercaseValue
                                            .contains('localhost')) {
                                          return null;
                                        }
                                        if (lowercaseValue
                                                .startsWith('http://') ||
                                            lowercaseValue
                                                .startsWith('https://')) {
                                          return null;
                                        }
                                        if (lowercaseValue.contains('.')) {
                                          return null;
                                        }
                                        return 'Por favor, insira um endereço válido';
                                      },
                                    ),

                                    const SizedBox(height: 24),

                                    // Linha com dois campos
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildFormField(
                                            icon: Icons.business,
                                            label: 'Código da Empresa',
                                            hint: 'Ex: 12345',
                                            controller: _companyCodeController,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Por favor, insira o código';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          child: _buildFormField(
                                            icon: Icons.point_of_sale,
                                            label: 'Terminal',
                                            hint: 'Ex: 1',
                                            controller: _terminalController,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Por favor, insira o terminal';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 24),

                                    _buildFormField(
                                      icon: Icons.storefront,
                                      label: 'ID da Loja iFood',
                                      hint: Consts.merchantId,
                                      controller: _ifoodMerchantIdController,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9a-fA-F-]'),
                                        ),
                                      ],
                                      validator: (value) {
                                        final merchantId = value?.trim() ?? '';
                                        if (merchantId.isEmpty) {
                                          return null;
                                        }

                                        final uuidRegex = RegExp(
                                          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                                        );
                                        if (!uuidRegex.hasMatch(merchantId)) {
                                          return 'Informe um ID de loja iFood valido';
                                        }
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 24),

                                    _buildFormField(
                                      icon: Icons.chat_bubble_outline,
                                      label: 'Widget ID iFood',
                                      hint: Consts.ifoodWidgetId,
                                      controller: _ifoodWidgetIdController,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9a-fA-F-]'),
                                        ),
                                      ],
                                      validator: (value) {
                                        final widgetId = value?.trim() ?? '';
                                        if (widgetId.isEmpty) {
                                          return null;
                                        }

                                        final uuidRegex = RegExp(
                                          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                                        );
                                        if (!uuidRegex.hasMatch(widgetId)) {
                                          return 'Informe um Widget ID valido';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 40),

                                // Botões de ação - agora em linha e alinhados à direita
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Botão Voltar (secundário)

                                    const SizedBox(width: 16),

                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        side: BorderSide(
                                            color: Consts.primaryColor),
                                        foregroundColor: Consts.primaryColor,
                                      ),
                                      icon: _isTestingConnection
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.wifi_tethering),
                                      label: Text(_isTestingConnection
                                          ? 'TESTANDO...'
                                          : 'TESTAR CONEXAO'),
                                      onPressed: _isTestingConnection
                                          ? null
                                          : _testarConexao,
                                    ),

                                    const SizedBox(width: 16),

                                    // Botão Limpar
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        side: BorderSide(
                                            color: Colors.grey[300]!),
                                        foregroundColor: Colors.grey[800],
                                      ),
                                      onPressed: () async {
                                        final confirmed =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                                'Limpar configurações'),
                                            content: const Text(
                                                'Tem certeza que deseja limpar todas as configurações?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                child: const Text('Limpar',
                                                    style: TextStyle(
                                                        color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed == true && mounted) {
                                          await preferencesService
                                              .clearCompanyCode();
                                          await preferencesService
                                              .clearServerIp();
                                          await preferencesService
                                              .clearTerminalCode();
                                          await preferencesService
                                              .clearIfoodMerchantId();
                                          await preferencesService
                                              .clearIfoodWidgetId();

                                          setState(() {
                                            _companyCodeController.clear();
                                            _serverIpController.clear();
                                            _terminalController.clear();
                                            _ifoodMerchantIdController.clear();
                                            _ifoodWidgetIdController.clear();
                                            _connectionOk = null;
                                            _connectionResult = null;
                                          });

                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Configurações limpas com sucesso!'),
                                              backgroundColor: Colors.green,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              margin: EdgeInsets.all(20),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('LIMPAR'),
                                    ),

                                    const SizedBox(width: 16),

                                    // Botão Salvar (primário)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                        backgroundColor: Consts.primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: _isSaving
                                          ? null
                                          : _salvarConfiguracoes,
                                      child: _isSaving
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.0,
                                              ),
                                            )
                                          : const Text('SALVAR'),
                                    ),
                                  ],
                                ),
                                if (_connectionResult != null)
                                  _buildConnectionResult(),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Rodapé informativo
                      const SizedBox(height: 32),
                      Text(
                        'Kronos Food • Versão 1.0.0',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    required String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey[500]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _companyCodeController.dispose();
    _serverIpController.dispose();
    _terminalController.dispose();
    _ifoodMerchantIdController.dispose();
    _ifoodWidgetIdController.dispose();
    super.dispose();
  }
}
