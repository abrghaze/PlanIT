import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/app/planit_app.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/auth/data/auth_repository.dart';
import 'package:planit_mobile/core/auth/domain/auth_session.dart';
import 'package:planit_mobile/core/auth/domain/auth_user.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/accounts/data/accounts_repository.dart';
import 'package:planit_mobile/features/accounts/domain/account.dart';

void main() {
  testWidgets('sign-in unlocks the owner-scoped application shell', (
    WidgetTester tester,
  ) async {
    final authRepository = _FakeAuthRepository(_session());
    final accountsRepository = _FakeAccountsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          accountsRepositoryProvider.overrideWithValue(accountsRepository),
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
  _FakeAuthRepository(this.session);

  final AuthSession session;
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
    return const AuthRestoreResult(session: null, offline: false);
  }
}

final class _FakeAccountsRepository implements AccountsRepository {
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
  Future<List<Account>> read(String ownerId) async => const <Account>[];

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
    return Stream<List<Account>>.value(const <Account>[]);
  }
}
