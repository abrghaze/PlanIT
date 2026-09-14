import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/data/auth_api.dart';
import 'package:planit_mobile/core/auth/data/auth_remote_data_source.dart';
import 'package:planit_mobile/core/auth/data/auth_repository.dart';
import 'package:planit_mobile/core/auth/data/secure_token_store.dart';
import 'package:planit_mobile/core/auth/data/token_store.dart';
import 'package:planit_mobile/core/database/providers.dart';
import 'package:planit_mobile/core/network/api_client.dart';
import 'package:planit_mobile/features/offline_finance/data/offline_finance_store.dart';

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(),
);

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (ref) => SecureTokenStore(),
);

final Provider<AuthRemoteDataSource> authRemoteDataSourceProvider =
    Provider<AuthRemoteDataSource>(
      (ref) => AuthApi(ref.watch(apiClientProvider)),
    );

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
      final database = ref.watch(appDatabaseProvider);
      final offlineFinanceStore = SecureOfflineFinanceStore();
      return DefaultAuthRepository(
        remote: ref.watch(authRemoteDataSourceProvider),
        tokenStore: ref.watch(tokenStoreProvider),
        clearOwnerData: (ownerId) async {
          await Future.wait<void>(<Future<void>>[
            database.clearOwnerData(ownerId),
            offlineFinanceStore.clearOwnerData(ownerId),
          ]);
        },
      );
    });
