import 'package:flutter/material.dart';
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
    final timelineStates = _getTimelineStates();
    final itemCount =
        timelineStates.length > 1 ? timelineStates.length * 2 - 1 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'Status do Pedido',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 106,
                child: Row(
                  children: List.generate(itemCount, (index) {
                    if (index % 2 == 0) {
                      final state = timelineStates[index ~/ 2];
                      final time = state.time;

                      return Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: state.color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: state.color.withValues(alpha: 0.30),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Icon(
                                state.icon,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Flexible(
                              child: Text(
                                state.title,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: state.color,
                                ),
                              ),
                            ),
                            if (time != null)
                              Text(
                                _formatTime(time),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: state.color,
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    final lineIndex = index ~/ 2;
                    final color = timelineStates[lineIndex].color;

                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 44),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedProgressIndicator(value: _calculateProgress()),
            ],
          ),
        ),
      ],
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
        color: Colors.orange,
      ),
    ];

    if (isConfirmed) {
      states.add(
        _TimelineState(
          title: 'Pedido Confirmado',
          time: confirmedEvent?.createdAt,
          icon: Icons.check_circle,
          color: Colors.blue,
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
          color: Colors.teal,
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
          color: Colors.purple,
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
          color: Colors.redAccent,
        ),
      );
    } else if (concludedEvent != null || status == Consts.statusConcluded) {
      states.add(
        _TimelineState(
          title: 'Pedido Concluido',
          time: concludedEvent?.createdAt,
          icon: Icons.check_circle_outline,
          color: Colors.green,
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

  String _formatTime(DateTime dateTime) {
    dateTime = dateTime.toLocal();
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }
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

class AnimatedProgressIndicator extends StatelessWidget {
  final double value;

  const AnimatedProgressIndicator({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                height: 8,
                width: constraints.maxWidth * value,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Consts.primaryColor.withValues(alpha: .1),
                      Consts.primaryColor
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
