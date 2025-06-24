import 'package:flutter/material.dart';
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
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _serverConfigured = false;
  final AuthController _authController = AuthController();

  @override
  void initState() {
    super.initState();
    _carregarCredenciaisSalvas();
    _verificarConfiguracaoServidor();
  }

  // Carrega credenciais salvas no SharedPreferences, se existirem
  Future<void> _carregarCredenciaisSalvas() async {
    var username = await preferencesService.getUsername() ?? "";
    var password = await preferencesService.getPassword() ?? "";
    setState(() {
      _usernameController.text = username;
      _passwordController.text = password;
    });
  }

  // Verifica se o servidor está configurado
  Future<void> _verificarConfiguracaoServidor() async {
    var serverIp = await preferencesService.getServerIp();
    setState(() {
      _serverConfigured = serverIp != null && serverIp.isNotEmpty;
    });
  }

  // Salva credenciais no SharedPreferences
  Future<void> _salvarCredenciais(String username, String password) async {
    await preferencesService.saveUsername(username);
    await preferencesService.savePassword(password);
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Salvar as credenciais para uso futuro
      await _salvarCredenciais(
          _usernameController.text, _passwordController.text);

      try {
        // Usar o novo método loginUser para autenticar
        final loginSuccessful = await _authController.loginUser(
            context, _usernameController.text, _passwordController.text);

        if (loginSuccessful && mounted) {
          // Se a autenticação foi bem sucedida, navegar para a tela de pedidos
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const PedidosPage(),
            ),
          );
        } else if (mounted) {
          // Se a autenticação falhou, mostrar mensagem de erro
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
                  // Logo e título
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
                      Text(
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

                  // Formulário de login
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
                            // Campo de usuário
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

                            // Campo de senha
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

                            // Botão de login
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

                  // Botão de configurações
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ConfigPage(),
                        ),
                      ).then((_) {
                        // Recarregar a configuração do servidor após retornar da tela de configurações
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
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
