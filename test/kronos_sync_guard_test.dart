import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/service/kronos_sync_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    KronosSyncGuard.resetInMemoryForTesting();
  });

  test('bloqueia duas criacoes concorrentes do mesmo pedido', () async {
    expect(await KronosSyncGuard.tryStart('create', 'pedido-1'), isTrue);
    expect(await KronosSyncGuard.tryStart('create', 'pedido-1'), isFalse);

    KronosSyncGuard.release('create', 'pedido-1');
    expect(await KronosSyncGuard.tryStart('create', 'pedido-1'), isTrue);
  });

  test('preserva operacao concluida depois de reiniciar o app', () async {
    expect(await KronosSyncGuard.tryStart('finalize', 'pedido-2'), isTrue);
    await KronosSyncGuard.markSucceeded('finalize', 'pedido-2');

    KronosSyncGuard.resetInMemoryForTesting();
    expect(await KronosSyncGuard.wasCompleted('finalize', 'pedido-2'), isTrue);
    expect(await KronosSyncGuard.tryStart('finalize', 'pedido-2'), isFalse);
  });
}
