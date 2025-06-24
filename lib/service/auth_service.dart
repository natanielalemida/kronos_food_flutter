// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:kronos_food/consts.dart';
// import 'package:kronos_food/service/preferences_service.dart';

// class AuthService {
//   final preferencesService = PreferencesService();
//   static const String _baseUrl = Consts.baseUrl;

//   // Dados armazenados localmente
//   String? _accessToken;
//   String? _refreshToken;
//   DateTime? _expiresAt;

//   // Credenciais
//   final String _clientId;
//   final String _clientSecret;

//   AuthService({
//     String? clientId,
//     String? clientSecret,
//     String? username,
//     String? password,
//   })  : _clientId = clientId ?? Consts.clientId,
//         _clientSecret = clientSecret ?? Consts.clientSecret;

//   /// Inicializa o serviço, carregando tokens salvos
//   Future<void> init() async {
//     await _loadTokens();
//   }

//   /// Verifica se o token está expirado
//   bool get isTokenExpired {
//     if (_expiresAt == null || _accessToken == null) return true;
//     // Considere renovar se estiver a menos de 5 minutos de expirar
//     return DateTime.now()
//         .isAfter(_expiresAt!.subtract(const Duration(minutes: 5)));
//   }

//   /// Obtém o token de acesso, renovando se necessário
//   Future<String> getAccessToken() async {
//     if (isTokenExpired) {
//       if (_refreshToken != null) {
//         await _refreshAccessToken();
//       } else {
//         await _authenticate();
//       }
//     }
//     return _accessToken!;
//   }

//   /// Autenticação usando credenciais
//   Future<void> _authenticate() async {
//     final url = Uri.parse('$_baseUrl/oauth/token');

//     final response = await http.post(
//       url,
//       headers: {
//         'Content-Type': 'application/x-www-form-urlencoded',
//       },
//       body: {
//         'grant_type': 'password',
//         'client_id': _clientId,
//         'client_secret': _clientSecret,
//       },
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       _processTokenResponse(data);
//     } else {
//       throw Exception('Falha na autenticação: ${response.statusCode}');
//     }
//   }

//   /// Renovação do token de acesso usando refresh token
//   Future<void> _refreshAccessToken() async {
//     final url = Uri.parse('$_baseUrl/oauth/token');

//     final response = await http.post(
//       url,
//       headers: {
//         'Content-Type': 'application/x-www-form-urlencoded',
//       },
//       body: {
//         'grant_type': 'refresh_token',
//         'client_id': _clientId,
//         'client_secret': _clientSecret,
//         'refresh_token': _refreshToken,
//       },
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       _processTokenResponse(data);
//     } else {
//       // Se falhou, tente autenticar novamente
//       _refreshToken = null;
//       await _authenticate();
//     }
//   }

//   /// Processa e salva os tokens recebidos
//   void _processTokenResponse(Map<String, dynamic> data) {
//     _accessToken = data['access_token'];
//     _refreshToken = data['refresh_token'];

//     final expiresIn = data['expires_in'] as int;
//     _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

//     _saveTokens();
//   }

//   /// Carrega tokens salvos localmente
//   Future<void> _loadTokens() async {
//     try {
//       _accessToken = await preferencesService.getAccessToken();
//       _refreshToken = await preferencesService.getRefreshToken();
//       _expiresAt = await preferencesService.getExpirationTime();
//     } catch (e) {
//       // Ignorar erros ao ler tokens salvos
//     }
//   }

//   /// Salva tokens localmente
//   Future<void> _saveTokens() async {
//     if (_accessToken == null || _refreshToken == null || _expiresAt == null) {
//       return;
//     }

//     await preferencesService.saveAccessToken(_accessToken!);
//     await preferencesService.saveRefreshToken(_refreshToken!);
//   }

//   /// Limpa todos os tokens
//   Future<void> logout() async {
//     _accessToken = null;
//     _refreshToken = null;
//     _expiresAt = null;

//     await preferencesService.clearTokens();
//   }
// }
