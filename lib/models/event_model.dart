class EventModel {
  final String id;
  final String code;
  final String fullCode;
  final String orderId;
  DateTime createdAt;
  final String merchantId;
  final String salesChannel;
  final Map<String, dynamic> metadata;

  EventModel({
    required this.id,
    required this.code,
    this.fullCode = '',
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
      fullCode: json['fullCode'] ?? '',
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
      fullCode: json['FullCode'] ?? '',
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
      'FullCode': fullCode,
      'OrderId': orderId,
      'CreatedAt': createdAt.toString(),
      'Metadata': metadata,
      'SalesChannel': salesChannel,
      'MerchantId': merchantId,
    };
  }
}
