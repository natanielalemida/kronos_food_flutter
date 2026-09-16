import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/courier_management.dart';
import '../repositories/darcapio_repository.dart';

class CouriersController extends ChangeNotifier {
  final DarcapioRepository repository;
  CourierManagement? data;
  CourierInvite? invite;
  CourierAccess? invitedCourier;
  String? error, notice;
  bool loading = true, busy = false, _disposed = false;
  Future<void>? _pendingLoad;
  Timer? _refresh, _expiry;
  CouriersController(this.repository);

  void start() {
    unawaited(reload());
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!busy) unawaited(reload());
    });
  }

  void changed() {
    if (!_disposed) notifyListeners();
  }

  String message(Object failure) {
    if (failure is DioException) {
      final status = failure.response?.statusCode;
      if ([400, 401, 403, 409, 429, 503].contains(status)) {
        final detail = darcapioField(failure.response?.data, 'mensagem');
        if (detail is String && detail.isNotEmpty) return detail;
      }
      if (status == 404) {
        return 'Atualize o Kronos Service e a integração da loja para usar a gestão de entregadores.';
      }
      return 'Não foi possível confirmar a operação. Atualize a lista antes de tentar novamente.';
    }
    return 'Não foi possível carregar os entregadores. Confira a conexão com o servidor.';
  }

  Future<void> reload() {
    if (_disposed) return Future.value();
    return _pendingLoad ??= _reload().whenComplete(() => _pendingLoad = null);
  }

  Future<void> _reload() async {
    try {
      final result = await repository.courierManagement();
      if (_disposed) return;
      data = result;
      error = null;
      final current = result.couriers
          .where((c) => c.code == invitedCourier?.code)
          .firstOrNull;
      if (invite != null &&
          current?.state != CourierAccessState.invitePending) {
        invite = null;
        invitedCourier = null;
        _expiry?.cancel();
      }
    } catch (e) {
      error = message(e);
      if (e is DioException && [401, 403].contains(e.response?.statusCode)) {
        data = null;
        invite = null;
        invitedCourier = null;
      }
    } finally {
      loading = false;
      changed();
    }
  }

  Future<void> generate(CourierAccess courier) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notice = null;
    invite = null;
    _expiry?.cancel();
    changed();
    try {
      if (_pendingLoad != null) await _pendingLoad;
      if (_disposed) return;
      final result = await repository.inviteCourier(courier.code);
      if (_disposed) return;
      invite = result;
      invitedCourier = courier;
      final remaining = result.expiresAt.difference(DateTime.now());
      _expiry =
          Timer(remaining.isNegative ? Duration.zero : remaining, changed);
      await reload();
    } catch (e) {
      error = message(e);
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> revoke(CourierAccess courier) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notice = null;
    changed();
    try {
      if (_pendingLoad != null) await _pendingLoad;
      if (_disposed) return;
      await repository.revokeCourier(courier.code);
      if (_disposed) return;
      if (invitedCourier?.code == courier.code) {
        invite = null;
        invitedCourier = null;
        _expiry?.cancel();
      }
      notice = 'Acesso de ${courier.name} encerrado.';
      await reload();
    } catch (e) {
      error = message(e);
    } finally {
      busy = false;
      changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refresh?.cancel();
    _expiry?.cancel();
    super.dispose();
  }
}
