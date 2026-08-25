import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/database/providers.dart';
import 'package:planit_mobile/features/accounts/data/accounts_api.dart';
import 'package:planit_mobile/features/accounts/data/accounts_local_data_source.dart';
import 'package:planit_mobile/features/accounts/data/accounts_remote_data_source.dart';
import 'package:planit_mobile/features/accounts/data/accounts_repository.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';

final Provider<AccountsRemoteDataSource> accountsRemoteDataSourceProvider =
    Provider<AccountsRemoteDataSource>(
      (ref) => AccountsApi(ref.watch(apiClientProvider)),
    );

final Provider<AccountsLocalDataSource> accountsLocalDataSourceProvider =
    Provider<AccountsLocalDataSource>(
      (ref) => AccountsLocalDataSource(ref.watch(appDatabaseProvider)),
    );

final Provider<AccountsRepository> accountsRepositoryProvider =
    Provider<AccountsRepository>(
      (ref) => DefaultAccountsRepository(
        remote: ref.watch(accountsRemoteDataSourceProvider),
        local: ref.watch(accountsLocalDataSourceProvider),
      ),
    );

final StreamProvider<List<Account>> accountsProvider =
    StreamProvider<List<Account>>((ref) {
      final ownerId = ref.watch(
        authControllerProvider.select((state) => state.session?.user.id),
      );
      if (ownerId == null) {
        return Stream<List<Account>>.value(const <Account>[]);
      }
      return ref.watch(accountsRepositoryProvider).watch(ownerId);
    });
