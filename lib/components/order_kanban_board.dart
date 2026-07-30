import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/controllers/pedidos_controller.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/utils/ifood_event_utils.dart';

enum KanbanOrderAction {
  details,
  accept,
  openWorkflow,
}

class OrderKanbanBoard extends StatefulWidget {
  final ValueNotifier<OrderTimming> orderTimming;
  final Map<String, List<PedidoModel>> pedidosMap;
  final void Function(PedidoModel order, String statusCode) onOrderSelected;
  final void Function(
    PedidoModel order,
    String statusCode,
    KanbanOrderAction action,
  ) onOrderAction;
  final VoidCallback onTabChanged;
  final String? selectedOrderId;

  const OrderKanbanBoard({
    super.key,
    required this.orderTimming,
    required this.pedidosMap,
    required this.onOrderSelected,
    required this.onOrderAction,
    required this.onTabChanged,
    this.selectedOrderId,
  });

  @override
  State<OrderKanbanBoard> createState() => _OrderKanbanBoardState();
}

class _OrderKanbanBoardState extends State<OrderKanbanBoard> {
  static const Set<String> _knownStatusCodes = {
    Consts.statusPlaced,
    Consts.statusDispute,
    Consts.statusConfirmed,
    Consts.statusReadyToPickup,
    Consts.statusDispatched,
    Consts.statusConcluded,
    Consts.statusCancelled,
  };

  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      child: ListenableBuilder(
        listenable: widget.orderTimming,
        builder: (context, child) {
          final scheduledOrders = _scheduledOrders();
          final totalScheduled = scheduledOrders.length;
          final totalImmediate = widget.pedidosMap.values.fold<int>(
            0,
            (sum, orders) => sum + orders.where(_isImmediateOrder).length,
          );

          final columns = widget.orderTimming.value == OrderTimming.scheduled
              ? [
                  _KanbanColumnConfig(
                    title: 'Agendados',
                    statusCode: 'SCHEDULED',
                    icon: Icons.event_available,
                    color: Colors.blueGrey,
                    orders: scheduledOrders,
                  ),
                ]
              : _immediateColumns();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Spacer(),
                    SizedBox(
                      width: 320,
                      child: Row(
                        children: [
                          Expanded(
                            child: _FilterButton(
                              label: 'Agora',
                              count: totalImmediate,
                              isActive: widget.orderTimming.value ==
                                  OrderTimming.immediate,
                              onTap: () {
                                if (widget.orderTimming.value !=
                                    OrderTimming.immediate) {
                                  widget.onTabChanged();
                                  widget.orderTimming.value =
                                      OrderTimming.immediate;
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _FilterButton(
                              label: 'Agendados',
                              count: totalScheduled,
                              isActive: widget.orderTimming.value ==
                                  OrderTimming.scheduled,
                              onTap: () {
                                if (widget.orderTimming.value !=
                                    OrderTimming.scheduled) {
                                  widget.onTabChanged();
                                  widget.orderTimming.value =
                                      OrderTimming.scheduled;
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final column in columns) ...[
                          _KanbanColumn(
                            config: column,
                            selectedOrderId: widget.selectedOrderId,
                            onOrderSelected: widget.onOrderSelected,
                            onOrderAction: widget.onOrderAction,
                          ),
                          const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_KanbanColumnConfig> _immediateColumns() {
    final pendingOrders = _ordersForStatus(Consts.statusPlaced);
    final disputeOrders = _ordersForStatus(Consts.statusDispute);

    return [
      if (pendingOrders.isNotEmpty)
        _KanbanColumnConfig(
          title: 'Pendentes',
          statusCode: Consts.statusPlaced,
          icon: Icons.access_time,
          color: Colors.orange,
          orders: pendingOrders,
        ),
      if (disputeOrders.isNotEmpty)
        _KanbanColumnConfig(
          title: 'Disputas',
          statusCode: Consts.statusDispute,
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFD6A21C),
          orders: disputeOrders,
        ),
      _KanbanColumnConfig(
        title: 'Confirmados',
        statusCode: Consts.statusConfirmed,
        icon: Icons.check_circle_outline,
        color: Colors.blue,
        orders: _ordersForStatus(Consts.statusConfirmed),
      ),
      _KanbanColumnConfig(
        title: 'Prontos',
        statusCode: Consts.statusReadyToPickup,
        icon: Icons.shopping_bag_outlined,
        color: Colors.teal,
        orders: _ordersForStatus(Consts.statusReadyToPickup),
      ),
      _KanbanColumnConfig(
        title: 'Despachados',
        statusCode: Consts.statusDispatched,
        icon: Icons.local_shipping,
        color: Colors.purple,
        orders: _ordersForStatus(Consts.statusDispatched),
      ),
      _KanbanColumnConfig(
        title: 'Concluidos',
        statusCode: Consts.statusConcluded,
        icon: Icons.done_all,
        color: Colors.green,
        orders: _ordersForStatus(Consts.statusConcluded),
      ),
      _KanbanColumnConfig(
        title: 'Cancelados',
        statusCode: Consts.statusCancelled,
        icon: Icons.cancel,
        color: Colors.red,
        orders: _ordersForStatus(Consts.statusCancelled),
      ),
      if (_unknownImmediateOrders().isNotEmpty)
        _KanbanColumnConfig(
          title: 'Outros status',
          statusCode: 'UNKNOWN',
          icon: Icons.help_outline,
          color: Colors.blueGrey,
          orders: _unknownImmediateOrders(),
        ),
    ];
  }

  List<PedidoModel> _ordersForStatus(String statusCode) {
    return (widget.pedidosMap[statusCode] ?? [])
        .where(_isImmediateOrder)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<PedidoModel> _scheduledOrders() {
    return widget.pedidosMap.values
        .expand((orders) => orders)
        .where(_isScheduledPending)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<PedidoModel> _unknownImmediateOrders() {
    return widget.pedidosMap.entries
        .where((entry) => !_knownStatusCodes.contains(entry.key))
        .expand((entry) => entry.value)
        .where(_isImmediateOrder)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  bool _isScheduledPending(PedidoModel order) {
    return order.orderTiming == 'SCHEDULED' &&
        order.status == Consts.statusPlaced;
  }

  bool _isImmediateOrder(PedidoModel order) {
    return !_isScheduledPending(order);
  }
}

class _KanbanColumnConfig {
  final String title;
  final String statusCode;
  final IconData icon;
  final Color color;
  final List<PedidoModel> orders;

  const _KanbanColumnConfig({
    required this.title,
    required this.statusCode,
    required this.icon,
    required this.color,
    required this.orders,
  });
}

class _KanbanColumn extends StatelessWidget {
  final _KanbanColumnConfig config;
  final String? selectedOrderId;
  final void Function(PedidoModel order, String statusCode) onOrderSelected;
  final void Function(
    PedidoModel order,
    String statusCode,
    KanbanOrderAction action,
  ) onOrderAction;

  const _KanbanColumn({
    required this.config,
    required this.selectedOrderId,
    required this.onOrderSelected,
    required this.onOrderAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.09),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(config.icon, color: config.color, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    config.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: config.color,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: config.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${config.orders.length}',
                    style: TextStyle(
                      color: config.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: config.orders.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Sem pedidos nessa coluna',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: config.orders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final order = config.orders[index];
                      return _KanbanOrderCard(
                        order: order,
                        statusCode: config.statusCode,
                        color: config.color,
                        isSelected: order.id == selectedOrderId,
                        onTap: () => onOrderSelected(
                          order,
                          config.statusCode,
                        ),
                        onAction: (action) => onOrderAction(
                          order,
                          config.statusCode,
                          action,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KanbanOrderCard extends StatelessWidget {
  final PedidoModel order;
  final String statusCode;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(KanbanOrderAction action) onAction;

  const _KanbanOrderCard({
    required this.order,
    required this.statusCode,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(8),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(isSelected ? 14 : 12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _orderTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? color : Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            'R\$ ${order.total.orderAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _customerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(_subtitleIcon, size: 13, color: color),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 13,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${order.items.length} ${order.items.length == 1 ? 'item' : 'itens'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        _ChannelBadge(brand: _channelBrand),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    _CardActions(
                      actions: _actions,
                      onAction: onAction,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _orderTitle {
    if (order.orderType == 'TAKEOUT') {
      return '#${order.displayId} - RETIRADA';
    }
    return '#${order.displayId}';
  }

  _ChannelBrand get _channelBrand {
    final channel = order.salesChannel.trim();
    final normalized = IfoodEventUtils.normalize(channel);
    final deliveredBy = IfoodEventUtils.normalize(order.delivery.deliveredBy);

    if (normalized.contains('IFOOD') || deliveredBy == 'IFOOD') {
      return const _ChannelBrand(
        label: 'iFood',
        backgroundColor: Color(0xFFEA1D2C),
        foregroundColor: Colors.white,
      );
    }

    if (normalized.contains('99')) {
      return const _ChannelBrand(
        label: '99',
        backgroundColor: Color(0xFFFFC400),
        foregroundColor: Color(0xFF111827),
      );
    }

    if (normalized.contains('TOTEM')) {
      return const _ChannelBrand(
        label: 'Totem',
        icon: Icons.storefront,
        backgroundColor: Color(0xFFE0F2F1),
        foregroundColor: Color(0xFF00796B),
      );
    }

    if (channel.isEmpty) {
      return _ChannelBrand(
        label: order.orderType.isEmpty ? 'Canal' : order.orderType,
        icon: Icons.point_of_sale,
        backgroundColor: const Color(0xFFF3F4F6),
        foregroundColor: const Color(0xFF4B5563),
      );
    }

    return _ChannelBrand(
      label: channel.toUpperCase(),
      icon: Icons.store_mall_directory_outlined,
      backgroundColor: const Color(0xFFF3F4F6),
      foregroundColor: const Color(0xFF4B5563),
    );
  }

  String get _customerTitle {
    final name = order.customer.name.trim();
    if (name.isEmpty) return 'CLIENTE NAO INFORMADO';
    final normalizedName = IfoodEventUtils.normalize(name);
    if (order.isTest || normalizedName.startsWith('PEDIDO DE TESTE')) {
      final localizer = order.customer.phone.localizer.trim();
      if (localizer.isNotEmpty) return 'PEDIDO TESTE - LOC. $localizer';
      return 'PEDIDO TESTE #${order.displayId}';
    }
    return name.toUpperCase();
  }

  List<_KanbanActionConfig> get _actions {
    switch (statusCode) {
      case Consts.statusDispute:
        return const [
          _KanbanActionConfig(
            label: 'DETALHES',
            action: KanbanOrderAction.details,
            color: Colors.blue,
          ),
          _KanbanActionConfig(
            label: 'RESPONDER',
            action: KanbanOrderAction.openWorkflow,
            color: Colors.teal,
          ),
        ];
      case Consts.statusPlaced:
      case 'SCHEDULED':
        return const [
          _KanbanActionConfig(
            label: 'RECUSAR',
            action: KanbanOrderAction.openWorkflow,
            color: Colors.red,
          ),
          _KanbanActionConfig(
            label: 'ACEITAR',
            action: KanbanOrderAction.accept,
            color: Colors.teal,
          ),
        ];
      case Consts.statusConfirmed:
        return [
          const _KanbanActionConfig(
            label: 'CANCELAR',
            action: KanbanOrderAction.openWorkflow,
            color: Colors.red,
          ),
          _KanbanActionConfig(
            label: _isMerchantDelivery ? 'DESPACHAR' : 'PRONTO',
            action: KanbanOrderAction.openWorkflow,
            color: _isMerchantDelivery ? Colors.orange : Colors.teal,
          ),
        ];
      case Consts.statusReadyToPickup:
        if (_isOrderWithoutDelivery) {
          return const [
            _KanbanActionConfig(
              label: 'DETALHES',
              action: KanbanOrderAction.details,
              color: Colors.blue,
            ),
            _KanbanActionConfig(
              label: 'CONCLUIR',
              action: KanbanOrderAction.openWorkflow,
              color: Colors.green,
            ),
          ];
        }

        if (_isMerchantDelivery) {
          return const [
            _KanbanActionConfig(
              label: 'DETALHES',
              action: KanbanOrderAction.details,
              color: Colors.blue,
            ),
            _KanbanActionConfig(
              label: 'DESPACHAR',
              action: KanbanOrderAction.openWorkflow,
              color: Colors.orange,
            ),
          ];
        }

        return const [
          _KanbanActionConfig(
            label: 'DETALHES',
            action: KanbanOrderAction.details,
            color: Colors.blue,
          ),
        ];
      case Consts.statusDispatched:
        return const [
          _KanbanActionConfig(
            label: 'DETALHES',
            action: KanbanOrderAction.details,
            color: Colors.blue,
          ),
        ];
      default:
        return const [
          _KanbanActionConfig(
            label: 'DETALHES',
            action: KanbanOrderAction.details,
            color: Colors.blue,
          ),
        ];
    }
  }

  bool get _isMerchantDelivery =>
      IfoodEventUtils.isMerchantDelivery(order.delivery.deliveredBy);

  bool get _isOrderWithoutDelivery {
    if (IfoodEventUtils.isIfoodDelivery(order.delivery.deliveredBy) ||
        IfoodEventUtils.isMerchantDelivery(order.delivery.deliveredBy)) {
      return false;
    }

    final salesChannel = IfoodEventUtils.normalize(order.salesChannel);
    final orderType = IfoodEventUtils.normalize(order.orderType);
    final address = order.delivery.deliveryAddress;
    final hasAddress = address.streetName.trim().isNotEmpty ||
        address.streetNumber.trim().isNotEmpty ||
        address.neighborhood.trim().isNotEmpty ||
        address.city.trim().isNotEmpty ||
        address.postalCode.trim().isNotEmpty;

    return salesChannel.contains('TOTEM') ||
        orderType.contains('TAKEOUT') ||
        !hasAddress;
  }

  IconData get _subtitleIcon {
    switch (statusCode) {
      case Consts.statusConfirmed:
        return Icons.check_circle;
      case Consts.statusReadyToPickup:
        return Icons.shopping_bag_outlined;
      case Consts.statusDispatched:
        return Icons.delivery_dining;
      case Consts.statusConcluded:
        return Icons.done_all;
      case Consts.statusCancelled:
        return Icons.cancel;
      case Consts.statusDispute:
        return Icons.warning_amber_rounded;
      case 'SCHEDULED':
        return Icons.event_available;
      default:
        return Icons.access_time;
    }
  }

  String get _subtitle {
    switch (statusCode) {
      case Consts.statusConfirmed:
        return 'Entregar ate ${_formatTime(order.delivery.deliveryDateTime)}';
      case Consts.statusReadyToPickup:
        return _readySubtitle(order);
      case Consts.statusDispatched:
        return 'Em entrega';
      case Consts.statusConcluded:
        return 'Finalizado';
      case Consts.statusCancelled:
        return 'Cancelado';
      case Consts.statusDispute:
        return 'Disputa em aberto';
      case 'SCHEDULED':
        return _scheduledLabel(order);
      default:
        return 'Feito as ${_formatTime(order.createdAt)} (${_getTimeAgo(order.createdAt)})';
    }
  }

  String _readySubtitle(PedidoModel order) {
    final logisticEvents = order.events
        .where((e) =>
            IfoodEventUtils.isWaitingDriverEvent(e.code) ||
            IfoodEventUtils.isReadyEvent(e.code))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (logisticEvents.isNotEmpty) {
      return IfoodEventUtils.eventTitle(
        logisticEvents.first.code,
        deliveredBy: order.delivery.deliveredBy,
        orderType: order.orderType,
      );
    }

    return IfoodEventUtils.readyLabel(
      order.delivery.deliveredBy,
      order.orderType,
    );
  }

  String _scheduledLabel(PedidoModel order) {
    final start = order.schedule.deliveryDateTimeStart;
    final end = order.schedule.deliveryDateTimeEnd;
    if (start != null && end != null) {
      return '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}';
    }
    return 'Pedido agendado';
  }

  String _formatTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    return '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getTimeAgo(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inHours > 0) return '${difference.inHours} h';
    return '${difference.inMinutes} min';
  }
}

class _KanbanActionConfig {
  final String label;
  final KanbanOrderAction action;
  final Color color;

  const _KanbanActionConfig({
    required this.label,
    required this.action,
    required this.color,
  });
}

class _CardActions extends StatelessWidget {
  final List<_KanbanActionConfig> actions;
  final void Function(KanbanOrderAction action) onAction;

  const _CardActions({
    required this.actions,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: actions.length == 1
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      children: [
        for (final action in actions)
          Flexible(
            child: TextButton(
              onPressed: () => onAction(action.action),
              style: TextButton.styleFrom(
                foregroundColor: action.color,
                minimumSize: const Size(74, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}

class _ChannelBrand {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _ChannelBrand({
    required this.label,
    this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}

class _ChannelBadge extends StatelessWidget {
  final _ChannelBrand brand;

  const _ChannelBadge({required this.brand});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 82),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: brand.backgroundColor,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (brand.icon != null) ...[
              Icon(brand.icon, size: 12, color: brand.foregroundColor),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                brand.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: brand.foregroundColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Consts.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Consts.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Consts.primaryColor : Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Consts.primaryColor : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
