import '../consts.dart';
import '../repositories/darcapio_repository.dart';
import 'pedido_model.dart';

enum FoodOrderSource {
  ifood('iFood'),
  darcapio('Darcapio');

  const FoodOrderSource(this.label);
  final String label;
}

/// Presentation only: each channel keeps its own payload and action contract.
class FoodOrderEntry {
  final PedidoModel? ifoodOrder;
  final DarcapioOrder? darcapioOrder;

  const FoodOrderEntry.ifood(PedidoModel order)
      : ifoodOrder = order,
        darcapioOrder = null;
  const FoodOrderEntry.darcapio(DarcapioOrder order)
      : darcapioOrder = order,
        ifoodOrder = null;

  FoodOrderSource get source =>
      ifoodOrder != null ? FoodOrderSource.ifood : FoodOrderSource.darcapio;
  String get id => ifoodOrder?.id ?? darcapioOrder!.id;
  String get key => '${source.name}-order-$id';
  String get displayId =>
      ifoodOrder?.displayId ??
      darcapioOrder!.delivery.toString().padLeft(4, '0');
  String get customer => ifoodOrder?.customer.name ?? darcapioOrder!.customer;
  int? get customerOrdersCount => ifoodOrder != null
      ? ifoodOrder!.customer.ordersCountOnMerchant
      : darcapioOrder!.customerOrdersCount;
  double get total => ifoodOrder?.total.orderAmount ?? darcapioOrder!.total;
  DateTime get created => ifoodOrder?.createdAt ?? darcapioOrder!.created;
  bool get pickup => ifoodOrder != null
      ? ifoodOrder!.orderType == 'TAKEOUT'
      : darcapioOrder!.pickup;

  String get status {
    if (darcapioOrder != null) return darcapioOrder!.status;
    final order = ifoodOrder!;
    if (order.orderTiming == 'SCHEDULED' &&
        order.status == Consts.statusPlaced) {
      return 'agendado';
    }
    return switch (order.status) {
      Consts.statusPlaced => 'recebido_erp',
      Consts.statusConfirmed => 'em_preparo',
      Consts.statusReadyToPickup =>
        pickup ? 'pronto_retirada' : 'pronto_entrega',
      Consts.statusDispatched => 'saiu_para_entrega',
      Consts.statusConcluded => 'concluido',
      Consts.statusCancelled => 'cancelado',
      Consts.statusDispute => 'atencao',
      _ => order.status,
    };
  }

  String get statusLabel =>
      darcapioOrder?.label ??
      switch (status) {
        'recebido_erp' => 'Aguardando aceite',
        'em_preparo' => 'Em preparo',
        'pronto_retirada' => 'Pronto para retirada',
        'pronto_entrega' => 'Pronto para entrega',
        'saiu_para_entrega' => 'Saiu para entrega',
        'concluido' => 'Concluído',
        'cancelado' => 'Cancelado',
        'agendado' => 'Agendado',
        'atencao' => 'Precisa de atenção',
        _ => status,
      };

  static List<FoodOrderEntry> combine(
      Iterable<PedidoModel> ifood, Iterable<DarcapioOrder> darcapio) {
    final entries = <String, FoodOrderEntry>{};
    for (final entry in [
      ...ifood.map(FoodOrderEntry.ifood),
      ...darcapio.map(FoodOrderEntry.darcapio),
    ]) {
      entries[entry.key] = entry;
    }
    return entries.values.toList()
      ..sort((a, b) {
        final byDate = b.created.compareTo(a.created);
        return byDate != 0 ? byDate : a.key.compareTo(b.key);
      });
  }
}
