import 'package:latlong2/latlong.dart';

class CourierTracking {
  final bool active, stale;
  final String? name;
  final LatLng? position;
  final DateTime? recordedAt;
  const CourierTracking(
      {required this.active,
      required this.stale,
      this.name,
      this.position,
      this.recordedAt});
  bool get isStale =>
      stale ||
      recordedAt == null ||
      DateTime.now().toUtc().difference(recordedAt!).inSeconds > 45;
  bool get hasVisiblePosition =>
      active &&
      position != null &&
      recordedAt != null &&
      DateTime.now().toUtc().difference(recordedAt!).inMinutes < 60;
  factory CourierTracking.fromJson(Map<String, dynamic> json) {
    final data = json.map((k, v) => MapEntry(k.toLowerCase(), v));
    final raw = data['position'];
    LatLng? position;
    DateTime? recorded;
    if (raw is Map) {
      final p = raw.map((k, v) => MapEntry(k.toString().toLowerCase(), v));
      final lat = p['latitude'], lng = p['longitude'];
      if (lat is num &&
          lng is num &&
          lat.isFinite &&
          lng.isFinite &&
          lat.abs() <= 90 &&
          lng.abs() <= 180) {
        position = LatLng(lat.toDouble(), lng.toDouble());
        recorded =
            DateTime.tryParse(p['recordedat']?.toString() ?? '')?.toUtc();
      }
    }
    return CourierTracking(
        active: data['active'] == true,
        stale: data['stale'] != false,
        name: data['name'] as String?,
        position: position,
        recordedAt: recorded);
  }
}
