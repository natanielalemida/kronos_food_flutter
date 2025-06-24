import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
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
  final kronosRepository = KronosRepository();

  late MerchantRepository merchantRepository;
  late PollingRepository pollingRepository;
  late OrderRepository orderRepository;
  late MerchantModel loja;
  ValueNotifier<PedidoModel?> selectedPedido =
      ValueNotifier<PedidoModel?>(null); // Pedido selecionado
  bool haveError = false;
  String errorMsg = "";
  Map<String, List<PedidoModel>> pedidosMap = {};
  var mainController = MainController();
  final AuthRepository _authRepository = AuthRepository();
  bool _batchNotifications = false;
  bool _needsNotification = false;

  final merchantStatus = ValueNotifier<MerchantStatus>(MerchantStatus.closed);
  final orderTimming = ValueNotifier<OrderTimming>(OrderTimming.immediate);

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
      // Verifica se o pedido já está no cache
      if (pedidos.isEmpty ||
          (pedidos.isNotEmpty &&
              pedidos.where((p) => p.id == pedidoId).isEmpty)) {
        developer.log("Cache de pedidos está vazio.");

        // Se não estiver no cache, busca da API
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

  // // Recupera um pedido do cache
  // Future<PedidoModel?> getPedidoFromCache(String pedidoId) async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final pedidoJson = prefs.getString('pedido_$pedidoId');

  //     if (pedidoJson == null) return null;

  //     // Obter o pedido do cache
  //     var pedido = PedidoModel.fromJson(jsonDecode(pedidoJson));

  //     // Log para verificar o status
  //     developer.log(
  //         "Pedido recuperado do cache: ${pedido.id} - status: ${pedido.status}");

  //     return pedido;
  //   } catch (e) {
  //     developer.log("Erro ao recuperar pedido do cache: $e");
  //     return null;
  //   }
  // }

  Future<void> handleNewEvent(EventModel event) async {
    developer.log('Recebeu novo evento: ${event.code} - ${event.id}');
    try {
      final String orderId = event.orderId;
      final String eventCode = event.code;

      developer.log('Processando evento $eventCode para pedido $orderId');

      // Tratar eventos de cancelamento com prioridade
      if (eventCode == 'CAN') {
        developer.log('Processando CANCELAMENTO para pedido $orderId');

        // Remover o pedido de qualquer lista de status atual
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

        // Se o pedido foi encontrado e removido, adicionar à lista de cancelados
        if (pedidoRemovido) {
          // Tenta obter detalhes atualizados, ou usar um modelo básico se falhar
          try {
            var updatedPedido = await getPedidoDetails(orderId);
            if (updatedPedido != null) {
              // Forçar o status para cancelado
              updatedPedido.statusCode = Consts.statusCancelled;

              // Adicionar à lista de cancelados
              if (!pedidosMap.containsKey(Consts.statusCancelled)) {
                pedidosMap[Consts.statusCancelled] = [];
              }
              pedidosMap[Consts.statusCancelled]!.add(updatedPedido);

              // Salvar o pedido atualizado no cache
              updatedPedido.status = eventCode;

              if (updatedPedido.events.where((e) => e.id == event.id).isEmpty) {
                updatedPedido.events.add(event);
              } else {
                // Atualizar o evento existente
                int index =
                    updatedPedido.events.indexWhere((e) => e.id == event.id);
                if (index != -1) {
                  updatedPedido.events[index] = event;
                }
              }

              await savePedidoToCache(updatedPedido);

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
      } else {
        // Buscar detalhes do pedido diretamente da API para garantir dados atualizados (código existente)
        try {
          var updatedPedido = await getPedidoDetails(orderId);
          if (updatedPedido != null) {
            developer
                .log('Detalhes do pedido $orderId atualizados com sucesso');
            updatedPedido.status = eventCode;

            // Determinar o status correspondente ao código do evento
            String status = mapApiStatusToCode(updatedPedido.status.isEmpty
                ? eventCode
                : updatedPedido.status);

            // Primeiro, remover o pedido de qualquer lista de status existente
            for (var statusKey in pedidosMap.keys.toList()) {
              pedidosMap[statusKey]?.removeWhere((p) => p.id == orderId);
            }

            // Adicionar o pedido atualizado à lista correta
            if (pedidosMap.containsKey(status)) {
              pedidosMap[status]!.add(updatedPedido);
            } else {
              pedidosMap[status] = [updatedPedido];
            }
            if (updatedPedido.events.where((e) => e.id == event.id).isEmpty) {
              updatedPedido.events.add(event);
            } else {
              // Atualizar o evento existente
              int index =
                  updatedPedido.events.indexWhere((e) => e.id == event.id);
              if (index != -1) {
                updatedPedido.events[index] = event;
              }
            }
            // Salvar o pedido no cache
            await savePedidoToCache(updatedPedido);
            await pollingRepository.acknowledgeEvents([
              {"id": event.id}
            ]);

            if (selectedPedido.value?.id == orderId) {
              selectedPedido.value = updatedPedido;
            }
            selectedPedido.notifyListeners();

            developer.log(
                'Pedido $orderId com status $status adicionado/atualizado no estado');
            _needsNotification = true;
          }
        } catch (e) {
          developer.log('Erro ao atualizar detalhes do pedido $orderId: $e');

          // Se falhar ao buscar detalhes, pelo menos atualizar o status baseado no evento
          // final existingPedido = _findPedidoInMap(orderId);
          // if (existingPedido != null) {
          //   // Atualizar o status do pedido baseado no código do evento
          //   final newStatus = mapApiStatusToCode(eventCode);

          //   // Remover o pedido do status antigo
          //   for (var statusKey in pedidosMap.keys.toList()) {
          //     pedidosMap[statusKey]?.removeWhere((p) => p.id == orderId);
          //   }

          //   // Atualizar o status do pedido
          //   existingPedido.status = newStatus;

          //   // Adicionar o pedido atualizado à lista correta
          //   if (pedidosMap.containsKey(newStatus)) {
          //     pedidosMap[newStatus]!.add(existingPedido);
          //   } else {
          //     pedidosMap[newStatus] = [existingPedido];
          //   }

          //   _needsNotification = true;
          //   developer.log(
          //       'Pedido $orderId movido para status $newStatus baseado no evento');
          // }
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

  // Salva um pedido no cache
  Future<void> savePedidoToCache(PedidoModel pedido) async {
    try {
      await kronosRepository.addPedidoToCache(pedido);
      developer.log("Pedido ${pedido.id} salvo no cache com datas corrigidas");
    } catch (e) {
      throw Exception("Erro ao salvar pedido no cache: $e");
    }
  }

  // // Carrega pedidos salvos do cache
  Future<void> loadSavedPedidos() async {
    try {
      developer.log("Carregando pedidos salvos do cache...");
      var pedidos = await kronosRepository.getPedidosCache();
      // final prefs = await SharedPreferences.getInstance();
      // List<String> pedidosIds = prefs.getStringList(_pedidosIdsKey) ?? [];

      Map<String, List<PedidoModel>> tempMap = {};

      for (var pedido in pedidos) {
        String status = pedido.status.isNotEmpty
            ? mapApiStatusToCode(pedido.status)
            : _determineStatus(pedido);

        // Atualiza o status do pedido antigo se ele estiver vazio
        if (pedido.status.isEmpty) {
          pedido.status = status;
          // Salva o pedido com o status atualizado
          await savePedidoToCache(pedido);
          developer.log(
              "Atualizando status do pedido antigo ${pedido.id} para $status");
        }

        // Garantir que o pedido só esteja presente em uma categoria de status
        // Remover o ID de qualquer outra lista de status
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

      // Atualiza o pedidosMap com os pedidos carregados
      pedidosMap = tempMap;

      developer
          .log("Carregamento concluído: ${pedidos.length} pedidos processados");
    } catch (e) {
      developer.log("Erro ao carregar pedidos salvos: $e");
    }
  }

  // Mapeia o status da API para o código interno
  String mapApiStatusToCode(String apiStatus) {
    final upperStatus = apiStatus.toUpperCase();

    // Log para debug
    developer.log("Mapeando status: $apiStatus (uppercase: $upperStatus)");

    // Verificação mais rígida para status de cancelamento
    if (upperStatus.contains('CAN') ||
        upperStatus.contains('CANCELLED') ||
        upperStatus.contains('CANCELLATION') ||
        upperStatus.contains('CANCEL')) {
      developer.log(
          "🔴 Status de CANCELAMENTO detectado: $apiStatus -> ${Consts.statusCancelled}");
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
      return 'DDCR'; // Novo status - Driver Declined/Delivery Declined
    } else {
      // Status desconhecido, vamos registrar para ajudar no diagnóstico
      developer.log("⚠️ Status desconhecido: $apiStatus, usando o padrão PLC");
      return Consts.statusPlaced; // Status padrão se não puder determinar
    }
  }

  // Determina o status de um pedido com base em seus dados
  String _determineStatus(PedidoModel pedido) {
    // Lógica simples para determinar o status com base no campo status do pedido
    // ou outras propriedades se disponíveis
    return mapApiStatusToCode(pedido.status);
  }

  Future<void> getPedidos() async {
    bool hasChanges = false;

    try {
      _batchNotifications = true;
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

      // Obter token de acesso válido
      token = await _authRepository.getValidAccessToken() ?? "";
      if (token.isEmpty) {
        throw Exception("Token de acesso inválido ou expirado");
      }

      merchantRepository = MerchantRepository(Consts.baseUrl, token);
      pollingRepository = PollingRepository();
      orderRepository = OrderRepository(Consts.baseUrl, token);
      //CARREGAR PEDIDOS DO CACHE
      await loadSavedPedidos();
      // Obter lojas do merchant
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

      // Iniciar polling de eventos
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
      isLoading = false;
      developer.log("Erro na inicialização: $err");
      notifyListeners();
    }
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
