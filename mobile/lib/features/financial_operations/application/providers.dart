import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/features/financial_operations/data/financial_operations_api.dart';
import 'package:planit_mobile/features/financial_operations/data/financial_operations_remote_data_source.dart';
import 'package:planit_mobile/features/financial_operations/data/financial_operations_repository.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/data/transactions_repository.dart';
import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';

final Provider<FinancialOperationsRemoteDataSource>
financialOperationsRemoteDataSourceProvider =
    Provider<FinancialOperationsRemoteDataSource>(
      (ref) => FinancialOperationsApi(ref.watch(apiClientProvider)),
    );

final Provider<FinancialOperationsRepository>
financialOperationsRepositoryProvider = Provider<FinancialOperationsRepository>(
  (ref) => DefaultFinancialOperationsRepository(
    remote: ref.watch(financialOperationsRemoteDataSourceProvider),
    transactions: ref.watch(transactionsRepositoryProvider),
  ),
);

final StreamProvider<List<PendingOperation>> pendingOperationsProvider =
    StreamProvider<List<PendingOperation>>((ref) {
      final ownerId = ref.watch(
        authControllerProvider.select((state) => state.session?.user.id),
      );
      if (ownerId == null) {
        return Stream<List<PendingOperation>>.value(const <PendingOperation>[]);
      }
      return ref
          .watch(transactionsRepositoryProvider)
          .watchPendingOperations(ownerId);
    });
