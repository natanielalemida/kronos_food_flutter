import 'dart:convert';

import 'package:kronos_food/models/pedido_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KronosPendingSyncService {
  static const String _keyPrefix = 'kronos_pending_sync_v1';

  String _key(String operation) =>
      '${_keyPrefix}_${operation.trim().toLowerCase()}';

  Future<void> enqueue(String operation, PedidoModel pedido) async {
    final preferences = await SharedPreferences.getInstance();
    final pending = _read(preferences.getString(_key(operation)));
    pending[pedido.id] = pedido.toJson();
    await preferences.setString(_key(operation), jsonEncode(pending));
  }

  Future<void> remove(String operation, String orderId) async {
    final preferences = await SharedPreferences.getInstance();
    final pending = _read(preferences.getString(_key(operation)));
    if (pending.remove(orderId) == null) return;

    if (pending.isEmpty) {
      await preferences.remove(_key(operation));
    } else {
      await preferences.setString(_key(operation), jsonEncode(pending));
    }
  }

  Future<List<PedidoModel>> getPending(String operation) async {
    final preferences = await SharedPreferences.getInstance();
    final pending = _read(preferences.getString(_key(operation)));
    final pedidos = <PedidoModel>[];

    for (final entry in pending.entries) {
      try {
        pedidos.add(
          PedidoModel.fromKronos(
            Map<String, dynamic>.from(jsonDecode(entry.value) as Map),
          ),
        );
      } catch (_) {
        // Uma entrada local corrompida nao pode impedir as demais tentativas.
      }
    }
    return pedidos;
  }

  Map<String, String> _read(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map<String, String>((key, value) {
        return MapEntry(key.toString(), value.toString());
      });
    } catch (_) {
      return {};
    }
  }
}
