import 'package:planit_mobile/core/auth/domain/auth_user.dart';

final class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;
  final AuthUser user;

  bool get canRefresh => refreshExpiresAt.isAfter(DateTime.now().toUtc());

  bool accessIsFresh({Duration margin = const Duration(seconds: 30)}) {
    return accessExpiresAt.isAfter(DateTime.now().toUtc().add(margin));
  }

  factory AuthSession.fromJson(Map<String, Object?> json) {
    return AuthSession(
      accessToken: json['access_token']! as String,
      refreshToken: json['refresh_token']! as String,
      accessExpiresAt: DateTime.parse(
        json['access_expires_at']! as String,
      ).toUtc(),
      refreshExpiresAt: DateTime.parse(
        json['refresh_expires_at']! as String,
      ).toUtc(),
      user: AuthUser.fromJson(Map<String, Object?>.from(json['user']! as Map)),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'access_expires_at': accessExpiresAt.toUtc().toIso8601String(),
    'refresh_expires_at': refreshExpiresAt.toUtc().toIso8601String(),
    'user': user.toJson(),
  };
}
