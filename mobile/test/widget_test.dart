import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/app/planit_app.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/auth/data/auth_repository.dart';
import 'package:planit_mobile/core/auth/domain/auth_session.dart';
import 'package:planit_mobile/core/auth/domain/auth_user.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/data/accounts_repository.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';
import 'package:planit_mobile/features/analytics/application/providers.dart';
import 'package:planit_mobile/features/analytics/domain/analytics_dashboard.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/data/catalog_repository.dart';
import 'package:planit_mobile/features/transactions/data/transactions_repository.dart';
import 'package:planit_mobile/features/transactions/domain/catalog.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';

void main() {
  testWidgets('sign-in unlocks the owner-scoped application shell', (
    WidgetTester tester,
  ) async {
    final authRepository = _FakeAuthRepository(_session());
    final accountsRepository = _FakeAccountsRepository();
    final transactionsRepository = _FakeTransactionsRepository();
    final catalogRepository = _FakeCatalogRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          accountsRepositoryProvider.overrideWithValue(accountsRepository),
          transactionsRepositoryProvider.overrideWithValue(
            transactionsRepository,
          ),
          catalogRepositoryProvider.overrideWithValue(catalogRepository),
          analyticsDashboardProvider.overrideWith(
            (ref, AnalyticsFilter filter) => Future<AnalyticsDashboard>.error(
              StateError('Analytics is offline in this shell test.'),
            ),
          ),
        ],
        child: const PlanItApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Add your first account'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'owner@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'correct horse battery staple',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(authRepository.loginCount, 1);
    expect(find.text('Add your first account'), findsOneWidget);
    expect(accountsRepository.refreshCount, 1);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Search transactions'), findsOneWidget);
  });

  testWidgets('Add flow saves an uncategorized draft', (
    WidgetTester tester,
  ) async {
    final authRepository = _FakeAuthRepository(
      _session(),
      restoreSession: true,
    );
    final accountsRepository = _FakeAccountsRepository(<Account>[_account()]);
    final transactionsRepository = _FakeTransactionsRepository();
    final catalogRepository = _FakeCatalogRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          accountsRepositoryProvider.overrideWithValue(accountsRepository),
          transactionsRepositoryProvider.overrideWithValue(
            transactionsRepository,
          ),
          catalogRepositoryProvider.overrideWithValue(catalogRepository),
          analyticsDashboardProvider.overrideWith(
            (ref, AnalyticsFilter filter) => Future<AnalyticsDashboard>.error(
              StateError('Analytics is offline in this shell test.'),
            ),
          ),
        ],
        child: const PlanItApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Expense'));
    await tester.pumpAndSettle();

    expect(find.text('Add transaction'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '12.5000',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save draft'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Save draft'));
    await tester.pumpAndSettle();

    expect(transactionsRepository.createCount, 1);
    expect(transactionsRepository.lastDraft?.categoryId, isNull);
    expect(transactionsRepository.lastPostAfterCreate, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('More opens the real privacy and security settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(_session(), restoreSession: true),
          ),
          accountsRepositoryProvider.overrideWithValue(
            _FakeAccountsRepository(),
          ),
          transactionsRepositoryProvider.overrideWithValue(
            _FakeTransactionsRepository(),
          ),
          catalogRepositoryProvider.overrideWithValue(_FakeCatalogRepository()),
          analyticsDashboardProvider.overrideWith(
            (ref, AnalyticsFilter filter) => Future<AnalyticsDashboard>.error(
              StateError('Analytics is not needed in this settings test.'),
            ),
          ),
        ],
        child: const PlanItApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Settings'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(ListTile, 'Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Your data'), findsOneWidget);
    expect(find.text('Export transactions'), findsOneWidget);
    expect(find.text('Delete profile permanently'), findsOneWidget);
  });
}

final class _FakeTransactionsRepository implements TransactionsRepository {
  int createCount = 0;
  TransactionDraft? lastDraft;
  bool? lastPostAfterCreate;

  @override
  Future<void> discardPending(LedgerTransaction transaction) async {}

  @override
  Future<void> queueCreate({
    required String ownerId,
    required TransactionDraft draft,
    required bool postAfterCreate,
    required String? postOperationId,
  }) async {
    createCount += 1;
    lastDraft = draft;
    lastPostAfterCreate = postAfterCreate;
  }

  @override
  Future<void> queuePost({
    required LedgerTransaction current,
    required String operationId,
  }) async {}

  @override
  Future<void> queueReversal({
    required LedgerTransaction current,
    required TransactionReversalDraft reversal,
  }) async {}

