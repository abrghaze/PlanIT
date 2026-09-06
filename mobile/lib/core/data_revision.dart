import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single revision shared by server-backed financial projections.
///
/// Successful ledger/account synchronization increments this value so every
/// dashboard derived from those records is recomputed from the same source.
final financialDataRevisionProvider =
    NotifierProvider<FinancialDataRevision, int>(FinancialDataRevision.new);

final class FinancialDataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void markChanged() => state += 1;
}
