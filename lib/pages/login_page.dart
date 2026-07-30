import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/controllers/auth_controller.dart';
import 'package:kronos_food/pages/config_page.dart';
import 'package:kronos_food/pages/pedidos_page.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:audioplayers/audioplayers.dart';

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

  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _serverConfigured = false;
  final AuthController _authController = AuthController();

  @override
  void initState() {
    super.initState();
    _verificarConfiguracaoServidor();
    _supAdicionarController.addListener(_formatarValorMonetario);

    // foco automático no campo usuário
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _usernameFocusNode.requestFocus();
    });
  }

  void _handleKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final logicalKey = event.logicalKey;

      if (logicalKey == LogicalKeyboardKey.enter) {
        if (_usernameFocusNode.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _passwordFocusNode.requestFocus();
          });
        } else if (_passwordFocusNode.hasFocus) {
          _login();
        }
      }

      if (logicalKey == LogicalKeyboardKey.escape) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Sair do sistema'),
            content: const Text('Tem certeza que deseja sair do sistema?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  exit(0);
                },
                child: const Text('Sair'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _verificarConfiguracaoServidor() async {
    var serverIp = await preferencesService.getServerIp();
    setState(() {
      _serverConfigured = serverIp != null && serverIp.isNotEmpty;
    });
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final loginSuccessful = await _authController.loginUser(
            context, _usernameController.text, _passwordController.text);

        if (loginSuccessful == true && mounted) {
          final caixaAberto = await _authController.getCodCaixa(context);
          if (caixaAberto == false) {
            _preencherDataHoraAtual();
            await _carregarTerminal();
            await _carregarCaixa();
            final caixaFoiAberto = await _showAbrirCaixaDialog();
            if (caixaFoiAberto != true) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Abra o caixa para entrar e finalizar pedidos.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              return;
            }
          }

          if (!mounted) return;
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
            SnackBar(
              content: Text('Erro ao efetuar login: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showAbrirCaixaDialog() async {
    if (_supAnteriorController.text.isEmpty) {
      _supAnteriorController.text = '0,00';
    }
    if (_supAdicionarController.text.isEmpty) {
      _supAdicionarController.text = '0,00';
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isOpening = false;
        String? error;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> abrirCaixa() async {
              setDialogState(() {
                isOpening = true;
                error = null;
              });

              try {
                final terminal =
                    int.tryParse(_terminalController.text.trim()) ?? 1;
                final opened = await _authController.abrirCaixa(
                  context,
                  terminal,
                  _dataHoraController.text,
                  _supAdicionarController.text,
                );

                final caixaCarregado = opened == true &&
                    await _authController.getCodCaixa(context);

                if (caixaCarregado) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                  return;
                }

                setDialogState(() {
                  error = 'Nao foi possivel abrir/carregar o caixa.';
                  isOpening = false;
                });
              } catch (e) {
                setDialogState(() {
                  error = e.toString().replaceFirst('Exception: ', '');
                  isOpening = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Abrir caixa'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Nao existe caixa aberto para este terminal. Abra o caixa para conseguir concluir pedidos.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _terminalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Terminal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dataHoraController,
                      decoration: const InputDecoration(
                        labelText: 'Data de abertura',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _supAnteriorController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Suprimento anterior',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _supAdicionarController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Suprimento para abertura',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isOpening ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isOpening ? null : abrirCaixa,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Consts.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: isOpening
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Abrir caixa'),
                ),
              ],
            );
          },
        );
      },
    );

    return result == true;
  }

  void _preencherDataHoraAtual() {
    final now = DateTime.now();
    _dataHoraController.text =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKey: _handleKeyPress,
      child: Scaffold(
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
                              focusNode: _usernameFocusNode,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context)
                                    .requestFocus(_passwordFocusNode);
                              },
                              decoration: InputDecoration(
                                labelText: 'Usuário',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              validator: (value) => value?.isEmpty ?? true
                                  ? 'Digite seu usuário'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              validator: (value) => value?.isEmpty ?? true
                                  ? 'Digite sua senha'
                                  : null,
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
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
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
                          MaterialPageRoute(
                              builder: (context) => const ConfigPage()),
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
      ),
    );
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _supAdicionarController.removeListener(_formatarValorMonetario);
    _usernameController.dispose();
    _passwordController.dispose();
    _dataHoraController.dispose();
    _terminalController.dispose();
    _usuarioController.dispose();
    _supAnteriorController.dispose();
    _supAdicionarController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
