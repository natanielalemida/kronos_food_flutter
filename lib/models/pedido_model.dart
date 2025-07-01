// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:kronos_food/models/event_model.dart';

class PedidoModel {
  String id;
  String displayId;
  DateTime createdAt;
  String category;
  String orderTiming;
  String orderType;
  Delivery delivery;
  DateTime preparationStartDateTime;
  bool isTest;
  String salesChannel;
  Merchant merchant;
  Customer customer;
  List<Item> items;
  Total total;
  Payments payments;
  List<AdditionalFee> additionalFees;
  AdditionalInfo additionalInfo;
  String status;
  List<EventModel> events = [];
  // Definir um setter personalizado para o status que garante consistência
  set statusCode(String statusCode) {
    if (statusCode.toUpperCase().contains('CAN') ||
        statusCode.toUpperCase().contains('CANCEL')) {
      print('🔴 Status do pedido $id definido como CANCELADO via setter');
      status = 'CAN'; // Definir código consistente
    } else {
      status = statusCode;
    }
  }

  PedidoModel({
    required this.id,
    required this.displayId,
    required this.createdAt,
    required this.category,
    required this.orderTiming,
    required this.orderType,
    required this.delivery,
    required this.preparationStartDateTime,
    required this.isTest,
    required this.salesChannel,
    required this.merchant,
    required this.customer,
    required this.items,
    required this.total,
    required this.payments,
    required this.additionalFees,
    required this.additionalInfo,
    required this.status,
    required this.events,
  });

  factory PedidoModel.fromKronos(Map<String, dynamic> json) {
    return PedidoModel(
      id: json['Id'] ?? '',
      displayId: json['DisplayId'] ?? '',
      createdAt: json['CreatedAt'] != null
          ? (json['CreatedAt'].runtimeType == int
              ? DateTime.fromMillisecondsSinceEpoch(json['CreatedAt']).toLocal()
              : DateTime.parse(json['CreatedAt']))
          : DateTime.now(),
      category: json['Category'] ?? '',
      orderTiming: json['OrderTiming'] ?? '',
      orderType: json['OrderType'] ?? '',
      delivery: json['Delivery'] != null
          ? Delivery.fromKronos(json['Delivery'])
          : Delivery.empty(),
      preparationStartDateTime: json['PreparationStartDateTime'] != null
          ? (json['PreparationStartDateTime'].runtimeType == int
              ? DateTime.fromMillisecondsSinceEpoch(
                      json['PreparationStartDateTime'])
                  .toLocal()
              : DateTime.parse(json['PreparationStartDateTime']))
          : DateTime.now(),
      isTest: json['IsTest'] ?? false,
      salesChannel: json['SalesChannel'] ?? '',
      merchant: json['Merchant'] != null
          ? Merchant.fromKronos(json['Merchant'])
          : Merchant.empty(),
      customer: json['Customer'] != null
          ? Customer.fromKronos(json['Customer'])
          : Customer.empty(),
      items:
          (json['Items'] as List?)?.map((i) => Item.fromKronos(i)).toList() ??
              [],
      total: json['Total'] != null
          ? Total.fromKronos(json['Total'])
          : Total.empty(),
      payments: json['Payments'] != null
          ? Payments.fromKronos(json['Payments'])
          : Payments.empty(),
      additionalFees: (json['AdditionalFees'] as List?)
              ?.map((i) => AdditionalFee.fromKronos(i))
              .toList() ??
          [],
      additionalInfo: json['AdditionalInfo'] != null
          ? AdditionalInfo.fromKronos(json['AdditionalInfo'])
          : AdditionalInfo(),
      status: json['Status'] ?? "",
      events: json['Events'] != null
          ? (json['Events'] as List)
              .map((e) => EventModel.fromKronos(e))
              .toList()
          : [],
    );
  }

