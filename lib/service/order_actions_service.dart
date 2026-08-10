// import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/models/delivery_tracking_model.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/utils/app_logger.dart';

class OrderActionsService {
  final dio = AppLogger.createDio(source: 'OrderActionsService');
  static const String _baseUrl = "${Consts.baseUrl}/order/v1.0";
  final AuthRepository _authRepository;
  OrderActionsService(this._authRepository);

  String _formatDioError(DioException error, String action) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final details = data == null ? error.message : data.toString();

    if (statusCode == null) {
      return 'Falha ao $action: $details';
    }

    return 'Falha ao $action (HTTP $statusCode): $details';
  }

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

    final url = '$_baseUrl/orders/$orderId/confirm';
    var headers = await _getHeaders();
    final response = await dio.post(
      url,
      options: Options(
        headers: headers,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    return statusCode >= 200 && statusCode < 300;
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

    final statusCode = response.statusCode ?? 0;
    return statusCode >= 200 && statusCode < 300;
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

    final statusCode = response.statusCode ?? 0;
    return statusCode >= 200 && statusCode < 300;
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
      data: const {
        'deliveredBy': 'MERCHANT',
      },
    );

    return response.statusCode == 202;
  }

  Future<DeliveryTrackingModel> getDeliveryTracking(String orderId) async {
    final url = '$_baseUrl/orders/$orderId/tracking';

    final response = await dio.get(
      url,
      options: Options(
        headers: await _getHeaders(),
      ),
    );

    return DeliveryTrackingModel.fromJson(response.data);
  }

  Future<bool> validatePickupCode(String orderId, String code) async {
    final url = '$_baseUrl/orders/$orderId/validatePickupCode';

    final response = await dio.post(
      url,
      options: Options(
        headers: await _getHeaders(),
      ),
      data: {
        'code': code,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data['valid'] == true;
    }

    return response.statusCode == 200;
  }

  Future<bool> verifyDeliveryCode(String orderId, String code) async {
    final url = '$_baseUrl/orders/$orderId/verifyDeliveryCode';

    final response = await dio.post(
      url,
      options: Options(
        headers: await _getHeaders(),
      ),
      data: {
        'code': code,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data['valid'] == true;
    }

    return response.statusCode == 200;
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

    if (response.statusCode == 204) {
      return [];
    }

    if (response.statusCode == 200) {
      final data = response.data;
      final List<dynamic> reasons;

      if (data is List) {
        reasons = data;
      } else if (data is Map && data['reasons'] is List) {
        reasons = data['reasons'] as List;
      } else {
        return [];
      }

      return reasons
          .whereType<Map>()
          .map((item) {
            final reason = Map<String, dynamic>.from(item);
            reason['cancelCodeId'] ??= reason['cancellationCode'] ??
                reason['code'] ??
                reason['id'];
            reason['description'] ??= reason['name'] ?? reason['reason'] ?? '';
            return reason;
          })
          .where((reason) => reason['cancelCodeId'] != null)
          .toList();
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
    final normalizedCode = int.tryParse(cancellationCode) ?? cancellationCode;

    final body = {
      'cancellationCode': normalizedCode,
      'reason': cancellationDescription?.trim().isNotEmpty == true
          ? cancellationDescription!.trim()
          : 'Cancelamento solicitado pelo restaurante',
    };
    var headers = await _getHeaders();

    final response = await dio.post(
      url,
      options: Options(
        headers: headers,
        contentType: 'application/json',
      ),
      data: body,
    ).onError<DioException>((error, stackTrace) {
      throw Exception(_formatDioError(error, 'solicitar cancelamento'));
    });

    return response.statusCode == 202;
  }
}
