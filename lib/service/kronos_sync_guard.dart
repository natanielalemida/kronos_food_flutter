import 'package:shared_preferences/shared_preferences.dart';

/// Impede que uma operacao ja confirmada pelo Kronos seja enviada novamente.
///
/// O conjunto em memoria cobre chamadas concorrentes e o SharedPreferences
/// preserva a idempotencia entre reinicializacoes do aplicativo.
class KronosSyncGuard {
  static const String _keyPrefix = 'kronos_sync_completed_v1';
  static final Set<String> _inFlight = <String>{};

  static String _key(String operation, String orderId) =>
      '${_keyPrefix}_${operation.trim().toLowerCase()}_${orderId.trim().toLowerCase()}';

  static Future<bool> tryStart(String operation, String orderId) async {
    final key = _key(operation, orderId);
    if (orderId.trim().isEmpty || !_inFlight.add(key)) return false;

    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.containsKey(key)) {
        _inFlight.remove(key);
        return false;
      }
      return true;
    } catch (_) {
      _inFlight.remove(key);
      rethrow;
    }
  }

  static Future<void> markSucceeded(String operation, String orderId) async {
    final key = _key(operation, orderId);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(key, DateTime.now().millisecondsSinceEpoch);
    } finally {
      _inFlight.remove(key);
    }
  }

  static void release(String operation, String orderId) {
    _inFlight.remove(_key(operation, orderId));
  }

  static Future<bool> wasCompleted(String operation, String orderId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.containsKey(_key(operation, orderId));
  }

  static void resetInMemoryForTesting() => _inFlight.clear();
}
