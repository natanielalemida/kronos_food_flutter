class ShippingModel {
  final String id;
  final String orderId;
  final String merchantId;
  final ShippingMode mode;
  final ShippingStatus status;
  final DelivererModel? deliverer;
  final DateTime? estimatedDeliveryTime;
  final DateTime? actualDeliveryTime;
  final double deliveryFee;
  final DeliveryAddressModel deliveryAddress;

  ShippingModel({
    required this.id,
    required this.orderId,
    required this.merchantId,
    required this.mode,
    required this.status,
    this.deliverer,
    this.estimatedDeliveryTime,
    this.actualDeliveryTime,
    required this.deliveryFee,
    required this.deliveryAddress,
  });

  factory ShippingModel.fromJson(Map<String, dynamic> json) {
    return ShippingModel(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      merchantId: json['merchantId'] ?? '',
      mode: ShippingModeExtension.fromString(json['mode']),
      status: ShippingStatusExtension.fromString(json['status']),
      deliverer: json['deliverer'] != null 
          ? DelivererModel.fromJson(json['deliverer']) 
          : null,
      estimatedDeliveryTime: json['estimatedDeliveryTime'] != null
          ? DateTime.parse(json['estimatedDeliveryTime'])
          : null,
      actualDeliveryTime: json['actualDeliveryTime'] != null
          ? DateTime.parse(json['actualDeliveryTime'])
          : null,
      deliveryFee: json['deliveryFee']?.toDouble() ?? 0.0,
      deliveryAddress: DeliveryAddressModel.fromJson(
          json['deliveryAddress'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'orderId': orderId,
      'merchantId': merchantId,
      'mode': mode.toShortString(),
      'status': status.toShortString(),
      'deliveryFee': deliveryFee,
      'deliveryAddress': deliveryAddress.toJson(),
    };

    if (deliverer != null) {
      data['deliverer'] = deliverer!.toJson();
    }

    if (estimatedDeliveryTime != null) {
      data['estimatedDeliveryTime'] = estimatedDeliveryTime!.toIso8601String();
    }

    if (actualDeliveryTime != null) {
      data['actualDeliveryTime'] = actualDeliveryTime!.toIso8601String();
    }

    return data;
  }
}

class DelivererModel {
  final String id;
  final String name;
  final String phone;
  final double? latitude;
  final double? longitude;

  DelivererModel({
    required this.id,
    required this.name,
    required this.phone,
    this.latitude,
    this.longitude,
  });

  factory DelivererModel.fromJson(Map<String, dynamic> json) {
    return DelivererModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'name': name,
      'phone': phone,
    };

    if (latitude != null) {
      data['latitude'] = latitude;
    }

    if (longitude != null) {
      data['longitude'] = longitude;
    }

    return data;
  }
}

class DeliveryAddressModel {
  final String formattedAddress;
  final String street;
  final String number;
  final String complement;
  final String neighborhood;
  final String city;
  final String state;
  final String postalCode;
  final String reference;
  final double latitude;
  final double longitude;

  DeliveryAddressModel({
    required this.formattedAddress,
    required this.street,
    required this.number,
    this.complement = '',
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.postalCode,
    this.reference = '',
    required this.latitude,
    required this.longitude,
  });

  factory DeliveryAddressModel.fromJson(Map<String, dynamic> json) {
    return DeliveryAddressModel(
      formattedAddress: json['formattedAddress'] ?? '',
      street: json['street'] ?? '',
      number: json['number'] ?? '',
      complement: json['complement'] ?? '',
      neighborhood: json['neighborhood'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      postalCode: json['postalCode'] ?? '',
      reference: json['reference'] ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formattedAddress': formattedAddress,
      'street': street,
      'number': number,
      'complement': complement,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'reference': reference,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

enum ShippingMode {
  ifood,
  restaurant,
  takeout
}

extension ShippingModeExtension on ShippingMode {
  String get name {
    switch (this) {
      case ShippingMode.ifood:
        return 'IFOOD';
      case ShippingMode.restaurant:
        return 'RESTAURANT';
      case ShippingMode.takeout:
        return 'TAKEOUT';
    }
  }

  String toShortString() => name;

  static ShippingMode fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'IFOOD':
        return ShippingMode.ifood;
      case 'RESTAURANT':
        return ShippingMode.restaurant;
      case 'TAKEOUT':
        return ShippingMode.takeout;
      default:
        return ShippingMode.ifood;
    }
  }
}

enum ShippingStatus {
  waiting,
  allocated,
  arrived,
  dispatched,
  completed,
  cancelled
}

extension ShippingStatusExtension on ShippingStatus {
  String get name {
    switch (this) {
      case ShippingStatus.waiting:
        return 'WAITING';
      case ShippingStatus.allocated:
        return 'ALLOCATED';
      case ShippingStatus.arrived:
        return 'ARRIVED';
      case ShippingStatus.dispatched:
        return 'DISPATCHED';
      case ShippingStatus.completed:
        return 'COMPLETED';
      case ShippingStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String toShortString() => name;

  static ShippingStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'WAITING':
        return ShippingStatus.waiting;
      case 'ALLOCATED':
        return ShippingStatus.allocated;
      case 'ARRIVED':
        return ShippingStatus.arrived;
      case 'DISPATCHED':
        return ShippingStatus.dispatched;
      case 'COMPLETED':
        return ShippingStatus.completed;
      case 'CANCELLED':
        return ShippingStatus.cancelled;
      default:
        return ShippingStatus.waiting;
    }
  }
} 