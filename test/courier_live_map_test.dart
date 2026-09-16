import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'delivery_map_test.dart' show MapFake, view, settleMap;

class TrackingFake extends MapFake {
  var active = true;
  var latitude = -3.726;
  var callsToTracking = 0;
  int? errorStatus;

  @override
  Future<Map<String, dynamic>> courierTracking(String orderId) async {
    callsToTracking++;
    if (errorStatus != null) {
      final request = RequestOptions(path: '/rastreamento');
      throw DioException(
          requestOptions: request,
          response: Response(requestOptions: request, statusCode: errorStatus));
    }
    return {
      'active': active,
      'stale': false,
      'name': 'Carlos',
      'position': {
        'latitude': latitude,
        'longitude': -38.526,
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
      }
    };
  }
}

void main() {
  testWidgets('GPS atualiza a cada 5 s sem mover a câmera e para ao fechar',
      (tester) async {
    final repo = TrackingFake();
    await tester.pumpWidget(view(repo));
    await settleMap(tester);
    expect(find.text('Carlos'), findsOneWidget);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    await tester.tap(find.byTooltip('Aproximar mapa'));
    await settleMap(tester);
    final zoom = map.mapController!.camera.zoom;
    final center = map.mapController!.camera.center;
    repo.latitude = -3.728;
    await tester.pump(const Duration(seconds: 5));
    await settleMap(tester);
    final markers =
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;
    expect(markers.last.point.latitude, -3.728);
    expect(map.mapController!.camera.zoom, zoom);
    expect(map.mapController!.camera.center, center);
    await tester.tap(find.byTooltip('Localizar entregador'));
    await settleMap(tester);
    expect(map.mapController!.camera.center.latitude, -3.728);
    await tester.pumpWidget(const SizedBox());
    final calls = repo.callsToTracking;
    await tester.pump(const Duration(seconds: 10));
    expect(repo.callsToTracking, calls);
  });

  testWidgets('revogação remove GPS e entrega encerrada não mostra marcador',
      (tester) async {
    final repo = TrackingFake();
    await tester.pumpWidget(view(repo));
    await settleMap(tester);
    expect(find.byTooltip('Localizar entregador'), findsOneWidget);
    repo.errorStatus = 403;
    await tester.pump(const Duration(seconds: 5));
    await settleMap(tester);
    expect(find.byTooltip('Localizar entregador'), findsNothing);
    expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length, 2);
    repo.errorStatus = null;
    repo.active = false;
    await tester.pump(const Duration(seconds: 5));
    await settleMap(tester);
    expect(find.text('Carlos'), findsNothing);
    expect(find.byTooltip('Localizar entregador'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
