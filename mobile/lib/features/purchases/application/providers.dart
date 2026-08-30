import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/database/providers.dart';
import 'package:planit_mobile/features/purchases/data/purchase_catalog_api.dart';
import 'package:planit_mobile/features/purchases/data/purchase_catalog_repository.dart';
import 'package:planit_mobile/features/purchases/domain/purchase_catalog.dart';

final purchaseCatalogRepositoryProvider = Provider<PurchaseCatalogRepository>(
  (ref) => PurchaseCatalogRepository(
    PurchaseCatalogApi(ref.watch(apiClientProvider)),
    ref.watch(appDatabaseProvider),
  ),
);

final merchantsProvider = StreamProvider<List<Merchant>>((ref) {
  final owner = ref.watch(
    authControllerProvider.select((state) => state.session?.user.id),
  );
  return owner == null
      ? Stream.value(const <Merchant>[])
      : ref.watch(purchaseCatalogRepositoryProvider).watchMerchants(owner);
});

final productsProvider = StreamProvider<List<Product>>((ref) {
  final owner = ref.watch(
    authControllerProvider.select((state) => state.session?.user.id),
  );
  return owner == null
      ? Stream.value(const <Product>[])
      : ref.watch(purchaseCatalogRepositoryProvider).watchProducts(owner);
});

final purchaseCatalogControllerProvider =
    NotifierProvider<PurchaseCatalogController, AsyncValue<void>>(
      PurchaseCatalogController.new,
    );

final class PurchaseCatalogController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);
  Future<bool> refresh() =>
      _run((repo, owner, token) => repo.refresh(owner, token));
  Future<bool> createMerchant(Map<String, Object?> payload, String operation) =>
      _run(
        (repo, owner, token) =>
            repo.createMerchant(owner, token, operation, payload),
      );
  Future<bool> createLocation(
    String merchantId,
    Map<String, Object?> payload,
    String operation,
  ) => _run(
    (repo, owner, token) =>
        repo.createLocation(owner, token, operation, merchantId, payload),
  );
  Future<bool> createProduct(Map<String, Object?> payload, String operation) =>
      _run(
        (repo, owner, token) =>
            repo.createProduct(owner, token, operation, payload),
      );
  Future<bool> _run(
    Future<void> Function(PurchaseCatalogRepository, String, String) action,
  ) async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return false;
    state = const AsyncLoading();
    try {
      await action(
        ref.read(purchaseCatalogRepositoryProvider),
        session.user.id,
        session.accessToken,
      );
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }
}