  factory PedidoModel.fromJson(Map<String, dynamic> json) {
    return PedidoModel(
        id: json['id'] ?? '',
        displayId: json['displayId'] ?? '',
        createdAt: json['createdAt'] != null
            ? (json['createdAt'].runtimeType == int
                ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
                    .toLocal()
                : DateTime.parse(json['createdAt']))
            : DateTime.now(),
        category: json['category'] ?? '',
        orderTiming: json['orderTiming'] ?? '',
        orderType: json['orderType'] ?? '',
        delivery: json['delivery'] != null
            ? Delivery.fromJson(json['delivery'])
            : Delivery.empty(),
        preparationStartDateTime: json['preparationStartDateTime'] != null
            ? (json['preparationStartDateTime'].runtimeType == int
                ? DateTime.fromMillisecondsSinceEpoch(
                        json['preparationStartDateTime'])
                    .toLocal()
                : DateTime.parse(json['preparationStartDateTime']))
            : DateTime.now(),
        isTest: json['isTest'] ?? false,
        salesChannel: json['salesChannel'] ?? '',
        merchant: json['merchant'] != null
            ? Merchant.fromJson(json['merchant'])
            : Merchant.empty(),
        customer: json['customer'] != null
            ? Customer.fromJson(json['customer'])
            : Customer.empty(),
        items:
            (json['items'] as List?)?.map((i) => Item.fromJson(i)).toList() ??
                [],
        total: json['total'] != null
            ? Total.fromJson(json['total'])
            : Total.empty(),
        payments: json['payments'] != null
            ? Payments.fromJson(json['payments'])
            : Payments.empty(),
        additionalFees: (json['additionalFees'] as List?)
                ?.map((i) => AdditionalFee.fromJson(i))
                .toList() ??
            [],
        additionalInfo: json['additionalInfo'] != null
            ? AdditionalInfo.fromJson(json['additionalInfo'])
            : AdditionalInfo(),
        status: json['status'] ?? "",
        events: []);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Id': id,
      'DisplayId': displayId,
      'CreatedAt': createdAt.toString(),
      'Category': category,
      'OrderTiming': orderTiming,
      'OrderType': orderType,
      'PreparationStartDateTime': preparationStartDateTime.toString(),
      'IsTest': isTest,
      'SalesChannel': salesChannel,
      'Status': status,
      'AdditionalFees': additionalFees.map((x) => x.toMap()).toList(),
      'Items': items.map((x) => x.toMap()).toList(),
      'AdditionalInfo': additionalInfo.toMap(),
      'Delivery': delivery.toMap(),
      'Merchant': merchant.toMap(),
      'Customer': customer.toMap(),
      'Payments': payments.toMap(),
      'Total': total.toMap(),
      'Events': events.map((e) => e.toJson()).toList(),
    };
  }

  factory PedidoModel.fromMap(Map<String, dynamic> map) {
    return PedidoModel(
        id: map['id'] as String,
        displayId: map['displayId'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
            .toLocal(),
        category: map['category'] as String,
        orderTiming: map['orderTiming'] as String,
        orderType: map['orderType'] as String,
        delivery: Delivery.fromMap(map['delivery'] as Map<String, dynamic>),
        preparationStartDateTime: DateTime.fromMillisecondsSinceEpoch(
                map['preparationStartDateTime'] as int)
            .toLocal(),
        isTest: map['isTest'] as bool,
        salesChannel: map['salesChannel'] as String,
        merchant: Merchant.fromMap(map['merchant'] as Map<String, dynamic>),
        customer: Customer.fromMap(map['customer'] as Map<String, dynamic>),
        items: (map['items'] as List?)
                ?.map((item) => Item.fromMap(item as Map<String, dynamic>))
                .toList() ??
            [],
        total: Total.fromMap(map['total'] as Map<String, dynamic>),
        payments: Payments.fromMap(map['payments'] as Map<String, dynamic>),
        additionalFees: (map['additionalFees'] as List?)
                ?.map(
                    (fee) => AdditionalFee.fromMap(fee as Map<String, dynamic>))
                .toList() ??
            [],
        additionalInfo: AdditionalInfo.fromMap(
            map['additionalInfo'] as Map<String, dynamic>),
        status: map['status'] as String,
        events: []);
  }

  String toJson() => json.encode(toMap());
}

class Delivery {
  final String mode;
  final String description;
  final String deliveredBy;
  final DateTime deliveryDateTime;
  final DeliveryAddress deliveryAddress;
  final String pickupCode;
  final String nomeEntregador;
  final String observations; 

  Delivery({
    required this.mode,
    required this.description,
    required this.deliveredBy,
    required this.deliveryDateTime,
    required this.deliveryAddress,
    required this.pickupCode,
    this.nomeEntregador = '',
    this.observations = '', // Novo campo com valor padrão vazio
  });

  factory Delivery.fromKronos(Map<String, dynamic> json) {
    return Delivery(
      mode: json['Mode'] ?? '',
      description: json['Description'] ?? '',
      deliveredBy: json['DeliveredBy'] ?? '',
      deliveryDateTime: json['DeliveryDateTime'] != null
          ? (json['DeliveryDateTime'].runtimeType == int
              ? DateTime.fromMillisecondsSinceEpoch(json['DeliveryDateTime'])
                  .toLocal()
              : DateTime.parse(json['DeliveryDateTime']))
          : DateTime.now(),
      deliveryAddress: json['DeliveryAddress'] != null
          ? DeliveryAddress.fromKronos(json['DeliveryAddress'])
          : DeliveryAddress.empty(),
      pickupCode: json['PickupCode'] ?? '',
      nomeEntregador: json['NomeEntregador'] ?? '',
      observations: json['Observations'] ?? '', // Parse do novo campo
    );
  }

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      mode: json['mode'] ?? '',
      description: json['description'] ?? '',
      deliveredBy: json['deliveredBy'] ?? '',
      deliveryDateTime: json['deliveryDateTime'] != null
          ? (json['deliveryDateTime'].runtimeType == int
              ? DateTime.fromMillisecondsSinceEpoch(json['deliveryDateTime'])
                  .toLocal()
              : DateTime.parse(json['deliveryDateTime']))
          : DateTime.now(),
      deliveryAddress: json['deliveryAddress'] != null
          ? DeliveryAddress.fromJson(json['deliveryAddress'])
          : DeliveryAddress.empty(),
      pickupCode: json['pickupCode'] ?? '',
      nomeEntregador: json['nomeEntregador'] ?? '',
      observations: json['observations'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Mode': mode,
      'Description': description,
      'DeliveredBy': deliveredBy,
      'DeliveryDateTime': deliveryDateTime.toString(),
      'DeliveryAddress': deliveryAddress.toMap(),
      'PickupCode': pickupCode,
      'Observations': observations, // Incluindo no mapa para serialização
    };
  }

  factory Delivery.fromMap(Map<String, dynamic> map) {
    return Delivery(
      mode: map['mode'] as String,
      description: map['description'] as String,
      deliveredBy: map['deliveredBy'] as String,
      deliveryDateTime: map['deliveryDateTime'].runtimeType == String
          ? DateTime.parse(map['deliveryDateTime'])
          : DateTime.fromMillisecondsSinceEpoch(map['deliveryDateTime'] as int)
              .toLocal(),
      deliveryAddress: DeliveryAddress.fromMap(
          map['deliveryAddress'] as Map<String, dynamic>),
      pickupCode: map['pickupCode'] as String,
      observations: map['observations'] as String? ?? '', // Lendo do mapa
    );
  }

  // Construtor vazio para usar em caso de valores nulos
  factory Delivery.empty() {
    return Delivery(
      mode: '',
      description: '',
      deliveredBy: '',
      deliveryDateTime: DateTime.now(),
      deliveryAddress: DeliveryAddress.empty(),
      pickupCode: '',
      observations: '', // Campo vazio no construtor empty
    );
  }

  String toJson() => json.encode(toMap());
}

