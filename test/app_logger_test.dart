import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/utils/app_logger.dart';

void main() {
  group('AppLogger', () {
    test('mascara credenciais em estruturas de dados', () {
      final sanitized = AppLogger.sanitizeForTesting({
        'username': 'operador',
        'password': 'senha-super-secreta',
        'clientSecret': 'segredo-do-cliente',
        'headers': {
          'Authorization': 'Bearer token-de-acesso',
          'Content-Type': 'application/json',
        },
        'nested': {
          'refresh_token': 'refresh-secreto',
          'status': 'OK',
        },
      }) as Map<String, dynamic>;

      expect(sanitized['username'], 'operador');
      expect(sanitized['password'], '***MASCARADO***');
      expect(sanitized['clientSecret'], '***MASCARADO***');
      expect(
        (sanitized['headers'] as Map<String, dynamic>)['Authorization'],
        '***MASCARADO***',
      );
      expect(
        (sanitized['nested'] as Map<String, dynamic>)['refresh_token'],
        '***MASCARADO***',
      );
      expect(
        (sanitized['nested'] as Map<String, dynamic>)['status'],
        'OK',
      );
    });

    test('mascara credenciais presentes em texto livre', () {
      final sanitized = AppLogger.sanitizeForTesting(
        'Authorization: Bearer abc.def.ghi clientSecret=nao-pode-vazar '
        'authorization=Basic YWRtaW46c2VuaGE= cookie=session-secreta',
      ) as String;

      expect(sanitized, contains('***MASCARADO***'));
      expect(sanitized, isNot(contains('abc.def.ghi')));
      expect(sanitized, isNot(contains('nao-pode-vazar')));
      expect(sanitized, isNot(contains('YWRtaW46c2VuaGE=')));
      expect(sanitized, isNot(contains('session-secreta')));
    });

    test('resume conteúdo binário extenso', () {
      final sanitized = AppLogger.sanitizeForTesting(
        List<int>.generate(256, (index) => index % 256),
      );

      expect(sanitized, contains('256 bytes'));
    });
  });
}
