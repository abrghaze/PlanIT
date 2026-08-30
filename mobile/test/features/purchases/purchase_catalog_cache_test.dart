import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';

void main() {
  test(
    'offline purchase cache preserves branches, variants, and owner isolation',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.utc(2026, 8, 29);
      await database.replaceMerchants('owner-a', <CachedMerchantsCompanion>[
        CachedMerchantsCompanion.insert(
          id: 'merchant-1',
          ownerId: 'owner-a',
          name: 'Market One',
          locationsJson:
              '[{"id":"branch-1","merchant_id":"merchant-1","name":"Centre","location_text":"Casablanca"}]',
          archived: false,
          version: 1,
          createdAt: now,
          updatedAt: now,
          cachedAt: now,
        ),
      ]);
      await database.replaceProducts('owner-a', <CachedProductsCompanion>[
        CachedProductsCompanion.insert(
          id: 'milk-1l',
          ownerId: 'owner-a',
          name: 'Milk',
          variantLabel: const Value('1 L'),
          sizeValue: const Value('1'),
          sizeUnit: const Value('L'),
          archived: false,
          version: 1,
          createdAt: now,
          updatedAt: now,
          cachedAt: now,
        ),
        CachedProductsCompanion.insert(
          id: 'milk-2l',
          ownerId: 'owner-a',
          name: 'Milk',
          variantLabel: const Value('2 L'),
          sizeValue: const Value('2'),
          sizeUnit: const Value('L'),
          archived: false,
          version: 1,
          createdAt: now,
          updatedAt: now,
          cachedAt: now,
        ),
      ]);
      final merchants = await database.watchMerchants('owner-a').first;
      final products = await database.watchProducts('owner-a').first;
      expect(merchants.single.locationsJson, contains('branch-1'));
      expect(products.map((item) => item.variantLabel), <String?>[
        '1 L',
        '2 L',
      ]);
      expect(await database.watchProducts('owner-b').first, isEmpty);
    },
  );
}
