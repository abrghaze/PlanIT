import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/auth/data/auth_remote_data_source.dart';
import 'package:planit_mobile/core/auth/data/auth_repository.dart';
import 'package:planit_mobile/core/auth/data/token_store.dart';
import 'package:planit_mobile/core/auth/domain/auth_session.dart';
import 'package:planit_mobile/core/auth/domain/auth_user.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';

void main() {
  group('DefaultAuthRepository', () {
    test(
      'rotates an expired access token and persists the new session',
      () async {
        final stored = _session(accessExpired: true, accessToken: 'access-old');
        final rotated = _session(
          accessToken: 'access-new',
          refreshToken: 'refresh-new',
        );
        final tokenStore = _MemoryTokenStore(stored);
        final remote = _FakeAuthRemote(refreshResult: rotated);
        final clearedOwners = <String>[];
        final repository = DefaultAuthRepository(
          remote: remote,
          tokenStore: tokenStore,
          clearOwnerData: (ownerId) async => clearedOwners.add(ownerId),
        );

        final result = await repository.restore();

        expect(result.session, same(rotated));
        expect(result.offline, isFalse);
        expect(remote.refreshedTokens, <String>['refresh-token']);
        expect(tokenStore.value, same(rotated));
        expect(tokenStore.writeCount, 1);
        expect(clearedOwners, isEmpty);
      },
    );

    test('revoked refresh tokens clear credentials and owner cache', () async {
      final stored = _session(accessExpired: true);
      final tokenStore = _MemoryTokenStore(stored);
      final remote = _FakeAuthRemote(
        refreshError: const AppException(
          code: 'TOKEN_REUSE_DETECTED',
          message: 'Sign in again.',
          statusCode: 401,
        ),
      );
      final clearedOwners = <String>[];
      final repository = DefaultAuthRepository(
        remote: remote,
        tokenStore: tokenStore,
        clearOwnerData: (ownerId) async => clearedOwners.add(ownerId),
      );

      final result = await repository.restore();

      expect(result.session, isNull);
      expect(result.offline, isFalse);
      expect(tokenStore.value, isNull);
      expect(tokenStore.clearCount, 1);
      expect(clearedOwners, <String>['owner-a']);
    });

    test('network failures preserve a valid cached refresh session', () async {
      final stored = _session(accessExpired: true);
      final tokenStore = _MemoryTokenStore(stored);
      final remote = _FakeAuthRemote(
        refreshError: const AppException(
          code: 'NETWORK_UNAVAILABLE',
          message: 'Offline.',
          isNetworkFailure: true,
        ),
      );
      final clearedOwners = <String>[];
      final repository = DefaultAuthRepository(
        remote: remote,
        tokenStore: tokenStore,
        clearOwnerData: (ownerId) async => clearedOwners.add(ownerId),
      );

      final result = await repository.restore();

      expect(result.session, same(stored));
      expect(result.offline, isTrue);
      expect(tokenStore.value, same(stored));
      expect(tokenStore.clearCount, 0);
      expect(clearedOwners, isEmpty);
    });

    test('logout always clears local secrets and cached owner data', () async {
      final stored = _session();
      final tokenStore = _MemoryTokenStore(stored);
      final remote = _FakeAuthRemote(
        logoutError: const AppException(
          code: 'NETWORK_UNAVAILABLE',
          message: 'Offline.',
          isNetworkFailure: true,
        ),
      );
      final clearedOwners = <String>[];
      final repository = DefaultAuthRepository(
        remote: remote,
        tokenStore: tokenStore,
        clearOwnerData: (ownerId) async => clearedOwners.add(ownerId),
      );

      await repository.logout(stored);

      expect(remote.loggedOutTokens, <String>['refresh-token']);
      expect(tokenStore.value, isNull);
      expect(tokenStore.clearCount, 1);
      expect(clearedOwners, <String>['owner-a']);
    });
  });
}

AuthSession _session({
  bool accessExpired = false,
  String accessToken = 'access-token',
  String refreshToken = 'refresh-token',
}) {
  final now = DateTime.now().toUtc();
  final createdAt = now.subtract(const Duration(days: 30));
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
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );
}

final class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this.value);

  AuthSession? value;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
    value = null;
  }

  @override
  Future<AuthSession?> read() async => value;

  @override
  Future<void> write(AuthSession session) async {
    writeCount += 1;
    value = session;
  }
}

final class _FakeAuthRemote implements AuthRemoteDataSource {
  _FakeAuthRemote({this.refreshResult, this.refreshError, this.logoutError});

  final AuthSession? refreshResult;
  final AppException? refreshError;
  final AppException? logoutError;
  final List<String> refreshedTokens = <String>[];
  final List<String> loggedOutTokens = <String>[];

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    String? deviceLabel,
  }) {
    throw UnsupportedError('Not used by this test.');
  }

  @override
  Future<void> logout(String refreshToken) async {
    loggedOutTokens.add(refreshToken);
    if (logoutError case final error?) {
      throw error;
    }
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    refreshedTokens.add(refreshToken);
    if (refreshError case final error?) {
      throw error;
    }
    return refreshResult!;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required String baseCurrency,
    required String timezone,
    String? deviceLabel,
  }) {
    throw UnsupportedError('Not used by this test.');
  }
}
