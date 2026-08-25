import 'package:planit_mobile/core/auth/data/auth_remote_data_source.dart';
import 'package:planit_mobile/core/auth/data/token_store.dart';
import 'package:planit_mobile/core/auth/domain/auth_session.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';

final class AuthRestoreResult {
  const AuthRestoreResult({required this.session, required this.offline});

  final AuthSession? session;
  final bool offline;
}

abstract interface class AuthRepository {
  Future<AuthRestoreResult> restore();

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required String baseCurrency,
    required String timezone,
  });

  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> ensureFresh(AuthSession session);

  Future<void> logout(AuthSession session);
}

final class DefaultAuthRepository implements AuthRepository {
  DefaultAuthRepository({
    required AuthRemoteDataSource remote,
    required TokenStore tokenStore,
    required Future<void> Function(String ownerId) clearOwnerData,
  }) : _remote = remote,
       _tokenStore = tokenStore,
       _clearOwnerData = clearOwnerData;

  final AuthRemoteDataSource _remote;
  final TokenStore _tokenStore;
  final Future<void> Function(String ownerId) _clearOwnerData;

  @override
  Future<AuthRestoreResult> restore() async {
    final stored = await _tokenStore.read();
    if (stored == null) {
      return const AuthRestoreResult(session: null, offline: false);
    }
    if (!stored.canRefresh) {
      await _clearSession(stored.user.id);
      return const AuthRestoreResult(session: null, offline: false);
    }
    if (stored.accessIsFresh()) {
      return AuthRestoreResult(session: stored, offline: false);
    }

    try {
      final refreshed = await _remote.refresh(stored.refreshToken);
      await _tokenStore.write(refreshed);
      return AuthRestoreResult(session: refreshed, offline: false);
    } on AppException catch (error) {
      if (error.isAuthenticationFailure) {
        await _clearSession(stored.user.id);
        return const AuthRestoreResult(session: null, offline: false);
      }
      return AuthRestoreResult(session: stored, offline: true);
    }
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required String baseCurrency,
    required String timezone,
  }) async {
    final session = await _remote.register(
      email: email,
      password: password,
      displayName: displayName,
      baseCurrency: baseCurrency,
      timezone: timezone,
      deviceLabel: 'PlanIT mobile',
    );
    await _tokenStore.write(session);
    return session;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final session = await _remote.login(
      email: email,
      password: password,
      deviceLabel: 'PlanIT mobile',
    );
    await _tokenStore.write(session);
    return session;
  }

  @override
  Future<AuthSession> ensureFresh(AuthSession session) async {
    if (session.accessIsFresh()) {
      return session;
    }
    if (!session.canRefresh) {
      await _clearSession(session.user.id);
      throw const AppException(
        code: 'SESSION_EXPIRED',
        message: 'Your session expired. Sign in again.',
        statusCode: 401,
      );
    }
    try {
      final refreshed = await _remote.refresh(session.refreshToken);
      await _tokenStore.write(refreshed);
      return refreshed;
    } on AppException catch (error) {
      if (error.isAuthenticationFailure) {
        await _clearSession(session.user.id);
      }
      rethrow;
    }
  }

  @override
  Future<void> logout(AuthSession session) async {
    try {
      await _remote.logout(session.refreshToken);
    } on AppException {
      // Local logout must succeed even if the backend is temporarily offline.
    } finally {
      await _clearSession(session.user.id);
    }
  }

  Future<void> _clearSession(String ownerId) async {
    await _tokenStore.clear();
    await _clearOwnerData(ownerId);
  }
}
