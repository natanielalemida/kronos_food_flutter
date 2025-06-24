class CatalogModel {
  final String id;
  final String merchantId;
  final List<CategoryModel> categories;
  
  CatalogModel({
    required this.id,
    required this.merchantId,
    required this.categories,
  });
  
  factory CatalogModel.fromJson(Map<String, dynamic> json) {
    return CatalogModel(
      id: json['id'] ?? '',
      merchantId: json['merchantId'] ?? '',
      categories: (json['categories'] as List<dynamic>?)
              ?.map((category) => CategoryModel.fromJson(category))
              .toList() ??
          [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'categories': categories.map((category) => category.toJson()).toList(),
    };
  }
}

class CategoryModel {
  final String id;
  final String name;
  final String externalCode;
  final int order;
  final bool enabled;
  final List<ProductModel> products;
  
  CategoryModel({
    required this.id,
    required this.name,
    required this.externalCode,
    required this.order,
    this.enabled = true,
    required this.products,
  });
  
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      externalCode: json['externalCode'] ?? '',
      order: json['order'] ?? 0,
      enabled: json['enabled'] ?? true,
      products: (json['products'] as List<dynamic>?)
              ?.map((product) => ProductModel.fromJson(product))
              .toList() ??
          [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'externalCode': externalCode,
      'order': order,
      'enabled': enabled,
      'products': products.map((product) => product.toJson()).toList(),
    };
  }
}

class ProductModel {
  final String id;
  final String name;
  final String description;
  final String externalCode;
  final double price;
  final bool enabled;
  final int order;
  final List<String> images;
  final List<OptionGroupModel> optionGroups;
  
  ProductModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.externalCode,
    required this.price,
    this.enabled = true,
    required this.order,
    this.images = const [],
    this.optionGroups = const [],
  });
  
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      externalCode: json['externalCode'] ?? '',
      price: json['price'] != null ? json['price'].toDouble() : 0.0,
      enabled: json['enabled'] ?? true,
      order: json['order'] ?? 0,
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      optionGroups: (json['optionGroups'] as List<dynamic>?)
              ?.map((group) => OptionGroupModel.fromJson(group))
              .toList() ??
          [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'externalCode': externalCode,
      'price': price,
      'enabled': enabled,
      'order': order,
      'images': images,
      'optionGroups': optionGroups.map((group) => group.toJson()).toList(),
    };
  }
}

class OptionGroupModel {
  final String id;
  final String name;
  final String externalCode;
  final int minOptions;
  final int maxOptions;
  final int order;
  final List<OptionModel> options;
  
  OptionGroupModel({
    required this.id,
    required this.name,
    required this.externalCode,
    required this.minOptions,
    required this.maxOptions,
    required this.order,
    required this.options,
  });
  
  factory OptionGroupModel.fromJson(Map<String, dynamic> json) {
    return OptionGroupModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      externalCode: json['externalCode'] ?? '',
      minOptions: json['minOptions'] ?? 0,
      maxOptions: json['maxOptions'] ?? 1,
      order: json['order'] ?? 0,
      options: (json['options'] as List<dynamic>?)
              ?.map((option) => OptionModel.fromJson(option))
              .toList() ??
          [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'externalCode': externalCode,
      'minOptions': minOptions,
      'maxOptions': maxOptions,
      'order': order,
      'options': options.map((option) => option.toJson()).toList(),
    };
  }
}

class OptionModel {
  final String id;
  final String name;
  final String externalCode;
  final double price;
  final int order;
  final bool enabled;
  
  OptionModel({
    required this.id,
    required this.name,
    required this.externalCode,
    required this.price,
    required this.order,
    this.enabled = true,
  });
  
  factory OptionModel.fromJson(Map<String, dynamic> json) {
    return OptionModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      externalCode: json['externalCode'] ?? '',
      price: json['price'] != null ? json['price'].toDouble() : 0.0,
      order: json['order'] ?? 0,
      enabled: json['enabled'] ?? true,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'externalCode': externalCode,
      'price': price,
      'order': order,
      'enabled': enabled,
    };
  }
} 