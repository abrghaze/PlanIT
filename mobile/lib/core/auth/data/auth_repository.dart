import 'package:planit_mobile/core/auth/data/auth_remote_data_source.dart';
import 'package:planit_mobile/core/auth/data/token_store.dart';
import 'package:planit_mobile/core/auth/domain/auth_session.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';

final class AuthRestoreResult {
  const AuthRestoreResult({
    required this.session,
    required this.offline,
    this.reauthenticationRequired = false,
  });

  final AuthSession? session;
  final bool offline;
  final bool reauthenticationRequired;
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

  Future<void> logout(AuthSession session, {bool clearLocalData = false});
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
  var _credentialRevision = 0;

  @override
  Future<AuthRestoreResult> restore() async {
    final stored = await _tokenStore.read();
    if (stored == null) {
      return const AuthRestoreResult(session: null, offline: false);
    }
    if (!stored.canRefresh) {
      return AuthRestoreResult(
        session: stored,
        offline: true,
        reauthenticationRequired: true,
      );
    }
    if (stored.accessIsFresh()) {
      return AuthRestoreResult(session: stored, offline: false);
    }

    final revision = _credentialRevision;
    try {
      final refreshed = await _remote.refresh(stored.refreshToken);
      if (revision != _credentialRevision) {
        return AuthRestoreResult(session: stored, offline: true);
      }
      await _tokenStore.write(refreshed);
      return AuthRestoreResult(session: refreshed, offline: false);
    } on AppException catch (error) {
      if (error.isAuthenticationFailure) {
        return AuthRestoreResult(
          session: stored,
          offline: true,
          reauthenticationRequired: true,
        );
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
    _credentialRevision += 1;
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
    _credentialRevision += 1;
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
      throw const AppException(
        code: 'REAUTHENTICATION_REQUIRED',
        message:
            'Sign in again to synchronize. Your saved phone data is still available.',
        statusCode: 401,
      );
    }
    final revision = _credentialRevision;
    try {
      final refreshed = await _remote.refresh(session.refreshToken);
      if (revision != _credentialRevision) {
        throw const AppException(
          code: 'SESSION_CHANGED',
          message: 'The active session changed. Please try again.',
        );
      }
      await _tokenStore.write(refreshed);
      return refreshed;
    } on AppException catch (error) {
      if (error.isAuthenticationFailure &&
          error.code != 'REAUTHENTICATION_REQUIRED') {
        throw AppException(
          code: 'REAUTHENTICATION_REQUIRED',
          message:
              'Sign in again to synchronize. Your saved phone data is still available.',
          statusCode: 401,
          details: error.details,
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> logout(
    AuthSession session, {
    bool clearLocalData = false,
  }) async {
    _credentialRevision += 1;
    try {
      await _remote.logout(session.refreshToken);
    } on AppException {
      // Local logout must succeed even if the backend is temporarily offline.
    } finally {
      await _clearCredentials();
      if (clearLocalData) {
        await _clearOwnerData(session.user.id);
      }
    }
  }

  Future<void> _clearCredentials() => _tokenStore.clear();
}
