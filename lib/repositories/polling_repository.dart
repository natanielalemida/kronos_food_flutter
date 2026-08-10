import 'dart:convert';
import 'package:kronos_food/utils/developer_logger.dart' as developer;

import 'package:dio/dio.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/models/event_model.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/utils/app_logger.dart';

class PollingRepository {
  final dio = AppLogger.createDio(source: 'PollingRepository');
  final AuthRepository _authRepository = AuthRepository();

  Future<List<EventModel>> getPolling() async {
    try {
      final accessToken = await _authRepository.getValidAccessToken();
      if (accessToken == null) {
        throw Exception("Token de acesso invalido ou expirado");
      }

      final headers = {
        "Authorization": "Bearer $accessToken",
        'Content-type': 'application/json',
      };

      final response = await dio
          .get(
            "${Consts.eventsUrl}/events:polling",
            options: Options(headers: headers),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 204) {
        return [];
      }

      if (response.statusCode != 200) {
        developer
            .log("Erro no polling: ${response.statusCode} - ${response.data}");
        await AppLogger.error(
          'Polling iFood retornou status inesperado.',
          data: {
            'statusCode': response.statusCode,
            'response': response.data,
          },
        );
        throw Exception("Falha no polling: ${response.statusCode}");
      }

      final body = _parseEventsBody(response.data);
      final events = body
          .whereType<Map>()
          .map((event) => EventModel.fromJson(Map<String, dynamic>.from(event)))
          .toList();

      developer.log("Eventos recebidos: ${events.length}");

      if (events.isNotEmpty) {
        await AppLogger.error(
          'Polling iFood retornou eventos.',
          data: {
            'statusCode': response.statusCode,
            'eventCount': events.length,
            'events': events
                .map((event) => {
                      'id': event.id,
                      'code': event.code,
                      'fullCode': event.fullCode,
                      'orderId': event.orderId,
                      'merchantId': event.merchantId,
                    })
                .toList(),
          },
        );
      }

      for (final event in events) {
        if (event.code == 'CAN' ||
            event.code.toUpperCase().contains('CANCEL')) {
          developer.log(
            "Evento de cancelamento recebido no polling: "
            "${event.code} para pedido ${event.id}",
          );
        }
      }

      return events;
    } catch (e, stackTrace) {
      developer.log("Erro ao fazer polling: $e");
      await AppLogger.error(
        'Erro ao fazer polling iFood.',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  List<dynamic> _parseEventsBody(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) return [data];
    if (data is String) {
      if (data.trim().isEmpty) return [];
      final decoded = jsonDecode(data);
      if (decoded is List) return decoded;
      if (decoded is Map) return [decoded];
      return [];
    }

    throw FormatException("Formato inesperado no polling: ${data.runtimeType}");
  }

  Future<bool> acknowledgeEvents(List<Map<String, String>> eventIds) async {
    try {
      final accessToken = await _authRepository.getValidAccessToken();
      if (accessToken == null) {
        throw Exception("Token de acesso invalido ou expirado");
      }

      final headers = {
        "Authorization": "Bearer $accessToken",
        'Content-type': 'application/json',
      };

      final response = await dio
          .post(
            "${Consts.eventsUrl}/events/acknowledgment",
            options: Options(headers: headers),
            data: eventIds,
          )
          .timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 202) {
        developer.log("Eventos confirmados com sucesso: ${eventIds.length}");
        return true;
      }

      developer.log(
        "Erro ao confirmar eventos: ${response.statusCode} - ${response.data}",
      );
      await AppLogger.error(
        'Ack de eventos iFood retornou status inesperado.',
        data: {
          'statusCode': response.statusCode,
          'response': response.data,
          'eventIds': eventIds,
        },
      );
      return false;
    } catch (e, stackTrace) {
      developer.log("Erro ao confirmar eventos: $e");
      await AppLogger.error(
        'Erro ao confirmar eventos iFood.',
        error: e,
        stackTrace: stackTrace,
        data: {'eventIds': eventIds},
      );
      return false;
    }
  }
}
