import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/database/providers.dart';
import 'package:planit_mobile/core/design_system/app_theme.dart';
import 'package:planit_mobile/features/local_wallet/data/wallet_store.dart';
import 'package:planit_mobile/features/local_wallet/presentation/wallet_editor.dart';
import 'wallet_store_test.dart' show cash, expense;

void main() {
  for (final kind in ['budget', 'goal', 'transfer', 'category', 'entry']) {
    testWidgets('$kind editor saves locally and corrections retain IDs', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = WalletStore(db);
      await store.saveAccount(cash());
      await store.saveAccount(cash('savings'));
      if (kind == 'entry') await store.saveEntry(expense('correct', '20'));
      final wallet = await store.read();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: PlanItTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => editWallet(
                    context,
                    wallet,
                    kind,
                    record: kind == 'entry'
                        ? wallet.entries.single.toJson()
                        : null,
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      Future<void> select(String label, String value) async {
        final field = find.widgetWithText(
          DropdownButtonFormField<String>,
          label,
        );
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text(value).last);
        await tester.pumpAndSettle();
      }

      if (kind == 'category' || kind == 'goal') {
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Name'),
          'Emergency',
        );
      }
      if (kind == 'budget') {
        await select('Category', 'Food & groceries');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Monthly limit'),
          '70.1234',
        );
      }
      if (kind == 'goal') {
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Target amount'),
          '200',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Amount saved'),
          '50',
        );
      }
      if (kind == 'transfer') await select('To account', 'savings');
      if (kind == 'transfer' || kind == 'entry') {
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Amount (MAD)'),
          '7.1234',
        );
      }
      tester.testTextInput.hide();
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final saved = await store.read();
      switch (kind) {
        case 'budget':
          expect(saved.budgets.single.limit.toApiString(), '70.1234');
        case 'goal':
          expect(saved.goalSaved(saved.goals.single).toApiString(), '50.0000');
        case 'transfer':
          expect(saved.entries, hasLength(2));
          expect(saved.balance(cash()).toApiString(), '92.8766');
        case 'category':
          expect(saved.categories.values, contains('Emergency'));
        case 'entry':
          expect(saved.entries.single.id, 'correct');
          expect(saved.balance(cash()).toApiString(), '92.8766');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
