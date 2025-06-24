class EventModel {
  final String id;
  final String code;
  final String orderId;
  final DateTime createdAt;
  final String merchantId;
  final String salesChannel;
  final Map<String, dynamic> metadata;

  EventModel({
    required this.id,
    required this.code,
    required this.orderId,
    required this.createdAt,
    required this.salesChannel,
    required this.merchantId,
    this.metadata = const {},
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      orderId: json['orderId'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      metadata: json['metadata'] ?? {},
      salesChannel: json['salesChannel'] ?? '',
      merchantId: json['merchantId'] ?? '',
    );
  }

  factory EventModel.fromKronos(Map<String, dynamic> json) {
    return EventModel(
      id: json['Id'] ?? '',
      code: json['Code'] ?? '',
      orderId: json['OrderId'] ?? '',
      createdAt: json['CreatedAt'] != null
          ? DateTime.parse(json['CreatedAt'])
          : DateTime.now(),
      metadata: json['Metadata'] ?? {},
      salesChannel: json['SalesChannel'] ?? '',
      merchantId: json['MerchantId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Code': code,
      'OrderId': orderId,
      'CreatedAt': createdAt.toString(),
      'Metadata': metadata,
      'SalesChannel': salesChannel,
      'MerchantId': merchantId,
    };
  }
}
