import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/database/providers.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/core/money/money_format.dart';
import 'package:planit_mobile/features/local_wallet/data/saved_account_copy.dart';
import 'package:planit_mobile/features/local_wallet/data/wallet_backup.dart';
import 'package:planit_mobile/features/local_wallet/data/wallet_store.dart';
import 'package:planit_mobile/features/local_wallet/domain/wallet.dart';
import 'package:planit_mobile/features/local_wallet/presentation/wallet_editor.dart';
import 'package:planit_mobile/features/offline_finance/application/providers.dart';
import 'package:planit_mobile/features/offline_finance/domain/report_period.dart';
import 'package:planit_mobile/features/offline_finance/presentation/local_insights_view.dart';
import 'package:planit_mobile/features/settings/data/privacy_file_saver.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});
  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  int _tab = 0;
  String _query = '';
  TransactionType? _filter;
  ReportPeriod? _activityRange;
  bool _fileBusy = false;
  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      _message(
        e is FormatException
            ? e.message.toString()
            : 'Could not save. Please try again.',
      );
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _detail(Wallet w, WalletEntry e) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  e.type.label,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(e.amount.toDisplayString()),
                Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatFullDate(e.date.toLocal()),
                ),
                Text(w.accounts.firstWhere((a) => a.id == e.accountId).name),
                Text(w.categories[e.categoryId] ?? 'Uncategorized'),
                if (e.note.isNotEmpty) Text(e.note),
                if (!e.type.isTransfer)
                  TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit transaction'),
                    onPressed: () {
                      Navigator.pop(sheet);
                      editWallet(context, w, 'entry', record: e.toJson());
                    },
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    e.type.isTransfer
                        ? 'Delete transfer'
                        : 'Delete transaction',
                  ),
                  onPressed: () async {
                    Navigator.pop(sheet);
                    if (!await _confirm(
                      'Delete this record?',
                      'Balances and reports will update. You can undo the deletion.',
                    )) {
                      return;
                    }
                    await _run(() async {
                      await ref
                          .read(walletStoreProvider)
                          .setDeleted(e.id, true);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Record deleted'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () => _run(
                              () => ref
                                  .read(walletStoreProvider)
                                  .setDeleted(e.id, false),
                            ),
                          ),
                        ),
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _entry(Wallet w, WalletEntry e) => Card(
    child: ListTile(
      leading: Icon(
        e.inflow ? Icons.south_west : Icons.north_east,
        color: e.inflow ? Colors.teal : Colors.deepOrange,
      ),
      title: Text(
        e.note.isEmpty ? w.categories[e.categoryId] ?? e.type.label : e.note,
      ),
      subtitle: Text(
        '${e.type.label} · ${MaterialLocalizations.of(context).formatShortDate(e.date.toLocal())}\n${e.amount.toDisplayString()}',
      ),
      isThreeLine: true,
      onTap: () => _detail(w, e),
    ),
  );
  Widget _planning(Wallet w, ReportPeriod period, String currency) {
    final now = ref.watch(localClockProvider);
    final relevant = w.budgets.where((b) {
      final month = DateTime.parse('${b.month}-01');
      return b.limit.currency == currency &&
          month.isBefore(period.end) &&
          DateTime(month.year, month.month + 1).isAfter(period.start);
    }).toList()..sort((a, b) => a.month.compareTo(b.month));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'Budgets & savings goals',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Budget limits cover their full calendar month. Savings goals show current progress.',
        ),
        for (final b in relevant)
          Builder(
            builder: (context) {
              final p = ReportPeriod.at(
                ReportSpan.month,
                DateTime.parse('${b.month}-01'),
              );
              final report = buildPeriodReport(
                transactions: w.entries.map((e) => e.toLedger()),
                currency: currency,
                period: p,
                now: now,
              ).current;
              final raw =
                  report.categories[b.categoryId] ?? Money.zero(currency);
              final spent = raw.scaledAmount.isNegative
                  ? Money.zero(currency)
                  : raw;
              return _progress(
                w.categories[b.categoryId] ?? 'Category',
                spent,
                b.limit,
                '${b.month} · ${spent.scaledAmount > b.limit.scaledAmount ? 'Over by ${(spent - b.limit).toDisplayString()}' : 'Remaining ${(b.limit - spent).toDisplayString()}'}',
                () => editWallet(context, w, 'budget', record: b.toJson()),
              );
            },
          ),
        for (final g in w.goals.where((g) => g.target.currency == currency))
          _progress(
            g.name,
            w.goalSaved(g),
            g.target,
            g.accountId == null
                ? 'Manually allocated savings'
                : 'Linked account balance',
            () => editWallet(context, w, 'goal', record: g.toJson()),
          ),
        if (relevant.isEmpty &&
            w.goals.where((g) => g.target.currency == currency).isEmpty)
          TextButton(
            onPressed: () => setState(() => _tab = 2),
            child: const Text('Add a budget or savings goal'),
          ),
      ],
    );
  }

  Widget _progress(
    String name,
    Money value,
    Money target,
    String detail,
    VoidCallback action,
  ) => Card(
    child: InkWell(
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${value.toDisplayString()} / ${target.toDisplayString()}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value:
                  (value.scaledAmount.toDouble() /
                          target.scaledAmount.toDouble())
                      .clamp(0, 1),
            ),
            const SizedBox(height: 8),
            Text(detail),
          ],
        ),
      ),
    ),
  );
  Widget _dashboard(Wallet w) {
    final now = ref.watch(localClockProvider);
    final currencies = {
      w.currency,
      for (final a in w.accounts) a.opening.currency,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your money, clearly',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Current balances · separate from income and spending in the selected period.',
        ),
        for (final currency in currencies)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$currency balance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    w.accounts
                        .where((a) => a.opening.currency == currency)
                        .fold(
                          Money.zero(currency),
                          (m, a) => m + w.balance(a, now: now),
                        )
                        .toDisplayString(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  for (final a in w.accounts.where(
                    (a) => a.opening.currency == currency,
                  ))
                    Text(
                      '${a.name}: ${w.balance(a, now: now).toDisplayString()}',
                    ),
                ],
              ),
            ),
          ),
        if (w.accounts.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Start with your cash or savings account and its opening balance. No login is needed.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => editWallet(context, w, 'account'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create your first account'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        ReportDashboard(
          rows: w.entries.map((e) => e.toLedger()).toList(),
          names: w.categories,
          currency: w.currency,
          now: now,
          onEntry: (row) =>
              _detail(w, w.entries.firstWhere((e) => e.id == row.id)),
          planning: (p, c) => _planning(w, p, c),
        ),
      ],
    );
  }

  Future<void> _activityDates() async {
    final now = DateTime.now();
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: now,
    );
    if (dates != null && mounted) {
      setState(
        () => _activityRange = ReportPeriod(
          ReportSpan.custom,
          dates.start,
          DateTime(dates.end.year, dates.end.month, dates.end.day + 1),
        ),
      );
    }
  }

  Widget _activity(Wallet w) {
    final list =
        w.entries
            .where(
              (e) =>
                  !e.deleted &&
                  (_filter == null || e.type == _filter) &&
                  (_activityRange == null ||
                      _activityRange!.contains(e.date)) &&
                  ('${e.note} ${w.categories[e.categoryId] ?? ''} ${w.accounts.firstWhere((a) => a.id == e.accountId).name} ${e.amount.toApiString()}')
                      .toLowerCase()
                      .contains(_query.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Transactions', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search note, category, account or amount',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (q) => setState(() => _query = q),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TransactionType>(
          isExpanded: true,
          initialValue: _filter,
          decoration: const InputDecoration(labelText: 'Transaction type'),
          items: [
            const DropdownMenuItem<TransactionType>(
              value: null,
              child: Text('All types'),
            ),
            for (final t in [
              TransactionType.expense,
              TransactionType.income,
              TransactionType.refund,
              TransactionType.transferOut,
              TransactionType.transferIn,
            ])
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (t) => setState(() => _filter = t),
        ),
        Wrap(
          children: [
            TextButton.icon(
              onPressed: _activityDates,
              icon: const Icon(Icons.date_range),
              label: const Text('Filter dates'),
            ),
            if (_activityRange != null)
              TextButton(
                onPressed: () => setState(() => _activityRange = null),
                child: const Text('Clear dates'),
              ),
          ],
        ),
        Text('${list.length} records'),
        for (final e in list) _entry(w, e),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No matching transactions. Add income or an expense to begin.',
            ),
          ),
      ],
    );
  }

  Widget _manage(Wallet w) {
    Widget heading(String name, String kind) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          TextButton.icon(
            onPressed: () => editWallet(context, w, kind),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
    Widget record(
      String name,
      String detail,
      String kind,
      Map<String, Object?> json,
      Future<void> Function() remove,
    ) => Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(detail),
        onTap: () => editWallet(context, w, kind, record: json),
        trailing: IconButton(
          tooltip: 'Delete $name',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            if (await _confirm(
              'Delete $name?',
              'This removes the selected item from your local workspace.',
            )) {
              await _run(remove);
            }
          },
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Accounts & plans',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        heading('Accounts', 'account'),
        for (final a in w.accounts)
          record(
            a.name,
            w.balance(a).toDisplayString(),
            'account',
            a.toJson(),
            () => ref.read(walletStoreProvider).change((current) {
              if (current.entries.any((e) => e.accountId == a.id) ||
                  current.goals.any((g) => g.accountId == a.id)) {
                throw const FormatException(
                  'This account has records or a linked goal. Keep it to preserve your history.',
                );
              }
              return current.copyWith(
                accounts: current.accounts.where((v) => v.id != a.id).toList(),
              );
            }),
          ),
        if (w.accounts.length >= 2)
          TextButton.icon(
            onPressed: () => editWallet(context, w, 'transfer'),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Transfer between accounts'),
          ),
        heading('Monthly budgets', 'budget'),
        for (final b in w.budgets)
          record(
            w.categories[b.categoryId] ?? 'Category',
            '${b.month} · ${b.limit.toDisplayString()}',
            'budget',
            b.toJson(),
            () => ref
                .read(walletStoreProvider)
                .change(
                  (c) => c.copyWith(
                    budgets: c.budgets.where((v) => v.id != b.id).toList(),
                  ),
                ),
          ),
        heading('Savings goals', 'goal'),
        for (final g in w.goals)
          record(
            g.name,
            '${w.goalSaved(g).toDisplayString()} / ${g.target.toDisplayString()}',
            'goal',
            g.toJson(),
            () => ref
                .read(walletStoreProvider)
                .change(
                  (c) => c.copyWith(
                    goals: c.goals.where((v) => v.id != g.id).toList(),
                  ),
                ),
          ),
        heading('Categories', 'category'),
        for (final c in w.categories.entries)
          record(
            c.value,
            'Tap to rename',
            'category',
            {'id': c.key, 'name': c.value},
            () => ref.read(walletStoreProvider).change((w) {
              if (w.entries.any((e) => e.categoryId == c.key) ||
                  w.budgets.any((b) => b.categoryId == c.key)) {
                throw const FormatException(
                  'This category is used by records or budgets. Rename it instead.',
                );
              }
              return w.copyWith(
                categories: {
                  for (final e in w.categories.entries)
                    if (e.key != c.key) e.key: e.value,
                },
              );
            }),
          ),
      ],
    );
  }

  Future<String?> _passphrase({required bool confirm}) async {
    final password = TextEditingController(), again = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(confirm ? 'Protect your backup' : 'Unlock your backup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Use at least 12 characters. Keep this passphrase safe; it cannot be recovered.',
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Backup passphrase',
                  ),
                ),
                if (confirm)
                  TextField(
                    controller: again,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Repeat passphrase',
                    ),
                  ),
                if (error != null) Text(error!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (password.text.length < 12 ||
                    password.text.length > 256 ||
                    (confirm && password.text != again.text)) {
                  set(
                    () => error =
                        'Use 12–256 characters and matching passphrases.',
                  );
                  return;
                }
                Navigator.pop(c, password.text);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    // Dialog transitions can still reference controllers until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      password.dispose();
      again.dispose();
    });
    return result;
  }

  Future<void> _backup(Wallet w, bool restore) async {
    setState(() => _fileBusy = true);
    try {
      if (restore) {
        final bytes = await pickPrivacyFile();
        if (bytes == null) return;
        if (!mounted) return;
        final pass = await _passphrase(confirm: false);
        if (pass == null) return;
        final incoming = await WalletBackup.decrypt(bytes, pass);
        if (!mounted) return;
        final replace = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Restore local backup'),
            content: Text(
              '${incoming.accounts.length} accounts, ${incoming.entries.length} records, ${incoming.budgets.length} budgets and ${incoming.goals.length} goals.\n\nMerge adds missing records and skips identical records. Replace restores the backup version of your entire local workspace. Your saved online account is unaffected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Replace local workspace'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Merge'),
              ),
            ],
          ),
        );
        if (replace == null) return;
        if (replace &&
            !await _confirm(
              'Replace local workspace?',
              'All current local records will be replaced by this backup. Save a backup first if you need to keep them.',
            )) {
          return;
        }
        await ref.read(walletStoreProvider).restore(incoming, replace: replace);
        _message('Backup restored. Balances and reports have updated.');
      } else {
        final pass = await _passphrase(confirm: true);
        if (pass == null) return;
        final latest = await ref.read(walletStoreProvider).read();
        final bytes = await WalletBackup.encrypt(latest, pass);
        final saved = await savePrivacyFile(
          'PlanIT-encrypted-backup-${DateTime.now().millisecondsSinceEpoch}.json',
          bytes,
        );
        if (saved != null) {
          _message('Encrypted backup saved. Keep it outside the app.');
        }
      }
    } on Object catch (e) {
      _message(
        e is FormatException
            ? e.message.toString()
            : 'Could not open or save the backup. Check the passphrase and file. Existing records are unchanged.',
      );
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Widget _settings(Wallet w) {
    final account = ref.watch(authControllerProvider).session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your local workspace',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        const Text(
          'Records save on this phone immediately. Closing the app or installing a compatible update keeps them. Uninstalling PlanIT or clearing its storage deletes phone data. Keep an encrypted backup outside the app.',
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: w.currency,
          key: ValueKey(w.currency),
          decoration: const InputDecoration(labelText: 'Default currency'),
          items: [
            for (final c in {...walletCurrencies, w.currency})
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (c) => _run(
            () => ref
                .read(walletStoreProvider)
                .change((w) => w.copyWith(currency: c)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Device app lock'),
          subtitle: const Text('Protect PlanIT using your phone unlock'),
          onTap: () => context.push('/privacy'),
        ),
        ListTile(
          leading: const Icon(Icons.save_alt),
          title: Text(_fileBusy ? 'Working…' : 'Save encrypted backup'),
          subtitle: const Text(
            'Accounts, records, categories, budgets and goals',
          ),
          onTap: _fileBusy ? null : () => _backup(w, false),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Restore encrypted backup'),
          onTap: _fileBusy ? null : () => _backup(w, true),
        ),
        const Divider(),
        if (account != null)
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Copy saved account records here'),
            subtitle: const Text(
              'Independent copy of downloaded income, expenses and refunds. Opening balances adjust to preserve current totals. Original records stay unchanged.',
            ),
            onTap: () async {
              if (!await _confirm(
                'Copy saved account records?',
                'Only records already on this phone are copied. Transfers and debt records stay in the saved account workspace. Repeat copies skip identical records; conflicts are reported.',
              )) {
                return;
              }
              await _run(() async {
                final incoming = await copySavedAccount(
                  ref.read(appDatabaseProvider),
                  account.user.id,
                  account.user.baseCurrency,
                );
                await ref
                    .read(walletStoreProvider)
                    .restore(incoming, replace: false);
                _message('Saved records copied into the local workspace.');
              });
            },
          ),
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: Text(
            account == null
                ? 'Optional account sign-in'
                : 'Open saved account workspace',
          ),
          subtitle: const Text(
            'Online account records remain separate from this local workspace',
          ),
          onTap: () async {
            await ref.read(localModeProvider.notifier).select(false);
            if (account == null && mounted) {
              await context.push<void>('/sign-in');
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(walletProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlanIT'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => setState(() => _tab = 3),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: value.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'Your local data could not be read. It has not been deleted.',
                ),
                TextButton(
                  onPressed: () => ref.invalidate(walletProvider),
                  child: const Text('Try again'),
                ),
                FilledButton(
                  onPressed: _fileBusy
                      ? null
                      : () => _backup(Wallet.empty(), true),
                  child: const Text('Restore encrypted backup'),
                ),
              ],
            ),
          ),
          data: (w) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              switch (_tab) {
                0 => _dashboard(w),
                1 => _activity(w),
                2 => _manage(w),
                _ => _settings(w),
              },
            ],
          ),
        ),
      ),
      floatingActionButton: value.value?.accounts.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () => editWallet(context, value.requireValue, 'entry'),
              icon: const Icon(Icons.add),
              label: const Text('Add money record'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Records',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Plans',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