  @override
  Future<void> queueUpdate({
    required LedgerTransaction current,
    required TransactionEdit edit,
    required String operationId,
  }) async {}

  @override
  Future<void> refresh({
    required String ownerId,
    required String accessToken,
  }) async {}

  @override
  Future<TransactionSyncResult> synchronize({
    required String ownerId,
    required String accessToken,
    bool force = false,
  }) async {
    return const TransactionSyncResult(processed: 0, blocked: false);
  }

  @override
  Stream<List<LedgerTransaction>> watch(String ownerId) {
    return Stream<List<LedgerTransaction>>.value(const <LedgerTransaction>[]);
  }

  @override
  Stream<int> watchPendingCount(String ownerId) => Stream<int>.value(0);
}

final class _FakeCatalogRepository implements CatalogRepository {
  @override
  Future<TransactionCategory> createCategory({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required CategoryDraft draft,
  }) {
    throw UnsupportedError('Not used by this test.');
  }

  @override
  Future<TransactionTag> createTag({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TagDraft draft,
  }) {
    throw UnsupportedError('Not used by this test.');
  }

  @override
  Future<void> refresh({
    required String ownerId,
    required String accessToken,
  }) async {}

  @override
  Future<void> setCategoryArchived({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TransactionCategory category,
    required bool archived,
  }) async {}

  @override
  Future<void> setTagArchived({
    required String ownerId,
    required String accessToken,
    required String operationId,
    required TransactionTag tag,
    required bool archived,
  }) async {}

  @override
  Stream<List<TransactionCategory>> watchCategories(String ownerId) {
    return Stream<List<TransactionCategory>>.value(
      const <TransactionCategory>[],
    );
  }

  @override
  Stream<List<TransactionTag>> watchTags(String ownerId) {
    return Stream<List<TransactionTag>>.value(const <TransactionTag>[]);
  }
}

AuthSession _session() {
  final now = DateTime.now().toUtc();
  return AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    accessExpiresAt: now.add(const Duration(minutes: 15)),
    refreshExpiresAt: now.add(const Duration(days: 30)),
    user: AuthUser(
      id: 'owner-a',
      email: 'owner@example.com',
      displayName: 'PlanIT Owner',
      baseCurrency: 'MAD',
      timezone: 'Africa/Casablanca',
      status: 'ACTIVE',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.session, {this.restoreSession = false});

  final AuthSession session;
  final bool restoreSession;
  int loginCount = 0;

  @override
  Future<AuthSession> ensureFresh(AuthSession session) async => session;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCount += 1;
    return session;
  }

  @override
  Future<void> logout(AuthSession session) async {}

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required String baseCurrency,
    required String timezone,
  }) async => session;

  @override
  Future<AuthRestoreResult> restore() async {
    return AuthRestoreResult(
      session: restoreSession ? session : null,
      offline: false,
    );
  }
}

final class _FakeAccountsRepository implements AccountsRepository {
  _FakeAccountsRepository([this.accounts = const <Account>[]]);

  final List<Account> accounts;
  int refreshCount = 0;

  @override
  Future<Account> create({
    required String ownerId,
    required String accessToken,
    required String idempotencyKey,
    required AccountDraft draft,
  }) {
    throw UnsupportedError('Not used by this test.');
  }

  @override
  Future<List<Account>> read(String ownerId) async => accounts;

  @override
  Future<void> refresh({
    required String ownerId,
    required String accessToken,
  }) async {
    refreshCount += 1;
  }

  @override
  Future<Account> update({
    required String ownerId,
    required String accessToken,
    required String accountId,
    required AccountPatch patch,
  }) {
    throw UnsupportedError('Not used by this test.');
  }

  @override
  Stream<List<Account>> watch(String ownerId) {
    return Stream<List<Account>>.value(accounts);
  }
}

Account _account() {
  final now = DateTime.now().toUtc();
  return Account(
    id: 'account-a',
    ownerId: 'owner-a',
    name: 'Wallet',
    type: AccountType.cash,
    currency: 'MAD',
    openingBalance: Money.parse('100.0000', 'MAD'),
    calculatedBalance: Money.parse('100.0000', 'MAD'),
    balanceAsOf: now,
    openedAt: now.subtract(const Duration(days: 1)),
    includeInTotal: true,
    allowNegative: false,
    status: AccountStatus.active,
    sortOrder: 0,
    archivedAt: null,
    closedAt: null,
    version: 1,
    createdAt: now,
    updatedAt: now,
  );
}
