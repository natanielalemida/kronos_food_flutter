import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/service/preferences_service.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  late String? _serverIp;
  late String? _companyCode;
  final preferencesService = PreferencesService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _companyCodeController = TextEditingController();
  final TextEditingController _serverIpController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }

  // Carrega configurações salvas no SharedPreferences, se existirem
  Future<void> _carregarConfiguracoes() async {
    _serverIp = await preferencesService.getServerIp();
    _companyCode = await preferencesService.getCompanyCode();
    setState(() {
      _companyCodeController.text = _companyCode ?? '';
      _serverIpController.text = _serverIp ?? '';
    });
  }

  // Salva configurações no SharedPreferences
  Future<void> _salvarConfiguracoes() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        await preferencesService.saveServerIp(_serverIpController.text);
        await preferencesService.saveCompanyCode(_companyCodeController.text);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configurações salvas com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar configurações: ${e.toString()}'),
              backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Configurações'),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card para configurações do servidor
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.settings,
                                  color: Consts.primaryColor,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Configurações do Servidor',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Estas configurações são necessárias para conexão com o servidor.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Campo para o código da empresa (apenas números)
                            TextFormField(
                              controller: _companyCodeController,
                              decoration: InputDecoration(
                                labelText: 'Código da Empresa',
                                hintText: 'Ex: 12345',
                                prefixIcon: const Icon(Icons.business),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, insira o código da empresa';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // Campo para o endereço do servidor (aceitando formatos mais flexíveis)
                            TextFormField(
                              controller: _serverIpController,
                              decoration: InputDecoration(
                                labelText: 'Endereço do Servidor',
                                hintText:
                                    'Ex: http://localhost:5000/arc ou 192.168.1.100:5000',
                                prefixIcon: const Icon(Icons.dns),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, insira o endereço do servidor';
                                }

                                // Aceita qualquer formato que contenha "localhost" ou um padrão válido de URL/IP
                                final lowercaseValue = value.toLowerCase();

                                // Aceita qualquer endereço que contenha "localhost"
                                if (lowercaseValue.contains('localhost')) {
                                  return null; // localhost é válido
                                }

                                // Aceita URLs com protocolo http/https
                                if (lowercaseValue.startsWith('http://') ||
                                    lowercaseValue.startsWith('https://')) {
                                  return null; // URLs com protocolo são válidas
                                }

                                // Aceita IPs (verificação básica: contém ponto)
                                if (lowercaseValue.contains('.')) {
                                  return null; // Provavelmente um endereço IP válido
                                }

                                return 'Por favor, insira um endereço de servidor válido';
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Botões de ação
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        // Botão para salvar configurações
                        SizedBox(
                          height: 50,
                          width: 220,
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.save,
                              color: Colors.white,
                            ),
                            label: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.0,
                                    ),
                                  )
                                : const Text(
                                    'SALVAR',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            onPressed: _isSaving ? null : _salvarConfiguracoes,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Consts.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),

                        // Botão para limpar configurações
                        SizedBox(
                          height: 50,
                          width: 220,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: const Text(
                              'LIMPAR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Limpar configurações'),
                                  content: const Text(
                                      'Tem certeza que deseja limpar todas as configurações?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('CANCELAR'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('LIMPAR'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true && mounted) {
                                await preferencesService.clearCompanyCode();
                                await preferencesService.clearServerIp();

                                setState(() {
                                  _companyCodeController.clear();
                                  _serverIpController.clear();
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Configurações limpas com sucesso!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Consts.primaryColor),
                              foregroundColor: Consts.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _companyCodeController.dispose();
    _serverIpController.dispose();
    super.dispose();
  }
}
