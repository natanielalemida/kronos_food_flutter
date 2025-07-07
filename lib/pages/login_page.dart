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
    if (text.isEmpty) {
      _supAdicionarController.text = "0,00";
      _supAdicionarController.selection = TextSelection.collapsed(offset: 4);
      return;
    }

    String cleanedText = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanedText.isEmpty) {
      _supAdicionarController.text = "0,00";
      _supAdicionarController.selection = TextSelection.collapsed(offset: 4);
      return;
    }

    cleanedText = cleanedText.padLeft(3, '0');
    String centavos = cleanedText.substring(cleanedText.length - 2);
    String reais = cleanedText.substring(0, cleanedText.length - 2);
    reais = reais.replaceAll(RegExp(r'^0+'), '');
    if (reais.isEmpty) reais = '0';

    String reaisFormatados = '';
    for (int i = reais.length - 1, count = 0; i >= 0; i--, count++) {
      reaisFormatados = reais[i] + reaisFormatados;
      if (count % 3 == 2 && i != 0) {
        reaisFormatados = '.$reaisFormatados';
      }
    }

    String valorFormatado = '$reaisFormatados,$centavos';
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
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
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
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildFormField('Data e Hora', _dataHoraController, width: 200),
                    _buildFormField('Terminal', _terminalController, enabled: false, width: 150),
                    _buildFormField('Usuário', _usuarioController, enabled: false, width: 150),
                  ],
                ),
                const SizedBox(height: 24),
                if (_supAnteriorController.text.isNotEmpty && _supAnteriorController.text != "0,00")
                  _buildFormField('Saldo Anterior', _supAnteriorController, enabled: false)
                else
                  _buildFormField('Saldo a Adicionar', _supAdicionarController),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _abrirCaixa,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Consts.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Confirmar Registro'),
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
      setState(() => _isLoading = true);
      await _salvarCredenciais(_usernameController.text, _passwordController.text);

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
            MaterialPageRoute(builder: (context) => const PedidosPage()),
          );
        } else if (mounted) {
          final error = _authController.haveError.value
              ? _authController.errorMsg.value
              : 'Falha na autenticação. Verifique suas credenciais.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao efetuar login: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _abrirCaixa() async {
    setState(() => _isLoading = true);
    final caixa = await preferencesService.getCodCaixaDecoded();

    if (caixa == null || caixa['Codigo'] == null) {
      setState(() => _isLoading = false);
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

    var valor = rawValor.replaceAll('.', '').replaceAll(',', '.');
    var result = await _authController.abrirCaixa(
      context,
      caixa['Codigo'],
      _dataHoraController.text,
      valor,
    );

    setState(() => _isLoading = false);

    if (result == true) {
      Navigator.of(context).pop();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PedidosPage()),
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
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Image.asset(
                        'assets/images/LOGO-KRONOS-food-icon-sync.png',
                        height: 250,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 250,
                            width: 250,
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
                      const SizedBox(height: 24),
                      Text(
                        "Gerenciador de Pedidos",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Faça login para continuar",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Usuário',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Digite seu usuário' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Digite sua senha' : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
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
                                elevation: 0,
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
                                  : const Text('ENTRAR',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          if (!_serverConfigured) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Configure o IP do servidor nas configurações',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ConfigPage()),
                      ).then((_) => _verificarConfiguracaoServidor());
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.settings, size: 18),
                        SizedBox(width: 8),
                        Text('Configurações'),
                      ],
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