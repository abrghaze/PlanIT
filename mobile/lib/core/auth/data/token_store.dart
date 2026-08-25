import 'package:planit_mobile/core/auth/domain/auth_session.dart';

abstract interface class TokenStore {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}
