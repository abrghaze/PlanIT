import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/auth/data/auth_repository.dart';
import 'package:planit_mobile/core/auth/domain/auth_session.dart';
import 'package:planit_mobile/core/auth/domain/auth_user.dart';
import 'package:planit_mobile/features/offline_finance/application/providers.dart';
import 'package:planit_mobile/features/offline_finance/data/offline_finance_store.dart';

class _Repository extends Mock implements AuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'overlapping budget saves persist both changes and reject invalid inputs',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final now = DateTime.now().toUtc();
      final session = AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        accessExpiresAt: now.add(const Duration(hours: 1)),
        refreshExpiresAt: now.add(const Duration(days: 30)),
        user: AuthUser(
          id: 'owner',
          email: 'owner@example.com',
          displayName: 'Owner',
          baseCurrency: 'MAD',
          timezone: 'Africa/Casablanca',
          status: 'ACTIVE',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final repository = _Repository();
      when(repository.restore).thenAnswer(
        (_) async => AuthRestoreResult(session: session, offline: true),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await container.read(offlineBudgetsProvider.future);
      final controller = container.read(offlineBudgetsProvider.notifier);
      await Future.wait([
        controller.save(
          categoryId: 'food',
          monthKey: '2026-10',
          amount: '100',
          currency: 'MAD',
          warningPercent: 80,
        ),
        controller.save(
          categoryId: 'travel',
          monthKey: '2026-10',
          amount: '200',
          currency: 'MAD',
          warningPercent: 90,
        ),
      ]);
      final saved = await SecureOfflineFinanceStore().readBudgets('owner');
      expect(saved.map((b) => b.categoryId).toSet(), {'food', 'travel'});
      await expectLater(
        controller.save(
          categoryId: 'food',
          monthKey: '2026-13',
          amount: '999',
          currency: 'MAD',
          warningPercent: 80,
        ),
        throwsFormatException,
      );
      expect(
        (await SecureOfflineFinanceStore().readBudgets(
          'owner',
        )).first.limit.toApiString(),
        '100.0000',
      );
      expect(
        await controller.copyPreviousMonth(DateTime(2026, 11), {
          'food',
          'travel',
        }),
        2,
      );
      expect(
        await controller.copyPreviousMonth(DateTime(2026, 11), {
          'food',
          'travel',
        }),
        0,
      );
    },
  );
}
