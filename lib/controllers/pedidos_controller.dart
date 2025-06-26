import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/controllers/main_controller.dart';
import 'package:kronos_food/models/event_model.dart';
import 'package:kronos_food/models/merchant_model.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/repositories/kronos_repository.dart';
import 'package:kronos_food/repositories/merchant_repository.dart';
import 'package:kronos_food/repositories/order_repository.dart';
import 'package:kronos_food/repositories/polling_repository.dart';

enum MerchantStatus { ok, warning, closed, error }

enum OrderTimming { immediate, scheduled }

enum OrderType { delivery, takeout }

class PedidosController extends ValueNotifier<List<dynamic>> {
  PedidosController() : super([]);
  late bool isLoading;
  late String token;
  late Timer? timer;
  late Timer? cleanupTimer;
  final kronosRepository = KronosRepository();

  late MerchantRepository merchantRepository;
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
  bool _batchNotifications = false;
  bool _needsNotification = false;

  final merchantStatus = ValueNotifier<MerchantStatus>(MerchantStatus.closed);
  final orderTimming = ValueNotifier<OrderTimming>(OrderTimming.immediate);

  // Métodos para gerenciar pedidos confirmados
  Future<bool> isPedidoConfirmed(String pedidoId) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('confirmed_${pedidoId}_timestamp');
    if (timestamp == null) return false;
    
