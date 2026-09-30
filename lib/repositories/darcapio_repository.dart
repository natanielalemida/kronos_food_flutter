import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../service/preferences_service.dart';
import '../models/darcapio_delivery_map.dart';
import '../models/food_store_identity.dart';
import '../models/courier_management.dart';
import '../models/darcapio_order_status.dart';

dynamic darcapioField(dynamic value, String key) {
  if (value is! Map) return null;
  for (final entry in value.entries) {
    if (entry.key.toString().toLowerCase() == key.toLowerCase()) {
      return entry.value;
    }
  }
  return null;
}

class DarcapioAction {
  final String action, label;
  final bool requiresCode, requiresCourier;
  const DarcapioAction(this.action, this.label,
      {this.requiresCode = false, this.requiresCourier = false});
  factory DarcapioAction.fromJson(dynamic json) => DarcapioAction(
      darcapioField(json, 'acao').toString(),
      darcapioField(json, 'rotulo').toString(),
      requiresCode: darcapioField(json, 'exigeCodigo') == true,
      requiresCourier: darcapioField(json, 'exigeEntregador') == true);
}

class DarcapioCourier {
  final int code;
  final String name;
  const DarcapioCourier(this.code, this.name);
  factory DarcapioCourier.fromJson(dynamic json) => DarcapioCourier(
      (darcapioField(json, 'codigo') as num).toInt(),
      darcapioField(json, 'nome') as String);
}

class DarcapioCashMovement {
  final int code;
  final DateTime opened;
  final DateTime? closed;
  final bool isOpen;
  const DarcapioCashMovement(
      {required this.code,
      required this.opened,
      this.closed,
      required this.isOpen});
  factory DarcapioCashMovement.fromJson(dynamic json) => DarcapioCashMovement(
      code: (darcapioField(json, 'codigo') as num).toInt(),
      opened: DateTime.parse(darcapioField(json, 'dataAbertura')).toLocal(),
      closed: darcapioField(json, 'dataFechamento') == null
          ? null
          : DateTime.parse(darcapioField(json, 'dataFechamento')).toLocal(),
      isOpen: darcapioField(json, 'aberto') == true);
}

class DarcapioOrderPage {
  final int page, size, total;
  final List<DarcapioOrder> orders;
  const DarcapioOrderPage(
      {required this.page,
      required this.size,
      required this.total,
      required this.orders});
  bool get hasNext => (page + 1) * size < total;
}

