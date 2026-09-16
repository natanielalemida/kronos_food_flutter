import 'package:flutter/material.dart';
import 'food_order_progress.dart';
import 'darcapio/order_style.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/models/event_model.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/utils/ifood_event_utils.dart';

class OrderTimeline extends StatelessWidget {
  final PedidoModel order;

  const OrderTimeline({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final states = _getTimelineStates();
    return FoodOrderProgress(
      progress: _calculateProgress(),
      cancelled: states.any((state) => state.title == 'Pedido Cancelado'),
      steps: states
          .map((state) => FoodOrderProgressStep(
                label: state.title,
                icon: state.icon,
                color: state.color,
                time: state.time,
              ))
          .toList(),
    );
  }

  double _calculateProgress() {
    final status = IfoodEventUtils.normalize(order.status);
    if (IfoodEventUtils.isWaitingDriverEvent(status)) return 0.70;
    if (IfoodEventUtils.isInRouteEvent(status)) return 0.85;

    switch (status) {
      case Consts.statusPlaced:
        return 0.25;
      case Consts.statusConfirmed:
        return 0.45;
      case Consts.statusReadyToPickup:
        return 0.65;
      case Consts.statusDispatched:
        return 0.80;
      case Consts.statusConcluded:
        return 1.0;
      case Consts.statusCancelled:
        return 0.0;
      default:
        return _progressFromEvents();
    }
  }

  double _progressFromEvents() {
    if (_firstEventMatching((code) => code == Consts.statusConcluded) != null) {
      return 1.0;
    }
    if (_firstEventMatching(IfoodEventUtils.isInRouteEvent) != null) {
      return 0.85;
    }
    if (_firstEventMatching((code) =>
            IfoodEventUtils.isReadyEvent(code) ||
            IfoodEventUtils.isWaitingDriverEvent(code)) !=
        null) {
      return 0.70;
    }
    if (_firstEventMatching(_isConfirmationEvent) != null) {
      return 0.45;
    }
    return 0.25;
  }

  List<_TimelineState> _getTimelineStates() {
    final status = IfoodEventUtils.normalize(order.status);

    final confirmedEvent = _firstEventMatching(_isConfirmationEvent);
    final readyEvent = _firstEventMatching((code) =>
        IfoodEventUtils.isReadyEvent(code) ||
        IfoodEventUtils.isWaitingDriverEvent(code));
    final dispatchedEvent = _firstEventMatching(IfoodEventUtils.isInRouteEvent);
    final concludedEvent = _firstEventMatching((code) =>
        code == Consts.statusConcluded ||
        code == 'CONCLUDED' ||
        code.contains('COMPLETE'));
    final cancelledEvent = _firstEventMatching((code) =>
        code == Consts.statusCancelled ||
        code == 'CANCELLED' ||
        code.contains('CANCEL'));
    final disputeEvent = _firstEventMatching(
      (code) => code == Consts.statusDispute || code.contains('DISPUTE'),
    );

    final isConfirmed = confirmedEvent != null ||
        _isStatusAtOrAfterConfirmed(status) ||
        readyEvent != null ||
        dispatchedEvent != null ||
        concludedEvent != null;
    final isReady = readyEvent != null ||
        _isStatusReadyOrLater(status) ||
        dispatchedEvent != null ||
        concludedEvent != null;
    final isDispatched = dispatchedEvent != null ||
        _isStatusDispatchedOrLater(status) ||
        concludedEvent != null;

    final states = <_TimelineState>[
      _TimelineState(
        title: 'Pedido Recebido',
        time: order.createdAt,
        icon: Icons.receipt,
        color: OrderStyle.statusColor('recebido_erp'),
      ),
    ];

    if (isConfirmed) {
      states.add(
        _TimelineState(
          title: 'Pedido Confirmado',
          time: confirmedEvent?.createdAt,
          icon: Icons.check_circle,
          color: OrderStyle.statusColor('aceito'),
        ),
      );
    }

    if (isReady) {
      states.add(
        _TimelineState(
          title: IfoodEventUtils.readyLabel(
            order.delivery.deliveredBy,
            order.orderType,
          ),
          time: readyEvent?.createdAt,
          icon: Icons.shopping_bag_outlined,
          color: OrderStyle.statusColor('pronto_entrega'),
        ),
      );
    }

    if (isDispatched) {
      states.add(
        _TimelineState(
          title: IfoodEventUtils.isIfoodDelivery(order.delivery.deliveredBy)
              ? 'Pedido saiu com iFood'
              : 'Pedido Despachado',
          time: dispatchedEvent?.createdAt,
          icon: Icons.delivery_dining,
          color: OrderStyle.statusColor('saiu_para_entrega'),
        ),
      );
    }

    if (disputeEvent != null || status == Consts.statusDispute) {
      states.add(
        _TimelineState(
          title: 'Pedido em Disputa',
          time: disputeEvent?.createdAt,
          icon: Icons.bookmark_remove,
          color: Colors.amber.shade700,
        ),
      );
    }

    if (cancelledEvent != null || status == Consts.statusCancelled) {
      states.add(
        _TimelineState(
          title: 'Pedido Cancelado',
          time: cancelledEvent?.createdAt,
          icon: Icons.cancel_outlined,
          color: OrderStyle.statusColor('cancelado'),
        ),
      );
    } else if (concludedEvent != null || status == Consts.statusConcluded) {
      states.add(
        _TimelineState(
          title: 'Pedido Concluído',
          time: concludedEvent?.createdAt,
          icon: Icons.check_circle_outline,
          color: OrderStyle.statusColor('concluido'),
        ),
      );
    }

    return states;
  }

  EventModel? _firstEventMatching(bool Function(String code) matches) {
    final events = order.events.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final event in events) {
      final code = IfoodEventUtils.normalize(
        event.code.isNotEmpty ? event.code : event.fullCode,
      );
      if (matches(code)) {
        return event;
      }
    }

    return null;
  }

  bool _isConfirmationEvent(String code) =>
      code == Consts.statusConfirmed ||
      code == 'CONFIRMED' ||
      code == 'STP' ||
      code == 'PREPARATION_STARTED' ||
      code == 'SEPARATION_STARTED';

  bool _isStatusAtOrAfterConfirmed(String status) =>
      status == Consts.statusConfirmed ||
      _isStatusReadyOrLater(status) ||
      IfoodEventUtils.isWaitingDriverEvent(status) ||
      IfoodEventUtils.isReadyEvent(status);

  bool _isStatusReadyOrLater(String status) =>
      status == Consts.statusReadyToPickup ||
      _isStatusDispatchedOrLater(status) ||
      IfoodEventUtils.isReadyEvent(status) ||
      IfoodEventUtils.isWaitingDriverEvent(status);

  bool _isStatusDispatchedOrLater(String status) =>
      status == Consts.statusDispatched ||
      status == Consts.statusConcluded ||
      IfoodEventUtils.isInRouteEvent(status);
}

class _TimelineState {
  final String title;
  final DateTime? time;
  final IconData icon;
  final Color color;

  const _TimelineState({
    required this.title,
    required this.time,
    required this.icon,
    required this.color,
  });
}
