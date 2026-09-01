import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/auth/data/auth_repository.dart';
import 'package:planit_mobile/core/auth/domain/auth_session.dart';
import 'package:planit_mobile/core/auth/domain/auth_user.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';

void main() {
  test('concurrent callers share one rotating-token refresh', () async {
    final expired = _session(
      accessToken: 'expired-access',
      refreshToken: 'refresh-old',
      accessExpired: true,
    );
    final refreshed = _session(
      accessToken: 'fresh-access',
      refreshToken: 'refresh-new',
    );
    final repository = _ControlledAuthRepository(
      restored: expired,
      loginResult: refreshed,
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    container.read(authControllerProvider);
    await pumpEventQueue();
    final controller = container.read(authControllerProvider.notifier);

    final first = controller.requireFreshSession();
    final second = controller.requireFreshSession();
    await pumpEventQueue();

    expect(repository.refreshCount, 1);
    repository.refreshCompleter.complete(refreshed);
    final results = await Future.wait(<Future<AuthSession>>[first, second]);

    expect(results, everyElement(same(refreshed)));
    expect(container.read(authControllerProvider).session, same(refreshed));
  });

  test('an old refresh cannot clear a newly signed-in session', () async {
    final expired = _session(
      accessToken: 'expired-access',
      refreshToken: 'refresh-old',
      accessExpired: true,
    );
    final replacement = _session(
      accessToken: 'replacement-access',
      refreshToken: 'refresh-replacement',
    );
    final repository = _ControlledAuthRepository(
      restored: expired,
      loginResult: replacement,
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    container.read(authControllerProvider);
    await pumpEventQueue();
    final controller = container.read(authControllerProvider.notifier);
    final oldRefresh = controller.requireFreshSession();
    await pumpEventQueue();

    expect(
      await controller.signIn(
        email: 'owner@example.com',
        password: 'Strong1!Password',
      ),
      isTrue,
    );
    repository.refreshCompleter.complete(
      _session(accessToken: 'stale-result', refreshToken: 'stale-rotation'),
    );

    await expectLater(
      oldRefresh,
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'SESSION_CHANGED',
        ),
      ),
    );
    expect(container.read(authControllerProvider).session, same(replacement));
  });
}

AuthSession _session({
  required String accessToken,
  required String refreshToken,
  bool accessExpired = false,
}) {
  final now = DateTime.now().toUtc();
  return AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessExpiresAt: accessExpired
        ? now.subtract(const Duration(minutes: 1))
        : now.add(const Duration(minutes: 15)),
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

final class _ControlledAuthRepository implements AuthRepository {
  _ControlledAuthRepository({
    required this.restored,
    required this.loginResult,
  });

  final AuthSession restored;
  final AuthSession loginResult;
  final Completer<AuthSession> refreshCompleter = Completer<AuthSession>();
  int refreshCount = 0;

  @override
  Future<AuthSession> ensureFresh(AuthSession session) {
    refreshCount += 1;
    return refreshCompleter.future;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => loginResult;

  @override
  Future<void> logout(AuthSession session) async {}

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required String baseCurrency,
    required String timezone,
  }) async => loginResult;

  @override
  Future<AuthRestoreResult> restore() async =>
      AuthRestoreResult(session: restored, offline: false);
}
