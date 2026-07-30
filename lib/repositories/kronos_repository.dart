import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/service/preferences_service.dart';
// import 'package:http/http.dart' as http;

class KronosRepository {
  final dio = Dio();
  final PreferencesService _preferencesService = PreferencesService();

  dynamic _readApiField(dynamic body, String field) {
    if (body is! Map) return null;
    if (body.containsKey(field)) return body[field];

    final lowerField = field.toLowerCase();
    if (body.containsKey(lowerField)) return body[lowerField];

    for (final entry in body.entries) {
      if (entry.key.toString().toLowerCase() == lowerField) {
        return entry.value;
      }
    }

    return null;
  }

  bool _isOne(dynamic value) => value == 1 || value?.toString() == '1';

  String _messageFromResponse(dynamic data) {
    final mensagens =
        _readApiField(data, 'mensagens') ?? _readApiField(data, 'Mensagens');

    if (mensagens is List && mensagens.isNotEmpty) {
      final first = mensagens.first;
      final content =
          _readApiField(first, 'conteudo') ?? _readApiField(first, 'Conteudo');
      if (content != null && content.toString().trim().isNotEmpty) {
        return content.toString();
      }
      return first.toString();
    }

    final mensagem =
        _readApiField(data, 'Mensagem') ?? _readApiField(data, 'mensagem');
    if (mensagem != null && mensagem.toString().trim().isNotEmpty) {
      return mensagem.toString();
    }

    return data.toString();
  }

  String _messageFromDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final message = data == null ? error.message : _messageFromResponse(data);

