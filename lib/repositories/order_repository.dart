import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/pedido_model.dart';
// import 'package:http/http.dart' as http;
import 'package:kronos_food/repositories/auth_repository.dart';

class OrderRepository {
  final dio = Dio();
  late String baseUrl;
  late String token;
  late Map<String, String> headers;
  final AuthRepository _authRepository = AuthRepository();

  OrderRepository(String baseUrl, this.token) {
    this.baseUrl = "$baseUrl/order/v1.0";
    headers = {"Authorization": "Bearer $token"};
  }

  Future<PedidoModel> getPedidoDetails(String pedidoId) async {
    // Atualize o token para garantir que estamos usando o mais recente
    final accessToken = await _authRepository.getValidAccessToken();
    if (accessToken == null) {
      throw Exception("Token de acesso inválido ou expirado");
    }

    final updatedHeaders = {
      "Authorization": "Bearer $accessToken",
      'Content-type': 'application/json',
    };

    try {
      var response = await dio.get("$baseUrl/orders/$pedidoId",
          options: Options(headers: updatedHeaders));

      if (response.statusCode == 200) {
        var body = response.data;
        return PedidoModel.fromJson(body);
      } else {
        throw Exception(
            "Falha ao obter detalhes do pedido: ${response.statusCode} - ${response.data}");
      }
    } catch (e) {
      print("Erro ao buscar detalhes do pedido: $e");
      throw Exception("Erro ao buscar detalhes do pedido: $e");
    }
  }

  // Aceitar pedido
  Future<bool> acceptOrder(String orderId) async {
    final accessToken = await _authRepository.getValidAccessToken();
    if (accessToken == null) {
      throw Exception("Token de acesso inválido ou expirado");
    }

    final updatedHeaders = {
      "Authorization": "Bearer $accessToken",
      'Content-type': 'application/json',
    };

    try {
      var response = await dio.post("$baseUrl/orders/$orderId/confirm",
          options: Options(
              headers: updatedHeaders)); // Use dio.post instead of http.post

      return response.statusCode == 202;
    } catch (e) {
      print("Erro ao aceitar pedido: $e");
      return false;
    }
  }

  Future<bool> respondToDispute(String action, String reason) async {
    final accessToken = await _authRepository.getValidAccessToken();
    if (accessToken == null) {
      throw Exception("Token de acesso inválido ou expirado");
    }

    final updatedHeaders = {
      "Authorization": "Bearer $accessToken",
      'Content-type': 'application/json',
    };

    var url = '$baseUrl/$action';

    var body = jsonEncode({"reason": reason});

    try {
      await dio.post(url,
          options: Options(headers: updatedHeaders), data: body);

      return true;
    } catch (e) {
      print("Erro ao aceitar pedido: $e");
      return false;
    }
  }

  Future<String?> getImage(String url) async {
  final accessToken = await _authRepository.getValidAccessToken();
  if (accessToken == null) {
    throw Exception("Token de acesso inválido ou expirado");
  }

  final updatedHeaders = {
    "Authorization": "Bearer $accessToken",
    "Accept": "*/*", 
  };

  try {
    final response = await dio.get<List<int>>(
      url,
      options: Options(
        headers: updatedHeaders,
        responseType: ResponseType.bytes,
      ),
    );

    final Uint8List bytes = Uint8List.fromList(response.data!);
    final String base64Str = base64Encode(bytes);

    return base64Str;
  } catch (e) {
    print("Erro ao obter imagem em Base64: $e");
    return null;
  }
}

  // Rejeitar pedido
  Future<bool> rejectOrder(
      String orderId, String cancellationCode, String observation) async {
    final accessToken = await _authRepository.getValidAccessToken();
    if (accessToken == null) {
      throw Exception("Token de acesso inválido ou expirado");
    }

    final updatedHeaders = {
      "Authorization": "Bearer $accessToken",
      'Content-type': 'application/json',
    };

    final body = jsonEncode(
        {"cancellationCode": cancellationCode, "observation": observation});

    try {
      var response = await dio.post("$baseUrl/orders/$orderId/cancel",
          options: Options(
            headers: updatedHeaders,
            contentType: 'application/json',
          ),
          data: body);
      return response.statusCode == 202;
    } catch (e) {
      print("Erro ao rejeitar pedido: $e");
      return false;
    }
  }
}
