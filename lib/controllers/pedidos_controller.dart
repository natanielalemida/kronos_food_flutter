import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:kronos_food/models/print_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/controllers/main_controller.dart';
import 'package:kronos_food/models/event_model.dart';
import 'package:kronos_food/models/merchant_model.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/repositories/kronos_repository.dart';
import 'package:kronos_food/repositories/order_repository.dart';
import 'package:kronos_food/repositories/polling_repository.dart';
import 'package:kronos_food/service/preferences_service.dart';
import 'package:kronos_food/utils/app_logger.dart';
import 'package:kronos_food/utils/ifood_event_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as path;

enum MerchantStatus { ok, warning, closed, error }

enum OrderTimming { immediate, scheduled }

enum OrderType { delivery, takeout }

class PedidosController extends ValueNotifier<List<dynamic>> {
  PedidosController() : super([]) {
    _initAudioPlayer();
  }

  late bool isLoading;
  late String token;
  Timer? timerMake;
  Timer? cleanupTimer;
  final kronosRepository = KronosRepository();

  late PollingRepository pollingRepository;
  late OrderRepository orderRepository;
  late MerchantModel loja;
  ValueNotifier<PedidoModel?> selectedPedido =
      ValueNotifier<PedidoModel?>(null);
  bool haveError = false;
  String errorMsg = "";
  Map<String, List<PedidoModel>> pedidosMap = {};
  var mainController = MainController();
  final AuthRepository _authRepository = AuthRepository();
  final PreferencesService _preferencesService = PreferencesService();
  bool _batchNotifications = false;
  bool _needsNotification = false;
  static bool _pollingInProgress = false;
  static final Set<String> _processingEventIds = <String>{};
  static const String _localOrdersBackupKey = 'ifood_local_orders_backup_v1';
  final Map<String, int> _latestCacheSaveRank = <String, int>{};
  final Map<String, PedidoModel> _pendingCacheSaves = <String, PedidoModel>{};
  final Map<String, Timer> _cacheSaveTimers = <String, Timer>{};

  // Configurações automáticas
  bool _autoAcceptEnabled = false;
  bool _autoPrintEnabled = false;
  final ValueNotifier<bool> autoAcceptNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> autoPrintNotifier = ValueNotifier<bool>(false);

  // Notificações e áudio
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<String> _notifiedPedidos = {};

  final merchantStatus = ValueNotifier<MerchantStatus>(MerchantStatus.closed);
  final orderTimming = ValueNotifier<OrderTimming>(OrderTimming.immediate);

  Future<MerchantModel> _getConfiguredLoja() async {
    final merchantId = await _preferencesService.getIfoodMerchantId();
    final merchantName =
        merchantId == Consts.merchantId ? Consts.merchantName : 'Loja iFood';

    return MerchantModel.fromJson({
      'id': merchantId,
      'name': merchantName,
      'corporateName': merchantName,
      'type': '',
      'active': true,
    });
  }