    // Verifica se já passou 8 horas (8 * 60 * 60 * 1000 ms)
    final now = DateTime.now().millisecondsSinceEpoch;
    final eightHoursInMs = 8 * 60 * 60 * 1000;
    if (now - timestamp > eightHoursInMs) {
      // Remove o pedido confirmado expirado
      await prefs.remove('confirmed_$pedidoId');
      await prefs.remove('confirmed_${pedidoId}_timestamp');
      developer.log("♻️ Confirmação expirada removida para pedido $pedidoId");
      return false;
    }
    return prefs.getBool('confirmed_$pedidoId') ?? false;
  }

  Future<void> markPedidoAsConfirmed(String pedidoId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('confirmed_$pedidoId', true);
    await prefs.setInt('confirmed_${pedidoId}_timestamp', 
        DateTime.now().millisecondsSinceEpoch);
    developer.log("✅ Pedido $pedidoId marcado como confirmado");
  }

  Future<void> clearConfirmedPedidos() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => 
        key.startsWith('confirmed_') && 
        !key.endsWith('_timestamp'));
    
    for (var key in keys) {
      final pedidoId = key.replaceFirst('confirmed_', '');
      await prefs.remove(key);
      await prefs.remove('confirmed_${pedidoId}_timestamp');
    }
    developer.log("🧹 Todas as confirmações de pedidos foram limpas");
  }

  Future<void> cleanExpiredConfirmations() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampKeys = prefs.getKeys().where((key) => 
        key.endsWith('_timestamp'));
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final eightHoursInMs = 8 * 60 * 60 * 1000;
    
    int removedCount = 0;
    
    for (var key in timestampKeys) {
      final timestamp = prefs.getInt(key);
      if (timestamp != null && (now - timestamp) > eightHoursInMs) {
        final pedidoId = key.replaceFirst('confirmed_', '').replaceFirst('_timestamp', '');
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

  Future<PedidoModel?> getPedidoDetails(String pedidoId) async {
    try {
      var pedidos = await kronosRepository.getPedidosCache();
      if (pedidos.isEmpty ||
          (pedidos.isNotEmpty &&
              pedidos.where((p) => p.id == pedidoId).isEmpty)) {
        developer.log("Cache de pedidos está vazio.");
        var pedido = await orderRepository.getPedidoDetails(pedidoId);
        return pedido;
      } else {
        PedidoModel? cachedPedido = pedidos.firstWhere((p) => p.id == pedidoId);
        developer.log("Pedido $pedidoId recuperado do cache.");
        return cachedPedido;
      }
    } catch (e) {
      developer.log("Erro ao obter detalhes do pedido: $e");
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

  Future<void> handleNewEvent(EventModel event) async {
    developer.log('Recebeu novo evento: ${event.code} - ${event.id}');
    try {
      final String orderId = event.orderId;
      final String eventCode = event.code;

      developer.log('Processando evento $eventCode para pedido $orderId');

      if (eventCode == 'CAN') {
        developer.log('Processando CANCELAMENTO para pedido $orderId');

        bool pedidoRemovido = false;
        for (var statusKey in pedidosMap.keys.toList()) {
          int countBefore = pedidosMap[statusKey]?.length ?? 0;
          pedidosMap[statusKey]?.removeWhere((p) => p.id == orderId);
          int countAfter = pedidosMap[statusKey]?.length ?? 0;
          if (countBefore > countAfter) {
            pedidoRemovido = true;
            developer.log('Pedido $orderId removido da lista de status $statusKey');
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
                updatedPedido.events.add(event);
              } else {
                int index = updatedPedido.events.indexWhere((e) => e.id == event.id);
                if (index != -1) {
                  updatedPedido.events[index] = event;
                }
              }

              await savePedidoToCache(updatedPedido);
              await pollingRepository.acknowledgeEvents([{"id": event.id}]);
              developer.log('🔄 Pedido $orderId movido para CANCELADOS');
              _needsNotification = true;
            }
          } catch (e) {
            developer.log('Erro ao obter detalhes do pedido cancelado: $e');
          }
        } else {
          await pollingRepository.acknowledgeEvents([{"id": event.id}]);
        }
      } else {
        try {
          var updatedPedido = await getPedidoDetails(orderId);
          if (updatedPedido != null) {
            developer.log('Detalhes do pedido $orderId atualizados com sucesso');
            updatedPedido.status = eventCode;

            String status = mapApiStatusToCode(
                updatedPedido.status.isEmpty ? eventCode : updatedPedido.status);

            // Verificação e envio de confirmação
            if (status == 'CON') {
              bool alreadyConfirmed = await isPedidoConfirmed(updatedPedido.id);
              if (!alreadyConfirmed) {
                await kronosRepository.sendConfirmar(updatedPedido);
                await markPedidoAsConfirmed(updatedPedido.id);
                developer.log("✅ Pedido ${updatedPedido.id} confirmado e marcado no storage");
              } else {
                developer.log("ℹ️ Pedido ${updatedPedido.id} já foi confirmado anteriormente");
              }
            }

            for (var statusKey in pedidosMap.keys.toList()) {
              pedidosMap[statusKey]?.removeWhere((p) => p.id == orderId);
            }

            if (pedidosMap.containsKey(status)) {
              pedidosMap[status]!.add(updatedPedido);
            } else {
              pedidosMap[status] = [updatedPedido];
            }
            
            if (updatedPedido.events.where((e) => e.id == event.id).isEmpty) {
              updatedPedido.events.add(event);
            } else {
              int index = updatedPedido.events.indexWhere((e) => e.id == event.id);
              if (index != -1) {
                updatedPedido.events[index] = event;
              }
            }
            
            await savePedidoToCache(updatedPedido);
            await pollingRepository.acknowledgeEvents([{"id": event.id}]);

            if (selectedPedido.value?.id == orderId) {
              selectedPedido.value = updatedPedido;
            }
            selectedPedido.notifyListeners();

            developer.log('Pedido $orderId com status $status adicionado/atualizado no estado');
            _needsNotification = true;
          }
        } catch (e) {
          developer.log('Erro ao atualizar detalhes do pedido $orderId: $e');
        }
      }
    } catch (e, stack) {
      developer.log('Erro ao processar evento: $e');
      developer.log(stack.toString());
    } finally {
      if (_needsNotification) {
        notifyListeners();
        _needsNotification = false;
      }
    }
  }

  Future<void> savePedidoToCache(PedidoModel pedido) async {
    try {
      await kronosRepository.addPedidoToCache(pedido);
      developer.log("Pedido ${pedido.id} salvo no cache com datas corrigidas");
    } catch (e) {
      throw Exception("Erro ao salvar pedido no cache: $e");
    }
  }

  Future<void> loadSavedPedidos() async {
    try {
      developer.log("Carregando pedidos salvos do cache...");
      var pedidos = await kronosRepository.getPedidosCache();

      Map<String, List<PedidoModel>> tempMap = {};

      for (var pedido in pedidos) {
        String status = pedido.status.isNotEmpty
            ? mapApiStatusToCode(pedido.status)
            : _determineStatus(pedido);

        if (pedido.status.isEmpty) {
          pedido.status = status;
          await savePedidoToCache(pedido);
          developer.log("Atualizando status do pedido antigo ${pedido.id} para $status");
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
      developer.log("Carregamento concluído: ${pedidos.length} pedidos processados");
    } catch (e) {
      developer.log("Erro ao carregar pedidos salvos: $e");
    }
  }

  String mapApiStatusToCode(String apiStatus) {
    final upperStatus = apiStatus.toUpperCase();
    developer.log("Mapeando status: $apiStatus (uppercase: $upperStatus)");

    if (upperStatus.contains('CAN') ||
        upperStatus.contains('CANCELLED') ||
        upperStatus.contains('CANCELLATION') ||
        upperStatus.contains('CANCEL')) {
      developer.log("🔴 Status de CANCELAMENTO detectado: $apiStatus -> ${Consts.statusCancelled}");
      return Consts.statusCancelled;
    } else if (upperStatus.contains('PLC') || upperStatus.contains('PLACED')) {
      return Consts.statusPlaced;
    } else if (upperStatus.contains('CFM') ||
        upperStatus.contains('CONFIRMED') ||
        upperStatus.contains('STP') ||
        upperStatus.contains('PREPARATION')) {
      return Consts.statusConfirmed;
    } else if (upperStatus.contains('DSP') ||
        upperStatus.contains('DISPATCHED') ||
        upperStatus.contains('DISPATCH')) {
      return Consts.statusDispatched;
    } else if (upperStatus.contains('CON') ||
        upperStatus.contains('CONCLUDED') ||
        upperStatus.contains('COMPLETE')) {
      return Consts.statusConcluded;
    } else if (upperStatus.contains('DDCR') ||
        upperStatus.contains('DECLINED')) {
      return 'DDCR';
    } else {
      developer.log("⚠️ Status desconhecido: $apiStatus, usando o padrão PLC");
      return Consts.statusPlaced;
    }
  }

  String _determineStatus(PedidoModel pedido) {
    return mapApiStatusToCode(pedido.status);
  }

  Future<void> getPedidos() async {
    bool hasChanges = false;

    try {
      _batchNotifications = true;
      
      // Limpar confirmações expiradas antes de processar novos pedidos
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
    } finally {
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
    try {
      merchantStatus.value = await merchantRepository.getLojaStatus(loja.id);
    } catch (e) {
      developer.log("Erro ao obter status do merchant: $e");
    }
  }

  Future<void> init(BuildContext context) async {
    isLoading = true;
    notifyListeners();

    try {
      developer.log("Iniciando PedidosController...");

      // Limpar confirmações expiradas ao iniciar
      await cleanExpiredConfirmations();
      
      token = await _authRepository.getValidAccessToken() ?? "";
      if (token.isEmpty) {
        throw Exception("Token de acesso inválido ou expirado");
      }

      merchantRepository = MerchantRepository(Consts.baseUrl, token);
      pollingRepository = PollingRepository();
      orderRepository = OrderRepository(Consts.baseUrl, token);
      
      await loadSavedPedidos();
      
      var lojas = await merchantRepository.getLojas();

      if (lojas.isEmpty) {
        throw Exception("Nenhuma loja encontrada para este merchant");
      }
      if (lojas.length == 1) {
        setLoja(await merchantRepository.getLoja(lojas.first.id));
        developer.log("Apenas uma loja encontrada: ${lojas.first.name}");
      } else {
        if (context.mounted) {
          MerchantModel? selectedLoja = await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return Dialog(
                  child: SizedBox(
                    height: 300,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "Selecione uma Loja",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: lojas.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(lojas[index].name),
                                subtitle: Text(lojas[index].id),
                                onTap: () {
                                  Navigator.pop(context, lojas[index]);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              });

          if (selectedLoja != null) {
            setLoja(await merchantRepository.getLoja(selectedLoja.id));
          } else {
            throw Exception("Nenhuma loja selecionada");
          }
        }
      }

      isLoading = false;
      notifyListeners();

      // Configurar timer para limpar confirmações expiradas a cada hora
      cleanupTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
        await cleanExpiredConfirmations();
      });

      getPedidos().then((_) {
        getMerchantStatus();
        timer = Timer.periodic(
            const Duration(seconds: Consts.pollingIntervalSeconds),
            (timer) async {
          await getPedidos();
        });
      });
    } catch (err) {
      haveError = true;
      errorMsg = err.toString();
      timer = null;
      cleanupTimer?.cancel();
      isLoading = false;
      developer.log("Erro na inicialização: $err");
      notifyListeners();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    cleanupTimer?.cancel();
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
    switch (code) {
      case "PLC":
        return "Aceitar Pedidos";
      case "CFM":
        return "Em Preparo";
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