import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/data/auth_api.dart';
import 'package:planit_mobile/core/auth/data/auth_remote_data_source.dart';
import 'package:planit_mobile/core/auth/data/auth_repository.dart';
import 'package:planit_mobile/core/auth/data/secure_token_store.dart';
import 'package:planit_mobile/core/auth/data/token_store.dart';
import 'package:planit_mobile/core/database/providers.dart';
import 'package:planit_mobile/core/network/api_client.dart';

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
      return DefaultAuthRepository(
        remote: ref.watch(authRemoteDataSourceProvider),
        tokenStore: ref.watch(tokenStoreProvider),
        clearOwnerData: database.clearOwnerData,
      );
    });
