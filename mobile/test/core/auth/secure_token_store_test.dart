import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/auth/data/secure_token_store.dart';
import 'package:planit_mobile/core/auth/domain/auth_session.dart';
import 'package:planit_mobile/core/auth/domain/auth_user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

  test('secure token store round-trips a complete session', () async {
    final store = SecureTokenStore();
    final session = _session();

    await store.write(session);
    final restored = await store.read();

    expect(restored, isNotNull);
    expect(restored!.accessToken, session.accessToken);
    expect(restored.refreshToken, session.refreshToken);
    expect(restored.accessExpiresAt, session.accessExpiresAt);
    expect(restored.refreshExpiresAt, session.refreshExpiresAt);
    expect(restored.user.id, session.user.id);
    expect(restored.user.email, session.user.email);
  });

  test('corrupt secure storage data is discarded', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'planit.auth.session.v1': '{invalid-json',
    });
    final store = SecureTokenStore();

    expect(await store.read(), isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'planit.auth.session.v1'),
      isNull,
    );
  });
}

AuthSession _session() {
  final now = DateTime.now().toUtc();
  return AuthSession(
    accessToken: 'access-secret',
    refreshToken: 'refresh-secret',
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
