import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:kronos_food/models/delivery_tracking_model.dart';
import 'package:kronos_food/models/event_model.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:kronos_food/service/order_actions_service.dart';
import 'package:kronos_food/utils/ifood_event_utils.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderIfoodTracking extends StatefulWidget {
  final PedidoModel order;

  const OrderIfoodTracking({
    super.key,
    required this.order,
  });

  @override
  State<OrderIfoodTracking> createState() => _OrderIfoodTrackingState();
}

class _OrderIfoodTrackingState extends State<OrderIfoodTracking> {
  late final OrderActionsService _actionsService;
  final MapController _mapController = MapController();
  final TextEditingController _pickupCodeController = TextEditingController();
  Timer? _trackingTimer;
  DeliveryTrackingModel? _tracking;
  bool _isLoadingTracking = false;
  bool _isValidatingCode = false;
  String? _trackingMessage;
  String? _pickupCodeMessage;
  bool? _pickupCodeValid;

  @override
  void initState() {
    super.initState();
    _actionsService = OrderActionsService(AuthRepository());
    _configureTrackingTimer(fetchNow: true);
  }

  @override
  void didUpdateWidget(OrderIfoodTracking oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldEvent = _latestLogisticEvent(oldWidget.order)?.id;
    final newEvent = _latestLogisticEvent(widget.order)?.id;

    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.status != widget.order.status ||
        oldEvent != newEvent) {
      _tracking = null;
      _trackingMessage = null;
      _pickupCodeMessage = null;
      _pickupCodeValid = null;
      _configureTrackingTimer(fetchNow: true);
    }
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _mapController.dispose();
    _pickupCodeController.dispose();
    super.dispose();
  }

  bool get _isIfoodDelivery =>
      IfoodEventUtils.isIfoodDelivery(widget.order.delivery.deliveredBy);

  bool get _isIfoodOrder =>
      IfoodEventUtils.isIfoodSalesChannel(widget.order.salesChannel) ||
      _isIfoodDelivery;

  bool get _canTrack {
    if (!_isIfoodDelivery) return false;
    return widget.order.events.any((e) =>
        IfoodEventUtils.isWaitingDriverEvent(e.code) ||
        IfoodEventUtils.isInRouteEvent(e.code));
  }

  bool get _isOrderFinished =>
      IfoodEventUtils.isFinishedEvent(widget.order.status) ||
      widget.order.events.any((e) => IfoodEventUtils.isFinishedEvent(e.code));

  bool get _shouldPollTracking => _canTrack && !_isOrderFinished;

  String _merchantDeliveryStageLabel() {
    final status = IfoodEventUtils.normalize(widget.order.status);

    if (status.contains('DSP') || status.contains('DISPATCHED')) {
      return 'Em entrega propria';
    }

    if (status.contains('CON') || status.contains('CONCLUDED')) {
      return 'Entrega propria concluida';
    }

    if (status.contains('CAN') || status.contains('CANCELLED')) {
      return 'Pedido cancelado';
    }

    return IfoodEventUtils.readyLabel(
      widget.order.delivery.deliveredBy,
      widget.order.orderType,
    );
  }

  void _configureTrackingTimer({required bool fetchNow}) {
    _trackingTimer?.cancel();

    if (!_shouldPollTracking) return;

    if (fetchNow) {
      unawaited(_fetchTracking());
    }

    _trackingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchTracking(),
    );
  }

  Future<void> _fetchTracking() async {
    if (_isLoadingTracking || !_shouldPollTracking) return;

    if (mounted) {
      setState(() {
        _isLoadingTracking = true;
        _trackingMessage = null;
      });
    }

    try {
      final tracking =
          await _actionsService.getDeliveryTracking(widget.order.id);
      if (!mounted) return;
      setState(() {
        _tracking = tracking;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.response?.statusCode == 404) {
          _trackingMessage = 'Rastreamento ainda indisponivel';
        } else {
          _trackingMessage =
              'Falha ao atualizar rastreamento (${e.response?.statusCode ?? 'rede'})';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _trackingMessage = 'Falha ao atualizar rastreamento';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTracking = false;
        });
      }
    }
  }

  Future<void> _validatePickupCode() async {
    final code = _pickupCodeController.text.trim();
    if (code.isEmpty || _isValidatingCode) return;

    setState(() {
      _isValidatingCode = true;
      _pickupCodeMessage = null;
      _pickupCodeValid = null;
    });

    try {
      final valid =
          await _actionsService.validatePickupCode(widget.order.id, code);
      if (!mounted) return;
      setState(() {
        _pickupCodeValid = valid;
        _pickupCodeMessage = valid ? 'Codigo validado' : 'Codigo invalido';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickupCodeValid = false;
        _pickupCodeMessage = 'Nao foi possivel validar o codigo';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isValidatingCode = false;
        });
      }
    }
  }

  Future<void> _openMap() async {
    final tracking = _tracking;
    if (tracking == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${tracking.latitude},${tracking.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _zoomMap(double delta) {
    try {
      final camera = _mapController.camera;
      final zoom = (camera.zoom + delta).clamp(3.0, 19.0).toDouble();
      _mapController.move(camera.center, zoom);
    } catch (_) {}
  }

  void _focusMap(LatLng point, double zoom) {
    try {
      _mapController.move(point, zoom);
    } catch (_) {}
  }

  void _fitMap(List<LatLng> points) {
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(44),
          maxZoom: 16.0,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_isIfoodOrder) return const SizedBox.shrink();

    if (!_isIfoodDelivery) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_outlined, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text(
                  'Logistica do pedido',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _StagePill(
                  label: _merchantDeliveryStageLabel(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoBox(
              icon: Icons.storefront_outlined,
              color: Colors.orange,
              text:
                  'Este pedido veio do iFood com deliveredBy=${widget.order.delivery.deliveredBy}. Nesse fluxo a entrega e propria da loja, entao o iFood nao envia rastreio, mapa, entregador parceiro ou codigo de coleta.',
            ),
            const SizedBox(height: 8),
            _InfoBox(
              icon: Icons.info_outline,
              color: Colors.teal,
              text:
                  'Para testar mapa e codigo do entregador, gere um pedido de teste configurado como Entrega iFood. O mapa aparece depois que o iFood mandar ASSIGN_DRIVER e o endpoint de tracking ficar disponivel.',
            ),
          ],
        ),
      );
    }

    final stageEvent = _latestLogisticEvent(widget.order);
    final stageTitle = stageEvent != null
        ? IfoodEventUtils.eventTitle(
            stageEvent.code,
            deliveredBy: widget.order.delivery.deliveredBy,
            orderType: widget.order.orderType,
          )
        : 'Aguardando atribuicao do entregador';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_outlined, color: Colors.teal[700]),
              const SizedBox(width: 8),
              const Text(
                'Rastreamento iFood',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _StagePill(label: stageTitle),
            ],
          ),
          const SizedBox(height: 14),
          _buildDriverInfo(),
          const SizedBox(height: 12),
          _buildPickupCodePanel(),
          const SizedBox(height: 12),
          if (_isOrderFinished)
            _InfoBox(
              icon: Icons.check_circle_outline,
              color: Colors.green,
              text:
                  'Entrega finalizada pelo iFood. O mapa fica oculto nesse status.',
            )
          else if (!_canTrack)
            _InfoBox(
              icon: Icons.schedule,
              color: Colors.orange,
              text:
                  'Aguardando evento de entregador do iFood. O mapa so aparece depois de ASSIGN_DRIVER/rota e pode ficar indisponivel em homolog ate o tracking existir.',
            )
          else
            _buildTrackingBody(),
        ],
      ),
    );
  }

  Widget _buildDriverInfo() {
    final driver = _latestDriverInfo();
    if (!driver.hasAny) {
      return _InfoBox(
        icon: Icons.person_pin_circle_outlined,
        color: Colors.teal,
        text: 'Entregador ainda nao informado',
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        children: [
          _DriverAvatar(driver: driver),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.name.isEmpty ? 'Entregador iFood' : driver.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (driver.phone.isNotEmpty)
                      _DataChip(
                        icon: Icons.phone_outlined,
                        label: driver.phone,
                      ),
                    if (driver.vehicle.isNotEmpty)
                      _DataChip(
                        icon: Icons.two_wheeler_outlined,
                        label: driver.vehicle,
                      ),
                    if (driver.photoUrl.isEmpty)
                      _DataChip(
                        icon: Icons.no_photography_outlined,
                        label: 'Foto nao enviada pelo iFood',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _DriverInfo _latestDriverInfo() {
    final tracking = _tracking;
    final trackingInfo = tracking == null
        ? const _DriverInfo()
        : _DriverInfo(
            name: tracking.driverName,
            phone: tracking.driverPhone,
            vehicle: tracking.driverVehicle,
            photoUrl: tracking.driverPhotoUrl,
          );

    final events = widget.order.events.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final event in events) {
      final eventInfo =
          _driverInfoFromMetadata(event.metadata).mergeWithFallback(
        trackingInfo,
      );
      if (eventInfo.hasAny) return eventInfo;
    }

    return trackingInfo;
  }

  _DriverInfo _driverInfoFromMetadata(Map<String, dynamic> metadata) {
    final driver = _driverMap(metadata) ?? metadata;

    return _DriverInfo(
      name: _readMetadata(driver, const [
        'name',
        'Name',
        'fullName',
        'driverName',
        'courierName',
        'deliverymanName',
        'deliveryManName',
      ]),
      phone: _readMetadata(driver, const [
        'phone',
        'Phone',
        'phoneNumber',
        'driverPhone',
        'courierPhone',
        'deliverymanPhone',
        'deliveryManPhone',
      ]),
      vehicle: _readMetadata(driver, const [
        'vehicle',
        'Vehicle',
        'modal',
        'transport',
        'driverVehicle',
        'courierVehicle',
      ]),
      photoUrl: _readPhotoUrl(driver),
    );
  }

  Map<String, dynamic>? _driverMap(Map<String, dynamic> metadata) {
    for (final key in const [
      'driver',
      'Driver',
      'courier',
      'Courier',
      'deliveryman',
      'deliveryMan',
      'deliveryPerson',
      'DeliveryPerson',
    ]) {
      final value = metadata[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }

    for (final key in const [
      'delivery',
      'Delivery',
      'logistics',
      'Logistics'
    ]) {
      final value = metadata[key];
      if (value is Map) {
        final nested = _driverMap(Map<String, dynamic>.from(value));
        if (nested != null) return nested;
      }
    }

    return null;
  }

  String _readPhotoUrl(Map<String, dynamic> metadata) {
    final direct = _readMetadata(metadata, const [
      'photoUrl',
      'photoURL',
      'imageUrl',
      'imageURL',
      'pictureUrl',
      'profilePictureUrl',
      'profileImageUrl',
      'avatarUrl',
    ]);
    if (direct.isNotEmpty) return direct;

    for (final key in const [
      'photo',
      'image',
      'picture',
      'profilePicture',
      'avatar',
    ]) {
      final value = metadata[key];
      if (value is Map) {
        final url = _readMetadata(Map<String, dynamic>.from(value), const [
          'url',
          'Url',
          'URL',
          'href',
        ]);
        if (url.isNotEmpty) return url;
      }
    }

    return '';
  }

  Widget _buildTrackingBody() {
    if (_isOrderFinished) {
      return _InfoBox(
        icon: Icons.check_circle_outline,
        color: Colors.green,
        text: 'Entrega finalizada pelo iFood. O mapa fica oculto nesse status.',
      );
    }

    final tracking = _tracking;

    if (tracking == null) {
      return _InfoBox(
        icon: Icons.location_searching,
        color: Colors.teal,
        text: _trackingMessage ?? 'Rastreamento aguardando atualizacao',
        trailing: _RefreshButton(
          isLoading: _isLoadingTracking,
          onPressed: _fetchTracking,
        ),
      );
    }

    final updatedAt = tracking.trackDate != null
        ? DateFormat('HH:mm:ss').format(tracking.trackDate!)
        : '--:--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DataChip(
              icon: Icons.my_location_outlined,
              label:
                  '${tracking.latitude.toStringAsFixed(6)}, ${tracking.longitude.toStringAsFixed(6)}',
            ),
            if (tracking.pickupEtaStart != null)
              _DataChip(
                icon: Icons.storefront_outlined,
                label: 'Coleta em ${_formatEta(tracking.pickupEtaStart!)}',
              ),
            if (tracking.deliveryEtaEnd != null)
              _DataChip(
                icon: Icons.home_outlined,
                label: 'Entrega em ${_formatEta(tracking.deliveryEtaEnd!)}',
              ),
            _DataChip(
              icon: Icons.update,
              label: 'Atualizado $updatedAt',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMap(tracking),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isLoadingTracking ? null : _fetchTracking,
              icon: _isLoadingTracking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: const Text('Atualizar'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _openMap,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Abrir mapa'),
            ),
          ],
        ),
        if (_trackingMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _trackingMessage!,
            style: TextStyle(color: Colors.orange[700]),
          ),
        ],
      ],
    );
  }

  Widget _buildPickupCodePanel() {
    final message = _pickupCodeMessage;
    final color = _pickupCodeValid == true ? Colors.green : Colors.red;
    final pickupCode = widget.order.delivery.pickupCode.trim();

    if (pickupCode.isEmpty) {
      return _InfoBox(
        icon: Icons.pin_outlined,
        color: Colors.teal,
        text:
            'Codigo de coleta ainda nao enviado pelo iFood para este pedido. Quando o iFood mandar pickupCode nos detalhes, a validacao aparece aqui.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pin_outlined, color: Colors.teal[700], size: 18),
              const SizedBox(width: 8),
              const Text(
                'Codigo de coleta',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                pickupCode,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pickupCodeController,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Codigo informado pelo entregador',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _validatePickupCode(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isValidatingCode ? null : _validatePickupCode,
                icon: _isValidatingCode
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Validar'),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMap(DeliveryTrackingModel tracking) {
    final courierPoint = LatLng(tracking.latitude, tracking.longitude);
    final customerCoordinates =
        widget.order.delivery.deliveryAddress.coordinates;
    final hasCustomerPoint =
        customerCoordinates.latitude != 0 || customerCoordinates.longitude != 0;
    final customerPoint = LatLng(
      customerCoordinates.latitude,
      customerCoordinates.longitude,
    );

    final markers = <Marker>[
      Marker(
        point: courierPoint,
        width: 46,
        height: 46,
        child: _MapMarker(
          color: Colors.teal,
          icon: Icons.two_wheeler,
          tooltip: 'Entregador iFood',
        ),
      ),
      if (hasCustomerPoint)
        Marker(
          point: customerPoint,
          width: 42,
          height: 42,
          child: _MapMarker(
            color: Colors.redAccent,
            icon: Icons.home_outlined,
            tooltip: 'Cliente',
          ),
        ),
    ];
    final initialZoom = hasCustomerPoint ? 15.5 : 17.0;
    final routePoints =
        hasCustomerPoint ? <LatLng>[courierPoint, customerPoint] : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 280,
        width: double.infinity,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: courierPoint,
            initialZoom: initialZoom,
            minZoom: 3,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag |
                  InteractiveFlag.flingAnimation |
                  InteractiveFlag.pinchMove |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.doubleTapDragZoom |
                  InteractiveFlag.scrollWheelZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'kronos_food',
            ),
            if (hasCustomerPoint)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [courierPoint, customerPoint],
                    strokeWidth: 4,
                    color: Colors.teal.withValues(alpha: 0.75),
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Atualiza a cada 30s',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                children: [
                  _MapControlButton(
                    icon: Icons.add,
                    tooltip: 'Aproximar',
                    onPressed: () => _zoomMap(1),
                  ),
                  const SizedBox(height: 6),
                  _MapControlButton(
                    icon: Icons.remove,
                    tooltip: 'Afastar',
                    onPressed: () => _zoomMap(-1),
                  ),
                  const SizedBox(height: 6),
                  _MapControlButton(
                    icon: Icons.my_location,
                    tooltip: 'Centralizar entregador',
                    onPressed: () => _focusMap(courierPoint, initialZoom),
                  ),
                  if (routePoints != null) ...[
                    const SizedBox(height: 6),
                    _MapControlButton(
                      icon: Icons.route_outlined,
                      tooltip: 'Ver rota completa',
                      onPressed: () => _fitMap(routePoints),
                    ),
                  ],
                ],
              ),
            ),
            const Positioned(
              left: 8,
              bottom: 8,
              child: _MapHint(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEta(int seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes <= 1) return '1 min';
    return '$minutes min';
  }

  EventModel? _latestLogisticEvent(PedidoModel order) {
    final events = order.events
        .where((e) =>
            IfoodEventUtils.isReadyEvent(e.code) ||
            IfoodEventUtils.isLogisticEvent(e.code) ||
            IfoodEventUtils.isFinishedEvent(e.code))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return events.isEmpty ? null : events.first;
  }

  String _readMetadata(Map<String, dynamic> metadata, List<String> keys) {
    for (final key in keys) {
      final value = metadata[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }
}

class _DriverInfo {
  final String name;
  final String phone;
  final String vehicle;
  final String photoUrl;

  const _DriverInfo({
    this.name = '',
    this.phone = '',
    this.vehicle = '',
    this.photoUrl = '',
  });

  bool get hasAny =>
      name.isNotEmpty ||
      phone.isNotEmpty ||
      vehicle.isNotEmpty ||
      photoUrl.isNotEmpty;

  _DriverInfo mergeWithFallback(_DriverInfo fallback) {
    return _DriverInfo(
      name: name.isNotEmpty ? name : fallback.name,
      phone: phone.isNotEmpty ? phone : fallback.phone,
      vehicle: vehicle.isNotEmpty ? vehicle : fallback.vehicle,
      photoUrl: photoUrl.isNotEmpty ? photoUrl : fallback.photoUrl,
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  final _DriverInfo driver;

  const _DriverAvatar({required this.driver});

  @override
  Widget build(BuildContext context) {
    final url = driver.photoUrl.trim();

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.teal.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(Icons.person_pin_circle_outlined,
              color: Colors.teal[700], size: 32)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.person_pin_circle_outlined,
                color: Colors.teal[700],
                size: 32,
              ),
            ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: Colors.teal[800]),
          ),
        ),
      ),
    );
  }
}

class _MapHint extends StatelessWidget {
  const _MapHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mouse_outlined, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            'Arraste e use a roda do mouse',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  final String label;

  const _StagePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.teal[800],
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DataChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final Widget? trailing;

  const _InfoBox({
    required this.icon,
    required this.color,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _RefreshButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      tooltip: 'Atualizar',
    );
  }
}

class _MapMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String tooltip;

  const _MapMarker({
    required this.color,
    required this.icon,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
