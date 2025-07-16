import 'package:dio/dio.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/service/preferences_service.dart';
// import 'package:http/http.dart' as http;

class KronosRepository {
  final dio = Dio();
  final PreferencesService _preferencesService = PreferencesService();

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
      "DataHora": pedido.delivery.deliveryDateTime.toIso8601String(),
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
    final kronosToken = await _preferencesService.getKronosToken() ?? "";

    final company = await _preferencesService.getCompanyCode() ?? "";

    final caixa = await _preferencesService.getCodCaixaDecoded();

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

    final url = '$serverIp/delivery/pedido/finalizar';
    var body = {
      "IdPedidos": [pedido.id],
      "CodigoCaixaMovimento": caixa?['Codigo'],
      "DataHora": pedido.delivery.deliveryDateTime.toIso8601String()
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
