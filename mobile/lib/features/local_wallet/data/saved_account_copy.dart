import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/data/accounts_local_data_source.dart';
import 'package:planit_mobile/features/local_wallet/domain/wallet.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';
import 'package:planit_mobile/features/transactions/data/transactions_local_data_source.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

/// Creates an independent local copy from already-downloaded records. Neither
/// canonical balances nor the original owner's outbox are modified.
Future<Wallet> copySavedAccount(
  AppDatabase db,
  String owner,
  String currency,
) => db.transaction(() async {
  final accounts = await AccountsLocalDataSource(db).read(owner);
  final rows = await TransactionsLocalDataSource(db).watch(owner).first;
  final categories = await db.watchCategories(owner).first;
  final prefix = 'copy-$owner-';
  final deltas = buildPendingAccountBalances(rows);
  final byId = {for (final a in accounts) a.id: a};
  final now = DateTime.now();
  final entries = <WalletEntry>[
    for (final r in rows)
      if (byId.containsKey(r.accountId) &&
          countsInLocalReports(r) &&
          !r.occurredAt.isAfter(now) &&
          (r.type.isSpending ||
              r.type.isIncome ||
              r.type == TransactionType.refund))
        WalletEntry(
          id: prefix + r.id,
          accountId: prefix + r.accountId,
          type: r.type == TransactionType.transferFee
              ? TransactionType.expense
              : r.type,
          amount: r.amount,
          date: r.occurredAt,
          categoryId: r.categoryId == null ? null : prefix + r.categoryId!,
          note: r.note ?? r.counterparty ?? '',
        ),
  ];
  return Wallet(
    currency: currency,
    entries: entries,
    categories: {
      for (final c in categories) prefix + c.id: c.name,
      for (final r in entries)
        if (r.categoryId != null &&
            !categories.any((c) => prefix + c.id == r.categoryId))
          r.categoryId!: 'Archived category',
    },
    budgets: [],
    goals: [],
    accounts: [
      for (final a in accounts)
        WalletAccount(
          id: prefix + a.id,
          name: a.name,
          opening:
              a.calculatedBalance +
              (deltas[a.id]?.delta ?? Money.zero(a.currency)) -
              entries
                  .where((r) => r.accountId == prefix + a.id)
                  .fold(
                    Money.zero(a.currency),
                    (sum, r) => sum + (r.inflow ? r.amount : -r.amount),
                  ),
        ),
    ],
  );
});