class Picking {
  final String? picker;

  Picking({
    this.picker,
  });

  factory Picking.fromJson(Map<String, dynamic> json) {
    return Picking(
      picker: json['picker'],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Picker': picker,
    };
  }

  factory Picking.fromMap(Map<String, dynamic> map) {
    return Picking(
      picker: map['picker'] as String?,
    );
  }

  // Construtor vazio
  factory Picking.empty() {
    return Picking(
      picker: '',
    );
  }

  String toJson() => json.encode(toMap());
}

class DeliveryAddress {
  final String streetName;
  final String streetNumber;
  final String formattedAddress;
  final String neighborhood;
  final String complement;
  final String postalCode;
  final String city;
  final String state;
  final String country;
  final String reference;
  final Coordinates coordinates;

  DeliveryAddress({
    required this.streetName,
    required this.streetNumber,
    required this.formattedAddress,
    required this.neighborhood,
    required this.complement,
    required this.postalCode,
    required this.city,
    required this.state,
    required this.country,
    required this.reference,
    required this.coordinates,
  });

  factory DeliveryAddress.fromKronos(Map<String, dynamic> json) {
    return DeliveryAddress(
      streetName: json['StreetName'] ?? '',
      streetNumber: json['StreetNumber'] ?? '',
      formattedAddress: json['FormattedAddress'] ?? '',
      neighborhood: json['Neighborhood'] ?? '',
      complement: json['Complement'] ?? '',
      postalCode: json['PostalCode'] ?? '',
      city: json['City'] ?? '',
      state: json['State'] ?? '',
      country: json['Country'] ?? '',
      reference: json['Reference'] ?? '',
      coordinates: json['Coordinates'] != null
          ? Coordinates.fromKronos(json['Coordinates'])
          : Coordinates.empty(),
    );
  }

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      streetName: json['streetName'] ?? '',
      streetNumber: json['streetNumber'] ?? '',
      formattedAddress: json['formattedAddress'] ?? '',
      neighborhood: json['neighborhood'] ?? '',
      complement: json['complement'] ?? '',
      postalCode: json['postalCode'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? '',
      reference: json['reference'] ?? '',
      coordinates: json['coordinates'] != null
          ? Coordinates.fromJson(json['coordinates'])
          : Coordinates.empty(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'StreetName': streetName,
      'StreetNumber': streetNumber,
      'FormattedAddress': formattedAddress,
      'Neighborhood': neighborhood,
      'Complement': complement,
      'PostalCode': postalCode,
      'City': city,
      'State': state,
      'Country': country,
      'Reference': reference,
      'Coordinates': coordinates.toMap(),
    };
  }

  factory DeliveryAddress.fromMap(Map<String, dynamic> map) {
    return DeliveryAddress(
      streetName: map['streetName'] as String,
      streetNumber: map['streetNumber'] as String,
      formattedAddress: map['formattedAddress'] as String,
      neighborhood: map['neighborhood'] as String,
      complement: map['complement'] as String,
      postalCode: map['postalCode'] as String,
      city: map['city'] as String,
      state: map['state'] as String,
      country: map['country'] as String,
      reference: map['reference'] as String,
      coordinates:
          Coordinates.fromMap(map['coordinates'] as Map<String, dynamic>),
    );
  }

  // Construtor vazio
  factory DeliveryAddress.empty() {
    return DeliveryAddress(
      streetName: '',
      streetNumber: '',
      formattedAddress: '',
      neighborhood: '',
      complement: '',
      postalCode: '',
      city: '',
      state: '',
      country: '',
      reference: '',
      coordinates: Coordinates.empty(),
    );
  }

  String toJson() => json.encode(toMap());
}

class Coordinates {
  final double latitude;
  final double longitude;

  Coordinates({
    required this.latitude,
    required this.longitude,
  });

  factory Coordinates.fromKronos(Map<String, dynamic> json) {
    return Coordinates(
      latitude: json['Latitude'] is int
          ? (json['Latitude'] as int).toDouble()
          : (json['Latitude'] ?? 0.0),
      longitude: json['Longitude'] is int
          ? (json['Longitude'] as int).toDouble()
          : (json['Longitude'] ?? 0.0),
    );
  }

  factory Coordinates.fromJson(Map<String, dynamic> json) {
    return Coordinates(
      latitude: json['latitude'] is int
          ? (json['latitude'] as int).toDouble()
          : (json['latitude'] ?? 0.0),
      longitude: json['longitude'] is int
          ? (json['longitude'] as int).toDouble()
          : (json['longitude'] ?? 0.0),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Latitude': latitude,
      'Longitude': longitude,
    };
  }

  factory Coordinates.fromMap(Map<String, dynamic> map) {
    return Coordinates(
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
    );
  }

  // Construtor vazio
  factory Coordinates.empty() {
    return Coordinates(
      latitude: 0.0,
      longitude: 0.0,
    );
  }

  String toJson() => json.encode(toMap());
}

class Merchant {
  final String id;
  final String name;

  Merchant({
    required this.id,
    required this.name,
  });

