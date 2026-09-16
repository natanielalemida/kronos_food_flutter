import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/components/darcapio/delivery_map.dart';
import 'package:kronos_food/components/darcapio/order_details.dart';
import 'package:kronos_food/models/darcapio_delivery_map.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'darcapio_test.dart' show order;

DarcapioDeliveryMap sample([String destination = 'Rua do cliente, 200']) => DarcapioDeliveryMap(
  route: const [LatLng(-3.72,-38.52),LatLng(-3.725,-38.525),LatLng(-3.73,-38.53)],
  originPoint: const LatLng(-3.72,-38.52), destinationPoint: const LatLng(-3.73,-38.53), distanceMeters: 4300, durationSeconds: 601,
  origin: 'Rua da loja, 100', destination: destination);
class MapFake extends DarcapioRepository {
  final calls = <String>[];
  final tileCalls = <(int, int, int)>[];
  bool tilesFail = false;
  @override
  Future<Uint8List> deliveryMapTile(String id, int z, int x, int y, {CancelToken? cancelToken}) async {
    tileCalls.add((z,x,y));
    if (tilesFail) throw StateError('Mapa indisponível');
    return base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');
  }
  Object? failure;
  Completer<DarcapioDeliveryMap>? pending;
  @override
  Future<DarcapioDeliveryMap> deliveryMap(String id) async {
    calls.add(id);
    if (pending != null) return pending!.future;
    if (failure != null) throw failure!;
    return sample(id);
  }
}
Widget view(MapFake repo, {String id = 'pedido 1'}) => MaterialApp(home: Scaffold(body:
  SingleChildScrollView(child: DarcapioDeliveryMapView(orderId: id, repository: repo))));
Future<void> settleMap(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  final images = find.byType(Image);
  for (final element in images.evaluate()) {
    await tester.runAsync(() => precacheImage((element.widget as Image).image, element));
  }
  await tester.pumpAndSettle();
}
void main() {
  testWidgets('Mostra rota, métricas e amplia com contexto, sem nova chamada no polling', (tester) async {
    final repo = MapFake();
    await tester.pumpWidget(view(repo)); await settleMap(tester);
    expect(find.text('4,3 km por ruas'), findsOneWidget);
    expect(find.text('≈ 11 min de trajeto'), findsOneWidget);
    await tester.pumpWidget(view(repo)); await settleMap(tester);
    expect(repo.calls.length, 1);
    await tester.ensureVisible(find.text('Ampliar mapa'));
    await tester.tap(find.text('Ampliar mapa')); await settleMap(tester);
    expect(find.text('Cliente · endereço deste pedido'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNWidgets(2));
    await tester.tap(find.byTooltip('Fechar mapa')); await settleMap(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Erro fica no mapa e permite tentar novamente', (tester) async {
    final repo = MapFake()..failure = DioException(requestOptions: RequestOptions(path: '/mapa'), response:
      Response(requestOptions: RequestOptions(path: '/mapa'), statusCode: 400, data: {'mensagem': 'Confirme a localização com o cliente.'}));
    await tester.pumpWidget(view(repo)); await settleMap(tester);
    expect(find.text('Confirme a localização com o cliente.'), findsOneWidget);
    repo.failure = null;
    await tester.tap(find.text('Tentar carregar mapa')); await settleMap(tester);
    expect(find.text('Ampliar mapa'), findsOneWidget);
    expect(repo.calls.length, 2);
  });
  testWidgets('Trocar pedido descarta resposta antiga e limpa o mapa anterior', (tester) async {
    final delayed = Completer<DarcapioDeliveryMap>();
    final repo = MapFake()..pending = delayed;
    await tester.pumpWidget(view(repo, id: 'antigo')); await tester.pump();
    expect(find.text('Carregando trajeto…'), findsOneWidget);
    repo.pending = null;
    await tester.pumpWidget(view(repo, id: 'novo')); await settleMap(tester);
    delayed.complete(sample('endereço antigo')); await settleMap(tester);
    expect(find.text('novo'), findsOneWidget);
    expect(find.text('endereço antigo'), findsNothing);
  });
  testWidgets('Zoom e arraste buscam novos tiles e mantêm a rota', (tester) async {
    final repo = MapFake();
    await tester.pumpWidget(view(repo)); await settleMap(tester);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final start = map.mapController!.camera;
    final oldTiles = repo.tileCalls.toSet();
    await tester.tap(find.byTooltip('Aproximar mapa')); await settleMap(tester);
    expect(map.mapController!.camera.zoom, greaterThan(start.zoom));
    expect(repo.tileCalls.any((t) => !oldTiles.contains(t)), isTrue);
    final beforePan = map.mapController!.camera.center;
    final beforePanTiles = repo.tileCalls.toSet();
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(FlutterMap), const Offset(550, 0)); await settleMap(tester);
    }
    expect(map.mapController!.camera.center, isNot(beforePan));
    expect(repo.tileCalls.any((t) => !beforePanTiles.contains(t)), isTrue);
    expect(tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines.single.points, sample().route);
    await tester.tap(find.byTooltip('Ver trajeto completo')); await settleMap(tester);
    expect(map.mapController!.camera.zoom, closeTo(start.zoom, .001));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Falha de tiles pode ser recarregada sem consultar a rota outra vez', (tester) async {
    final repo = MapFake()..tilesFail = true;
    await tester.pumpWidget(view(repo)); await settleMap(tester);
    expect(find.text('Algumas ruas não carregaram.'), findsOneWidget);
    repo.tilesFail = false;
    await tester.tap(find.byTooltip('Recarregar ruas')); await settleMap(tester);
    expect(find.text('Algumas ruas não carregaram.'), findsNothing);
    expect(repo.calls.length, 1);
  });
  testWidgets('Retirada não consulta nem exibe mapa', (tester) async {
    final repo = MapFake();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DarcapioOrderDetails(
      order: order('aceito', 1), busy: false, blocked: false, onAction: (_) {}, repository: repo))));
    await settleMap(tester);
    expect(repo.calls, isEmpty);
    expect(find.byType(DarcapioDeliveryMapView), findsNothing);
  });
  testWidgets('Mapa e visualização ampliada cabem em largura de 360px', (tester) async {
    tester.view.physicalSize = const Size(360, 780); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(view(MapFake())); await settleMap(tester);
    await tester.tap(find.text('Ampliar mapa')); await settleMap(tester);
    expect(tester.takeException(), isNull);
  });
}
