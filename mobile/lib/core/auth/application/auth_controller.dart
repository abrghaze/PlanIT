import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_state.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/auth/data/auth_repository.dart';
import 'package:planit_mobile/core/auth/domain/auth_session.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final class AuthController extends Notifier<AuthState> {
  Future<AuthSession>? _refreshInFlight;
  String? _refreshTokenInFlight;

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    unawaited(Future<void>.microtask(_restore));
    return const AuthState.initial();
  }

  Future<void> _restore() async {
    try {
      final restored = await _repository.restore();
      state = AuthState(
        initialized: true,
        busy: false,
        offline: restored.offline,
        session: restored.session,
      );
    } on Object {
      state = const AuthState(
        initialized: true,
        busy: false,
        offline: false,
        errorMessage: 'PlanIT could not restore the saved session.',
      );
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await _repository.login(email: email, password: password);
      state = AuthState(
        initialized: true,
        busy: false,
        offline: false,
        session: session,
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(busy: false, errorMessage: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not securely save this session.',
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    required String baseCurrency,
    required String timezone,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
        baseCurrency: baseCurrency,
        timezone: timezone,
      );
      state = AuthState(
        initialized: true,
        busy: false,
        offline: false,
        session: session,
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(busy: false, errorMessage: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not securely save this session.',
      );
      return false;
    }
  }

  Future<AuthSession> requireFreshSession() async {
    final session = state.session;
    if (session == null) {
      throw const AppException(
        code: 'SESSION_REQUIRED',
        message: 'Sign in to continue.',
        statusCode: 401,
      );
    }

    if (session.accessIsFresh()) {
      return session;
    }

    final inFlight = _refreshInFlight;
    if (inFlight != null && _refreshTokenInFlight == session.refreshToken) {
      return inFlight;
    }

    final refresh = _refreshSession(session);
    _refreshInFlight = refresh;
    _refreshTokenInFlight = session.refreshToken;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
        _refreshTokenInFlight = null;
      }
    }
  }

  Future<AuthSession> _refreshSession(AuthSession session) async {
    try {
      final refreshed = await _repository.ensureFresh(session);
      final current = state.session;
      if (current == null || current.refreshToken != session.refreshToken) {
        throw const AppException(
          code: 'SESSION_CHANGED',
          message: 'The active session changed. Please try again.',
        );
      }
      if (!identical(refreshed, session)) {
        state = state.copyWith(
          session: refreshed,
          offline: false,
          clearError: true,
        );
      }
      return refreshed;
    } on AppException catch (error) {
      if (error.isAuthenticationFailure) {
        state = state.copyWith(
          busy: false,
          offline: false,
          clearSession: true,
          errorMessage: error.message,
        );
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final session = state.session;
    if (session == null) {
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _repository.logout(session);
      state = const AuthState(initialized: true, busy: false, offline: false);
    } on Object {
      state = state.copyWith(
        busy: false,
        errorMessage: 'PlanIT could not clear the saved session.',
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}
