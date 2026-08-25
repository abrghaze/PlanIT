final class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.baseCurrency,
    required this.timezone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String baseCurrency;
  final String timezone;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AuthUser.fromJson(Map<String, Object?> json) {
    return AuthUser(
      id: json['id']! as String,
      email: json['email']! as String,
      displayName: json['display_name']! as String,
      baseCurrency: json['base_currency']! as String,
      timezone: json['timezone']! as String,
      status: json['status']! as String,
      createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'email': email,
    'display_name': displayName,
    'base_currency': baseCurrency,
    'timezone': timezone,
    'status': status,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}
