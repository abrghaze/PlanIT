import 'package:planit_mobile/core/auth/domain/auth_session.dart';

final class AuthState {
  const AuthState({
    required this.initialized,
    required this.busy,
    required this.offline,
    this.session,
    this.errorMessage,
  });

  const AuthState.initial()
    : initialized = false,
      busy = false,
      offline = false,
      session = null,
      errorMessage = null;

  final bool initialized;
  final bool busy;
  final bool offline;
  final AuthSession? session;
  final String? errorMessage;

  bool get isAuthenticated => session != null;

  AuthState copyWith({
    bool? initialized,
    bool? busy,
    bool? offline,
    AuthSession? session,
    bool clearSession = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      initialized: initialized ?? this.initialized,
      busy: busy ?? this.busy,
      offline: offline ?? this.offline,
      session: clearSession ? null : session ?? this.session,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
