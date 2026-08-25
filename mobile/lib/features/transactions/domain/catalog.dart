enum CategoryKind { expense, income, both }

extension CategoryKindContract on CategoryKind {
  String get apiValue => name.toUpperCase();

  String get label => switch (this) {
    CategoryKind.expense => 'Expense',
    CategoryKind.income => 'Income',
    CategoryKind.both => 'Expense & income',
  };

  static CategoryKind fromApi(String value) {
    return CategoryKind.values.firstWhere(
      (kind) => kind.apiValue == value,
      orElse: () => CategoryKind.both,
    );
  }
}

final class TransactionCategory {
  const TransactionCategory({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.kind,
    required this.parentId,
    required this.isSeeded,
    required this.archivedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final CategoryKind kind;
  final String? parentId;
  final bool isSeeded;
  final DateTime? archivedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get active => archivedAt == null;

  factory TransactionCategory.fromJson(
    Map<String, Object?> json, {
    required String ownerId,
  }) {
    return TransactionCategory(
      id: json['id']! as String,
      ownerId: ownerId,
      name: json['name']! as String,
      kind: CategoryKindContract.fromApi(json['kind']! as String),
      parentId: json['parent_id'] as String?,
      isSeeded: json['is_seeded']! as bool,
      archivedAt: _optionalDate(json['archived_at']),
      version: json['version']! as int,
      createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
    );
  }
}

final class TransactionTag {
  const TransactionTag({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.color,
    required this.archivedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? color;
  final DateTime? archivedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get active => archivedAt == null;

  factory TransactionTag.fromJson(
    Map<String, Object?> json, {
    required String ownerId,
  }) {
    return TransactionTag(
      id: json['id']! as String,
      ownerId: ownerId,
      name: json['name']! as String,
      color: json['color'] as String?,
      archivedAt: _optionalDate(json['archived_at']),
      version: json['version']! as int,
      createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at']! as String).toUtc(),
    );
  }
}

final class CategoryDraft {
  const CategoryDraft({
    required this.id,
    required this.name,
    required this.kind,
    this.parentId,
  });

  final String id;
  final String name;
  final CategoryKind kind;
  final String? parentId;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'kind': kind.apiValue,
    'parent_id': parentId,
  };
}

final class TagDraft {
  const TagDraft({required this.id, required this.name, this.color});

  final String id;
  final String name;
  final String? color;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'color': color,
  };
}

DateTime? _optionalDate(Object? value) {
  return value == null ? null : DateTime.parse(value as String).toUtc();
}
