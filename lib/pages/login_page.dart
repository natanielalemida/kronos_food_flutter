import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/controllers/auth_controller.dart';
import 'package:kronos_food/pages/config_page.dart';
import 'package:kronos_food/pages/pedidos_page.dart';
import 'package:kronos_food/service/preferences_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final preferencesService = PreferencesService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _dataHoraController = TextEditingController();
  final TextEditingController _terminalController = TextEditingController();
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _supAnteriorController = TextEditingController();
  final TextEditingController _supAdicionarController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _serverConfigured = false;
  final AuthController _authController = AuthController();

  @override
  void initState() {
    super.initState();
    _carregarCredenciaisSalvas();
    _verificarConfiguracaoServidor();
    _supAdicionarController.addListener(_formatarValorMonetario);
  }

  void _formatarValorMonetario() {
    final text = _supAdicionarController.text;
    final selection = _supAdicionarController.selection;

    if (text.isEmpty) {
      _supAdicionarController.text = "0,00";
      _supAdicionarController.selection = TextSelection.collapsed(offset: 4);
      return;
    }

    // Remove todos os caracteres não numéricos
    String cleanedText = text.replaceAll(RegExp(r'[^0-9]'), '');

    // Se não tiver nada, retorna 0,00
    if (cleanedText.isEmpty) {
      _supAdicionarController.text = "0,00";
      _supAdicionarController.selection = TextSelection.collapsed(offset: 4);
      return;
    }

    // Garante que temos pelo menos 3 dígitos (para os centavos)
    cleanedText = cleanedText.padLeft(3, '0');

    // Pega os últimos 2 dígitos para os centavos
    String centavos = cleanedText.substring(cleanedText.length - 2);

    // Pega o restante para os reais
    String reais = cleanedText.substring(0, cleanedText.length - 2);

    // Remove zeros à esquerda desnecessários
    reais = reais.replaceAll(RegExp(r'^0+'), '');
    if (reais.isEmpty) reais = '0';

    // Formata os reais com separadores de milhar
    String reaisFormatados = '';
    int count = 0;
    for (int i = reais.length - 1; i >= 0; i--) {
      reaisFormatados = reais[i] + reaisFormatados;
      count++;
      if (count % 3 == 0 && i != 0) {
        reaisFormatados = '.$reaisFormatados';
      }
    }

    // Combina o valor formatado
    String valorFormatado = '$reaisFormatados,$centavos';

    // Atualiza o controller mantendo a posição do cursor
    _supAdicionarController.value = _supAdicionarController.value.copyWith(
      text: valorFormatado,
      selection: TextSelection.collapsed(offset: valorFormatado.length),
    );
  }

  Future<void> _carregarTerminal() async {
    final terminal = await preferencesService.getTerminalCode() ?? '';
    setState(() {
      _terminalController.text = terminal;
      _usuarioController.text = 'admin';
    });
  }

  Future<void> _carregarCaixa() async {
    final caixa = await preferencesService.getCodCaixaDecoded();

    if (caixa != null) {
      setState(() {
        _supAnteriorController.text =
            _formatarParaExibicao(caixa['ValorSupProximoCaixa']);
      });
    }
  }

  String _formatarParaExibicao(dynamic valor) {
    if (valor == null) return "0,00";

    double valorNumerico =
        valor is String ? double.tryParse(valor) ?? 0.0 : valor.toDouble();
    String valorString = valorNumerico.toStringAsFixed(2).replaceAll('.', ',');

    List<String> partes = valorString.split(',');
    String parteInteira = partes[0];
    String parteDecimal = partes.length > 1 ? partes[1] : '00';

    String parteInteiraFormatada = '';
    for (int i = parteInteira.length - 1, count = 0; i >= 0; i--, count++) {
      if (count % 3 == 0 && count != 0) {
        parteInteiraFormatada = '.$parteInteiraFormatada';
      }
      parteInteiraFormatada = parteInteira[i] + parteInteiraFormatada;
    }

    return '$parteInteiraFormatada,$parteDecimal';
  }

  void _preencherDataHoraAtual() {
    final now = DateTime.now();
    _dataHoraController.text =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _carregarCredenciaisSalvas() async {
    var username = await preferencesService.getUsername() ?? "";
    var password = await preferencesService.getPassword() ?? "";
    setState(() {
      _usernameController.text = username;
      _passwordController.text = password;
    });
  }

  Future<void> _verificarConfiguracaoServidor() async {
    var serverIp = await preferencesService.getServerIp();
    setState(() {
      _serverConfigured = serverIp != null && serverIp.isNotEmpty;
    });
  }

  Future<void> _salvarCredenciais(String username, String password) async {
    await preferencesService.saveUsername(username);
    await preferencesService.savePassword(password);
  }

  Widget _buildFormField(String label, TextEditingController controller,
      {bool enabled = true, double? width}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            style: const TextStyle(fontSize: 14),
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            ],
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              filled: !enabled,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarModalDesktop() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Abertura de caixa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Primeira linha - Campos fixos
                Row(
                  children: [
                    _buildFormField('Data e Hora', _dataHoraController,
                        width: 200),
                    const SizedBox(width: 16),
                    _buildFormField('Terminal', _terminalController,
                        enabled: false, width: 150),
                    const SizedBox(width: 16),
                    _buildFormField('Usuário', _usuarioController,
                        enabled: false, width: 150),
                  ],
                ),
                const SizedBox(height: 24),

                // Segunda linha - Campos editáveis
                Row(
                  children: [
                    if (_supAnteriorController.text.isNotEmpty &&
                        _supAnteriorController.text != "0,00") ...[
                      Expanded(
                        child: _buildFormField(
                          'Saldo Anterior',
                          _supAnteriorController,
                          enabled: false,
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: _buildFormField(
                          'Saldo a Adicionar',
                          _supAdicionarController,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 32),

                // Botões de ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        _abrirCaixa();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Consts.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Confirmar Registro',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      await _salvarCredenciais(
          _usernameController.text, _passwordController.text);

      try {
        final loginSuccessful = await _authController.loginUser(
            context, _usernameController.text, _passwordController.text);

        if (loginSuccessful == true && mounted) {
          var result = await _authController.getCodCaixa(context);

          if (result == false) {
            _preencherDataHoraAtual();
            _carregarTerminal();
            _carregarCaixa();
            _mostrarModalDesktop();
            return;
          }

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const PedidosPage(),
            ),
          );
        } else if (mounted) {
          final error = _authController.haveError.value
              ? _authController.errorMsg.value
              : 'Falha na autenticação. Verifique suas credenciais.';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao efetuar login: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _abrirCaixa() async {
    setState(() {
      _isLoading = true;
    });

    final caixa = await preferencesService.getCodCaixaDecoded();

    if (caixa == null || caixa['Codigo'] == null) {
      setState(() {
        _isLoading = false;
      });
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text("Erro"),
          content: Text("Código do caixa não encontrado."),
        ),
      );
      return;
    }

    var rawValor = _supAnteriorController.text != '0.00'
        ? _supAnteriorController.text
        : _supAdicionarController.text;

    // Corrige possível vírgula e ponto errado
    var valor = rawValor.replaceAll('.', '').replaceAll(',', '.');

    var result = await _authController.abrirCaixa(
      context,
      caixa['Codigo'],
      _dataHoraController.text,
      valor,
    );

    setState(() {
      _isLoading = false;
    });

    if (result == true) {
      Navigator.of(context).pop();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const PedidosPage(),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text("Erro"),
          content: Text("Não foi possível abrir o caixa."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Image.network(
                        'https://logodownload.org/wp-content/uploads/2017/05/ifood-logo-0.png',
                        height: 80,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: Icon(
                              Icons.restaurant_menu,
                              size: 48,
                              color: Colors.red.shade700,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Gerenciador de Pedidos",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Consts.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Faça login para continuar",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  color: Colors.grey.shade700,
                                ),
                                labelText: 'Usuário',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, digite seu usuário';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Colors.grey.shade700,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey.shade700,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                labelText: 'Senha',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, digite sua senha';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 55,
                              child: ElevatedButton(
                                onPressed: (!_serverConfigured || _isLoading)
                                    ? null
                                    : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Consts.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.0,
                                        ),
                                      )
                                    : const Text(
                                        'ENTRAR',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            if (!_serverConfigured) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Configure o IP do servidor nas configurações antes de fazer login',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ConfigPage(),
                        ),
                      ).then((_) {
                        _verificarConfiguracaoServidor();
                      });
                    },
                    icon: Icon(
                      Icons.settings,
                      color: Colors.grey[700],
                    ),
                    label: Text(
                      'Configurações',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _supAdicionarController.removeListener(_formatarValorMonetario);
    _usernameController.dispose();
    _passwordController.dispose();
    _dataHoraController.dispose();
    _terminalController.dispose();
    _usuarioController.dispose();
    _supAnteriorController.dispose();
    _supAdicionarController.dispose();
    super.dispose();
  }
}
