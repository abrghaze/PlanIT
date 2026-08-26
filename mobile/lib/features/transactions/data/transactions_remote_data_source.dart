import 'package:planit_mobile/features/transactions/domain/outbox_operation.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

final class RemoteOperationResult {
  RemoteOperationResult({required List<LedgerTransaction> transactions})
    : transactions = List<LedgerTransaction>.unmodifiable(transactions) {
    if (transactions.isEmpty) {
      throw ArgumentError.value(
        transactions,
        'transactions',
        'A remote operation must return at least one transaction.',
      );
    }
  }

  final List<LedgerTransaction> transactions;
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
