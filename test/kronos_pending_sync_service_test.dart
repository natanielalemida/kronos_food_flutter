import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/service/kronos_pending_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('mantem pedido pendente ate a confirmacao da sincronizacao', () async {
    final service = KronosPendingSyncService();
    final pedido = PedidoModel.fromJson({
      'id': 'pedido-pendente',
      'displayId': '1234',
      'status': 'CFM',
    });

    await service.enqueue('create', pedido);
    final pending = await service.getPending('create');

    expect(pending, hasLength(1));
    expect(pending.single.id, pedido.id);
    expect(pending.single.status, pedido.status);

    await service.remove('create', pedido.id);
    expect(await service.getPending('create'), isEmpty);
  });
}
