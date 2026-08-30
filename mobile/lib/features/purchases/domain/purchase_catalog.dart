final class MerchantLocation {
  const MerchantLocation({
    required this.id,
    required this.merchantId,
    required this.name,
    this.locationText,
  });
  final String id;
  final String merchantId;
  final String name;
  final String? locationText;
  factory MerchantLocation.fromJson(Map<String, Object?> json) =>
      MerchantLocation(
        id: json['id']! as String,
        merchantId: json['merchant_id']! as String,
        name: json['name']! as String,
        locationText: json['location_text'] as String?,
      );
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'merchant_id': merchantId,
    'name': name,
    'location_text': locationText,
  };
}

final class Merchant {
  const Merchant({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.notes,
    required this.locations,
    required this.archived,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String name;
  final String? categoryId;
  final String? notes;
  final List<MerchantLocation> locations;
  final bool archived;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  bool get active => !archived;
  factory Merchant.fromJson(Map<String, Object?> json) => Merchant(
    id: json['id']! as String,
    name: json['name']! as String,
    categoryId: json['category_id'] as String?,
    notes: json['notes'] as String?,
    locations: (json['locations']! as List)
        .map(
          (value) => MerchantLocation.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
        )
        .toList(growable: false),
    archived: json['archived']! as bool,
    version: json['version']! as int,
    createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
  );
}

final class Product {
  const Product({
    required this.id,
    required this.parentProductId,
    required this.name,
    required this.brand,
    required this.variantLabel,
    required this.sizeValue,
    required this.sizeUnit,
    required this.barcode,
    required this.categoryId,
    required this.defaultMerchantId,
    required this.notes,
    required this.archived,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String? parentProductId;
  final String name;
  final String? brand;
  final String? variantLabel;
  final String? sizeValue;
  final String? sizeUnit;
  final String? barcode;
  final String? categoryId;
  final String? defaultMerchantId;
  final String? notes;
  final bool archived;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  bool get active => !archived;
  String get displayName => [name, ?brand, ?variantLabel].join(' · ');
  factory Product.fromJson(Map<String, Object?> json) => Product(
    id: json['id']! as String,
    parentProductId: json['parent_product_id'] as String?,
    name: json['name']! as String,
    brand: json['brand'] as String?,
    variantLabel: json['variant_label'] as String?,
    sizeValue: json['size_value']?.toString(),
    sizeUnit: json['size_unit'] as String?,
    barcode: json['barcode'] as String?,
    categoryId: json['category_id'] as String?,
    defaultMerchantId: json['default_merchant_id'] as String?,
    notes: json['notes'] as String?,
    archived: json['archived']! as bool,
    version: json['version']! as int,
    createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
  );
}
