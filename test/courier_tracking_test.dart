import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/models/courier_tracking.dart';

void main() {
  test('rastreio aceita casing da API e marca GPS antigo', () {
    final data = CourierTracking.fromJson({
      'Active': true,
      'Stale': false,
      'Name': 'Entregador',
      'Position': {
        'Latitude': -6.1,
        'Longitude': -49.8,
        'RecordedAt': DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 2))
            .toIso8601String()
      }
    });
    expect(data.active, true);
    expect(data.position?.latitude, -6.1);
    expect(data.isStale, true);
  });
  test('coordenadas inválidas nunca viram marcador no mapa', () {
    final data = CourierTracking.fromJson({
      'active': true,
      'stale': false,
      'position': {'latitude': 999, 'longitude': -49}
    });
    expect(data.position, isNull);
    expect(data.isStale, true);
  });
  test('entrega encerrada ou GPS de mais de uma hora não exibe marcador', () {
    final now = DateTime.now().toUtc();
    CourierTracking location(bool active, DateTime time) =>
        CourierTracking.fromJson({
          'active': active,
          'stale': false,
          'position': {
            'latitude': -6.1,
            'longitude': -49.8,
            'recordedAt': time.toIso8601String()
          }
        });
    expect(location(true, now).hasVisiblePosition, true);
    expect(location(false, now).hasVisiblePosition, false);
    expect(
        location(true, now.subtract(const Duration(minutes: 61)))
            .hasVisiblePosition,
        false);
    final old = location(true, now.subtract(const Duration(minutes: 2)));
    expect(old.hasVisiblePosition, true);
    expect(old.isStale, true);
  });
}
