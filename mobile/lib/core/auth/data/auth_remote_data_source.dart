import 'package:planit_mobile/core/auth/domain/auth_session.dart';

abstract interface class AuthRemoteDataSource {
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required String baseCurrency,
    required String timezone,
    String? deviceLabel,
  });

  Future<AuthSession> login({
    required String email,
    required String password,
    String? deviceLabel,
  });

  Future<AuthSession> refresh(String refreshToken);

  Future<void> logout(String refreshToken);
}
