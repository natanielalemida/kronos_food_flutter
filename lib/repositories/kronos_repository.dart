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
