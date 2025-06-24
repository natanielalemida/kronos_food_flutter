import 'dart:developer' as developer;

// import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:kronos_food/models/event_model.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/consts.dart';

class PollingRepository {
  final dio = Dio();
  final AuthRepository _authRepository = AuthRepository();

  Future<List<EventModel>> getPolling() async {
    try {
      final accessToken = await _authRepository.getValidAccessToken();
      if (accessToken == null) {
        throw Exception("Token de acesso inválido ou expirado");
      }

      final headers = {
        "Authorization": "Bearer $accessToken",
        'Content-type': 'application/json',
      };

      var response = await dio.get(
          "${Consts.eventsUrl}/events:polling?groups=${Consts.orderStatusGroup}",
          options: Options(headers: headers));

      if (response.statusCode == 200) {
        List<dynamic> body = response.data;
        var events = body.map((e) => EventModel.fromJson(e)).toList();
        developer.log("Eventos recebidos: ${events.length}");

        // Detectar eventos de cancelamento
        for (var event in events) {
          if (event.code == 'CAN' ||
              event.code.toUpperCase().contains('CANCEL')) {
            developer.log(
                "🔴 EVENTO DE CANCELAMENTO recebido no polling: ${event.code} para pedido ${event.id}");
          }
        }

        return events;
      } else if (response.statusCode == 204) {
        // Sem conteúdo, retorna lista vazia
        return [];
      } else {
        developer
            .log("Erro no polling: ${response.statusCode} - ${response.data}");
        throw Exception("Falha no polling: ${response.statusCode}");
      }
    } catch (e) {
      developer.log("Erro ao fazer polling: $e");
      // Retorna lista vazia em caso de erro para não interromper o fluxo
      return [];
    }
  }

  Future<bool> acknowledgeEvents(List<Map<String, String>> eventIds) async {
    try {
      final accessToken = await _authRepository.getValidAccessToken();
      if (accessToken == null) {
        throw Exception("Token de acesso inválido ou expirado");
      }

      final headers = {
        "Authorization": "Bearer $accessToken",
        'Content-type': 'application/json',
      };

      var body = eventIds;
      var response = await dio.post("${Consts.eventsUrl}/events/acknowledgment",
          options: Options(
            headers: headers,
          ),
          data: body);

      if (response.statusCode == 202) {
        developer.log("Eventos confirmados com sucesso: ${eventIds.length}");
        return true;
      } else {
        developer.log(
            "Erro ao confirmar eventos: ${response.statusCode} - ${response.data}");
        return false;
      }
    } catch (e) {
      developer.log("Erro ao confirmar eventos: $e");
      return false;
    }
  }
}