class DarcapioOrder {
  final String id, status, customer, payment;
  final int version, delivery;
  final double total;
  final DateTime created;
  final List<Map<String, dynamic>> items;
  final List<DarcapioAction> actions;
  final bool pickup, needsChange;
  final double deliveryFee;
  final double? changeFor;
  final Map<String, dynamic>? address;
  final int? courierCode;
  final String? courierName;
  final String? cancellationReason;
  DarcapioOrder(
      {required this.id,
      required this.status,
      required this.customer,
      required this.payment,
      required this.version,
      required this.delivery,
      required this.total,
      required this.created,
      required this.items,
      this.actions = const [],
      this.pickup = true,
      this.needsChange = false,
      this.deliveryFee = 0,
      this.changeFor,
      this.address,
      this.courierCode,
      this.courierName,
      this.cancellationReason});
  factory DarcapioOrder.fromJson(Map<String, dynamic> json) {
    final order = darcapioField(json, 'pedido');
    final cancellations = (darcapioField(json, 'historico') as List? ?? [])
        .where((entry) => darcapioField(entry, 'situacao') == 'cancelado');
    return DarcapioOrder(
        id: darcapioField(json, 'pedidoId') as String,
        status: darcapioField(json, 'situacao') as String,
        customer: darcapioField(json, 'clienteNome')?.toString() ??
            'Cliente Darcapio',
        payment: darcapioField(json, 'formaPagamento')?.toString() ??
            'Pagamento na retirada',
        version: (darcapioField(json, 'versaoStatus') as num).toInt(),
        courierCode: (darcapioField(json, 'codigoEntregador') as num?)?.toInt(),
        courierName: darcapioField(json, 'nomeEntregador') as String?,
        cancellationReason: cancellations.isEmpty
            ? null
            : darcapioField(cancellations.last, 'motivo') as String?,
        delivery: (darcapioField(json, 'codigoDelivery') as num).toInt(),
        total: (darcapioField(order, 'total') as num?)?.toDouble() ?? 0,
        created: DateTime.parse(darcapioField(json, 'criadoEm')).toLocal(),
        pickup: darcapioField(order, 'retirada') != false,
        needsChange: darcapioField(order, 'precisaTroco') == true,
        changeFor: (darcapioField(order, 'trocoPara') as num?)?.toDouble(),
        deliveryFee:
            (darcapioField(order, 'taxaEntrega') as num?)?.toDouble() ?? 0,
        address: darcapioField(order, 'endereco') is Map
            ? Map<String, dynamic>.from(darcapioField(order, 'endereco'))
            : null,
        actions: (darcapioField(json, 'acoesPermitidas') as List? ?? [])
            .map(DarcapioAction.fromJson)
            .toList(),
        items: (darcapioField(order, 'itens') as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
  }
  String get label => darcapioStatusLabel(status);
}

class DarcapioRepository {
  final Dio dio;
  DarcapioCashMovement? currentMovement;
  String? _server, _token;
  int? _company;
  DarcapioRepository({Dio? client})
      : dio = client ??
            Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                followRedirects: false)) {
    if (client == null) {
      // Não herda o aceite global de certificados inválidos do conector legado iFood.
      dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () =>
              HttpClient()..badCertificateCallback = (_, __, ___) => false);
    }
  }
  static Uri validateServer(String server) {
    final uri = Uri.tryParse(server.trim().replaceAll(RegExp(r'/+$'), ''));
    final local = uri?.host == 'localhost' || uri?.host == '127.0.0.1';
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && local))) {
      throw StateError(
          'Informe o servidor HTTPS do ERP, terminado em /arc. HTTP somente em localhost.');
    }
    if (uri.path != '/arc') {
      throw StateError('O endereço do ERP deve terminar em /arc.');
    }
    return uri;
  }

  Future<int> useExistingSession() async {
    final prefs = PreferencesService();
    final values = await Future.wait(
        [prefs.getServerIp(), prefs.getKronosToken(), prefs.getCompanyCode()]);
    final company = int.tryParse(values[2] ?? '');
    if (values[1]?.isNotEmpty != true || company == null || company <= 0) {
      throw StateError(
          'Entre no Kronos Food para acessar os pedidos. Não há outro login para o Darcapio.');
    }
    _server = validateServer(values[0] ?? '').toString();
    _token = values[1];
    _company = company;
    return company;
  }

  Options get _options {
    if (_token == null) throw StateError('Entre novamente no Kronos Food.');
    return Options(
        headers: {'Auth': _token, 'Empresa': '$_company'},
        followRedirects: false);
  }

  Future<List<DarcapioOrder>> list() async {
    await useExistingSession();
    final response = await dio.get(
        '$_server/darcapio/food/pedidos/movimento-atual',
        options: _options);
    final items = darcapioField(response.data, 'itens');
    if (items is! List) {
      throw StateError('Resposta de pedidos inválida.');
    }
    final movement = darcapioField(response.data, 'movimento');
    final orders = items
        .map((e) => DarcapioOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    currentMovement =
        movement == null ? null : DarcapioCashMovement.fromJson(movement);
    return orders;
  }

  Future<List<DarcapioCashMovement>> movements({int? code}) async {
    await useExistingSession();
    final response = await dio.get('$_server/darcapio/food/pedidos/movimentos',
        queryParameters: {if (code != null) 'codigo': code}, options: _options);
    if (response.data is! List) {
      throw StateError('Resposta de movimentos inválida.');
    }
    return (response.data as List).map(DarcapioCashMovement.fromJson).toList();
  }

  Future<DarcapioOrderPage> history(int movement, {int page = 0}) async {
    await useExistingSession();
    final response = await dio.get('$_server/darcapio/food/pedidos/paginados',
        queryParameters: {
          'movimentoCaixa': movement,
          'pagina': page,
          'tamanho': 100
        },
        options: _options);
    final items = darcapioField(response.data, 'itens');
    if (items is! List) throw StateError('Resposta de histórico inválida.');
    return DarcapioOrderPage(
        page: (darcapioField(response.data, 'pagina') as num).toInt(),
        size: (darcapioField(response.data, 'tamanho') as num).toInt(),
        total: (darcapioField(response.data, 'total') as num).toInt(),
        orders: items
            .map((e) => DarcapioOrder.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  Future<Map<String, dynamic>> storeStatus() async {
    await useExistingSession();
    final response =
        await dio.get('$_server/darcapio/food/loja', options: _options);
    return Map<String, dynamic>.from(response.data);
  }

  Future<FoodStoreIdentity> storeIdentity() async {
    final company = await useExistingSession();
    final response =
        await dio.get('$_server/empresa/$company', options: _options);
    final result = darcapioField(response.data, 'resultado');
    if (result is! Map) throw StateError('Identidade da loja indisponível.');
    final identity =
        FoodStoreIdentity.fromJson(Map<String, dynamic>.from(result));
    if (identity.company != company) {
      throw StateError('A identidade não pertence à empresa selecionada.');
    }
    return identity;
  }

  Future<Map<String, dynamic>> courierTracking(String orderId) async {
    await useExistingSession();
    final response = await dio.get(
        '$_server/darcapio/food/pedidos/$orderId/rastreamento',
        options: _options);
    return Map<String, dynamic>.from(response.data);
  }

  Future<DarcapioDeliveryMap> deliveryMap(String orderId) async {
    await useExistingSession();
    final response = await dio.get(
        '$_server/darcapio/food/pedidos/$orderId/mapa',
        options:
            _options.copyWith(receiveTimeout: const Duration(seconds: 35)));
    return DarcapioDeliveryMap.fromJson(
        Map<String, dynamic>.from(response.data));
  }

  Future<Uint8List> deliveryMapTile(String orderId, int z, int x, int y,
      {CancelToken? cancelToken}) async {
    await useExistingSession();
    final response = await dio.get<List<int>>(
        '$_server/darcapio/food/pedidos/$orderId/mapa/tiles/$z/$x/$y',
        cancelToken: cancelToken,
        options: _options.copyWith(responseType: ResponseType.bytes));
    return Uint8List.fromList(response.data!);
  }

  Future<Map<String, dynamic>> changeStore(int version, String action) async {
    await useExistingSession();
    final response = await dio.post('$_server/darcapio/food/loja',
        options: _options, data: {'Versao': version, 'Acao': action});
    return Map<String, dynamic>.from(response.data);
  }

  Future<List<DarcapioCourier>> couriers() async {
    await useExistingSession();
    final response = await dio
        .get('$_server/darcapio/food/pedidos/entregadores', options: _options);
    if (response.data is! List) {
      throw StateError('Não foi possível carregar os entregadores.');
    }
    return (response.data as List).map(DarcapioCourier.fromJson).toList();
  }

  Future<CourierManagement> courierManagement() async {
    await useExistingSession();
    final response =
        await dio.get('$_server/darcapio/food/entregadores', options: _options);
    return CourierManagement.fromJson(response.data);
  }

  Future<CourierInvite> inviteCourier(int code) async {
    await useExistingSession();
    final response = await dio.post(
        '$_server/darcapio/food/entregadores/$code/convite',
        options: _options);
    return CourierInvite.fromJson(response.data);
  }

  Future<void> revokeCourier(int code) async {
    await useExistingSession();
    await dio.delete('$_server/darcapio/food/entregadores/$code/acesso',
        options: _options);
  }

  Future<void> advance(DarcapioOrder order, DarcapioAction action,
      {String? code, int? courierCode, String? reason}) async {
    await useExistingSession();
    await dio.post('$_server/darcapio/food/pedidos/${order.id}/status',
        options: _options,
        data: {
          'Versao': order.version,
          'Acao': action.action,
          if (reason != null) 'Motivo': reason,
          if (code != null) 'CodigoConfirmacao': code,
          if (courierCode != null) 'CodigoEntregador': courierCode
        });
  }

  Future<List<Map<String, dynamic>>> conversationSummaries() async {
    await useExistingSession();
    final response =
        await dio.get('$_server/darcapio/food/conversas', options: _options);
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> conversation(String order, {int? before}) async {
    await useExistingSession();
    final response = await dio.get('$_server/darcapio/food/conversas/$order',
        queryParameters: {if (before != null) 'antes': before},
        options: _options);
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> conversationPost(
      String order, String path, Map<String, dynamic> data) async {
    await useExistingSession();
    await dio.post('$_server/darcapio/food/conversas/$order/$path',
        data: data, options: _options);
  }

  Future<Uint8List> conversationPhoto(String order, String id) async {
    await useExistingSession();
    final response = await dio.get<List<int>>(
        '$_server/darcapio/food/conversas/$order/fotos/$id',
        options: _options.copyWith(responseType: ResponseType.bytes));
    return Uint8List.fromList(response.data!);
  }

  void dispose() {
    dio.close();
    _token = null;
  }
}