  Future<void> _initAudioPlayer() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.release);
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
      developer.log('Som de notificação tocado');
    } catch (e) {
      developer.log('Erro ao tocar som de notificação: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _autoAcceptEnabled = prefs.getBool(Consts.autoAcceptKey) ?? false;
    _autoPrintEnabled = prefs.getBool(Consts.autoPrintKey) ?? false;
    autoAcceptNotifier.value = _autoAcceptEnabled;
    autoPrintNotifier.value = _autoPrintEnabled;
  }

  Future<void> setAutoAcceptEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Consts.autoAcceptKey, enabled);
    _autoAcceptEnabled = enabled;
    autoAcceptNotifier.value = enabled;
    developer.log('Aceite automatico ${enabled ? "ativado" : "desativado"}');
  }

  Future<void> setAutoPrintEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Consts.autoPrintKey, enabled);
    _autoPrintEnabled = enabled;
    autoPrintNotifier.value = enabled;
    developer.log('Impressao automatica ${enabled ? "ativada" : "desativada"}');
  }

  Future<bool> _shouldAutoAcceptNow() async {
    final prefs = await SharedPreferences.getInstance();
    final storedEnabled = prefs.getBool(Consts.autoAcceptKey) ?? false;

    if (!storedEnabled) {
      _autoAcceptEnabled = false;
      autoAcceptNotifier.value = false;
      return false;
    }

    return _autoAcceptEnabled && autoAcceptNotifier.value;
  }

  Future<void> cancelar(PedidoModel pedidoParaCancelar) async {
    try {
      bool pedidoAtualizado = false;

      pedidosMap.forEach((status, pedidos) {
        final pedidoIndex =
            pedidos.indexWhere((p) => p.id == pedidoParaCancelar.id);
        if (pedidoIndex != -1) {
          pedidos[pedidoIndex].status = 'CAN';
          pedidos[pedidoIndex].statusCode = Consts.statusCancelled;
          pedidoAtualizado = true;
          developer.log(
              '🔄 Pedido ${pedidoParaCancelar.id} atualizado para CANCELADO na lista $status');
        }
      });

      if (pedidoAtualizado) {
        await savePedidoToCache(pedidoParaCancelar);
        notifyListeners();
      } else {
        developer.log(
            '⚠️ Pedido ${pedidoParaCancelar.id} não encontrado nas listas');
      }
    } catch (e) {
      developer.log('❌ Erro ao cancelar pedido: $e');
      throw Exception('Falha na atualização do pedido');
    }
  }

  Future<void> atualizarPedido(PedidoModel pedido) async {
    try {
      // 1. Determinar o status correto
      String status = _determineStatus(pedido);
      pedido.status = status;

      // 2. Remover o pedido de qualquer status anterior
      for (var statusKey in pedidosMap.keys.toList()) {
        pedidosMap[statusKey]?.removeWhere((p) => p.id == pedido.id);
      }

      // 3. Adicionar no status certo
      if (pedidosMap.containsKey(status)) {
        pedidosMap[status]!.add(pedido);
      } else {
        pedidosMap[status] = [pedido];
      }

      unawaited(_savePedidoToLocalBackup(pedido));
      notifyListeners();

      developer.log(
        "🔄 Pedido ${pedido.id} atualizado no pedidosMap (Status: $status)",
      );
    } catch (e) {
      developer.log("❌ Erro ao atualizar pedido: $e");
      throw Exception("Falha ao atualizar pedido");
    }
  }

  Future<void> dispararNotificacaoNativaPowerShell({
    required String head,
    required String body,
    required String imagePath,
    required String idPedido,
  }) async {
    developer.log("Notificacao: $head - $body ($idPedido)");
  }

  Future<void> clearConfirmedPedidos() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
        (key) => key.startsWith('confirmed_') && !key.endsWith('_timestamp'));

    for (var key in keys) {
      final pedidoId = key.replaceFirst('confirmed_', '');
      await prefs.remove(key);
      await prefs.remove('confirmed_${pedidoId}_timestamp');
    }
    developer.log("🧹 Todas as confirmações de pedidos foram limpas");
  }

  Future<void> cleanExpiredConfirmations() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampKeys =
        prefs.getKeys().where((key) => key.endsWith('_timestamp'));

    final now = DateTime.now().millisecondsSinceEpoch;
    const eightHoursInMs = 8 * 60 * 60 * 1000;

    int removedCount = 0;

    for (var key in timestampKeys) {
      final timestamp = prefs.getInt(key);
      if (timestamp != null && (now - timestamp) > eightHoursInMs) {
        final pedidoId =
            key.replaceFirst('confirmed_', '').replaceFirst('_timestamp', '');
        await prefs.remove('confirmed_$pedidoId');
        await prefs.remove(key);
        removedCount++;
      }
    }

    if (removedCount > 0) {
      developer.log("🧹 $removedCount confirmações expiradas foram removidas");
    }
  }

  Future<void> setLoja(MerchantModel loja) async {
    this.loja = loja;
    _notifyIfNeeded();
  }

  void _notifyIfNeeded() {
    if (!_batchNotifications && _needsNotification) {
      notifyListeners();
      _needsNotification = false;
    } else if (_batchNotifications) {
      _needsNotification = true;
    }
  }

  bool _shouldKeepLocalBackup(PedidoModel pedido) {
    final age = DateTime.now().difference(pedido.createdAt);
    final status = _determineStatus(pedido);

    if (age.inHours >= 24 &&
        (status == Consts.statusCancelled ||
            status == Consts.statusConcluded ||
            status == Consts.statusDispute)) {
      return false;
    }

    return age.inHours < 72;
  }

  Future<Map<String, dynamic>> _readLocalBackupMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localOrdersBackupKey);
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};

    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);

    return <String, dynamic>{};
  }

  Future<List<PedidoModel>> _loadPedidosFromLocalBackup() async {
    try {
      final backup = await _readLocalBackupMap();
      final pedidos = <PedidoModel>[];
      var changed = false;

      for (final entry in backup.entries.toList()) {
        try {
          final value = entry.value;
          final Map<String, dynamic> json;

          if (value is String) {
            json = Map<String, dynamic>.from(jsonDecode(value));
          } else if (value is Map) {
            json = Map<String, dynamic>.from(value);
          } else {
            changed = true;
            backup.remove(entry.key);
            continue;
          }

          final pedido = PedidoModel.fromKronos(json);
          pedido.status = _determineStatus(pedido);

          if (_shouldKeepLocalBackup(pedido)) {
            pedidos.add(pedido);
          } else {
            changed = true;
            backup.remove(entry.key);
          }
        } catch (e, stackTrace) {
          changed = true;
          backup.remove(entry.key);
          await AppLogger.error(
            'Pedido local ignorado por falha ao ler backup.',
            error: e,
            stackTrace: stackTrace,
            data: {'backupKey': entry.key},
          );
        }
      }

      if (changed) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_localOrdersBackupKey, jsonEncode(backup));
      }

      return pedidos;
    } catch (e, stackTrace) {
      await AppLogger.error(
        'Falha ao carregar backup local de pedidos.',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<void> _savePedidoToLocalBackup(PedidoModel pedido) async {
    try {
      pedido.status = _determineStatus(pedido);
      final backup = await _readLocalBackupMap();

      if (_shouldKeepLocalBackup(pedido)) {
        backup[pedido.id] = pedido.toJson();
      } else {
        backup.remove(pedido.id);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localOrdersBackupKey, jsonEncode(backup));
    } catch (e, stackTrace) {
      await AppLogger.error(
        'Falha ao salvar pedido no backup local.',
        error: e,
        stackTrace: stackTrace,
        data: {
          'orderId': pedido.id,
          'displayId': pedido.displayId,
          'status': pedido.status,
        },
      );
    }
  }

  PedidoModel? _findPedidoInMap(String orderId) {
    for (final pedidos in pedidosMap.values) {
      for (final pedido in pedidos) {
        if (pedido.id == orderId) return pedido;
      }
    }
    return null;
  }

  void _mergeKnownPedidoState(PedidoModel target, PedidoModel? existing) {
    if (existing == null) return;

    for (final event in existing.events) {
      final hasSameEvent = target.events.any((current) =>
          current.id.isNotEmpty && current.id == event.id ||
          (current.id.isEmpty &&
              current.code == event.code &&
              current.fullCode == event.fullCode &&
              current.createdAt == event.createdAt));

      if (!hasSameEvent) {
        target.events.add(event);
      }
    }

    if (target.delivery.nomeEntregador.trim().isEmpty &&
        existing.delivery.nomeEntregador.trim().isNotEmpty) {
      target.delivery.nomeEntregador = existing.delivery.nomeEntregador;
    }
  }

  void _addOrUpdateEvent(PedidoModel pedido, EventModel event) {
    final eventIndex = pedido.events.indexWhere((current) =>
        current.id.isNotEmpty && current.id == event.id ||
        (current.id.isEmpty &&
            current.code == event.code &&
            current.fullCode == event.fullCode &&
            current.createdAt == event.createdAt));

    if (eventIndex == -1) {
      pedido.events.add(event);
    } else {
      pedido.events[eventIndex] = event;
    }
  }

  void _putPedidoInMap(PedidoModel pedido, String status) {
    for (var statusKey in pedidosMap.keys.toList()) {
      pedidosMap[statusKey]?.removeWhere((p) => p.id == pedido.id);
    }

    if (pedidosMap.containsKey(status)) {
      pedidosMap[status]!.add(pedido);
    } else {
      pedidosMap[status] = [pedido];
    }
  }

  Future<void> _savePedidoToCacheNow(PedidoModel pedido) async {
    try {
      await kronosRepository.addPedidoToCache(pedido).timeout(
            const Duration(seconds: 5),
          );
      developer.log("Pedido ${pedido.id} salvo no cache com datas corrigidas");
    } catch (e, stackTrace) {
      developer.log(
        "Falha ao salvar pedido ${pedido.id} no cache Kronos: $e",
        stackTrace: stackTrace,
      );
      await AppLogger.error(
        'Falha ao salvar pedido no cache Kronos. Estado local mantido.',
        error: e,
        stackTrace: stackTrace,
        data: {
          'orderId': pedido.id,
          'displayId': pedido.displayId,
          'status': pedido.status,
        },
      );
    }
  }

  void queuePedidoCacheSave(PedidoModel pedido) {
    pedido.status = _determineStatus(pedido);
    unawaited(_savePedidoToLocalBackup(pedido));
    final rank = _statusProgressRank(pedido.status);
    final previousRank = _latestCacheSaveRank[pedido.id];

    if (previousRank == null || rank >= previousRank) {
      _latestCacheSaveRank[pedido.id] = rank;
    }

    _pendingCacheSaves[pedido.id] = pedido;
    _cacheSaveTimers[pedido.id]?.cancel();
    _cacheSaveTimers[pedido.id] = Timer(const Duration(seconds: 2), () {
      final latestPedido = _pendingCacheSaves.remove(pedido.id);
      _cacheSaveTimers.remove(pedido.id);

      if (latestPedido == null) return;

      latestPedido.status = _determineStatus(latestPedido);
      unawaited(_savePedidoToCacheNow(latestPedido));
    });
  }

  Future<PedidoModel?> getPedidoDetails(String pedidoId) async {
    try {
      await AppLogger.error(
        'Buscando detalhes do pedido.',
        data: {'orderId': pedidoId},
      );
      var pedidos = <PedidoModel>[];
      try {
        pedidos = await kronosRepository.getPedidosCache();
        await AppLogger.error(
          'Cache de pedidos consultado.',
          data: {
            'orderId': pedidoId,
            'cacheCount': pedidos.length,
            'hasOrder': pedidos.any((pedido) => pedido.id == pedidoId),
          },
        );
      } catch (e, stackTrace) {
        await AppLogger.error(
          'Cache Kronos falhou, buscando detalhes direto no iFood.',
          error: e,
          stackTrace: stackTrace,
          data: {'orderId': pedidoId},
        );
      }

      if (pedidos.where((p) => p.id == pedidoId).isEmpty) {
        developer.log("Cache de pedidos está vazio.");
        var pedido = await orderRepository.getPedidoDetails(pedidoId);
        pedido.status = _determineStatus(pedido);
        await AppLogger.error(
          'Detalhes do pedido obtidos na API iFood.',
          data: {
            'orderId': pedidoId,
            'displayId': pedido.displayId,
            'status': pedido.status,
            'merchantId': pedido.merchant.id,
          },
        );
        return pedido;
      } else {
        final cachedPedido = pedidos.firstWhere((p) => p.id == pedidoId);
        cachedPedido.status = _determineStatus(cachedPedido);
        developer.log("Pedido $pedidoId recuperado do cache.");
        await AppLogger.error(
          'Detalhes do pedido recuperados do cache.',
          data: {
            'orderId': pedidoId,
            'displayId': cachedPedido.displayId,
            'status': cachedPedido.status,
            'merchantId': cachedPedido.merchant.id,
          },
        );
        return cachedPedido;
      }
    } catch (e, stackTrace) {
      developer.log("Erro ao obter detalhes do pedido: $e");
      await AppLogger.error(
        'Erro ao obter detalhes do pedido.',
        error: e,
        stackTrace: stackTrace,
        data: {'orderId': pedidoId},
      );
      return null;
    }
  }

  void removeFromPreviousEvents(String orderId, List<String> events) {
    bool removed = false;
    for (var event in events) {
      if (pedidosMap.containsKey(event)) {
        int beforeSize = pedidosMap[event]!.length;
        pedidosMap[event]!.removeWhere((pedido) => pedido.id == orderId);
        if (beforeSize != pedidosMap[event]!.length) {
          removed = true;
        }
      }
    }

    if (removed) {
      _needsNotification = true;
    }
  }

  Future<void> alterarStatus(PedidoModel? pedido) async {
    await _loadPreferences();
    final String orderId = pedido!.id;
    var updatedPedido = await getPedidoDetails(orderId);

    if (updatedPedido != null) {
      developer.log('Detalhes do pedido $orderId atualizados com sucesso');

      final conEventIndex = updatedPedido.events
          .indexWhere((e) => e.code == 'CON' || e.code == 'CONCLUDED');

      // Se encontrou o evento CON, move para o final
      if (conEventIndex != -1) {
        var conEvent = updatedPedido.events.removeAt(conEventIndex);
        conEvent.createdAt = DateTime.now();
        updatedPedido.events.add(conEvent);
        updatedPedido.status = 'CON';
        developer.log('Evento CON/CONCLUDED movido para o final da lista');
      }

      await savePedidoToCache(updatedPedido);

      selectedPedido.value = updatedPedido;

      selectedPedido.notifyListeners();

      developer.log(
          'Pedido $orderId com status ${updatedPedido.status} adicionado/atualizado no estado');
      _needsNotification = true;
    }
  }

  Future<void> handleNewEvent(EventModel event) async {
    developer.log('Recebeu novo evento: ${event.code} - ${event.id}');
    final eventProcessingKey = event.id.isNotEmpty
        ? event.id
        : '${event.code}_${event.fullCode}_${event.orderId}';

    if (!_processingEventIds.add(eventProcessingKey)) {
      await AppLogger.error(
        'Evento ignorado porque ja esta em processamento.',
        data: {
          'eventId': event.id,
          'eventCode': event.code,
          'fullCode': event.fullCode,
          'orderId': event.orderId,
          'merchantId': event.merchantId,
        },
      );
      return;
    }

    try {
      final String orderId = event.orderId;
      final String eventCode =
          event.code.isNotEmpty ? event.code : event.fullCode;

      await AppLogger.error(
        'Processando evento do polling.',
        data: {
          'eventId': event.id,
          'eventCode': eventCode,
          'fullCode': event.fullCode,
          'orderId': orderId,
          'merchantId': event.merchantId,
        },
      );

      developer.log('Processando evento $eventCode para pedido $orderId');

      if (orderId.isEmpty) {
        developer.log('Evento $eventCode ignorado por nao conter orderId');
        await pollingRepository.acknowledgeEvents([
          {"id": event.id}
        ]);
        return;
      }

      if (eventCode == 'CAN') {
        developer.log('Processando CANCELAMENTO para pedido $orderId');

        bool pedidoRemovido = false;
        for (var statusKey in pedidosMap.keys.toList()) {
          int countBefore = pedidosMap[statusKey]?.length ?? 0;
          pedidosMap[statusKey]?.removeWhere((p) => p.id == orderId);
          int countAfter = pedidosMap[statusKey]?.length ?? 0;
          if (countBefore > countAfter) {
            pedidoRemovido = true;
            developer
                .log('Pedido $orderId removido da lista de status $statusKey');
          }
        }

        if (pedidoRemovido) {
          try {
            var updatedPedido = await getPedidoDetails(orderId);
            if (updatedPedido != null) {
              updatedPedido.statusCode = Consts.statusCancelled;

              if (!pedidosMap.containsKey(Consts.statusCancelled)) {
                pedidosMap[Consts.statusCancelled] = [];
              }
              pedidosMap[Consts.statusCancelled]!.add(updatedPedido);

              updatedPedido.status = eventCode;

              if (updatedPedido.events.where((e) => e.id == event.id).isEmpty) {
                _addOrUpdateEvent(updatedPedido, event);
              }

              _needsNotification = false;
              notifyListeners();

              await _savePedidoToLocalBackup(updatedPedido);
              queuePedidoCacheSave(updatedPedido);
              await pollingRepository.acknowledgeEvents([
                {"id": event.id}
              ]);
              developer.log('🔄 Pedido $orderId movido para CANCELADOS');
              _needsNotification = true;
            }
          } catch (e) {
            developer.log('Erro ao obter detalhes do pedido cancelado: $e');
          }
        } else {
          await pollingRepository.acknowledgeEvents([
            {"id": event.id}
          ]);
        }
        var service = KronosRepository();
        unawaited(
          service.cancelarPedido(orderId, 'cancelamento ifood').catchError(
            (e, stackTrace) async {
              await AppLogger.error(
                'Falha ao sincronizar cancelamento iFood no Kronos.',
                error: e,
                stackTrace: stackTrace,
                data: {
                  'orderId': orderId,
                  'eventId': event.id,
                  'eventCode': eventCode,
                },
              );
              return false;
            },
          ),
        );
      } else {
        try {
          await _loadPreferences();
          final existingPedido = _findPedidoInMap(orderId);
          PedidoModel? updatedPedido;

          try {
            updatedPedido = await orderRepository.getPedidoDetails(orderId);
            _mergeKnownPedidoState(updatedPedido, existingPedido);
            await AppLogger.error(
              'Detalhes do pedido obtidos direto no iFood para evento.',
              data: {
                'orderId': orderId,
                'displayId': updatedPedido.displayId,
                'eventCode': eventCode,
              },
            );
          } catch (e, stackTrace) {
            await AppLogger.error(
              'Falha ao buscar pedido direto no iFood; tentando fallback.',
              error: e,
              stackTrace: stackTrace,
              data: {
                'orderId': orderId,
                'eventId': event.id,
                'eventCode': eventCode,
              },
            );
            updatedPedido = await getPedidoDetails(orderId);
            if (updatedPedido != null) {
              _mergeKnownPedidoState(updatedPedido, existingPedido);
            }
          }

          if (updatedPedido != null) {
            developer
                .log('Detalhes do pedido $orderId atualizados com sucesso');
            final eventStatus =
                _statusSourceForEvent(eventCode, updatedPedido.status);
            updatedPedido.status = eventStatus;
            if (eventCode == 'HSD') {
              updatedPedido.metadata = DisputeMetadata.fromJson(event.metadata);
            }

            String status = mapApiStatusToCode(updatedPedido.status.isEmpty
                ? eventCode
                : updatedPedido.status);
            updatedPedido.status = status;

            await AppLogger.error(
              'Detalhes do pedido processados.',
              data: {
                'orderId': orderId,
                'displayId': updatedPedido.displayId,
                'eventCode': eventCode,
                'eventStatus': eventStatus,
                'mappedStatus': status,
                'orderTiming': updatedPedido.orderTiming,
                'merchantId': updatedPedido.merchant.id,
              },
            );

            if (status == 'CON' || status == 'HSD') {
              await _savePedidoToLocalBackup(updatedPedido);
              final sucess = await pollingRepository.acknowledgeEvents([
                {"id": event.id}
              ]);
              if (sucess && status == 'CON') {
                unawaited(
                  kronosRepository.sendConfirmar(updatedPedido).catchError(
                    (e, stackTrace) async {
                      await AppLogger.error(
                        'Falha ao sincronizar conclusao iFood no Kronos.',
                        error: e,
                        stackTrace: stackTrace,
                        data: {
                          'orderId': orderId,
                          'eventId': event.id,
                          'eventCode': eventCode,
                        },
                      );
                      return false;
                    },
                  ),
                );
              }
            }

            // ACEITAÇÃO AUTOMÁTICA DE PEDIDOS
            final shouldAutoAccept =
                status == Consts.statusPlaced && await _shouldAutoAcceptNow();

            if (status == Consts.statusPlaced && !shouldAutoAccept) {
              await AppLogger.error(
                'Aceite automatico ignorado porque esta desativado.',
                data: {
                  'orderId': orderId,
                  'displayId': updatedPedido.displayId,
                  'eventCode': eventCode,
                  'status': status,
                  'autoAcceptEnabled': _autoAcceptEnabled,
                  'autoAcceptNotifier': autoAcceptNotifier.value,
                },
              );
            }

            if (status == Consts.statusConfirmed) {
              await AppLogger.error(
                'Pedido chegou como confirmado por evento/status externo, sem chamada de aceite automatico neste ponto.',
                data: {
                  'orderId': orderId,
                  'displayId': updatedPedido.displayId,
                  'eventCode': eventCode,
                  'status': status,
                },
              );
            }

            if (shouldAutoAccept) {
              try {
                if (!await _shouldAutoAcceptNow()) {
                  await AppLogger.error(
                    'Aceite automatico abortado antes de chamar o iFood porque a preferencia esta desativada.',
                    data: {
                      'orderId': orderId,
                      'displayId': updatedPedido.displayId,
                      'eventCode': eventCode,
                      'status': status,
                    },
                  );
                  return;
                }

                await AppLogger.error(
                  'Aceite automatico vai chamar confirm no iFood.',
                  data: {
                    'orderId': orderId,
                    'displayId': updatedPedido.displayId,
                    'eventCode': eventCode,
                    'status': status,
                    'autoAcceptEnabled': _autoAcceptEnabled,
                    'autoAcceptNotifier': autoAcceptNotifier.value,
                  },
                );
                debugPrint(
                    '⚠️ Tentando aceitar pedido $orderId automaticamente');
                bool success = await orderRepository.acceptOrder(orderId);
                if (success) {
                  debugPrint(
                      '✅ Pedido $orderId aceito automaticamente com sucesso');
                  updatedPedido.status = 'CFM';
                  status = Consts.statusConfirmed;
                  try {
                    await kronosRepository.savePedidoToKronos(updatedPedido);
                  } catch (e, stack) {
                    developer.log(
                      'Pedido $orderId confirmado automaticamente no iFood, mas a sincronizacao com Kronos falhou: $e',
                      stackTrace: stack,
                    );
                  }
                  if (_autoPrintEnabled) {
                    await printReceiptOnceForStatus(updatedPedido, 'CFM');
                  }
                } else {
                  debugPrint(
                      '❌ Falha ao aceitar pedido $orderId automaticamente');
                }
              } catch (e) {
                debugPrint(
                    '❌ Erro ao aceitar pedido $orderId automaticamente: $e');
              }
            }

            // Verificar se é um novo pedido (status PLC) e ainda não foi notificado
            if (status == Consts.statusPlaced &&
                !_notifiedPedidos.contains(orderId)) {
              _notifiedPedidos.add(orderId);
              await _playNotificationSound();
              await dispararNotificacaoNativaPowerShell(
                  head: 'Novo Pedido Recebido!',
                  body: 'Pedido #${updatedPedido.displayId}',
                  imagePath: path.absolute(
                      'data/flutter_assets/assets/images/LOGO-KRONOS-food-icon-sync.png'),
                  idPedido: updatedPedido.displayId);
            }

            if (status == Consts.statusDispute) {
              await _playNotificationSound();
              await dispararNotificacaoNativaPowerShell(
                  head: 'Nova disputa recebida!',
                  body: 'Pedido #${updatedPedido.displayId}',
                  imagePath: path.absolute(
                      'data/flutter_assets/assets/images/LOGO-KRONOS-food-icon-sync.png'),
                  idPedido: updatedPedido.displayId);
            }

            _addOrUpdateEvent(updatedPedido, event);
            updatedPedido.status = _determineStatus(updatedPedido);
            status = updatedPedido.status;

            _putPedidoInMap(updatedPedido, status);

            if (selectedPedido.value?.id == orderId) {
              selectedPedido.value = updatedPedido;
            }
            selectedPedido.notifyListeners();
            _needsNotification = false;
            notifyListeners();

            await _savePedidoToLocalBackup(updatedPedido);
            queuePedidoCacheSave(updatedPedido);
            await pollingRepository.acknowledgeEvents([
              {"id": event.id}
            ]);

            await AppLogger.error(
              'Evento processado e aplicado no mapa.',
              data: {
                'eventId': event.id,
                'orderId': orderId,
                'displayId': updatedPedido.displayId,
                'status': status,
                'statusCount': pedidosMap[status]?.length ?? 0,
              },
            );

            developer.log(
                'Pedido $orderId com status $status adicionado/atualizado no estado');
          }
        } catch (e, stackTrace) {
          developer.log('Erro ao atualizar detalhes do pedido $orderId: $e');
          await AppLogger.error(
            'Erro ao atualizar detalhes do pedido vindo do polling.',
            error: e,
            stackTrace: stackTrace,
            data: {
              'orderId': orderId,
              'eventId': event.id,
              'eventCode': eventCode,
              'merchantId': event.merchantId,
            },
          );
        }
      }
    } catch (e, stack) {
      developer.log('Erro ao processar evento: $e');
      developer.log(stack.toString());
      await AppLogger.error(
        'Erro ao processar evento do polling.',
        error: e,
        stackTrace: stack,
        data: {
          'eventId': event.id,
          'eventCode': event.code,
          'fullCode': event.fullCode,
          'orderId': event.orderId,
          'merchantId': event.merchantId,
        },
      );
    } finally {
      _processingEventIds.remove(eventProcessingKey);
      if (_needsNotification) {
        notifyListeners();
        _needsNotification = false;
      }
    }
  }

  Future<void> savePedidoToCache(PedidoModel pedido) async {
    pedido.status = _determineStatus(pedido);
    await _savePedidoToLocalBackup(pedido);
    await _savePedidoToCacheNow(pedido);
  }

  Future<void> loadSavedPedidos() async {
    try {
      developer.log("Carregando pedidos salvos do cache e backup local...");
      final localPedidos = await _loadPedidosFromLocalBackup();
      var cachePedidos = <PedidoModel>[];

      try {
        cachePedidos = await kronosRepository.getPedidosCache().timeout(
              const Duration(seconds: 8),
            );
      } catch (e, stackTrace) {
        developer.log("Cache Kronos falhou ao carregar: $e");
        await AppLogger.error(
          'Cache Kronos falhou ao carregar; usando backup local.',
          error: e,
          stackTrace: stackTrace,
          data: {'localBackupCount': localPedidos.length},
        );
      }

      final mergedPedidos = <String, PedidoModel>{};

      void mergePedido(PedidoModel pedido) {
        if (pedido.id.trim().isEmpty) return;

        pedido.status = _determineStatus(pedido);
        final currentPedido = mergedPedidos[pedido.id];

        if (currentPedido == null) {
          mergedPedidos[pedido.id] = pedido;
          return;
        }

        final currentRank = _statusProgressRank(currentPedido.status);
        final candidateRank = _statusProgressRank(pedido.status);
        final shouldUseCandidate = candidateRank > currentRank ||
            (candidateRank == currentRank &&
                pedido.events.length > currentPedido.events.length) ||
            (candidateRank == currentRank &&
                pedido.events.length == currentPedido.events.length &&
                pedido.createdAt.isAfter(currentPedido.createdAt));

        if (shouldUseCandidate) {
          _mergeKnownPedidoState(pedido, currentPedido);
          pedido.status = _determineStatus(pedido);
          mergedPedidos[pedido.id] = pedido;
        } else {
          _mergeKnownPedidoState(currentPedido, pedido);
          currentPedido.status = _determineStatus(currentPedido);
        }
      }

      for (final pedido in cachePedidos) {
        mergePedido(pedido);
      }

      for (final pedido in localPedidos) {
        mergePedido(pedido);
      }

      final pedidos = mergedPedidos.values.toList();

      Map<String, List<PedidoModel>> tempMap = {};

      for (var pedido in pedidos) {
        var shouldSaveNormalizedPedido = false;
        String status = _determineStatus(pedido);

        if (pedido.displayId.isEmpty) {
          try {
            var pedidoResult = await orderRepository.getPedidoDetails(pedido.id);
            _mergeKnownPedidoState(pedidoResult, pedido);
            pedido = pedidoResult;
            shouldSaveNormalizedPedido = true;
            status = _determineStatus(pedido);
          } catch (e, stackTrace) {
            developer.log(
                "Falha ao completar detalhes do pedido salvo ${pedido.id}: $e");
            await AppLogger.error(
              'Falha ao completar detalhes de pedido salvo.',
              error: e,
              stackTrace: stackTrace,
              data: {
                'orderId': pedido.id,
                'displayId': pedido.displayId,
                'status': pedido.status,
              },
            );
          }
        }

        if (pedido.status != status) {
          pedido.status = status;
          shouldSaveNormalizedPedido = true;
          developer
              .log("Normalizando status do pedido ${pedido.id} para $status");
        }

        if (shouldSaveNormalizedPedido) {
          queuePedidoCacheSave(pedido);
        }

        for (var key in tempMap.keys) {
          tempMap[key]?.removeWhere((p) => p.id == pedido.id);
        }

        if (tempMap.containsKey(status)) {
          tempMap[status]!.add(pedido);
        } else {
          tempMap[status] = [pedido];
        }

        developer.log("Pedido carregado: ${pedido.id} (Status: $status)");
      }

      pedidosMap = tempMap;
      notifyListeners();
      developer
          .log("Carregamento concluído: ${pedidos.length} pedidos processados");
    } catch (e) {
      developer.log("Erro ao carregar pedidos salvos: $e");
    }
  }

  String mapApiStatusToCode(String apiStatus) {
    final upperStatus = apiStatus.toUpperCase();
    developer.log("Mapeando status: $apiStatus (uppercase: $upperStatus)");

    if (upperStatus.contains('CAN') ||
        upperStatus == 'CAR' ||
        upperStatus.contains('CANCELLED') ||
        upperStatus.contains('CANCELLATION') ||
        upperStatus.contains('CANCEL')) {
      developer.log(
          "🔴 Status de CANCELAMENTO detectado: $apiStatus -> ${Consts.statusCancelled}");
      return Consts.statusCancelled;
    } else if (upperStatus.contains('PLC') || upperStatus.contains('PLACED')) {
      return Consts.statusPlaced;
    } else if (IfoodEventUtils.isReadyEvent(upperStatus) ||
        IfoodEventUtils.isWaitingDriverEvent(upperStatus) ||
        upperStatus.contains('RTP') ||
        upperStatus.contains('READY_TO_PICKUP') ||
        upperStatus.contains('READY TO PICKUP') ||
        upperStatus.contains('PREPARATION_ENDED') ||
        upperStatus.contains('SEPARATION_ENDED')) {
      return Consts.statusReadyToPickup;
    } else if (upperStatus.contains('CFM') ||
        upperStatus.contains('CONFIRMED') ||
        upperStatus.contains('STP') ||
        upperStatus.contains('PREPARATION')) {
      return Consts.statusConfirmed;
    } else if (IfoodEventUtils.isInRouteEvent(upperStatus) ||
        upperStatus.contains('DSP') ||
        upperStatus.contains('DISPATCHED') ||
        upperStatus.contains('DISPATCH')) {
      return Consts.statusDispatched;
    } else if (IfoodEventUtils.isFinishedEvent(upperStatus) ||
        upperStatus.contains('CON') ||
        upperStatus.contains('CONCLUDED') ||
        upperStatus.contains('COMPLETE') ||
        upperStatus.contains('DELIVERED')) {
      return Consts.statusConcluded;
    } else if (upperStatus.contains('DDCR') ||
        upperStatus.contains('DELIVERY_DROP_CODE_REQUESTED')) {
      return Consts.statusConfirmed;
    } else if (upperStatus.contains('DECLINED')) {
      return Consts.statusConfirmed;
    } else if (upperStatus.contains('HSD')) {
      return 'HSD';
    } else {
      developer.log("⚠️ Status desconhecido: $apiStatus, usando o padrão PLC");
      return Consts.statusPlaced;
    }
  }

  String _statusSourceForEvent(String eventCode, String currentStatus) {
    final upperEventCode = IfoodEventUtils.normalize(eventCode);

    if (upperEventCode == 'DDCR' ||
        upperEventCode == 'DELIVERY_DROP_CODE_REQUESTED') {
      return currentStatus.isNotEmpty && currentStatus != Consts.statusPlaced
          ? currentStatus
          : Consts.statusConfirmed;
    }

    if (IfoodEventUtils.isInformationalEvent(upperEventCode)) {
      return currentStatus.isNotEmpty ? currentStatus : Consts.statusConfirmed;
    }

    if (upperEventCode == 'HANDSHAKE_SETTLEMENT') {
      return currentStatus.isNotEmpty ? currentStatus : Consts.statusDispute;
    }

    if (upperEventCode == 'CAR') {
      return Consts.statusCancelled;
    }

    return eventCode;
  }

  String _determineStatus(PedidoModel pedido) {
    final candidates = <String>[
      if (pedido.status.trim().isNotEmpty) pedido.status,
      for (final event in pedido.events) ...[
        if (event.code.trim().isNotEmpty) event.code,
        if (event.fullCode.trim().isNotEmpty) event.fullCode,
      ],
    ];

    if (candidates.isEmpty) return Consts.statusPlaced;

    var bestStatus = Consts.statusPlaced;
    var bestRank = -1;

    for (final candidate in candidates) {
      final mappedStatus = mapApiStatusToCode(candidate);
      final rank = _statusProgressRank(mappedStatus);

      if (rank > bestRank) {
        bestStatus = mappedStatus;
        bestRank = rank;
      }
    }

    return bestStatus;
  }

  int _statusProgressRank(String status) {
    switch (mapApiStatusToCode(status)) {
      case Consts.statusPlaced:
        return 10;
      case Consts.statusConfirmed:
        return 20;
      case Consts.statusReadyToPickup:
        return 30;
      case Consts.statusDispatched:
        return 40;
      case Consts.statusConcluded:
        return 50;
      case Consts.statusCancelled:
        return 60;
      case Consts.statusDispute:
        return 70;
      default:
        return 0;
    }
  }

  Future<void> getPedidos() async {
    if (_pollingInProgress) {
      await AppLogger.error('Polling ignorado porque outro ciclo ainda roda.');
      return;
    }

    _pollingInProgress = true;
    bool hasChanges = false;

    try {
      _batchNotifications = true;

      await cleanExpiredConfirmations();

      var events = await pollingRepository.getPolling();

      developer.log("Eventos recebidos: ${events.length}");

      if (events.isNotEmpty) {
        hasChanges = true;
      }

      for (var event in events) {
        developer.log("Processando evento: ${event.code} - ${event.id}");
        await handleNewEvent(event);
      }

      _logAllOrders();

      final displayId = selectedPedido.value?.displayId;

      if (displayId != null) {
        pedidosMap.forEach((key, value) {
          for (var pedido in value) {
            if (pedido.displayId == displayId) {
              selectedPedido.value = pedido;
            }
          }
        });
      }
    } finally {
      _pollingInProgress = false;
      _batchNotifications = false;
      if (hasChanges || _needsNotification) {
        notifyListeners();
        _needsNotification = false;
      }
    }
  }

  Color getMerchantStatusColor(MerchantStatus status) {
    switch (status) {
      case MerchantStatus.ok:
        return Colors.green;
      case MerchantStatus.closed:
        return Colors.grey;
      case MerchantStatus.error:
        return Colors.red;
      case MerchantStatus.warning:
        return Colors.orange;
    }
  }

  Future<void> getMerchantStatus() async {
    merchantStatus.value = MerchantStatus.ok;
  }

  void _startPollingLoops() {
    cleanupTimer?.cancel();
    timerMake?.cancel();

    cleanupTimer =
        Timer.periodic(const Duration(seconds: Consts.pollingIntervalSeconds),
            (timer) {
      unawaited(cleanExpiredConfirmations());
    });

    unawaited(getMerchantStatus());
    unawaited(getPedidos());
    timerMake = Timer.periodic(
        const Duration(seconds: Consts.pollingIntervalSeconds), (timer) {
      unawaited(getPedidos());
    });
  }

  Future<void> init(BuildContext context) async {
    isLoading = true;
    notifyListeners();

    try {
      developer.log("Iniciando PedidosController...");

      token = await _authRepository.getValidAccessToken() ?? "";
      if (token.isEmpty) {
        throw Exception("Token de acesso inválido ou expirado");
      }

      pollingRepository = PollingRepository();
      orderRepository = OrderRepository(Consts.baseUrl, token);

      await loadSavedPedidos();

      await setLoja(await _getConfiguredLoja());
      developer.log("Loja configurada: ${loja.name} (${loja.id})");

      isLoading = false;
      notifyListeners();

      _startPollingLoops();
    } catch (err) {
      haveError = true;
      errorMsg = err.toString();
      timerMake = null;
      cleanupTimer = null;
      isLoading = false;
      developer.log("Erro na inicialização: $err");
      notifyListeners();
    }
  }

  @override
  void dispose() {
    timerMake?.cancel();
    cleanupTimer?.cancel();
    for (final timer in _cacheSaveTimers.values) {
      timer.cancel();
    }
    _cacheSaveTimers.clear();
    _pendingCacheSaves.clear();
    _audioPlayer.dispose();
    autoAcceptNotifier.dispose();
    autoPrintNotifier.dispose();
    super.dispose();
  }

  void _logAllOrders() {
    developer.log("==== Estado atual dos pedidos ====");
    pedidosMap.forEach((key, value) {
      developer.log("$key: ${value.length} pedidos");
      for (var pedido in value) {
        developer.log("  - ${pedido.id}: ${pedido.displayId}");
      }
    });
    developer.log("================================");
  }

  String getEventTitle(String code) {
    switch (IfoodEventUtils.normalize(code)) {
      case "PLC":
        return "Aceitar Pedidos";
      case "CFM":
        return "Em Preparo";
      case "RTP":
        return "Aguardando Entregador iFood";
      case "ASSIGN_DRIVER":
      case "GOING_TO_ORIGIN":
      case "ARRIVED_AT_ORIGIN":
      case "DELIVERY_GROUP_ASSIGNED":
      case "COLLECTED":
      case "ARRIVED_AT_DESTINATION":
      case "DELIVERY_RETURNING_TO_ORIGIN":
      case "DELIVERY_RETURNED_TO_ORIGIN":
      case "DELIVERY_RETURN_CODE_REQUESTED":
      case "READY_TO_PICKUP":
      case "SEPARATION_ENDED":
      case "PREPARATION_ENDED":
        return IfoodEventUtils.eventTitle(code);
      case "DSP":
        return "Em Entrega";
      case "CAN":
        return "Cancelado";
      case "CON":
        return "Concluído";
      case "DDCR":
        return "Entrega Recusada";
      default:
        return "";
    }
  }
}
