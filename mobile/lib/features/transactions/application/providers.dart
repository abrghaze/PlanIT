import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/database/providers.dart';
import 'package:planit_mobile/features/transactions/data/catalog_api.dart';
import 'package:planit_mobile/features/transactions/data/catalog_local_data_source.dart';
import 'package:planit_mobile/features/transactions/data/catalog_remote_data_source.dart';
import 'package:planit_mobile/features/transactions/data/catalog_repository.dart';
import 'package:planit_mobile/features/transactions/data/transactions_api.dart';
import 'package:planit_mobile/features/transactions/data/transactions_local_data_source.dart';
import 'package:planit_mobile/features/transactions/data/transactions_remote_data_source.dart';
import 'package:planit_mobile/features/transactions/data/transactions_repository.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

final Provider<CatalogRemoteDataSource> catalogRemoteDataSourceProvider =
    Provider<CatalogRemoteDataSource>(
      (ref) => CatalogApi(ref.watch(apiClientProvider)),
    );

final Provider<CatalogLocalDataSource> catalogLocalDataSourceProvider =
    Provider<CatalogLocalDataSource>(
      (ref) => CatalogLocalDataSource(ref.watch(appDatabaseProvider)),
    );

final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>(
      (ref) => DefaultCatalogRepository(
        remote: ref.watch(catalogRemoteDataSourceProvider),
        local: ref.watch(catalogLocalDataSourceProvider),
      ),
    );

final Provider<TransactionsRemoteDataSource>
transactionsRemoteDataSourceProvider = Provider<TransactionsRemoteDataSource>(
  (ref) => TransactionsApi(ref.watch(apiClientProvider)),
);

final Provider<TransactionsLocalDataSource>
transactionsLocalDataSourceProvider = Provider<TransactionsLocalDataSource>(
  (ref) => TransactionsLocalDataSource(ref.watch(appDatabaseProvider)),
);

final Provider<TransactionsRepository> transactionsRepositoryProvider =
    Provider<TransactionsRepository>(
      (ref) => DefaultTransactionsRepository(
        remote: ref.watch(transactionsRemoteDataSourceProvider),
        local: ref.watch(transactionsLocalDataSourceProvider),
      ),
    );

final StreamProvider<List<LedgerTransaction>> transactionsProvider =
    StreamProvider<List<LedgerTransaction>>((ref) {
      final ownerId = ref.watch(
        authControllerProvider.select((state) => state.session?.user.id),
      );
      if (ownerId == null) {
        return Stream<List<LedgerTransaction>>.value(
          const <LedgerTransaction>[],
        );
      }
      return ref.watch(transactionsRepositoryProvider).watch(ownerId);
    });

final StreamProvider<List<TransactionCategory>> transactionCategoriesProvider =
    StreamProvider<List<TransactionCategory>>((ref) {
      final ownerId = ref.watch(
        authControllerProvider.select((state) => state.session?.user.id),
      );
      if (ownerId == null) {
        return Stream<List<TransactionCategory>>.value(
          const <TransactionCategory>[],
        );
      }
      return ref.watch(catalogRepositoryProvider).watchCategories(ownerId);
    });

final StreamProvider<List<TransactionTag>> transactionTagsProvider =
    StreamProvider<List<TransactionTag>>((ref) {
      final ownerId = ref.watch(
        authControllerProvider.select((state) => state.session?.user.id),
      );
      if (ownerId == null) {
        return Stream<List<TransactionTag>>.value(const <TransactionTag>[]);
      }
      return ref.watch(catalogRepositoryProvider).watchTags(ownerId);
    });

final StreamProvider<int> pendingTransactionCountProvider = StreamProvider<int>(
  (ref) {
    final ownerId = ref.watch(
      authControllerProvider.select((state) => state.session?.user.id),
    );
    if (ownerId == null) {
      return Stream<int>.value(0);
    }
    return ref.watch(transactionsRepositoryProvider).watchPendingCount(ownerId);
  },
);
