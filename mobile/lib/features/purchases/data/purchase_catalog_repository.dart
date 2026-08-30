import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/features/purchases/data/purchase_catalog_api.dart';
import 'package:planit_mobile/features/purchases/domain/purchase_catalog.dart';

final class PurchaseCatalogRepository {
  const PurchaseCatalogRepository(this._api, this._database);
  final PurchaseCatalogApi _api;
  final AppDatabase _database;

  Stream<List<Merchant>> watchMerchants(String ownerId) => _database
      .watchMerchants(ownerId)
      .map(
        (rows) => rows
            .map(
              (row) => Merchant(
                id: row.id,
                name: row.name,
                categoryId: row.categoryId,
                notes: row.notes,
                locations: (jsonDecode(row.locationsJson) as List)
                    .map(
                      (value) => MerchantLocation.fromJson(
                        Map<String, Object?>.from(value as Map),
                      ),
                    )
                    .toList(growable: false),
                archived: row.archived,
                version: row.version,
                createdAt: row.createdAt.toUtc(),
                updatedAt: row.updatedAt.toUtc(),
              ),
            )
            .toList(growable: false),
      );
  Stream<List<Product>> watchProducts(String ownerId) => _database
      .watchProducts(ownerId)
      .map(
        (rows) => rows
            .map(
              (row) => Product(
                id: row.id,
                parentProductId: row.parentProductId,
                name: row.name,
                brand: row.brand,
                variantLabel: row.variantLabel,
                sizeValue: row.sizeValue,
                sizeUnit: row.sizeUnit,
                barcode: row.barcode,
                categoryId: row.categoryId,
                defaultMerchantId: row.defaultMerchantId,
                notes: row.notes,
                archived: row.archived,
                version: row.version,
                createdAt: row.createdAt.toUtc(),
                updatedAt: row.updatedAt.toUtc(),
              ),
            )
            .toList(growable: false),
      );

  Future<void> refresh(String ownerId, String token) async {
    final values = await Future.wait<Object>([
      _api.merchants(token),
      _api.products(token),
    ]);
    final now = DateTime.now().toUtc();
    final merchants = values[0] as List<Merchant>;
    final products = values[1] as List<Product>;
    await _database.replaceMerchants(
      ownerId,
      merchants.map((value) => _merchantRow(value, ownerId, now)).toList(),
    );
    await _database.replaceProducts(
      ownerId,
      products.map((value) => _productRow(value, ownerId, now)).toList(),
    );
  }

  Future<void> createMerchant(
    String ownerId,
    String token,
    String operation,
    Map<String, Object?> payload,
  ) async {
    final value = await _api.createMerchant(token, operation, payload);
    await _database.upsertMerchant(
      _merchantRow(value, ownerId, DateTime.now().toUtc()),
    );
  }

  Future<void> createLocation(
    String ownerId,
    String token,
    String operation,
    String merchantId,
    Map<String, Object?> payload,
  ) async {
    final value = await _api.createLocation(
      token,
      operation,
      merchantId,
      payload,
    );
    await _database.upsertMerchant(
      _merchantRow(value, ownerId, DateTime.now().toUtc()),
    );
  }

  Future<void> createProduct(
    String ownerId,
    String token,
    String operation,
    Map<String, Object?> payload,
  ) async {
    final value = await _api.createProduct(token, operation, payload);
    await _database.upsertProduct(
      _productRow(value, ownerId, DateTime.now().toUtc()),
    );
  }

  static CachedMerchantsCompanion _merchantRow(
    Merchant value,
    String ownerId,
    DateTime now,
  ) => CachedMerchantsCompanion(
    id: Value(value.id),
    ownerId: Value(ownerId),
    name: Value(value.name),
    categoryId: Value(value.categoryId),
    notes: Value(value.notes),
    locationsJson: Value(
      jsonEncode(value.locations.map((x) => x.toJson()).toList()),
    ),
    archived: Value(value.archived),
    version: Value(value.version),
    createdAt: Value(value.createdAt),
    updatedAt: Value(value.updatedAt),
    cachedAt: Value(now),
  );
  static CachedProductsCompanion _productRow(
    Product value,
    String ownerId,
    DateTime now,
  ) => CachedProductsCompanion(
    id: Value(value.id),
    ownerId: Value(ownerId),
    parentProductId: Value(value.parentProductId),
    name: Value(value.name),
    brand: Value(value.brand),
    variantLabel: Value(value.variantLabel),
    sizeValue: Value(value.sizeValue),
    sizeUnit: Value(value.sizeUnit),
    barcode: Value(value.barcode),
    categoryId: Value(value.categoryId),
    defaultMerchantId: Value(value.defaultMerchantId),
    notes: Value(value.notes),
    archived: Value(value.archived),
    version: Value(value.version),
    createdAt: Value(value.createdAt),
    updatedAt: Value(value.updatedAt),
    cachedAt: Value(now),
  );
}
