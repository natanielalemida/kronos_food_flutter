class DeliveryTrackingModel {
  final double latitude;
  final double longitude;
  final DateTime? expectedDelivery;
  final int? pickupEtaStart;
  final int? deliveryEtaEnd;
  final DateTime? trackDate;
  final String driverName;
  final String driverPhone;
  final String driverVehicle;
  final String driverPhotoUrl;

  const DeliveryTrackingModel({
    required this.latitude,
    required this.longitude,
    this.expectedDelivery,
    this.pickupEtaStart,
    this.deliveryEtaEnd,
    this.trackDate,
    this.driverName = '',
    this.driverPhone = '',
    this.driverVehicle = '',
    this.driverPhotoUrl = '',
  });

  factory DeliveryTrackingModel.fromJson(Map<String, dynamic> json) {
    final driver = _driverMap(json);

    return DeliveryTrackingModel(
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      expectedDelivery: _parseDate(json['expectedDelivery']),
      pickupEtaStart: _toInt(json['pickupEtaStart']),
      deliveryEtaEnd: _toInt(json['deliveryEtaEnd']),
      trackDate: _parseDate(json['trackDate']),
      driverName: _readString(
          json,
          const [
            'driverName',
            'courierName',
            'deliverymanName',
            'deliveryManName',
          ],
          fallback: _readString(driver, const [
            'name',
            'Name',
            'fullName',
            'driverName',
          ])),
      driverPhone: _readString(
          json,
          const [
            'driverPhone',
            'courierPhone',
            'deliverymanPhone',
            'deliveryManPhone',
          ],
          fallback: _readString(driver, const [
            'phone',
            'Phone',
            'phoneNumber',
          ])),
      driverVehicle: _readString(
          json,
          const [
            'driverVehicle',
            'courierVehicle',
            'vehicle',
            'modal',
          ],
          fallback: _readString(driver, const [
            'vehicle',
            'Vehicle',
            'modal',
            'transport',
          ])),
      driverPhotoUrl: _readPhotoUrl(json, fallback: _readPhotoUrl(driver)),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static Map<String, dynamic> _driverMap(Map<String, dynamic> json) {
    for (final key in const [
      'driver',
      'Driver',
      'courier',
      'Courier',
      'deliveryman',
      'deliveryMan',
      'deliveryPerson',
    ]) {
      final value = json[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }

    for (final key in const [
      'delivery',
      'Delivery',
      'logistics',
      'Logistics'
    ]) {
      final value = json[key];
      if (value is Map) {
        final nested = _driverMap(Map<String, dynamic>.from(value));
        if (nested.isNotEmpty) return nested;
      }
    }

    return const {};
  }

  static String _readString(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  static String _readPhotoUrl(
    Map<String, dynamic> source, {
    String fallback = '',
  }) {
    final direct = _readString(source, const [
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
      final value = source[key];
      if (value is Map) {
        final url = _readString(Map<String, dynamic>.from(value), const [
          'url',
          'Url',
          'URL',
          'href',
        ]);
        if (url.isNotEmpty) return url;
      }
    }

    return fallback;
  }
}
