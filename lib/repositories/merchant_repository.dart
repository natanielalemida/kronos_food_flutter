
// import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:kronos_food/controllers/pedidos_controller.dart';
import 'package:kronos_food/models/merchant_model.dart';
import 'package:kronos_food/repositories/auth_repository.dart';

class MerchantRepository {
  final dio = Dio();
  late String baseUrl;
  late String token;
  late Map<String, String> headers;
  final AuthRepository _authRepository = AuthRepository();

  MerchantRepository(String baseUrl, this.token) {
    this.baseUrl = "$baseUrl/merchant/v1.0";
    headers = {
      "Authorization": "Bearer $token",
    };
  }

  Future<List<MerchantModel>> getLojas() async {
    // Atualize o token para garantir que estamos usando o mais recente
    final accessToken = await _authRepository.getValidAccessToken();
    if (accessToken == null) {
      throw Exception("Token de acesso inválido ou expirado");
    }

    final updatedHeaders = {
      "Authorization": "Bearer $accessToken",
      'Content-type': 'application/json',
    };

    var response = await dio.get("$baseUrl/merchants",
        options: Options(headers: updatedHeaders));

    if (response.statusCode == 200) {
      List<dynamic> body = response.data;
      return body.map((m) => MerchantModel.fromJson(m)).toList();
    } else {
      throw Exception("Failed to get lojas");
    }
  }

  Future<MerchantModel> getLoja(String merchantId) async {
    // Atualize o token para garantir que estamos usando o mais recente
    final accessToken = await _authRepository.getValidAccessToken();
    if (accessToken == null) {
      throw Exception("Token de acesso inválido ou expirado");
    }

    final updatedHeaders = {
      "Authorization": "Bearer $accessToken",
      'Content-type': 'application/json',
    };

    var response = await dio.get("$baseUrl/merchants/$merchantId",
        options: Options(headers: updatedHeaders));

    if (response.statusCode == 200) {
      var body = response.data;
      return MerchantModel.fromJson(body);
    } else {
      throw Exception("Failed to get loja");
    }
  }

  Future<MerchantStatus> getLojaStatus(String merchantId) async {
    // Atualize o token para garantir que estamos usando o mais recente
    final accessToken = await _authRepository.getValidAccessToken();
    if (accessToken == null) {
      throw Exception("Token de acesso inválido ou expirado");
    }

    final updatedHeaders = {
      "Authorization": "Bearer $accessToken",
      'Content-type': 'application/json',
    };

    var response = await dio.get(
      "$baseUrl/merchants/$merchantId/status",
      options: Options(
        headers: updatedHeaders,
      ),
    );

    if (response.statusCode == 200) {
      var body = response.data;
      var state = body[0]['state'];
      if (state == null) {
        throw Exception("State not found in response");
      }
      switch (state) {
        case "OK":
          return MerchantStatus.ok;
        case "ERROR":
          return MerchantStatus.error;
        case "WARNING":
          return MerchantStatus.warning;
        case "CLOSED":
          return MerchantStatus.closed;
        default:
          throw Exception("Unknown status");
      }
    } else {
      throw Exception("Failed to get loja status");
    }
  }
}
