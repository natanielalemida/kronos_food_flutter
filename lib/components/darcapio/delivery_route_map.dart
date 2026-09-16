import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/darcapio_delivery_map.dart';
import '../../models/courier_tracking.dart';
import '../../repositories/darcapio_repository.dart';
import 'delivery_tile_provider.dart';
import 'order_style.dart';

class DeliveryRouteMap extends StatefulWidget {
  final DarcapioDeliveryMap data;
  final DarcapioRepository repository;
  final String orderId;
  const DeliveryRouteMap(
      {super.key,
      required this.data,
      required this.repository,
      required this.orderId});
  @override
  State<DeliveryRouteMap> createState() => _DeliveryRouteMapState();
}

class _DeliveryRouteMapState extends State<DeliveryRouteMap> {
  final controller = MapController();
  late DeliveryTileProvider tiles;
  var failed = false;
  var generation = 0;
  CourierTracking? courier;
  Timer? trackingTimer;
  bool trackingBusy = false, trackingFailed = false;
  Future<void> refreshTracking() async {
    if (trackingBusy) return;
    trackingBusy = true;
    try {
      final value = CourierTracking.fromJson(
          await widget.repository.courierTracking(widget.orderId));
      if (mounted) {
        setState(() {
          courier = value;
          trackingFailed = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          trackingFailed = true;
          // Revoked access and removed orders must not keep a cached position.
          if (error is DioException &&
              [401, 403, 404].contains(error.response?.statusCode)) {
            courier = null;
          }
        });
      }
    } finally {
      trackingBusy = false;
    }
  }

