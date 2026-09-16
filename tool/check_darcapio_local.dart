import 'dart:io';
import 'package:dio/dio.dart';

// Diagnóstico somente leitura. Usa sessão existente; nunca pede outro login.
Future<void> main() async {
  final token = Platform.environment['KRONOS_FOOD_LOCAL_SESSION'];
  if (token == null || token.isEmpty)
    throw StateError(
        'Forneça a sessão de teste existente por variável de ambiente.');
  final dio = Dio(BaseOptions(
      followRedirects: false,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20)));
  try {
    final response = await dio.get(
        'https://localhost:5943/arc/darcapio/food/pedidos',
        options: Options(headers: {'Auth': token, 'Empresa': '1'}));
    if (response.data is! List) throw StateError('Contrato inesperado.');
    stdout.writeln(
        'PASS: sessão existente consultou a fila do Service por HTTPS. Nenhum status foi alterado.');
  } finally {
    dio.close();
  }
}