    if (statusCode == null) return message ?? error.toString();
    return 'HTTP $statusCode - ${message ?? error.toString()}';
  }

  bool _isAlreadyProcessedSaleMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('pr\u00e9-venda processada') ||
        normalized.contains('pre-venda processada') ||
        normalized.contains('pre venda processada') ||
        normalized.contains('j\u00e1 finalizado') ||
        normalized.contains('ja finalizado') ||
        normalized.contains('pedido finalizado');
  }

  Future<dynamic> _getCodigoCaixaMovimento({
    required String serverIp,
    required Map<String, String> headers,
  }) async {
    final caixa = await _preferencesService.getCodCaixaDecoded();
    final cachedCodigo = _readApiField(caixa, 'Codigo');
    if (cachedCodigo != null) return cachedCodigo;

    final response = await dio
        .get(
          '$serverIp/caixa/',
          options: Options(headers: headers),
        )
        .timeout(
          const Duration(seconds: 30),
        );

    if (response.statusCode != 200) {
      throw Exception(
          'Falha ao carregar caixa antes de finalizar: HTTP ${response.statusCode}');
    }

    final data = response.data;
    if (!_isOne(_readApiField(data, 'Status'))) {
      throw Exception(
          'Falha ao carregar caixa antes de finalizar: ${_messageFromResponse(data)}');
    }

    final resultado = _readApiField(data, 'Resultado');
    final codigo = _readApiField(resultado, 'Codigo');
    if (codigo == null) {
      throw Exception(
          'Caixa nao retornou Codigo para finalizar o pedido. Verifique se o caixa esta aberto para este terminal.');
    }

    final situacao = _readApiField(resultado, 'Situacao');
    if (situacao != null && !_isOne(situacao)) {
      throw Exception(
          'Caixa encontrado, mas nao esta aberto para finalizar o pedido. Abra o caixa e tente novamente.');
    }

    await _preferencesService.saveCodCaixa(jsonEncode({
      "Codigo": codigo,
      "ValorSupProximoCaixa":
          _readApiField(resultado, 'ValorSupProximoCaixa') ?? 0,
    }));

    return codigo;
  }

  Future<List<PedidoModel>> getPedidosCache() async {
    final kronosToken = await _preferencesService.getKronosToken() ?? "";
    final serverIp =
        await _preferencesService.getServerIp() ?? "http://localhost:5000";
    // final companyCode = await _preferencesService.getCompanyCode() ?? "";
    final headers = {
      'Content-Type': 'application/json',
      'Auth': kronosToken,
    };

    final url = '$serverIp/delivery/externo/cachePedidos';
    final response = await dio
        .get(url,
            options: Options(
              headers: headers,
            ))
        .timeout(
          const Duration(seconds: 10),
        );
    if (response.statusCode == 200) {
      var data = response.data;
      if (data['Status'] != 1) {
        throw Exception('Erro na resposta: ${data['Mensagem']}');
      }
      List items = data['Resultado'];
      if (items.isNotEmpty && items[0] == null) {
        return [];
      }
      var orders = items.map((e) => PedidoModel.fromKronos(e)).toList();
      return orders;
    } else {
      throw Exception('Falha ao carregar pedidos: ${response.statusCode}');
    }
  }

  Future<List> getEntregadores() async {
    final kronosToken = await _preferencesService.getKronosToken() ?? "";
    final serverIp =
        await _preferencesService.getServerIp() ?? "http://localhost:5000";
    // final companyCode = await _preferencesService.getCompanyCode() ?? "";
    final headers = {
      'Content-Type': 'application/json',
      'Auth': kronosToken,
    };

    final url = '$serverIp/funcionario/cargo/entregador';
    final response = await dio
        .get(url,
            options: Options(
              headers: headers,
            ))
        .timeout(
          const Duration(seconds: 10),
        );
    if (response.statusCode == 200) {
      var data = response.data;
      if (data['Status'] != 1) {
        throw Exception('Erro na resposta: ${data['Mensagem']}');
      }
      List items = data['Resultado'];
      return items;
    } else {
      throw Exception('Falha ao carregar pedidos: ${response.statusCode}');
    }
  }

  Future<bool> sendDespachar(PedidoModel pedido, int? Codigo) async {
    final kronosToken = await _preferencesService.getKronosToken() ?? "";

    final company = await _preferencesService.getCompanyCode() ?? "";

    final terminal = await _preferencesService.getTerminalCode() ?? "";
    final serverIp =
        await _preferencesService.getServerIp() ?? "http://localhost:5000";
    // final companyCode = await _preferencesService.getCompanyCode() ?? "";
    final headers = {
      'Content-Type': 'application/json',
      'Auth': kronosToken,
      'Empresa': company,
      'Terminal': terminal
    };

    final url = '$serverIp/delivery/pedido/despachar';
    var body = {
      "IdPedidos": [pedido.id],
      "DataHora": DateTime.now().toIso8601String(),
      "CodigoEntregador": Codigo
    };
    final response = await dio
        .put(
          url,
          options: Options(
            headers: headers,
          ),
          data: body,
        )
        .timeout(
          const Duration(seconds: 10),
        );
    if (response.statusCode == 200) {
      var data = response.data;
      if (data['Status'] != 1) {
        throw Exception('Erro na resposta: ${data['mensagens'][0]}');
      }
      return true;
    } else {
      throw Exception(
          'Falha ao adicionar pedido ao cache: ${response.statusCode}');
    }
  }

  Future<bool> sendConfirmar(PedidoModel pedido) async {
    try {
      final kronosToken = await _preferencesService.getKronosToken() ?? "";

      final company = await _preferencesService.getCompanyCode() ?? "";

      final terminal = await _preferencesService.getTerminalCode() ?? "";
      final serverIp =
          await _preferencesService.getServerIp() ?? "http://localhost:5000";
      // final companyCode = await _preferencesService.getCompanyCode() ?? "";
      final headers = {
        'Content-Type': 'application/json',
        'Auth': kronosToken,
        'Empresa': company,
        'Terminal': terminal
      };

      final codigoCaixaMovimento = await _getCodigoCaixaMovimento(
        serverIp: serverIp,
        headers: headers,
      );

      final url = '$serverIp/delivery/pedido/finalizar';
      var body = {
        "IdPedidos": [pedido.id],
        "CodigoCaixaMovimento": codigoCaixaMovimento,
        "DataHora": DateTime.now().toIso8601String()
      };
      final response = await dio
          .put(
            url,
            options: Options(
              headers: headers,
            ),
            data: body,
          )
          .timeout(
            const Duration(seconds: 30),
          );
      if (response.statusCode == 200) {
        var data = response.data;
        if (!_isOne(_readApiField(data, 'Status'))) {
          final message = _messageFromResponse(data);
          if (_isAlreadyProcessedSaleMessage(message)) {
            return true;
          }
          throw Exception('Erro ao finalizar pedido no Kronos: $message');
        }
        return true;
      } else {
        throw Exception(
            'Falha ao finalizar pedido no Kronos: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final message = _messageFromDioError(e);
      if (_isAlreadyProcessedSaleMessage(message)) {
        return true;
      }
      throw Exception('Erro ao finalizar pedido no Kronos: $message');
    }
  }

  Future<bool> cancelarPedido(String? id, String reason) async {
    final kronosToken = await _preferencesService.getKronosToken() ?? "";

    final company = await _preferencesService.getCompanyCode() ?? "";

    final terminal = await _preferencesService.getTerminalCode() ?? "";

    final codeUser = await _preferencesService.getCodeUser();

    final serverIp =
        await _preferencesService.getServerIp() ?? "http://localhost:5000";
    // final companyCode = await _preferencesService.getCompanyCode() ?? "";
    final headers = {
      'Content-Type': 'application/json',
      'Auth': kronosToken,
      'Empresa': company,
      'Terminal': terminal
    };

    final url = '$serverIp/delivery/pedido/cancelar';
    var body = {
      "IdPedido": id,
      "Justificativa": reason,
      "CodigoResponsavelOperacao": int.parse(codeUser!),
    };

    final response = await dio
        .put(
          url,
          options: Options(
            headers: headers,
          ),
          data: body,
        )
        .timeout(
          const Duration(seconds: 10),
        );
    if (response.statusCode == 200) {
      var data = response.data;
      if (data['Status'] != 1) {
        throw Exception('Erro na resposta: ${data['mensagens'][0]}');
      }
      return true;
    } else {
      throw Exception(
          'Falha ao adicionar pedido ao cache: ${response.statusCode}');
    }
  }

  Future<bool> addPedidoToCache(PedidoModel pedido) async {
    final kronosToken = await _preferencesService.getKronosToken() ?? "";
    final serverIp =
        await _preferencesService.getServerIp() ?? "http://localhost:5000";
    // final companyCode = await _preferencesService.getCompanyCode() ?? "";
    final headers = {
      'Content-Type': 'application/json',
      'Auth': kronosToken,
    };

    final url = '$serverIp/delivery/externo/cachePedidos';
    var body = pedido.toJson();
    final response = await dio
        .post(
          url,
          options: Options(
            headers: headers,
          ),
          data: body,
        )
        .timeout(
          const Duration(seconds: 10),
        );
    if (response.statusCode == 200) {
      var data = response.data;
      if (data['Status'] != 1) {
        throw Exception('Erro na resposta: ${data['mensagens'][0]}');
      }
      return true;
    } else {
      throw Exception(
          'Falha ao adicionar pedido ao cache: ${response.statusCode}');
    }
  }

  Future<bool> savePedidoToKronos(PedidoModel pedido) async {
    final kronosToken = await _preferencesService.getKronosToken() ?? "";
    final serverIp =
        await _preferencesService.getServerIp() ?? "http://localhost:5000";
    final codigoEmpresa = await _preferencesService.getCompanyCode() ?? "1";
    // Construir a URL para a
    // final companyCode = await _preferencesService.getCompanyCode() ?? "";
    final headers = {
      'Content-Type': 'application/json',
      'codigoTerminal': '1',
      'Empresa': codigoEmpresa,
      'Auth': kronosToken,
    };

    final url = '$serverIp/delivery/externo/pedidos';
    var body = pedido.toJson();
    final response = await dio
        .post(
          url,
          options: Options(
            headers: headers,
          ),
          data: body,
        )
        .timeout(
          const Duration(seconds: 10),
        );
    if (response.statusCode == 200) {
      var data = response.data;
      if (data['Status'] != 1) {
        throw Exception('Erro na resposta: ${data['mensagens'][0]}');
      }
      return true;
    } else {
      throw Exception(
          'Falha ao salvar pedido no Kronos: ${response.statusCode}');
    }
  }
}