  factory Merchant.fromKronos(Map<String, dynamic> json) {
    return Merchant(
      id: json['Id'] ?? '',
      name: json['Name'] ?? '',
    );
  }

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Id': id,
      'Name': name,
    };
  }

  factory Merchant.fromMap(Map<String, dynamic> map) {
    return Merchant(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  // Construtor vazio
  factory Merchant.empty() {
    return Merchant(
      id: '',
      name: '',
    );
  }
}

class Customer {
  final String id;
  final String name;
  final String documentNumber;
  final Phone phone;
  final int ordersCountOnMerchant;
  final String segmentation;

  Customer({
    required this.id,
    required this.name,
    required this.documentNumber,
    required this.phone,
    required this.ordersCountOnMerchant,
    required this.segmentation,
  });

  factory Customer.fromKronos(Map<String, dynamic> json) {
    return Customer(
      id: json['Id'] ?? '',
      name: json['Name'] ?? '',
      documentNumber: json['DocumentNumber'] ?? '',
      phone: json['Phone'] != null
          ? Phone.fromKronos(json['Phone'])
          : Phone.empty(),
      ordersCountOnMerchant: json['OrdersCountOnMerchant'] ?? 0,
      segmentation: json['Segmentation'] ?? '',
    );
  }
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      documentNumber: json['documentNumber'] ?? '',
      phone:
          json['phone'] != null ? Phone.fromJson(json['phone']) : Phone.empty(),
      ordersCountOnMerchant: json['ordersCountOnMerchant'] ?? 0,
      segmentation: json['segmentation'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Id': id,
      'Name': name,
      'DocumentNumber': documentNumber,
      'Phone': phone.toMap(),
      'OrdersCountOnMerchant': ordersCountOnMerchant,
      'Segmentation': segmentation,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      name: map['name'] as String,
      documentNumber: map['documentNumber'] as String,
      phone: Phone.fromMap(map['phone'] as Map<String, dynamic>),
      ordersCountOnMerchant: map['ordersCountOnMerchant'] as int,
      segmentation: map['segmentation'] as String,
    );
  }

  // Construtor vazio
  factory Customer.empty() {
    return Customer(
      id: '',
      name: '',
      documentNumber: '',
      phone: Phone.empty(),
      ordersCountOnMerchant: 0,
      segmentation: '',
    );
  }

  String toJson() => json.encode(toMap());
}

class Phone {
  final String number;
  final String localizer;
  final DateTime localizerExpiration;

  Phone({
    required this.number,
    required this.localizer,
    required this.localizerExpiration,
  });

  factory Phone.fromKronos(Map<String, dynamic> json) {
    return Phone(
      number: json['Number'] ?? '',
      localizer: json['Localizer'] ?? '',
      localizerExpiration: json['LocalizerExpiration'] != null
          ? (json['LocalizerExpiration'].runtimeType == int
              ? DateTime.fromMillisecondsSinceEpoch(json['LocalizerExpiration'])
              : DateTime.parse(json['LocalizerExpiration']))
          : DateTime.now(),
    );
  }

  factory Phone.fromJson(Map<String, dynamic> json) {
    return Phone(
      number: json['number'] ?? '',
      localizer: json['localizer'] ?? '',
      localizerExpiration: json['localizerExpiration'] != null
          ? (json['localizerExpiration'].runtimeType == int
              ? DateTime.fromMillisecondsSinceEpoch(json['localizerExpiration'])
              : DateTime.parse(json['localizerExpiration']))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Number': number,
      'Localizer': localizer,
      'LocalizerExpiration': localizerExpiration.toString(),
    };
  }

  factory Phone.fromMap(Map<String, dynamic> map) {
    return Phone(
      number: map['number'] as String,
      localizer: map['localizer'] as String,
      localizerExpiration: DateTime.fromMillisecondsSinceEpoch(
          map['localizerExpiration'] as int),
    );
  }

