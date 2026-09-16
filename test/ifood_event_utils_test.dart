import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/utils/ifood_event_utils.dart';

void main() {
  group('IfoodEventUtils', () {
    test('somente eventos de pedido novo sao classificados como placed', () {
      expect(IfoodEventUtils.isPlacedEvent('PLC'), isTrue);
      expect(IfoodEventUtils.isPlacedEvent('placed'), isTrue);

      for (final event in ['ADR', 'GTO', 'DPCR', 'AAO', 'CLT', 'AAD', 'DDCS']) {
        expect(
          IfoodEventUtils.isPlacedEvent(event),
          isFalse,
          reason: '$event nunca pode acionar aceite/criacao de venda',
        );
      }
    });

    test('eventos logisticos curtos preservam a progressao do pedido', () {
      for (final event in ['ADR', 'GTO', 'DPCR', 'AAO']) {
        expect(IfoodEventUtils.isWaitingDriverEvent(event), isTrue);
      }

      for (final event in ['CLT', 'AAD', 'DDCS']) {
        expect(IfoodEventUtils.isInRouteEvent(event), isTrue);
      }
    });

    test('eventos finais sao reconhecidos', () {
      for (final event in ['CON', 'CONCLUDED', 'CAN', 'CANCELLED']) {
        expect(IfoodEventUtils.isFinishedEvent(event), isTrue);
      }
    });
  });
}
