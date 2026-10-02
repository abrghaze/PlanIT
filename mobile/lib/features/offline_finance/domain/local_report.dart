import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

final class LocalReport {
  const LocalReport({
    required this.currency,
    required this.grossSpending,
    required this.refunds,
    required this.income,
    required this.categories,
    required this.sources,
    required this.pendingCount,
    required this.omittedCurrencies,
    required this.dailySpending,
  });

  final String currency;
  final Money grossSpending;
  final Money refunds;
  final Money income;
  final Map<String, Money> categories;
  final List<LedgerTransaction> sources;
  final int pendingCount;
  final Set<String> omittedCurrencies;
  final Map<int, Money> dailySpending;
  Money get netSpending => grossSpending - refunds;
  Money get remainingIncome => income - netSpending;
}

/// Calendar boundaries use the phone's time zone. Keep currencies separate
/// rather than using stale or unavailable exchange rates.
LocalReport buildLocalReport({
  required Iterable<LedgerTransaction> transactions,
  required String currency,
  required DateTime month,
  DateTime? asOf,
}) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  var gross = Money.zero(currency);
  var refunds = Money.zero(currency);
  var income = Money.zero(currency);
  var pending = 0;
  final categories = <String, Money>{};
  final daily = <int, Money>{};
  final sources = <LedgerTransaction>[];
  final omitted = <String>{};
  for (final row in transactions) {
    final date = row.occurredAt.toLocal();
    if (date.isBefore(start) ||
        !date.isBefore(end) ||
        (asOf != null && date.isAfter(asOf))) {
      continue;
    }
    if (row.hasPendingWork &&
        (countsInLocalReports(row) || row.pendingAction == 'REVERSE')) {
      pending++;
    }
    if (!countsInLocalReports(row)) continue;
    if (!row.type.isSpending &&
        !row.type.isIncome &&
        row.type != TransactionType.refund) {
      continue;
    }
    if (row.amount.currency != currency) {
      omitted.add(row.amount.currency);
      continue;
    }
    sources.add(row);
    if (row.type.isIncome) {
      income += row.amount;
    } else {
      final isRefund = row.type == TransactionType.refund;
      final amount = isRefund ? -row.amount : row.amount;
      if (isRefund) {
        refunds += row.amount;
      } else {
        gross += row.amount;
      }
      final category = row.categoryId ?? '';
      categories.update(
        category,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
      daily.update(date.day, (value) => value + amount, ifAbsent: () => amount);
    }
  }
  sources.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return LocalReport(
    currency: currency,
    grossSpending: gross,
    refunds: refunds,
    income: income,
    categories: Map.unmodifiable(categories),
    sources: List.unmodifiable(sources),
    pendingCount: pending,
    omittedCurrencies: Set.unmodifiable(omitted),
    dailySpending: Map.unmodifiable(daily),
  );
}
