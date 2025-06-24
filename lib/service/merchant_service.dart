// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:kronos_food/consts.dart';
// import 'package:kronos_food/models/merchant_model.dart';
// import 'package:kronos_food/service/auth_service.dart';

// class MerchantService {
//   static const String _baseUrl = Consts.baseUrl;

//   final AuthService _authService;

//   MerchantService(this._authService);

//   /// Obtém os headers com o token de autenticação
//   Future<Map<String, String>> _getHeaders() async {
//     final token = await _authService.getAccessToken();
//     return {
//       'Authorization': 'Bearer $token',
//       'Content-Type': 'application/json',
//     };
//   }

//   /// Obtém informações do estabelecimento
//   Future<MerchantModel> getMerchantDetails(String merchantId) async {
//     final url = Uri.parse('$_baseUrl/merchant/v1.0/merchants/$merchantId');

//     final response = await http.get(
//       url,
//       headers: await _getHeaders(),
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       return MerchantModel.fromJson(data);
//     } else {
//       throw Exception(
//           'Falha ao obter detalhes do estabelecimento: ${response.statusCode}');
//     }
//   }

//   /// Obtém a lista de estabelecimentos do usuário
//   Future<List<MerchantModel>> getMerchants() async {
//     final url = Uri.parse('$_baseUrl/merchant/v1.0/merchants');

//     final response = await http.get(
//       url,
//       headers: await _getHeaders(),
//     );

//     if (response.statusCode == 200) {
//       final List<dynamic> data = jsonDecode(response.body);
//       return data.map((item) => MerchantModel.fromJson(item)).toList();
//     } else {
//       throw Exception(
//           'Falha ao obter lista de estabelecimentos: ${response.statusCode}');
//     }
//   }

//   /// Atualiza o status de operação do estabelecimento (aberto/fechado)
//   Future<bool> updateOperationStatus(String merchantId, bool isOpen) async {
//     final url = Uri.parse(
//         '$_baseUrl/merchant/v1.0/merchants/$merchantId/operation-status');

//     final response = await http.put(
//       url,
//       headers: await _getHeaders(),
//       body: jsonEncode({
//         'status': isOpen ? 'OPEN' : 'CLOSED',
//       }),
//     );

//     return response.statusCode == 204;
//   }

//   /// Obtém as informações de integração do estabelecimento
//   Future<Map<String, dynamic>> getIntegrationInfo(String merchantId) async {
//     final url =
//         Uri.parse('$_baseUrl/merchant/v1.0/merchants/$merchantId/integration');

//     final response = await http.get(
//       url,
//       headers: await _getHeaders(),
//     );

//     if (response.statusCode == 200) {
//       return jsonDecode(response.body);
//     } else {
//       throw Exception(
//           'Falha ao obter informações de integração: ${response.statusCode}');
//     }
//   }
// }
