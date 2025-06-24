class MerchantModel {
  final String id;
  final String name;
  final String corporateName;
  final String type;
  final MerchantAddress address;
  final MerchantOperation operation;
  final List<MerchantPhone> phones;
  final String website;
  final List<String> tags;
  final bool active;

  MerchantModel({
    required this.id,
    required this.name,
    required this.corporateName,
    required this.type,
    required this.address,
    required this.operation,
    required this.phones,
    this.website = '',
    this.tags = const [],
    this.active = true,
  });

  factory MerchantModel.fromJson(Map<String, dynamic> json) {
    return MerchantModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      corporateName: json['corporateName'] ?? '',
      type: json['type'] ?? '',
      address: MerchantAddress.fromJson(json['address'] ?? {}),
      operation: MerchantOperation.fromJson(json['operation'] ?? {}),
      phones: (json['phones'] as List<dynamic>?)
              ?.map((phone) => MerchantPhone.fromJson(phone))
              .toList() ??
          [],
      website: json['website'] ?? '',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      active: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'corporateName': corporateName,
      'type': type,
      'address': address.toJson(),
      'operation': operation.toJson(),
      'phones': phones.map((phone) => phone.toJson()).toList(),
      'website': website,
      'tags': tags,
      'active': active,
    };
  }
}

class MerchantAddress {
  final String formattedAddress;
  final String country;
  final String state;
  final String city;
  final String neighborhood;
  final String streetName;
  final String streetNumber;
  final String postalCode;
  final String complement;
  final double latitude;
  final double longitude;
  final String reference;

  MerchantAddress({
    required this.formattedAddress,
    required this.country,
    required this.state,
    required this.city,
    required this.neighborhood,
    required this.streetName,
    required this.streetNumber,
    required this.postalCode,
    this.complement = '',
    required this.latitude,
    required this.longitude,
    this.reference = '',
  });

  factory MerchantAddress.fromJson(Map<String, dynamic> json) {
    return MerchantAddress(
      formattedAddress: json['formattedAddress'] ?? '',
      country: json['country'] ?? '',
      state: json['state'] ?? '',
      city: json['city'] ?? '',
      neighborhood: json['neighborhood'] ?? '',
      streetName: json['streetName'] ?? '',
      streetNumber: json['streetNumber'] ?? '',
      postalCode: json['postalCode'] ?? '',
      complement: json['complement'] ?? '',
      latitude: json['latitude'] != null ? json['latitude'].toDouble() : 0.0,
      longitude: json['longitude'] != null ? json['longitude'].toDouble() : 0.0,
      reference: json['reference'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formattedAddress': formattedAddress,
      'country': country,
      'state': state,
      'city': city,
      'neighborhood': neighborhood,
      'streetName': streetName,
      'streetNumber': streetNumber,
      'postalCode': postalCode,
      'complement': complement,
      'latitude': latitude,
      'longitude': longitude,
      'reference': reference,
    };
  }
}

class MerchantOperation {
  final String timeZone;
  final List<OperationTime> operationTimes;

  MerchantOperation({
    required this.timeZone,
    required this.operationTimes,
  });

  factory MerchantOperation.fromJson(Map<String, dynamic> json) {
    return MerchantOperation(
      timeZone: json['timeZone'] ?? 'America/Sao_Paulo',
      operationTimes: (json['operationTimes'] as List<dynamic>?)
              ?.map((time) => OperationTime.fromJson(time))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timeZone': timeZone,
      'operationTimes': operationTimes.map((time) => time.toJson()).toList(),
    };
  }
}

class OperationTime {
  final List<String> daysOfWeek;
  final String startTime;
  final String endTime;

  OperationTime({
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory OperationTime.fromJson(Map<String, dynamic> json) {
    return OperationTime(
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)?.cast<String>() ?? [],
      startTime: json['startTime'] ?? '00:00',
      endTime: json['endTime'] ?? '23:59',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'daysOfWeek': daysOfWeek,
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}

class MerchantPhone {
  final String number;
  final String type;

  MerchantPhone({
    required this.number,
    required this.type,
  });

  factory MerchantPhone.fromJson(Map<String, dynamic> json) {
    return MerchantPhone(
      number: json['number'] ?? '',
      type: json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'type': type,
    };
  }
}