  // Construtor vazio
  factory Phone.empty() {
    return Phone(
      number: '',
      localizer: '',
      localizerExpiration: DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
}

class Item {
  final int index;
  final String id;
  final String uniqueId;
  final String name;
  final String externalCode;
  final String ean;
  final int quantity;
  final String unit;
  final double unitPrice;
  final double optionsPrice;
  final double totalPrice;
  final double price;
  final String observations;
  final List<Option> options;
  final String imageUrl;

  Item({
    required this.index,
    required this.id,
    required this.uniqueId,
    required this.name,
    required this.externalCode,
    required this.ean,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.optionsPrice,
    required this.totalPrice,
    required this.price,
    required this.observations,
    required this.options,
    required this.imageUrl,
  });

  factory Item.fromKronos(Map<String, dynamic> json) {
    return Item(
      index: json['Index'] ?? 0,
      id: json['Id'] ?? '',
      uniqueId: json['UniqueId'] ?? '',
      name: json['Name'] ?? '',
      externalCode: json['ExternalCode'] ?? '',
      ean: json['Ean'] ?? '',
      quantity: json['Quantity'] ?? 0,
      unit: json['Unit'] ?? '',
      unitPrice: json['UnitPrice'] is int
          ? (json['UnitPrice'] as int).toDouble()
          : (json['UnitPrice'] ?? 0.0),
      optionsPrice: json['OptionsPrice'] is int
          ? (json['OptionsPrice'] as int).toDouble()
          : (json['OptionsPrice'] ?? 0.0),
      totalPrice: json['TotalPrice'] is int
          ? (json['TotalPrice'] as int).toDouble()
          : (json['TotalPrice'] ?? 0.0),
      price: json['Price'] is int
          ? (json['Price'] as int).toDouble()
          : (json['Price'] ?? 0.0),
      observations: json['Observations'] ?? '',
      options: (json['Options'] as List?)
              ?.map((i) => Option.fromKronos(i))
              .toList() ??
          [],
      imageUrl: json['ImageUrl'] ?? '',
    );
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      index: json['index'] ?? 0,
      id: json['id'] ?? '',
      uniqueId: json['uniqueId'] ?? '',
      name: json['name'] ?? '',
      externalCode: json['externalCode'] ?? '',
      ean: json['ean'] ?? '',
      quantity: json['quantity'] ?? 0,
      unit: json['unit'] ?? '',
      unitPrice: json['unitPrice'] is int
          ? (json['unitPrice'] as int).toDouble()
          : (json['unitPrice'] ?? 0.0),
      optionsPrice: json['optionsPrice'] is int
          ? (json['optionsPrice'] as int).toDouble()
          : (json['optionsPrice'] ?? 0.0),
      totalPrice: json['totalPrice'] is int
          ? (json['totalPrice'] as int).toDouble()
          : (json['totalPrice'] ?? 0.0),
      price: json['price'] is int
          ? (json['price'] as int).toDouble()
          : (json['price'] ?? 0.0),
      observations: json['observations'] ?? '',
      options:
          (json['options'] as List?)?.map((i) => Option.fromJson(i)).toList() ??
              [],
      imageUrl: json['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Index': index,
      'Id': id,
      'UniqueId': uniqueId,
      'Name': name,
      'ExternalCode': externalCode,
      'Ean': ean,
      'Quantity': quantity,
      'Unit': unit,
      'UnitPrice': unitPrice,
      'OptionsPrice': optionsPrice,
      'TotalPrice': totalPrice,
      'Price': price,
      'Observations': observations,
      'Options': options.map((x) => x.toMap()).toList(),
      'ImageUrl': imageUrl,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      index: map['index'] as int,
      id: map['id'] as String,
      uniqueId: map['uniqueId'] as String,
      name: map['name'] as String,
      externalCode: map['externalCode'] as String,
      ean: map['ean'] as String,
      quantity: map['quantity'] as int,
      unit: map['unit'] as String,
      unitPrice: map['unitPrice'] as double,
      optionsPrice: map['optionsPrice'] as double,
      totalPrice: map['totalPrice'] as double,
      price: map['price'] as double,
      observations: map['observations'] as String,
      options: List<Option>.from(
        (map['options'] as List<int>).map<Option>(
          (x) => Option.fromMap(x as Map<String, dynamic>),
        ),
      ),
      imageUrl: map['imageUrl'] as String,
    );
  }

  String toJson() => json.encode(toMap());
}

class Option {
  final int index;
  final String id;
  final String name;
  final String type;
  final String groupName;
  final String externalCode;
  final String ean;
  final int quantity;
  final String unit;
  final double unitPrice;
  final double addition;
  final double price;
  final List<Customization> customizations;

  Option({
    required this.index,
    required this.id,
    required this.name,
    required this.type,
    required this.groupName,
    required this.externalCode,
    required this.ean,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.addition,
    required this.price,
    required this.customizations,
  });

  factory Option.fromKronos(Map<String, dynamic> json) {
    return Option(
      index: json['Index'] ?? 0,
      id: json['Id'] ?? '',
      name: json['Name'] ?? '',
      type: json['Type'] ?? '',
      groupName: json['GroupName'] ?? '',
      externalCode: json['ExternalCode'] ?? '',
      ean: json['Ean'] ?? '',
      quantity: json['Quantity'] ?? 0,
      unit: json['Unit'] ?? '',
      unitPrice: json['UnitPrice'] is int
          ? (json['UnitPrice'] as int).toDouble()
          : (json['UnitPrice'] ?? 0.0),
      addition: json['Addition'] is int
          ? (json['Addition'] as int).toDouble()
          : (json['Addition'] ?? 0.0),
      price: json['Price'] is int
          ? (json['Price'] as int).toDouble()
          : (json['Price'] ?? 0.0),
      customizations: json['Customizations'] != null
          ? (json['Customizations'] as List?)
                  ?.map((i) => Customization.fromKronos(i))
                  .toList() ??
              []
          : [],
    );
  }

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(
      index: json['index'] ?? 0,
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      groupName: json['groupName'] ?? '',
      externalCode: json['externalCode'] ?? '',
      ean: json['ean'] ?? '',
      quantity: json['quantity'] ?? 0,
      unit: json['unit'] ?? '',
      unitPrice: json['unitPrice'] is int
          ? (json['unitPrice'] as int).toDouble()
          : (json['unitPrice'] ?? 0.0),
      addition: json['addition'] is int
          ? (json['addition'] as int).toDouble()
          : (json['addition'] ?? 0.0),
      price: json['price'] is int
          ? (json['price'] as int).toDouble()
          : (json['price'] ?? 0.0),
      customizations: json['customizations'] != null
          ? (json['customizations'] as List?)
                  ?.map((i) => Customization.fromJson(i))
                  .toList() ??
              []
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Index': index,
      'Id': id,
      'Name': name,
      'Type': type,
      'GroupName': groupName,
      'ExternalCode': externalCode,
      'Ean': ean,
      'Quantity': quantity,
      'Unit': unit,
      'UnitPrice': unitPrice,
      'Addition': addition,
      'Price': price,
      'Customizations': customizations.map((x) => x.toMap()).toList(),
    };
  }

  factory Option.fromMap(Map<String, dynamic> map) {
    return Option(
      index: map['index'] as int,
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      groupName: map['groupName'] as String,
      externalCode: map['externalCode'] as String,
      ean: map['ean'] as String,
      quantity: map['quantity'] as int,
      unit: map['unit'] as String,
      unitPrice: map['unitPrice'] as double,
      addition: map['addition'] as double,
      price: map['price'] as double,
      customizations: List<Customization>.from(
        (map['customizations'] as List<int>).map<Customization>(
          (x) => Customization.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());
}

class Customization {
  final String id;
  final String externalCode;
  final String name;
  final String groupName;
  final String type;
  final int quantity;
  final double unitPrice;
  final double addition;
  final double price;

  Customization({
    required this.id,
    required this.externalCode,
    required this.name,
    required this.groupName,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.addition,
    required this.price,
  });

  factory Customization.fromKronos(Map<String, dynamic> json) {
    return Customization(
      id: json['Id'] ?? '',
      externalCode: json['ExternalCode'] ?? '',
      name: json['Name'] ?? '',
      groupName: json['GroupName'] ?? '',
      type: json['Type'] ?? '',
      quantity: json['Quantity'] ?? 0,
      unitPrice: json['UnitPrice'] is int
          ? (json['UnitPrice'] as int).toDouble()
          : (json['UnitPrice'] ?? 0.0),
      addition: json['Addition'] is int
          ? (json['Addition'] as int).toDouble()
          : (json['Addition'] ?? 0.0),
      price: json['Price'] is int
          ? (json['Price'] as int).toDouble()
          : (json['Price'] ?? 0.0),
    );
  }

  factory Customization.fromJson(Map<String, dynamic> json) {
    return Customization(
      id: json['id'] ?? '',
      externalCode: json['externalCode'] ?? '',
      name: json['name'] ?? '',
      groupName: json['groupName'] ?? '',
      type: json['type'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: json['unitPrice'] is int
          ? (json['unitPrice'] as int).toDouble()
          : (json['unitPrice'] ?? 0.0),
      addition: json['addition'] is int
          ? (json['addition'] as int).toDouble()
          : (json['addition'] ?? 0.0),
      price: json['price'] is int
          ? (json['price'] as int).toDouble()
          : (json['price'] ?? 0.0),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Id': id,
      'ExternalCode': externalCode,
      'Name': name,
      'GroupName': groupName,
      'Type': type,
      'Quantity': quantity,
      'UnitPrice': unitPrice,
      'Addition': addition,
      'Price': price,
    };
  }

  factory Customization.fromMap(Map<String, dynamic> map) {
    return Customization(
      id: map['id'] as String,
      externalCode: map['externalCode'] as String,
      name: map['name'] as String,
      groupName: map['groupName'] as String,
      type: map['type'] as String,
      quantity: map['quantity'] as int,
      unitPrice: map['unitPrice'] as double,
      addition: map['addition'] as double,
      price: map['price'] as double,
    );
  }

  String toJson() => json.encode(toMap());
}

class Total {
  final double additionalFees;
  final double subTotal;
  final double deliveryFee;
  final double benefits;
  final double orderAmount;

  Total({
    required this.additionalFees,
    required this.subTotal,
    required this.deliveryFee,
    required this.benefits,
    required this.orderAmount,
  });

  factory Total.fromKronos(Map<String, dynamic> json) {
    return Total(
      additionalFees: json['AdditionalFees'] is int
          ? (json['AdditionalFees'] as int).toDouble()
          : (json['AdditionalFees'] ?? 0.0),
      subTotal: json['SubTotal'] is int
          ? (json['SubTotal'] as int).toDouble()
          : (json['SubTotal'] ?? 0.0),
      deliveryFee: json['DeliveryFee'] is int
          ? (json['DeliveryFee'] as int).toDouble()
          : (json['DeliveryFee'] ?? 0.0),
      benefits: json['Benefits'] is int
          ? (json['Benefits'] as int).toDouble()
          : (json['Benefits'] ?? 0.0),
      orderAmount: json['OrderAmount'] is int
          ? (json['OrderAmount'] as int).toDouble()
          : (json['OrderAmount'] ?? 0.0),
    );
  }

  factory Total.fromJson(Map<String, dynamic> json) {
    return Total(
      additionalFees: json['additionalFees'] is int
          ? (json['additionalFees'] as int).toDouble()
          : (json['additionalFees'] ?? 0.0),
      subTotal: json['subTotal'] is int
          ? (json['subTotal'] as int).toDouble()
          : (json['subTotal'] ?? 0.0),
      deliveryFee: json['deliveryFee'] is int
          ? (json['deliveryFee'] as int).toDouble()
          : (json['deliveryFee'] ?? 0.0),
      benefits: json['benefits'] is int
          ? (json['benefits'] as int).toDouble()
          : (json['benefits'] ?? 0.0),
      orderAmount: json['orderAmount'] is int
          ? (json['orderAmount'] as int).toDouble()
          : (json['orderAmount'] ?? 0.0),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'AdditionalFees': additionalFees,
      'SubTotal': subTotal,
      'DeliveryFee': deliveryFee,
      'Benefits': benefits,
      'OrderAmount': orderAmount,
    };
  }

  factory Total.fromMap(Map<String, dynamic> map) {
    return Total(
      additionalFees: map['additionalFees'] as double,
      subTotal: map['subTotal'] as double,
      deliveryFee: map['deliveryFee'] as double,
      benefits: map['benefits'] as double,
      orderAmount: map['orderAmount'] as double,
    );
  }

  // Construtor vazio
  factory Total.empty() {
    return Total(
      additionalFees: 0.0,
      subTotal: 0.0,
      deliveryFee: 0.0,
      benefits: 0,
      orderAmount: 0.0,
    );
  }

  String toJson() => json.encode(toMap());
}

class Payments {
  final double prepaid;
  final double pending;
  final List<PaymentMethod> methods;

  Payments({
    required this.prepaid,
    required this.pending,
    required this.methods,
  });

  factory Payments.fromKronos(Map<String, dynamic> json) {
    return Payments(
      prepaid: json['Prepaid'] is int
          ? (json['Prepaid'] as int).toDouble()
          : (json['Prepaid'] ?? 0.0),
      pending: json['Pending'] is int
          ? (json['Pending'] as int).toDouble()
          : (json['Pending'] ?? 0.0),
      methods: json['Methods'] != null
          ? (json['Methods'] as List?)
                  ?.map((i) => PaymentMethod.fromKronos(i))
                  .toList() ??
              []
          : [],
    );
  }

  factory Payments.fromJson(Map<String, dynamic> json) {
    return Payments(
      prepaid: json['prepaid'] is int
          ? (json['prepaid'] as int).toDouble()
          : (json['prepaid'] ?? 0.0),
      pending: json['pending'] is int
          ? (json['pending'] as int).toDouble()
          : (json['pending'] ?? 0.0),
      methods: json['methods'] != null
          ? (json['methods'] as List?)
                  ?.map((i) => PaymentMethod.fromJson(i))
                  .toList() ??
              []
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Prepaid': prepaid,
      'Pending': pending,
      'Methods': methods.map((x) => x.toMap()).toList(),
    };
  }

  factory Payments.fromMap(Map<String, dynamic> map) {
    return Payments(
      prepaid: map['prepaid'] as double,
      pending: map['pending'] as double,
      methods: List<PaymentMethod>.from(
        (map['methods'] as List<int>).map<PaymentMethod>(
          (x) => PaymentMethod.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  // Construtor vazio
  factory Payments.empty() {
    return Payments(
      prepaid: 0.0,
      pending: 0,
      methods: [],
    );
  }

  String toJson() => json.encode(toMap());
}

class PaymentMethod {
  final double value;
  final String currency;
  final String method;
  final bool prepaid;
  final String type;
  final CreditCard card;
  final Cash cash;

  PaymentMethod({
    required this.value,
    required this.currency,
    required this.method,
    required this.prepaid,
    required this.type,
    required this.card,
    required this.cash,
  });

  factory PaymentMethod.fromKronos(Map<String, dynamic> json) {
    return PaymentMethod(
      value: json['Value'] is int
          ? (json['Value'] as int).toDouble()
          : (json['Value'] ?? 0.0),
      currency: json['Currency'] ?? '',
      method: json['Method'] ?? '',
      prepaid: json['Prepaid'] ?? false,
      type: json['Type'] ?? '',
      card: json['Card'] != null
          ? CreditCard.fromKronos(json['Card'])
          : CreditCard.empty(),
      cash: json['Cash'] != null ? Cash.fromKronos(json['Cash']) : Cash.empty(),
    );
  }

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      value: json['value'] is int
          ? (json['value'] as int).toDouble()
          : (json['value'] ?? 0.0),
      currency: json['currency'] ?? '',
      method: json['method'] ?? '',
      prepaid: json['prepaid'] ?? false,
      type: json['type'] ?? '',
      card: json['card'] != null
          ? CreditCard.fromJson(json['card'])
          : CreditCard.empty(),
      cash: json['cash'] != null ? Cash.fromJson(json['cash']) : Cash.empty(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Value': value,
      'Currency': currency,
      'Method': method,
      'Prepaid': prepaid,
      'Type': type,
      'Card': card.toMap(),
      'Cash': cash.toMap(),
    };
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      value: map['value'] as double,
      currency: map['currency'] as String,
      method: map['method'] as String,
      prepaid: map['prepaid'] as bool,
      type: map['type'] as String,
      card: CreditCard.fromMap(map['card'] as Map<String, dynamic>),
      cash: Cash.fromMap(map['cash'] as Map<String, dynamic>),
    );
  }

  String toJson() => json.encode(toMap());
}

class Cash {
  final double? changeFor;

  Cash({
    this.changeFor,
  });

  factory Cash.fromKronos(Map<String, dynamic> json) {
    return Cash(
      changeFor: json['ChangeFor'],
    );
  }

  factory Cash.fromJson(Map<String, dynamic> json) {
    return Cash(
      changeFor: json['changeFor'],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'ChangeFor': changeFor ?? 0.0,
    };
  }

  factory Cash.fromMap(Map<String, dynamic> map) {
    return Cash(
      changeFor: map['changeFor'] as double? ?? 0.0,
    );
  }

  // Construtor vazio
  factory Cash.empty() {
    return Cash(
      changeFor: 0.0,
    );
  }

  String toJson() => json.encode(toMap());
}

class CreditCard {
  final String brand;

  CreditCard({
    required this.brand,
  });

  factory CreditCard.fromKronos(Map<String, dynamic> json) {
    return CreditCard(
      brand: json['Brand'] ?? '',
    );
  }

  factory CreditCard.fromJson(Map<String, dynamic> json) {
    return CreditCard(
      brand: json['brand'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Brand': brand,
    };
  }

  factory CreditCard.fromMap(Map<String, dynamic> map) {
    return CreditCard(
      brand: map['brand'] as String,
    );
  }

  // Construtor vazio
  factory CreditCard.empty() {
    return CreditCard(
      brand: '',
    );
  }

  String toJson() => json.encode(toMap());
}

class AdditionalFee {
  final String type;
  final String description;
  final String fullDescription;
  final double value;
  final List<Liability> liabilities;

  AdditionalFee({
    required this.type,
    required this.description,
    required this.fullDescription,
    required this.value,
    required this.liabilities,
  });

  factory AdditionalFee.fromKronos(Map<String, dynamic> json) {
    return AdditionalFee(
      type: json['Type'] ?? '',
      description: json['Description'] ?? '',
      fullDescription: json['FullDescription'] ?? '',
      value: json['Value'] is int
          ? (json['Value'] as int).toDouble()
          : (json['Value'] ?? 0.0),
      liabilities: json['Liabilities'] != null
          ? (json['Liabilities'] as List?)
                  ?.map((i) => Liability.fromKronos(i))
                  .toList() ??
              []
          : [],
    );
  }

  factory AdditionalFee.fromJson(Map<String, dynamic> json) {
    return AdditionalFee(
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      fullDescription: json['fullDescription'] ?? '',
      value: json['value'] is int
          ? (json['value'] as int).toDouble()
          : (json['value'] ?? 0.0),
      liabilities: json['liabilities'] != null
          ? (json['liabilities'] as List?)
                  ?.map((i) => Liability.fromJson(i))
                  .toList() ??
              []
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Type': type,
      'Description': description,
      'FullDescription': fullDescription,
      'Value': value,
      'Liabilities': liabilities.map((x) => x.toMap()).toList(),
    };
  }

  factory AdditionalFee.fromMap(Map<String, dynamic> map) {
    return AdditionalFee(
      type: map['type'] as String,
      description: map['description'] as String,
      fullDescription: map['fullDescription'] as String,
      value: map['value'] as double,
      liabilities: List<Liability>.from(
        (map['liabilities'] as List<int>).map<Liability>(
          (x) => Liability.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());
}

class Liability {
  final String name;
  final double percentage;

  Liability({
    required this.name,
    required this.percentage,
  });

  factory Liability.fromKronos(Map<String, dynamic> json) {
    return Liability(
      name: json['Name'] ?? '',
      percentage: json['Percentage'] is int
          ? (json['Percentage'] as int).toDouble()
          : (json['Percentage'] ?? 0.0),
    );
  }

  factory Liability.fromJson(Map<String, dynamic> json) {
    return Liability(
      name: json['name'] ?? '',
      percentage: json['percentage'] is int
          ? (json['percentage'] as int).toDouble()
          : (json['percentage'] ?? 0.0),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Name': name,
      'Percentage': percentage,
    };
  }

  factory Liability.fromMap(Map<String, dynamic> map) {
    return Liability(
      name: map['name'] as String,
      percentage: map['percentage'] as double,
    );
  }

  String toJson() => json.encode(toMap());
}

class AdditionalInfo {
  final String? origin;
  final String? cancellationReason;
  final Metadata? metadata;

  AdditionalInfo({
    this.metadata,
    this.origin,
    this.cancellationReason,
  });

  factory AdditionalInfo.fromKronos(Map<String, dynamic> json) {
    return AdditionalInfo(
      origin: json['Origin'],
      cancellationReason: json['CancellationReason'],
      metadata: json['Metadata'] != null
          ? Metadata.fromKronos(json['Metadata'])
          : null,
    );
  }

  factory AdditionalInfo.fromJson(Map<String, dynamic> json) {
    return AdditionalInfo(
      origin: json['origin'],
      cancellationReason: json['cancellationReason'],
      metadata:
          json['metadata'] != null ? Metadata.fromJson(json['metadata']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'Origin': origin ?? '',
      'CancellationReason': cancellationReason ?? '',
      'Metadata': metadata?.toMap() ?? {},
    };
  }

  factory AdditionalInfo.fromMap(Map<String, dynamic> map) {
    return AdditionalInfo(
      origin: map['origin'] as String?,
      cancellationReason: map['cancellationReason'] as String?,
      metadata: map['metadata'] != null
          ? Metadata.fromMap(map['metadata'] as Map<String, dynamic>)
          : null,
    );
  }

  String toJson() => json.encode(toMap());
}

class Metadata {
  final String? developerId;
  final String? customerEmail;
  final String? developerEmail;
  final String? deliveryProduct;
  final String? cartId;
  final String? logisticProvider;

  Metadata({
    this.developerId,
    this.customerEmail,
    this.developerEmail,
    this.deliveryProduct,
    this.cartId,
    this.logisticProvider,
  });

  factory Metadata.fromKronos(Map<String, dynamic> json) {
    return Metadata(
      developerId: json['DeveloperId'],
      customerEmail: json['CustomerEmail'],
      developerEmail: json['DeveloperEmail'],
      deliveryProduct: json['DeliveryProduct'],
      cartId: json['CartId'],
      logisticProvider: json['LogisticProvider'],
    );
  }

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      developerId: json['developerId'],
      customerEmail: json['customerEmail'],
      developerEmail: json['developerEmail'],
      deliveryProduct: json['deliveryProduct'],
      cartId: json['cartId'],
      logisticProvider: json['logisticProvider'],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'DeveloperId': developerId,
      'CustomerEmail': customerEmail,
      'DeveloperEmail': developerEmail,
      'DeliveryProduct': deliveryProduct,
      'CartId': cartId,
      'LogisticProvider': logisticProvider,
    };
  }

  factory Metadata.fromMap(Map<String, dynamic> map) {
    return Metadata(
      developerId: map['developerId'] as String,
      customerEmail: map['customerEmail'] as String,
      developerEmail: map['developerEmail'] as String,
      deliveryProduct: map['deliveryProduct'] as String,
      cartId: map['cartId'] as String,
      logisticProvider: map['logisticProvider'] as String,
    );
  }

  String toJson() => json.encode(toMap());
}
