import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';

abstract interface class OfflineFinanceStore {
  Future<List<CategoryBudget>> readBudgets(String ownerId);
  Future<void> saveBudgets(String ownerId, List<CategoryBudget> budgets);
  Future<List<QuickTransactionTemplate>> readTemplates(String ownerId);
  Future<void> saveTemplates(
    String ownerId,
    List<QuickTransactionTemplate> templates,
  );
  Future<void> clearOwnerData(String ownerId);
}

final class SecureOfflineFinanceStore implements OfflineFinanceStore {
  SecureOfflineFinanceStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _budgetPrefix = 'planit.offline.budgets.v1.';
  static const _templatePrefix = 'planit.offline.templates.v1.';
  final FlutterSecureStorage _storage;

  @override
  Future<List<CategoryBudget>> readBudgets(String ownerId) async {
    final values = await _readList(_budgetPrefix + ownerId);
    return values.map(CategoryBudget.fromJson).toList(growable: false)
      ..sort((left, right) => left.categoryId.compareTo(right.categoryId));
  }

  @override
  Future<void> saveBudgets(String ownerId, List<CategoryBudget> budgets) {
    return _writeList(
      _budgetPrefix + ownerId,
      budgets.map((budget) => budget.toJson()).toList(growable: false),
    );
  }

  @override
  Future<List<QuickTransactionTemplate>> readTemplates(String ownerId) async {
    final values = await _readList(_templatePrefix + ownerId);
    return values.map(QuickTransactionTemplate.fromJson).toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
  }

  @override
  Future<void> saveTemplates(
    String ownerId,
    List<QuickTransactionTemplate> templates,
  ) {
    return _writeList(
      _templatePrefix + ownerId,
      templates.map((template) => template.toJson()).toList(growable: false),
    );
  }

  @override
  Future<void> clearOwnerData(String ownerId) {
    return Future.wait<void>(<Future<void>>[
      _storage.delete(key: _budgetPrefix + ownerId),
      _storage.delete(key: _templatePrefix + ownerId),
    ]);
  }

  Future<List<Map<String, Object?>>> _readList(String key) async {
    final encoded = await _storage.read(key: key);
    if (encoded == null) return const <Map<String, Object?>>[];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const <Map<String, Object?>>[];
      return decoded
          .whereType<Map>()
          .map((value) => Map<String, Object?>.from(value))
          .toList(growable: false);
    } on Object {
      await _storage.delete(key: key);
      return const <Map<String, Object?>>[];
    }
  }

  Future<void> _writeList(String key, List<Map<String, Object?>> values) {
    return _storage.write(key: key, value: jsonEncode(values));
  }
}
