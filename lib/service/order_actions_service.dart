import 'dart:convert';
// import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/repositories/order_repository.dart';

class OrderActionsService {
  final dio = Dio();
  static const String _baseUrl = "${Consts.baseUrl}/order/v1.0";
  final AuthRepository _authRepository;
  OrderActionsService(this._authRepository);

  /// Obtém os headers com o token de autenticação
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authRepository.getValidAccessToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
  }

  /// Confirma um pedido
  /// [orderId] O ID do pedido a ser confirmado
  Future<bool> confirmOrder(String orderId) async {
    final token = await _authRepository.getValidAccessToken();

    if (token == null) {
      throw Exception("Token de acesso inválido ou expirado");
    }

    final orderRepository = OrderRepository(Consts.baseUrl, token);
    var currentPedido = await orderRepository.getPedidoDetails(orderId);

    final url = '$_baseUrl/orders/$orderId/confirm';
    var headers = await _getHeaders();
    final response = await dio.post(
      url,
      options: Options(
        headers: headers,
      ),
    );

    return response.statusMessage == "Accepted";
  }

  /// Inicia a preparação de um pedido
  /// [orderId] O ID do pedido para iniciar a preparação
  Future<bool> startPreparation(String orderId) async {
    final url = '$_baseUrl/orders/$orderId/startPreparation';

    final response = await dio.post(
      url,
      options: Options(
        headers: await _getHeaders(),
      ),
    );

    return response.statusCode == 202;
  }

  /// Marca um pedido como pronto para retirada
  /// [orderId] O ID do pedido a ser marcado como pronto
  Future<bool> readyToPickup(String orderId) async {
    final url = '$_baseUrl/orders/$orderId/readyToPickup';

    final response = await dio.post(
      url,
      options: Options(
        headers: await _getHeaders(),
      ),
    );

    return response.statusCode == 202;
  }

  /// Despacha um pedido
  /// [orderId] O ID do pedido a ser despachado
  Future<bool> dispatchOrder(String orderId) async {
    final url = '$_baseUrl/orders/$orderId/dispatch';

    final response = await dio.post(
      url,
      options: Options(
        headers: await _getHeaders(),
      ),
    );

    return response.statusMessage == 'Accepted';
  }

  /// Obtém os motivos de cancelamento disponíveis para um pedido
  /// [orderId] O ID do pedido
  /// Retorna uma lista de motivos de cancelamento com código e descrição
  Future<List<Map<String, dynamic>>> getCancellationReasons(
      String orderId) async {
    final url = '$_baseUrl/orders/$orderId/cancellationReasons';

    final response = await dio.get(
      url,
      options: Options(
        headers: await _getHeaders(),
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception(
          'Falha ao obter motivos de cancelamento: ${response.statusCode}');
    }
  }

  /// Solicita o cancelamento de um pedido
  /// [orderId] O ID do pedido a ser cancelado
  /// [cancellationCode] O código do motivo de cancelamento
  /// [cancellationDescription] Descrição opcional para o cancelamento
  Future<bool> requestCancellation(String orderId, String cancellationCode,
      {String? cancellationDescription}) async {
    final url = '$_baseUrl/orders/$orderId/requestCancellation';
    //coloque o content type para application/json

    final body = {
      'cancellationCode': cancellationCode,
      'reason': cancellationDescription ?? '',
    };
    var headers = await _getHeaders();
    var encodedBody = jsonEncode(body);

    final response = await dio.post(
      url,
      options: Options(
        headers: headers,
        contentType: 'application/json',
      ),
      data: body,
    );

    return response.statusCode == 202;
  }
}
