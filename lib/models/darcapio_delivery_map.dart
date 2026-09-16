import 'package:latlong2/latlong.dart';

class DarcapioDeliveryMap {
  final List<LatLng> route;
  final LatLng originPoint, destinationPoint;
  final int distanceMeters, durationSeconds;
  final String origin, destination;
  const DarcapioDeliveryMap(
      {required this.route,
      required this.originPoint,
      required this.destinationPoint,
      required this.distanceMeters,
      required this.durationSeconds,
      required this.origin,
      required this.destination});

  factory DarcapioDeliveryMap.fromJson(Map<String, dynamic> json) {
    final data = json.map((key, value) => MapEntry(key.toLowerCase(), value));
    LatLng point(dynamic value) {
      if (value is! Map) throw const FormatException('Ponto do mapa inválido.');
      final p = value
          .map((key, value) => MapEntry(key.toString().toLowerCase(), value));
      final lat = p['latitude'], lon = p['longitude'];
      if (lat is! num ||
          lon is! num ||
          !lat.isFinite ||
          !lon.isFinite ||
          lat.abs() > 90 ||
          lon.abs() > 180) {
        throw const FormatException('Ponto do mapa inválido.');
      }
      return LatLng(lat.toDouble(), lon.toDouble());
    }

    final route = data['trajeto'];
    if (route is! List || route.length < 2 || route.length > 30000) {
      throw const FormatException(
          'Trajeto do mapa inválido. Atualize o servidor do ERP e tente novamente.');
    }
    int number(String key, int max, {int min = 0}) {
      final value = data[key];
      if (value is! int || value < min || value > max) {
        throw const FormatException('Dados do mapa inválidos.');
      }
      return value;
    }

    return DarcapioDeliveryMap(
        route: List.unmodifiable(route.map(point)),
        originPoint: point(data['pontoorigem']),
        destinationPoint: point(data['pontodestino']),
        distanceMeters: number('distanciametros', 20000000),
        durationSeconds: number('duracaosegundos', 2678400),
        origin: data['origem'] as String,
        destination: data['destino'] as String);
  }
}