  CameraFit get fit => CameraFit.coordinates(
          coordinates: [
            widget.data.originPoint,
            ...widget.data.route,
            widget.data.destinationPoint
          ],
          padding: const EdgeInsets.fromLTRB(50, 50, 65, 60),
          maxZoom: 16,
          minZoom: 2);
  @override
  void initState() {
    super.initState();
    createTiles();
    refreshTracking();
    trackingTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => refreshTracking());
  }

  void createTiles() {
    final current = generation;
    tiles = DeliveryTileProvider(
        widget.repository,
        widget.orderId,
        () => scheduleMicrotask(() {
              if (mounted && current == generation && !failed) {
                setState(() => failed = true);
              }
            }));
  }

  @override
  void dispose() {
    trackingTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void retry() => setState(() {
        generation++;
        failed = false;
        createTiles();
      });
  void zoom(double delta) => controller.move(
      controller.camera.center, (controller.camera.zoom + delta).clamp(2, 22));
  bool get hasCourier => courier?.hasVisiblePosition == true;
  bool get staleCourier => trackingFailed || courier?.isStale != false;
  void locateCourier() {
    if (hasCourier) {
      controller.move(courier!.position!, controller.camera.zoom.clamp(14, 18));
    }
  }

  Widget trackingStatus() {
    final color = staleCourier ? const Color(0xFF946200) : OrderStyle.teal;
    final time = courier?.recordedAt?.toLocal();
    final timestamp = time == null
        ? ''
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    final detail = trackingFailed
        ? 'Sem conexão · tentando atualizar'
        : !hasCourier
            ? 'Aguardando localização do app'
            : staleCourier
                ? 'Última posição às $timestamp · GPS sem atualização'
                : 'Atualizado às $timestamp · consulta a cada 5 s';
    return Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.delivery_dining, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(courier?.name ?? 'Entregador da loja',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: OrderStyle.ink)),
                    const SizedBox(height: 3),
                    Text(detail, style: TextStyle(fontSize: 11, color: color)),
                  ])),
            ])));
  }

  Widget button(IconData icon, String label, VoidCallback action) => Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(7),
      child: IconButton(
          tooltip: label,
          onPressed: action,
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: OrderStyle.teal)));
  Marker marker(LatLng point, String letter, String title, String address,
          Color color) =>
      Marker(
          point: point,
          width: 42,
          height: 48,
          alignment: Alignment.topCenter,
          child: Tooltip(
              message: '$title · $address',
              child: Column(children: [
                Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 5,
                              offset: Offset(0, 2))
                        ]),
                    child: Text(letter,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800))),
                Icon(Icons.arrow_drop_down, size: 14, color: color),
              ])));
  Widget credit(String text, String url) => InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Text(text,
              style: const TextStyle(fontSize: 10, color: OrderStyle.ink))));

  @override
  Widget build(BuildContext context) => FlutterMap(
          mapController: controller,
          options: MapOptions(
              initialCameraFit: fit,
              minZoom: 2,
              maxZoom: 22,
              backgroundColor: const Color(0xFFE8EEED),
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate)),
          children: [
            TileLayer(
                key: ValueKey(generation),
                tileProvider: tiles,
                tileDimension: 512,
                zoomOffset: -1,
                minNativeZoom: 1,
                maxNativeZoom: 22,
                retinaMode: false,
                panBuffer: 1,
                keepBuffer: 2,
                userAgentPackageName: 'kronos_food'),
            PolylineLayer(polylines: [
              Polyline(
                  points: widget.data.route,
                  strokeWidth: 5,
                  color: OrderStyle.teal,
                  borderColor: Colors.white,
                  borderStrokeWidth: 2)
            ]),
            MarkerLayer(markers: [
              marker(widget.data.originPoint, 'A', 'Loja', widget.data.origin,
                  OrderStyle.teal),
              marker(widget.data.destinationPoint, 'B', 'Cliente',
                  widget.data.destination, const Color(0xFF2563EB)),
              if (hasCourier)
                Marker(
                    point: courier!.position!,
                    width: 44,
                    height: 44,
                    child: Tooltip(
                        message:
                            '${courier!.name ?? 'Entregador'} · ${courier!.isStale || trackingFailed ? 'Última posição conhecida' : 'Localização recente'}',
                        child: Container(
                            decoration: BoxDecoration(
                                color: courier!.isStale || trackingFailed
                                    ? Colors.blueGrey
                                    : const Color(0xFF7C3AED),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3)),
                            child: const Icon(Icons.delivery_dining,
                                color: Colors.white, size: 25)))),
            ]),
            Positioned(
                top: 10,
                right: 10,
                child: Column(children: [
                  button(Icons.add, 'Aproximar mapa', () => zoom(1)),
                  const SizedBox(height: 5),
                  button(Icons.remove, 'Afastar mapa', () => zoom(-1)),
                  const SizedBox(height: 5),
                  button(Icons.route, 'Ver trajeto completo',
                      () => controller.fitCamera(fit)),
                  if (hasCourier) ...[
                    const SizedBox(height: 5),
                    button(Icons.my_location, 'Localizar entregador',
                        locateCourier),
                  ],
                ])),
            if (courier?.active == true || trackingFailed)
              Positioned(left: 8, top: 8, right: 64, child: trackingStatus()),
            if (failed)
              Positioned(
                  left: 8,
                  right: 8,
                  bottom: 56,
                  child: Material(
                      color: const Color(0xFFFFF4DF),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Row(children: [
                            const Expanded(
                                child: Text('Algumas ruas não carregaram.',
                                    style: TextStyle(fontSize: 12))),
                            IconButton(
                                tooltip: 'Recarregar ruas',
                                onPressed: retry,
                                icon: const Icon(Icons.refresh, size: 18)),
                          ])))),
            Positioned(
                left: 8,
                bottom: 28,
                child: InkWell(
                    onTap: () => launchUrl(Uri.parse('https://www.mapbox.com/'),
                        mode: LaunchMode.externalApplication),
                    child: SvgPicture.asset('assets/images/mapbox-logo.svg',
                        width: 88, height: 23, semanticsLabel: 'Mapbox'))),
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                    color: Colors.white.withValues(alpha: .93),
                    child: Wrap(alignment: WrapAlignment.end, children: [
                      credit('© Mapbox', 'https://www.mapbox.com/about/maps/'),
                      credit('© OpenStreetMap',
                          'https://www.openstreetmap.org/copyright'),
                      InkWell(
                          onTap: () {
                            final p = controller.camera;
                            launchUrl(
                                Uri.parse(
                                    'https://apps.mapbox.com/feedback/#/${p.center.longitude}/${p.center.latitude}/${p.zoom}'),
                                mode: LaunchMode.externalApplication);
                          },
                          child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 3),
                              child: Text('Melhorar este mapa',
                                  style: TextStyle(
                                      fontSize: 10, color: OrderStyle.ink)))),
                    ]))),
          ]);
}
