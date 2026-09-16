import '../repositories/darcapio_repository.dart' show darcapioField;

enum CourierAccessState {
  notConnected,
  invitePending,
  connected,
  expired,
  revoked
}

class CourierAccess {
  final int code, activeOrders;
  final String name;
  final CourierAccessState state;
  final bool sharingLocation;
  const CourierAccess(
      {required this.code,
      required this.name,
      required this.state,
      this.activeOrders = 0,
      this.sharingLocation = false});
  factory CourierAccess.fromJson(dynamic value) => CourierAccess(
      code: (darcapioField(value, 'code') as num).toInt(),
      name: darcapioField(value, 'name') as String,
      state: switch (darcapioField(value, 'state')) {
        'Connected' => CourierAccessState.connected,
        'InvitePending' => CourierAccessState.invitePending,
        'Expired' => CourierAccessState.expired,
        'Revoked' => CourierAccessState.revoked,
        _ => CourierAccessState.notConnected,
      },
      activeOrders:
          (darcapioField(value, 'activeOrders') as num?)?.toInt() ?? 0,
      sharingLocation: darcapioField(value, 'sharingLocation') == true);
  String get statusLabel => switch (state) {
        CourierAccessState.connected => 'Celular conectado',
        CourierAccessState.invitePending => 'Aguardando conexão',
        CourierAccessState.expired => 'Acesso expirado',
        CourierAccessState.revoked => 'Acesso encerrado',
        CourierAccessState.notConnected => 'Sem celular conectado',
      };
  bool get hasAccess =>
      state == CourierAccessState.connected ||
      state == CourierAccessState.invitePending;
}

class CourierManagement {
  final String storeName;
  final String? storeUrl;
  final List<CourierAccess> couriers;
  const CourierManagement(
      {required this.storeName, this.storeUrl, required this.couriers});
  factory CourierManagement.fromJson(dynamic value) => CourierManagement(
      storeName: darcapioField(value, 'storeName') as String,
      storeUrl: darcapioField(value, 'storeUrl') as String?,
      couriers: (darcapioField(value, 'couriers') as List)
          .map(CourierAccess.fromJson)
          .toList());
}

class CourierInvite {
  final String code, storeUrl;
  final DateTime expiresAt;
  const CourierInvite(
      {required this.code, required this.storeUrl, required this.expiresAt});
  factory CourierInvite.fromJson(dynamic value) {
    final invite = darcapioField(value, 'invite');
    return CourierInvite(
        code: darcapioField(invite, 'code') as String,
        storeUrl: darcapioField(value, 'storeUrl') as String,
        expiresAt: DateTime.parse(darcapioField(invite, 'expiresAt') as String)
            .toLocal());
  }
  bool get expired => !expiresAt.isAfter(DateTime.now());
}
