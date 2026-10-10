import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/local_wallet/data/wallet_store.dart';
import 'package:planit_mobile/features/local_wallet/domain/wallet.dart';
import 'package:planit_mobile/features/offline_finance/domain/offline_finance.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';
import 'package:uuid/uuid.dart';

Future<void> editWallet(
  BuildContext context,
  Wallet wallet,
  String kind, {
  Map<String, Object?>? record,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => WalletEditor(wallet: wallet, kind: kind, record: record),
  ),
);

class WalletEditor extends ConsumerStatefulWidget {
  const WalletEditor({
    required this.wallet,
    required this.kind,
    this.record,
    super.key,
  });
  final Wallet wallet;
  final String kind;
  final Map<String, Object?>? record;
  @override
  ConsumerState<WalletEditor> createState() => _WalletEditorState();
}

class _WalletEditorState extends ConsumerState<WalletEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _amount = TextEditingController(),
      _opening = TextEditingController(),
      _saved = TextEditingController(),
      _note = TextEditingController();
  late String _currency, _month;
  String? _account, _to, _category, _linked;
  TransactionType _type = TransactionType.expense;
  late DateTime _date;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final j = widget.record ?? {};
    _name.text = (j['name'] as String?) ?? '';
    _amount.text = (j['amount'] ?? j['target'] ?? '').toString();
    _opening.text = (j['opening'] ?? '0').toString();
    _saved.text = (j['saved'] ?? '0').toString();
    _note.text = (j['note'] as String?) ?? '';
    _currency = (j['currency'] as String?) ?? widget.wallet.currency;
    _account =
        (j['account_id'] as String?) ?? widget.wallet.accounts.firstOrNull?.id;
    _category = j['category_id'] as String?;
    _linked = widget.kind == 'goal' ? j['account_id'] as String? : null;
    _month = (j['month'] as String?) ?? localMonthKey(DateTime.now());
    _date = j['date'] == null
        ? DateTime.now()
        : DateTime.parse(j['date'] as String).toLocal();
    if (j['type'] != null) {
      _type = TransactionTypeContract.fromApi(j['type'] as String);
    }
    if ((widget.kind == 'entry' || widget.kind == 'transfer') &&
        _account != null) {
      _currency = widget.wallet.accounts
          .firstWhere((a) => a.id == _account)
          .opening
          .currency;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _amount, _opening, _saved, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _text(
    String label,
    TextEditingController c, {
    bool money = false,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      keyboardType: money
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (optional) return null;
        if (v == null || v.trim().isEmpty) {
          return 'Enter ${label.toLowerCase()}.';
        }
        if (money) {
          try {
            Money.parse(v, _currency);
          } on Object {
            return 'Enter a valid amount with up to four decimals.';
          }
        }
        return null;
      },
    ),
  );
  Widget _select(
    String label,
    String? value,
    Map<String, String> choices,
    void Function(String?) change, {
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      key: ValueKey(label + (value ?? '')),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (!required)
          const DropdownMenuItem<String>(value: '', child: Text('None')),
        for (final e in choices.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() => change(v == '' ? null : v)),
      validator: (v) => required && (v == null || v.isEmpty)
          ? 'Choose ${label.toLowerCase()}.'
          : null,
    ),
  );
  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: calendar(_date),
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted) return;
    setState(
      () => _date = DateTime(
        d.year,
        d.month,
        d.day,
        t?.hour ?? _date.hour,
        t?.minute ?? _date.minute,
      ),
    );
  }

  DateTime calendar(DateTime d) => DateTime(d.year, d.month, d.day);
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = ref.read(walletStoreProvider);
      final id = (widget.record?['id'] as String?) ?? const Uuid().v4();
      switch (widget.kind) {
        case 'account':
          final account = WalletAccount(
            id: id,
            name: _name.text.trim(),
            opening: Money.parse(_opening.text, _currency),
          );
          await store.saveAccount(account);
        case 'entry':
          final money = Money.parse(_amount.text, _currency);
          if (money.scaledAmount <= BigInt.zero) {
            throw const FormatException('Amount must be greater than zero.');
          }
          if (_date.isAfter(DateTime.now())) {
            throw const FormatException(
              'Choose a date and time that is not in the future.',
            );
          }
          await store.saveEntry(
            WalletEntry(
              id: id,
              accountId: _account!,
              type: _type,
              amount: money,
              date: _date.toUtc(),
              categoryId: _category,
              note: _note.text.trim(),
            ),
          );
        case 'transfer':
          if (_account == _to) {
            throw const FormatException('Choose two different accounts.');
          }
          final amount = Money.parse(_amount.text, _currency);
          if (amount.scaledAmount <= BigInt.zero) {
            throw const FormatException('Amount must be greater than zero.');
          }
          final now = DateTime.now().toUtc();
          await store.change(
            (w) => w.copyWith(
              entries: [
                ...w.entries,
                WalletEntry(
                  id: const Uuid().v4(),
                  accountId: _account!,
                  type: TransactionType.transferOut,
                  amount: amount,
                  date: now,
                  categoryId: null,
                  note: _note.text.trim(),
                  transferId: id,
                ),
                WalletEntry(
                  id: const Uuid().v4(),
                  accountId: _to!,
                  type: TransactionType.transferIn,
                  amount: amount,
                  date: now,
                  categoryId: null,
                  note: _note.text.trim(),
                  transferId: id,
                ),
              ],
            ),
          );
        case 'category':
          await store.change(
            (w) => w.copyWith(
              categories: {...w.categories, id: _name.text.trim()},
            ),
          );
        case 'budget':
          final limit = Money.parse(_amount.text, _currency);
          final budget = WalletBudget(
            id: id,
            categoryId: _category!,
            month: _month,
            limit: limit,
          );
          await store.change(
            (w) => w.copyWith(
              budgets: [
                for (final b in w.budgets)
                  if (b.id != id &&
                      !(b.categoryId == _category &&
                          b.month == _month &&
                          b.limit.currency == _currency))
                    b,
                budget,
              ],
            ),
          );
        case 'goal':
          final goal = WalletGoal(
            id: id,
            name: _name.text.trim(),
            target: Money.parse(_amount.text, _currency),
            saved: Money.parse(_saved.text, _currency),
            accountId: _linked,
          );
          await store.change(
            (w) => w.copyWith(
              goals: [
                for (final g in w.goals)
                  if (g.id != id) g,
                goal,
              ],
            ),
          );
      }
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message.toString()
              : 'Could not save. Your previous data is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = {
      for (final a in widget.wallet.accounts)
        a.id: '${a.name} · ${a.opening.currency}',
    };
    final currencyChoices = {
      for (final c in {...walletCurrencies, _currency}) c: c,
    };
    final entry = widget.kind == 'entry', transfer = widget.kind == 'transfer';
    final title =
        (widget.record == null ? 'Add ' : 'Edit ') +
        switch (widget.kind) {
          'entry' => 'transaction',
          'account' => 'account',
          'category' => 'category',
          'budget' => 'monthly budget',
          'goal' => 'savings goal',
          _ => 'transfer',
        };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (['account', 'category', 'goal'].contains(widget.kind))
                _text('Name', _name),
              if (!entry && !transfer && widget.kind != 'category')
                _select('Currency', _currency, currencyChoices, (v) {
                  _currency = v!;
                  _linked = null;
                }, required: true),
              if (widget.kind == 'account') ...[
                _text('Opening balance', _opening, money: true),
                const Text(
                  'Opening balance is your starting money. It does not count as income in reports.',
                ),
              ],
              if (entry) ...[
                DropdownButtonFormField<TransactionType>(
                  isExpanded: true,
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in [
                      TransactionType.expense,
                      TransactionType.income,
                      TransactionType.refund,
                    ])
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (t) => setState(() => _type = t!),
                ),
                const SizedBox(height: 16),
              ],
              if (entry || transfer) ...[
                _select(
                  transfer ? 'From account' : 'Account',
                  _account,
                  accounts,
                  (v) {
                    _account = v;
                    _currency = widget.wallet.accounts
                        .firstWhere((a) => a.id == v)
                        .opening
                        .currency;
                    _to = null;
                  },
                  required: true,
                ),
                if (transfer)
                  _select(
                    'To account',
                    _to,
                    {
                      for (final a in widget.wallet.accounts)
                        if (a.id != _account && a.opening.currency == _currency)
                          a.id: a.name,
                    },
                    (v) => _to = v,
                    required: true,
                  ),
                _text('Amount ($_currency)', _amount, money: true),
              ],
              if (entry || widget.kind == 'budget')
                _select(
                  'Category',
                  _category,
                  widget.wallet.categories,
                  (v) => _category = v,
                  required: widget.kind == 'budget',
                ),
              if (entry)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date & time'),
                  subtitle: Text(
                    '${MaterialLocalizations.of(context).formatFullDate(_date)} ${TimeOfDay.fromDateTime(_date).format(context)}',
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: _pickDate,
                ),
              if (entry || transfer) _text('Note', _note, optional: true),
              if (widget.kind == 'budget') ...[
                TextFormField(
                  initialValue: _month,
                  decoration: const InputDecoration(
                    labelText: 'Month (YYYY-MM)',
                  ),
                  onChanged: (v) => _month = v,
                  validator: (v) =>
                      RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(v ?? '')
                      ? null
                      : 'Use YYYY-MM.',
                ),
                const SizedBox(height: 16),
                _text('Monthly limit', _amount, money: true),
              ],
              if (widget.kind == 'goal') ...[
                _text('Target amount', _amount, money: true),
                _select('Linked savings account (optional)', _linked, {
                  for (final a in widget.wallet.accounts)
                    if (a.opening.currency == _currency) a.id: a.name,
                }, (v) => _linked = v),
                if (_linked == null)
                  _text('Amount saved', _saved, money: true)
                else
                  const Text(
                    'Progress follows the current balance of this account.',
                  ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
