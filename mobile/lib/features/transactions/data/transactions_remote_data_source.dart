import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

final class RemoteOperationResult {
  const RemoteOperationResult({required this.primary, this.secondary});

  final LedgerTransaction primary;
  final LedgerTransaction? secondary;
}

abstract interface class TransactionsRemoteDataSource {
  Future<List<LedgerTransaction>> fetchTransactions({
    required String ownerId,
    required String accessToken,
  });

  Future<RemoteOperationResult> execute({
    required String accessToken,
    required PendingOperation operation,
  });
}
