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
  late String? _terminalCode;
  final preferencesService = PreferencesService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _companyCodeController = TextEditingController();
  final TextEditingController _terminalController = TextEditingController();
  final TextEditingController _serverIpController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    _serverIp = await preferencesService.getServerIp();
    _companyCode = await preferencesService.getCompanyCode();
    _terminalCode = await preferencesService.getTerminalCode();
    setState(() {
      _companyCodeController.text = _companyCode ?? '';
      _terminalController.text = _terminalCode ?? '1';
      _serverIpController.text = _serverIp ?? '';
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
                                      hint: 'Ex: http://servidor:5000 ou 192.168.1.100',
                                      controller: _serverIpController,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Por favor, insira o endereço do servidor';
                                        }
                                        final lowercaseValue = value.toLowerCase();
                                        if (lowercaseValue.contains('localhost')) {
                                          return null;
                                        }
                                        if (lowercaseValue.startsWith('http://') ||
                                            lowercaseValue.startsWith('https://')) {
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
                                              FilteringTextInputFormatter.digitsOnly,
                                            ],
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
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
                                              FilteringTextInputFormatter.digitsOnly,
                                            ],
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Por favor, insira o terminal';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
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
                                    
                                    // Botão Limpar
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        side: BorderSide(color: Colors.grey[300]!),
                                        foregroundColor: Colors.grey[800],
                                      ),
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Limpar configurações'),
                                            content: const Text('Tem certeza que deseja limpar todas as configurações?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('Limpar', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                        
                                        if (confirmed == true && mounted) {
                                          await preferencesService.clearCompanyCode();
                                          await preferencesService.clearServerIp();
                                          await preferencesService.clearTerminalCode();
                                          
                                          setState(() {
                                            _companyCodeController.clear();
                                            _serverIpController.clear();
                                            _terminalController.clear();
                                          });
                                          
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Configurações limpas com sucesso!'),
                                              backgroundColor: Colors.green,
                                              behavior: SnackBarBehavior.floating,
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
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        backgroundColor: Consts.primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: _isSaving ? null : _salvarConfiguracoes,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    super.dispose();
  }
}