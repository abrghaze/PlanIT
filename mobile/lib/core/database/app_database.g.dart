// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedAccountsTable extends CachedAccounts
    with TableInfo<$CachedAccountsTable, CachedAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 24,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openingBalanceAmountMeta =
      const VerificationMeta('openingBalanceAmount');
  @override
  late final GeneratedColumn<String> openingBalanceAmount =
      GeneratedColumn<String>(
        'opening_balance_amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _calculatedBalanceAmountMeta =
      const VerificationMeta('calculatedBalanceAmount');
  @override
  late final GeneratedColumn<String> calculatedBalanceAmount =
      GeneratedColumn<String>(
        'calculated_balance_amount',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _balanceAsOfMeta = const VerificationMeta(
    'balanceAsOf',
  );
  @override
  late final GeneratedColumn<DateTime> balanceAsOf = GeneratedColumn<DateTime>(
    'balance_as_of',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _includeInTotalMeta = const VerificationMeta(
    'includeInTotal',
  );
  @override
  late final GeneratedColumn<bool> includeInTotal = GeneratedColumn<bool>(
    'include_in_total',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_in_total" IN (0, 1))',
    ),
  );
  static const VerificationMeta _allowNegativeMeta = const VerificationMeta(
    'allowNegative',
  );
  @override
  late final GeneratedColumn<bool> allowNegative = GeneratedColumn<bool>(
    'allow_negative',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_negative" IN (0, 1))',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('sort_order >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('version > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    name,
    type,
    currency,
    openingBalanceAmount,
    calculatedBalanceAmount,
    balanceAsOf,
    openedAt,
    includeInTotal,
    allowNegative,
    status,
    sortOrder,
    archivedAt,
    closedAt,
    version,
    createdAt,
    updatedAt,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedAccount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('opening_balance_amount')) {
      context.handle(
        _openingBalanceAmountMeta,
        openingBalanceAmount.isAcceptableOrUnknown(
          data['opening_balance_amount']!,
          _openingBalanceAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_openingBalanceAmountMeta);
    }
    if (data.containsKey('calculated_balance_amount')) {
      context.handle(
        _calculatedBalanceAmountMeta,
        calculatedBalanceAmount.isAcceptableOrUnknown(
          data['calculated_balance_amount']!,
          _calculatedBalanceAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_calculatedBalanceAmountMeta);
    }
    if (data.containsKey('balance_as_of')) {
      context.handle(
        _balanceAsOfMeta,
        balanceAsOf.isAcceptableOrUnknown(
          data['balance_as_of']!,
          _balanceAsOfMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_balanceAsOfMeta);
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_openedAtMeta);
    }
    if (data.containsKey('include_in_total')) {
      context.handle(
        _includeInTotalMeta,
        includeInTotal.isAcceptableOrUnknown(
          data['include_in_total']!,
          _includeInTotalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_includeInTotalMeta);
    }
    if (data.containsKey('allow_negative')) {
      context.handle(
        _allowNegativeMeta,
        allowNegative.isAcceptableOrUnknown(
          data['allow_negative']!,
          _allowNegativeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allowNegativeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedAccount(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      openingBalanceAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opening_balance_amount'],
      )!,
      calculatedBalanceAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calculated_balance_amount'],
      )!,
      balanceAsOf: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}balance_as_of'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opened_at'],
      )!,
      includeInTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_in_total'],
      )!,
      allowNegative: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_negative'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}closed_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedAccountsTable createAlias(String alias) {
    return $CachedAccountsTable(attachedDatabase, alias);
  }
}

class CachedAccount extends DataClass implements Insertable<CachedAccount> {
  final String id;
  final String ownerId;
  final String name;
  final String type;
  final String currency;
  final String openingBalanceAmount;
  final String calculatedBalanceAmount;
  final DateTime balanceAsOf;
  final DateTime openedAt;
  final bool includeInTotal;
  final bool allowNegative;
  final String status;
  final int sortOrder;
  final DateTime? archivedAt;
  final DateTime? closedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime cachedAt;
  const CachedAccount({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    required this.currency,
    required this.openingBalanceAmount,
    required this.calculatedBalanceAmount,
    required this.balanceAsOf,
    required this.openedAt,
    required this.includeInTotal,
    required this.allowNegative,
    required this.status,
    required this.sortOrder,
    this.archivedAt,
    this.closedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['currency'] = Variable<String>(currency);
    map['opening_balance_amount'] = Variable<String>(openingBalanceAmount);
    map['calculated_balance_amount'] = Variable<String>(
      calculatedBalanceAmount,
    );
    map['balance_as_of'] = Variable<DateTime>(balanceAsOf);
    map['opened_at'] = Variable<DateTime>(openedAt);
    map['include_in_total'] = Variable<bool>(includeInTotal);
    map['allow_negative'] = Variable<bool>(allowNegative);
    map['status'] = Variable<String>(status);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<DateTime>(closedAt);
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedAccountsCompanion toCompanion(bool nullToAbsent) {
    return CachedAccountsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      name: Value(name),
      type: Value(type),
      currency: Value(currency),
      openingBalanceAmount: Value(openingBalanceAmount),
      calculatedBalanceAmount: Value(calculatedBalanceAmount),
      balanceAsOf: Value(balanceAsOf),
      openedAt: Value(openedAt),
      includeInTotal: Value(includeInTotal),
      allowNegative: Value(allowNegative),
      status: Value(status),
      sortOrder: Value(sortOrder),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedAccount(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      currency: serializer.fromJson<String>(json['currency']),
      openingBalanceAmount: serializer.fromJson<String>(
        json['openingBalanceAmount'],
      ),
      calculatedBalanceAmount: serializer.fromJson<String>(
        json['calculatedBalanceAmount'],
      ),
      balanceAsOf: serializer.fromJson<DateTime>(json['balanceAsOf']),
      openedAt: serializer.fromJson<DateTime>(json['openedAt']),
      includeInTotal: serializer.fromJson<bool>(json['includeInTotal']),
      allowNegative: serializer.fromJson<bool>(json['allowNegative']),
      status: serializer.fromJson<String>(json['status']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'currency': serializer.toJson<String>(currency),
      'openingBalanceAmount': serializer.toJson<String>(openingBalanceAmount),
      'calculatedBalanceAmount': serializer.toJson<String>(
        calculatedBalanceAmount,
      ),
      'balanceAsOf': serializer.toJson<DateTime>(balanceAsOf),
      'openedAt': serializer.toJson<DateTime>(openedAt),
      'includeInTotal': serializer.toJson<bool>(includeInTotal),
      'allowNegative': serializer.toJson<bool>(allowNegative),
      'status': serializer.toJson<String>(status),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedAccount copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? type,
    String? currency,
    String? openingBalanceAmount,
    String? calculatedBalanceAmount,
    DateTime? balanceAsOf,
    DateTime? openedAt,
    bool? includeInTotal,
    bool? allowNegative,
    String? status,
    int? sortOrder,
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> closedAt = const Value.absent(),
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? cachedAt,
  }) => CachedAccount(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    name: name ?? this.name,
    type: type ?? this.type,
    currency: currency ?? this.currency,
    openingBalanceAmount: openingBalanceAmount ?? this.openingBalanceAmount,
    calculatedBalanceAmount:
        calculatedBalanceAmount ?? this.calculatedBalanceAmount,
    balanceAsOf: balanceAsOf ?? this.balanceAsOf,
    openedAt: openedAt ?? this.openedAt,
    includeInTotal: includeInTotal ?? this.includeInTotal,
    allowNegative: allowNegative ?? this.allowNegative,
    status: status ?? this.status,
    sortOrder: sortOrder ?? this.sortOrder,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedAccount copyWithCompanion(CachedAccountsCompanion data) {
    return CachedAccount(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      currency: data.currency.present ? data.currency.value : this.currency,
      openingBalanceAmount: data.openingBalanceAmount.present
          ? data.openingBalanceAmount.value
          : this.openingBalanceAmount,
      calculatedBalanceAmount: data.calculatedBalanceAmount.present
          ? data.calculatedBalanceAmount.value
          : this.calculatedBalanceAmount,
      balanceAsOf: data.balanceAsOf.present
          ? data.balanceAsOf.value
          : this.balanceAsOf,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      includeInTotal: data.includeInTotal.present
          ? data.includeInTotal.value
          : this.includeInTotal,
      allowNegative: data.allowNegative.present
          ? data.allowNegative.value
          : this.allowNegative,
      status: data.status.present ? data.status.value : this.status,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedAccount(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('openingBalanceAmount: $openingBalanceAmount, ')
          ..write('calculatedBalanceAmount: $calculatedBalanceAmount, ')
          ..write('balanceAsOf: $balanceAsOf, ')
          ..write('openedAt: $openedAt, ')
          ..write('includeInTotal: $includeInTotal, ')
          ..write('allowNegative: $allowNegative, ')
          ..write('status: $status, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    name,
    type,
    currency,
    openingBalanceAmount,
    calculatedBalanceAmount,
    balanceAsOf,
    openedAt,
    includeInTotal,
    allowNegative,
    status,
    sortOrder,
    archivedAt,
    closedAt,
    version,
    createdAt,
    updatedAt,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedAccount &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.name == this.name &&
          other.type == this.type &&
          other.currency == this.currency &&
          other.openingBalanceAmount == this.openingBalanceAmount &&
          other.calculatedBalanceAmount == this.calculatedBalanceAmount &&
          other.balanceAsOf == this.balanceAsOf &&
          other.openedAt == this.openedAt &&
          other.includeInTotal == this.includeInTotal &&
          other.allowNegative == this.allowNegative &&
          other.status == this.status &&
          other.sortOrder == this.sortOrder &&
          other.archivedAt == this.archivedAt &&
          other.closedAt == this.closedAt &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.cachedAt == this.cachedAt);
}

class CachedAccountsCompanion extends UpdateCompanion<CachedAccount> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> name;
  final Value<String> type;
  final Value<String> currency;
  final Value<String> openingBalanceAmount;
  final Value<String> calculatedBalanceAmount;
  final Value<DateTime> balanceAsOf;
  final Value<DateTime> openedAt;
  final Value<bool> includeInTotal;
  final Value<bool> allowNegative;
  final Value<String> status;
  final Value<int> sortOrder;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> closedAt;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedAccountsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.openingBalanceAmount = const Value.absent(),
    this.calculatedBalanceAmount = const Value.absent(),
    this.balanceAsOf = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.includeInTotal = const Value.absent(),
    this.allowNegative = const Value.absent(),
    this.status = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedAccountsCompanion.insert({
    required String id,
    required String ownerId,
    required String name,
    required String type,
    required String currency,
    required String openingBalanceAmount,
    required String calculatedBalanceAmount,
    required DateTime balanceAsOf,
    required DateTime openedAt,
    required bool includeInTotal,
    required bool allowNegative,
    required String status,
    required int sortOrder,
    this.archivedAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       name = Value(name),
       type = Value(type),
       currency = Value(currency),
       openingBalanceAmount = Value(openingBalanceAmount),
       calculatedBalanceAmount = Value(calculatedBalanceAmount),
       balanceAsOf = Value(balanceAsOf),
       openedAt = Value(openedAt),
       includeInTotal = Value(includeInTotal),
       allowNegative = Value(allowNegative),
       status = Value(status),
       sortOrder = Value(sortOrder),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       cachedAt = Value(cachedAt);
  static Insertable<CachedAccount> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? currency,
    Expression<String>? openingBalanceAmount,
    Expression<String>? calculatedBalanceAmount,
    Expression<DateTime>? balanceAsOf,
    Expression<DateTime>? openedAt,
    Expression<bool>? includeInTotal,
    Expression<bool>? allowNegative,
    Expression<String>? status,
    Expression<int>? sortOrder,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? closedAt,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (currency != null) 'currency': currency,
      if (openingBalanceAmount != null)
        'opening_balance_amount': openingBalanceAmount,
      if (calculatedBalanceAmount != null)
        'calculated_balance_amount': calculatedBalanceAmount,
      if (balanceAsOf != null) 'balance_as_of': balanceAsOf,
      if (openedAt != null) 'opened_at': openedAt,
      if (includeInTotal != null) 'include_in_total': includeInTotal,
      if (allowNegative != null) 'allow_negative': allowNegative,
      if (status != null) 'status': status,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedAccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? name,
    Value<String>? type,
    Value<String>? currency,
    Value<String>? openingBalanceAmount,
    Value<String>? calculatedBalanceAmount,
    Value<DateTime>? balanceAsOf,
    Value<DateTime>? openedAt,
    Value<bool>? includeInTotal,
    Value<bool>? allowNegative,
    Value<String>? status,
    Value<int>? sortOrder,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? closedAt,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedAccountsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      openingBalanceAmount: openingBalanceAmount ?? this.openingBalanceAmount,
      calculatedBalanceAmount:
          calculatedBalanceAmount ?? this.calculatedBalanceAmount,
      balanceAsOf: balanceAsOf ?? this.balanceAsOf,
      openedAt: openedAt ?? this.openedAt,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      allowNegative: allowNegative ?? this.allowNegative,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      archivedAt: archivedAt ?? this.archivedAt,
      closedAt: closedAt ?? this.closedAt,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (openingBalanceAmount.present) {
      map['opening_balance_amount'] = Variable<String>(
        openingBalanceAmount.value,
      );
    }
    if (calculatedBalanceAmount.present) {
      map['calculated_balance_amount'] = Variable<String>(
        calculatedBalanceAmount.value,
      );
    }
    if (balanceAsOf.present) {
      map['balance_as_of'] = Variable<DateTime>(balanceAsOf.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (includeInTotal.present) {
      map['include_in_total'] = Variable<bool>(includeInTotal.value);
    }
    if (allowNegative.present) {
      map['allow_negative'] = Variable<bool>(allowNegative.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedAccountsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('openingBalanceAmount: $openingBalanceAmount, ')
          ..write('calculatedBalanceAmount: $calculatedBalanceAmount, ')
          ..write('balanceAsOf: $balanceAsOf, ')
          ..write('openedAt: $openedAt, ')
          ..write('includeInTotal: $includeInTotal, ')
          ..write('allowNegative: $allowNegative, ')
          ..write('status: $status, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedCategoriesTable extends CachedCategories
    with TableInfo<$CachedCategoriesTable, CachedCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSeededMeta = const VerificationMeta(
    'isSeeded',
  );
  @override
  late final GeneratedColumn<bool> isSeeded = GeneratedColumn<bool>(
    'is_seeded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_seeded" IN (0, 1))',
    ),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('version > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    name,
    kind,
    parentId,
    isSeeded,
    archivedAt,
    version,
    createdAt,
    updatedAt,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('is_seeded')) {
      context.handle(
        _isSeededMeta,
        isSeeded.isAcceptableOrUnknown(data['is_seeded']!, _isSeededMeta),
      );
    } else if (isInserting) {
      context.missing(_isSeededMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      isSeeded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_seeded'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedCategoriesTable createAlias(String alias) {
    return $CachedCategoriesTable(attachedDatabase, alias);
  }
}

class CachedCategory extends DataClass implements Insertable<CachedCategory> {
  final String id;
  final String ownerId;
  final String name;
  final String kind;
  final String? parentId;
  final bool isSeeded;
  final DateTime? archivedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime cachedAt;
  const CachedCategory({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.kind,
    this.parentId,
    required this.isSeeded,
    this.archivedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['is_seeded'] = Variable<bool>(isSeeded);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedCategoriesCompanion toCompanion(bool nullToAbsent) {
    return CachedCategoriesCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      name: Value(name),
      kind: Value(kind),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      isSeeded: Value(isSeeded),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCategory(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      isSeeded: serializer.fromJson<bool>(json['isSeeded']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'parentId': serializer.toJson<String?>(parentId),
      'isSeeded': serializer.toJson<bool>(isSeeded),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedCategory copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? kind,
    Value<String?> parentId = const Value.absent(),
    bool? isSeeded,
    Value<DateTime?> archivedAt = const Value.absent(),
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? cachedAt,
  }) => CachedCategory(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    parentId: parentId.present ? parentId.value : this.parentId,
    isSeeded: isSeeded ?? this.isSeeded,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedCategory copyWithCompanion(CachedCategoriesCompanion data) {
    return CachedCategory(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      isSeeded: data.isSeeded.present ? data.isSeeded.value : this.isSeeded,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCategory(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('parentId: $parentId, ')
          ..write('isSeeded: $isSeeded, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    name,
    kind,
    parentId,
    isSeeded,
    archivedAt,
    version,
    createdAt,
    updatedAt,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCategory &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.parentId == this.parentId &&
          other.isSeeded == this.isSeeded &&
          other.archivedAt == this.archivedAt &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.cachedAt == this.cachedAt);
}

class CachedCategoriesCompanion extends UpdateCompanion<CachedCategory> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> name;
  final Value<String> kind;
  final Value<String?> parentId;
  final Value<bool> isSeeded;
  final Value<DateTime?> archivedAt;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedCategoriesCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.parentId = const Value.absent(),
    this.isSeeded = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCategoriesCompanion.insert({
    required String id,
    required String ownerId,
    required String name,
    required String kind,
    this.parentId = const Value.absent(),
    required bool isSeeded,
    this.archivedAt = const Value.absent(),
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       name = Value(name),
       kind = Value(kind),
       isSeeded = Value(isSeeded),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       cachedAt = Value(cachedAt);
  static Insertable<CachedCategory> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? parentId,
    Expression<bool>? isSeeded,
    Expression<DateTime>? archivedAt,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (parentId != null) 'parent_id': parentId,
      if (isSeeded != null) 'is_seeded': isSeeded,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? name,
    Value<String>? kind,
    Value<String?>? parentId,
    Value<bool>? isSeeded,
    Value<DateTime?>? archivedAt,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedCategoriesCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      parentId: parentId ?? this.parentId,
      isSeeded: isSeeded ?? this.isSeeded,
      archivedAt: archivedAt ?? this.archivedAt,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (isSeeded.present) {
      map['is_seeded'] = Variable<bool>(isSeeded.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('parentId: $parentId, ')
          ..write('isSeeded: $isSeeded, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedTagsTable extends CachedTags
    with TableInfo<$CachedTagsTable, CachedTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 7,
      maxTextLength: 7,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('version > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    name,
    color,
    archivedAt,
    version,
    createdAt,
    updatedAt,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedTagsTable createAlias(String alias) {
    return $CachedTagsTable(attachedDatabase, alias);
  }
}

class CachedTag extends DataClass implements Insertable<CachedTag> {
  final String id;
  final String ownerId;
  final String name;
  final String? color;
  final DateTime? archivedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime cachedAt;
  const CachedTag({
    required this.id,
    required this.ownerId,
    required this.name,
    this.color,
    this.archivedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedTagsCompanion toCompanion(bool nullToAbsent) {
    return CachedTagsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTag(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String?>(json['color']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedTag copyWith({
    String? id,
    String? ownerId,
    String? name,
    Value<String?> color = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? cachedAt,
  }) => CachedTag(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedTag copyWithCompanion(CachedTagsCompanion data) {
    return CachedTag(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTag(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    name,
    color,
    archivedAt,
    version,
    createdAt,
    updatedAt,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTag &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.name == this.name &&
          other.color == this.color &&
          other.archivedAt == this.archivedAt &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.cachedAt == this.cachedAt);
}

class CachedTagsCompanion extends UpdateCompanion<CachedTag> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> name;
  final Value<String?> color;
  final Value<DateTime?> archivedAt;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedTagsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedTagsCompanion.insert({
    required String id,
    required String ownerId,
    required String name,
    this.color = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       name = Value(name),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       cachedAt = Value(cachedAt);
  static Insertable<CachedTag> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? name,
    Expression<String>? color,
    Expression<DateTime>? archivedAt,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedTagsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? name,
    Value<String?>? color,
    Value<DateTime?>? archivedAt,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedTagsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      color: color ?? this.color,
      archivedAt: archivedAt ?? this.archivedAt,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedTagsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedTransactionsTable extends CachedTransactions
    with TableInfo<$CachedTransactionsTable, CachedTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _effectMeta = const VerificationMeta('effect');
  @override
  late final GeneratedColumn<String> effect = GeneratedColumn<String>(
    'effect',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<String> amount = GeneratedColumn<String>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _counterpartyMeta = const VerificationMeta(
    'counterparty',
  );
  @override
  late final GeneratedColumn<String> counterparty = GeneratedColumn<String>(
    'counterparty',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 160,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentTransactionIdMeta =
      const VerificationMeta('parentTransactionId');
  @override
  late final GeneratedColumn<String> parentTransactionId =
      GeneratedColumn<String>(
        'parent_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reversalOfIdMeta = const VerificationMeta(
    'reversalOfId',
  );
  @override
  late final GeneratedColumn<String> reversalOfId = GeneratedColumn<String>(
    'reversal_of_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientOperationIdMeta = const VerificationMeta(
    'clientOperationId',
  );
  @override
  late final GeneratedColumn<String> clientOperationId =
      GeneratedColumn<String>(
        'client_operation_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('version > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pendingActionMeta = const VerificationMeta(
    'pendingAction',
  );
  @override
  late final GeneratedColumn<String> pendingAction = GeneratedColumn<String>(
    'pending_action',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 24,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncErrorMeta = const VerificationMeta(
    'lastSyncError',
  );
  @override
  late final GeneratedColumn<String> lastSyncError = GeneratedColumn<String>(
    'last_sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    accountId,
    type,
    effect,
    amount,
    currency,
    occurredAt,
    status,
    categoryId,
    counterparty,
    note,
    parentTransactionId,
    reversalOfId,
    clientOperationId,
    version,
    createdAt,
    updatedAt,
    cachedAt,
    syncState,
    pendingAction,
    lastSyncError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('effect')) {
      context.handle(
        _effectMeta,
        effect.isAcceptableOrUnknown(data['effect']!, _effectMeta),
      );
    } else if (isInserting) {
      context.missing(_effectMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('counterparty')) {
      context.handle(
        _counterpartyMeta,
        counterparty.isAcceptableOrUnknown(
          data['counterparty']!,
          _counterpartyMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('parent_transaction_id')) {
      context.handle(
        _parentTransactionIdMeta,
        parentTransactionId.isAcceptableOrUnknown(
          data['parent_transaction_id']!,
          _parentTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('reversal_of_id')) {
      context.handle(
        _reversalOfIdMeta,
        reversalOfId.isAcceptableOrUnknown(
          data['reversal_of_id']!,
          _reversalOfIdMeta,
        ),
      );
    }
    if (data.containsKey('client_operation_id')) {
      context.handle(
        _clientOperationIdMeta,
        clientOperationId.isAcceptableOrUnknown(
          data['client_operation_id']!,
          _clientOperationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientOperationIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    } else if (isInserting) {
      context.missing(_syncStateMeta);
    }
    if (data.containsKey('pending_action')) {
      context.handle(
        _pendingActionMeta,
        pendingAction.isAcceptableOrUnknown(
          data['pending_action']!,
          _pendingActionMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_error')) {
      context.handle(
        _lastSyncErrorMeta,
        lastSyncError.isAcceptableOrUnknown(
          data['last_sync_error']!,
          _lastSyncErrorMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      effect: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effect'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      counterparty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterparty'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      parentTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_transaction_id'],
      ),
      reversalOfId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reversal_of_id'],
      ),
      clientOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_operation_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      pendingAction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_action'],
      ),
      lastSyncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_sync_error'],
      ),
    );
  }

  @override
  $CachedTransactionsTable createAlias(String alias) {
    return $CachedTransactionsTable(attachedDatabase, alias);
  }
}

class CachedTransaction extends DataClass
    implements Insertable<CachedTransaction> {
  final String id;
  final String ownerId;
  final String accountId;
  final String type;
  final String effect;
  final String amount;
  final String currency;
  final DateTime occurredAt;
  final String status;
  final String? categoryId;
  final String? counterparty;
  final String? note;
  final String? parentTransactionId;
  final String? reversalOfId;
  final String clientOperationId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime cachedAt;
  final String syncState;
  final String? pendingAction;
  final String? lastSyncError;
  const CachedTransaction({
    required this.id,
    required this.ownerId,
    required this.accountId,
    required this.type,
    required this.effect,
    required this.amount,
    required this.currency,
    required this.occurredAt,
    required this.status,
    this.categoryId,
    this.counterparty,
    this.note,
    this.parentTransactionId,
    this.reversalOfId,
    required this.clientOperationId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.cachedAt,
    required this.syncState,
    this.pendingAction,
    this.lastSyncError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['account_id'] = Variable<String>(accountId);
    map['type'] = Variable<String>(type);
    map['effect'] = Variable<String>(effect);
    map['amount'] = Variable<String>(amount);
    map['currency'] = Variable<String>(currency);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || counterparty != null) {
      map['counterparty'] = Variable<String>(counterparty);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || parentTransactionId != null) {
      map['parent_transaction_id'] = Variable<String>(parentTransactionId);
    }
    if (!nullToAbsent || reversalOfId != null) {
      map['reversal_of_id'] = Variable<String>(reversalOfId);
    }
    map['client_operation_id'] = Variable<String>(clientOperationId);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || pendingAction != null) {
      map['pending_action'] = Variable<String>(pendingAction);
    }
    if (!nullToAbsent || lastSyncError != null) {
      map['last_sync_error'] = Variable<String>(lastSyncError);
    }
    return map;
  }

  CachedTransactionsCompanion toCompanion(bool nullToAbsent) {
    return CachedTransactionsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      accountId: Value(accountId),
      type: Value(type),
      effect: Value(effect),
      amount: Value(amount),
      currency: Value(currency),
      occurredAt: Value(occurredAt),
      status: Value(status),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      counterparty: counterparty == null && nullToAbsent
          ? const Value.absent()
          : Value(counterparty),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      parentTransactionId: parentTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentTransactionId),
      reversalOfId: reversalOfId == null && nullToAbsent
          ? const Value.absent()
          : Value(reversalOfId),
      clientOperationId: Value(clientOperationId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      cachedAt: Value(cachedAt),
      syncState: Value(syncState),
      pendingAction: pendingAction == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingAction),
      lastSyncError: lastSyncError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncError),
    );
  }

  factory CachedTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTransaction(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      type: serializer.fromJson<String>(json['type']),
      effect: serializer.fromJson<String>(json['effect']),
      amount: serializer.fromJson<String>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      status: serializer.fromJson<String>(json['status']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      counterparty: serializer.fromJson<String?>(json['counterparty']),
      note: serializer.fromJson<String?>(json['note']),
      parentTransactionId: serializer.fromJson<String?>(
        json['parentTransactionId'],
      ),
      reversalOfId: serializer.fromJson<String?>(json['reversalOfId']),
      clientOperationId: serializer.fromJson<String>(json['clientOperationId']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      syncState: serializer.fromJson<String>(json['syncState']),
      pendingAction: serializer.fromJson<String?>(json['pendingAction']),
      lastSyncError: serializer.fromJson<String?>(json['lastSyncError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'accountId': serializer.toJson<String>(accountId),
      'type': serializer.toJson<String>(type),
      'effect': serializer.toJson<String>(effect),
      'amount': serializer.toJson<String>(amount),
      'currency': serializer.toJson<String>(currency),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'status': serializer.toJson<String>(status),
      'categoryId': serializer.toJson<String?>(categoryId),
      'counterparty': serializer.toJson<String?>(counterparty),
      'note': serializer.toJson<String?>(note),
      'parentTransactionId': serializer.toJson<String?>(parentTransactionId),
      'reversalOfId': serializer.toJson<String?>(reversalOfId),
      'clientOperationId': serializer.toJson<String>(clientOperationId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'syncState': serializer.toJson<String>(syncState),
      'pendingAction': serializer.toJson<String?>(pendingAction),
      'lastSyncError': serializer.toJson<String?>(lastSyncError),
    };
  }

  CachedTransaction copyWith({
    String? id,
    String? ownerId,
    String? accountId,
    String? type,
    String? effect,
    String? amount,
    String? currency,
    DateTime? occurredAt,
    String? status,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> counterparty = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> parentTransactionId = const Value.absent(),
    Value<String?> reversalOfId = const Value.absent(),
    String? clientOperationId,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? cachedAt,
    String? syncState,
    Value<String?> pendingAction = const Value.absent(),
    Value<String?> lastSyncError = const Value.absent(),
  }) => CachedTransaction(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    accountId: accountId ?? this.accountId,
    type: type ?? this.type,
    effect: effect ?? this.effect,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    occurredAt: occurredAt ?? this.occurredAt,
    status: status ?? this.status,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    counterparty: counterparty.present ? counterparty.value : this.counterparty,
    note: note.present ? note.value : this.note,
    parentTransactionId: parentTransactionId.present
        ? parentTransactionId.value
        : this.parentTransactionId,
    reversalOfId: reversalOfId.present ? reversalOfId.value : this.reversalOfId,
    clientOperationId: clientOperationId ?? this.clientOperationId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cachedAt: cachedAt ?? this.cachedAt,
    syncState: syncState ?? this.syncState,
    pendingAction: pendingAction.present
        ? pendingAction.value
        : this.pendingAction,
    lastSyncError: lastSyncError.present
        ? lastSyncError.value
        : this.lastSyncError,
  );
  CachedTransaction copyWithCompanion(CachedTransactionsCompanion data) {
    return CachedTransaction(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      type: data.type.present ? data.type.value : this.type,
      effect: data.effect.present ? data.effect.value : this.effect,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      status: data.status.present ? data.status.value : this.status,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      counterparty: data.counterparty.present
          ? data.counterparty.value
          : this.counterparty,
      note: data.note.present ? data.note.value : this.note,
      parentTransactionId: data.parentTransactionId.present
          ? data.parentTransactionId.value
          : this.parentTransactionId,
      reversalOfId: data.reversalOfId.present
          ? data.reversalOfId.value
          : this.reversalOfId,
      clientOperationId: data.clientOperationId.present
          ? data.clientOperationId.value
          : this.clientOperationId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      pendingAction: data.pendingAction.present
          ? data.pendingAction.value
          : this.pendingAction,
      lastSyncError: data.lastSyncError.present
          ? data.lastSyncError.value
          : this.lastSyncError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTransaction(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('accountId: $accountId, ')
          ..write('type: $type, ')
          ..write('effect: $effect, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('status: $status, ')
          ..write('categoryId: $categoryId, ')
          ..write('counterparty: $counterparty, ')
          ..write('note: $note, ')
          ..write('parentTransactionId: $parentTransactionId, ')
          ..write('reversalOfId: $reversalOfId, ')
          ..write('clientOperationId: $clientOperationId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('syncState: $syncState, ')
          ..write('pendingAction: $pendingAction, ')
          ..write('lastSyncError: $lastSyncError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    ownerId,
    accountId,
    type,
    effect,
    amount,
    currency,
    occurredAt,
    status,
    categoryId,
    counterparty,
    note,
    parentTransactionId,
    reversalOfId,
    clientOperationId,
    version,
    createdAt,
    updatedAt,
    cachedAt,
    syncState,
    pendingAction,
    lastSyncError,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTransaction &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.accountId == this.accountId &&
          other.type == this.type &&
          other.effect == this.effect &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.occurredAt == this.occurredAt &&
          other.status == this.status &&
          other.categoryId == this.categoryId &&
          other.counterparty == this.counterparty &&
          other.note == this.note &&
          other.parentTransactionId == this.parentTransactionId &&
          other.reversalOfId == this.reversalOfId &&
          other.clientOperationId == this.clientOperationId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.cachedAt == this.cachedAt &&
          other.syncState == this.syncState &&
          other.pendingAction == this.pendingAction &&
          other.lastSyncError == this.lastSyncError);
}

class CachedTransactionsCompanion extends UpdateCompanion<CachedTransaction> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> accountId;
  final Value<String> type;
  final Value<String> effect;
  final Value<String> amount;
  final Value<String> currency;
  final Value<DateTime> occurredAt;
  final Value<String> status;
  final Value<String?> categoryId;
  final Value<String?> counterparty;
  final Value<String?> note;
  final Value<String?> parentTransactionId;
  final Value<String?> reversalOfId;
  final Value<String> clientOperationId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime> cachedAt;
  final Value<String> syncState;
  final Value<String?> pendingAction;
  final Value<String?> lastSyncError;
  final Value<int> rowid;
  const CachedTransactionsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.type = const Value.absent(),
    this.effect = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.status = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.note = const Value.absent(),
    this.parentTransactionId = const Value.absent(),
    this.reversalOfId = const Value.absent(),
    this.clientOperationId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.syncState = const Value.absent(),
    this.pendingAction = const Value.absent(),
    this.lastSyncError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedTransactionsCompanion.insert({
    required String id,
    required String ownerId,
    required String accountId,
    required String type,
    required String effect,
    required String amount,
    required String currency,
    required DateTime occurredAt,
    required String status,
    this.categoryId = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.note = const Value.absent(),
    this.parentTransactionId = const Value.absent(),
    this.reversalOfId = const Value.absent(),
    required String clientOperationId,
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime cachedAt,
    required String syncState,
    this.pendingAction = const Value.absent(),
    this.lastSyncError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       accountId = Value(accountId),
       type = Value(type),
       effect = Value(effect),
       amount = Value(amount),
       currency = Value(currency),
       occurredAt = Value(occurredAt),
       status = Value(status),
       clientOperationId = Value(clientOperationId),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       cachedAt = Value(cachedAt),
       syncState = Value(syncState);
  static Insertable<CachedTransaction> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? accountId,
    Expression<String>? type,
    Expression<String>? effect,
    Expression<String>? amount,
    Expression<String>? currency,
    Expression<DateTime>? occurredAt,
    Expression<String>? status,
    Expression<String>? categoryId,
    Expression<String>? counterparty,
    Expression<String>? note,
    Expression<String>? parentTransactionId,
    Expression<String>? reversalOfId,
    Expression<String>? clientOperationId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? cachedAt,
    Expression<String>? syncState,
    Expression<String>? pendingAction,
    Expression<String>? lastSyncError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (accountId != null) 'account_id': accountId,
      if (type != null) 'type': type,
      if (effect != null) 'effect': effect,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (status != null) 'status': status,
      if (categoryId != null) 'category_id': categoryId,
      if (counterparty != null) 'counterparty': counterparty,
      if (note != null) 'note': note,
      if (parentTransactionId != null)
        'parent_transaction_id': parentTransactionId,
      if (reversalOfId != null) 'reversal_of_id': reversalOfId,
      if (clientOperationId != null) 'client_operation_id': clientOperationId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (syncState != null) 'sync_state': syncState,
      if (pendingAction != null) 'pending_action': pendingAction,
      if (lastSyncError != null) 'last_sync_error': lastSyncError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? accountId,
    Value<String>? type,
    Value<String>? effect,
    Value<String>? amount,
    Value<String>? currency,
    Value<DateTime>? occurredAt,
    Value<String>? status,
    Value<String?>? categoryId,
    Value<String?>? counterparty,
    Value<String?>? note,
    Value<String?>? parentTransactionId,
    Value<String?>? reversalOfId,
    Value<String>? clientOperationId,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime>? cachedAt,
    Value<String>? syncState,
    Value<String?>? pendingAction,
    Value<String?>? lastSyncError,
    Value<int>? rowid,
  }) {
    return CachedTransactionsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      effect: effect ?? this.effect,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      occurredAt: occurredAt ?? this.occurredAt,
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      counterparty: counterparty ?? this.counterparty,
      note: note ?? this.note,
      parentTransactionId: parentTransactionId ?? this.parentTransactionId,
      reversalOfId: reversalOfId ?? this.reversalOfId,
      clientOperationId: clientOperationId ?? this.clientOperationId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      syncState: syncState ?? this.syncState,
      pendingAction: pendingAction ?? this.pendingAction,
      lastSyncError: lastSyncError ?? this.lastSyncError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (effect.present) {
      map['effect'] = Variable<String>(effect.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (counterparty.present) {
      map['counterparty'] = Variable<String>(counterparty.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (parentTransactionId.present) {
      map['parent_transaction_id'] = Variable<String>(
        parentTransactionId.value,
      );
    }
    if (reversalOfId.present) {
      map['reversal_of_id'] = Variable<String>(reversalOfId.value);
    }
    if (clientOperationId.present) {
      map['client_operation_id'] = Variable<String>(clientOperationId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (pendingAction.present) {
      map['pending_action'] = Variable<String>(pendingAction.value);
    }
    if (lastSyncError.present) {
      map['last_sync_error'] = Variable<String>(lastSyncError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('accountId: $accountId, ')
          ..write('type: $type, ')
          ..write('effect: $effect, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('status: $status, ')
          ..write('categoryId: $categoryId, ')
          ..write('counterparty: $counterparty, ')
          ..write('note: $note, ')
          ..write('parentTransactionId: $parentTransactionId, ')
          ..write('reversalOfId: $reversalOfId, ')
          ..write('clientOperationId: $clientOperationId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('syncState: $syncState, ')
          ..write('pendingAction: $pendingAction, ')
          ..write('lastSyncError: $lastSyncError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedTransactionTagsTable extends CachedTransactionTags
    with TableInfo<$CachedTransactionTagsTable, CachedTransactionTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTransactionTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [transactionId, tagId, ownerId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_transaction_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedTransactionTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {transactionId, tagId};
  @override
  CachedTransactionTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTransactionTag(
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
    );
  }

  @override
  $CachedTransactionTagsTable createAlias(String alias) {
    return $CachedTransactionTagsTable(attachedDatabase, alias);
  }
}

class CachedTransactionTag extends DataClass
    implements Insertable<CachedTransactionTag> {
  final String transactionId;
  final String tagId;
  final String ownerId;
  const CachedTransactionTag({
    required this.transactionId,
    required this.tagId,
    required this.ownerId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['transaction_id'] = Variable<String>(transactionId);
    map['tag_id'] = Variable<String>(tagId);
    map['owner_id'] = Variable<String>(ownerId);
    return map;
  }

  CachedTransactionTagsCompanion toCompanion(bool nullToAbsent) {
    return CachedTransactionTagsCompanion(
      transactionId: Value(transactionId),
      tagId: Value(tagId),
      ownerId: Value(ownerId),
    );
  }

  factory CachedTransactionTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTransactionTag(
      transactionId: serializer.fromJson<String>(json['transactionId']),
      tagId: serializer.fromJson<String>(json['tagId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'transactionId': serializer.toJson<String>(transactionId),
      'tagId': serializer.toJson<String>(tagId),
      'ownerId': serializer.toJson<String>(ownerId),
    };
  }

  CachedTransactionTag copyWith({
    String? transactionId,
    String? tagId,
    String? ownerId,
  }) => CachedTransactionTag(
    transactionId: transactionId ?? this.transactionId,
    tagId: tagId ?? this.tagId,
    ownerId: ownerId ?? this.ownerId,
  );
  CachedTransactionTag copyWithCompanion(CachedTransactionTagsCompanion data) {
    return CachedTransactionTag(
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTransactionTag(')
          ..write('transactionId: $transactionId, ')
          ..write('tagId: $tagId, ')
          ..write('ownerId: $ownerId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(transactionId, tagId, ownerId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTransactionTag &&
          other.transactionId == this.transactionId &&
          other.tagId == this.tagId &&
          other.ownerId == this.ownerId);
}

class CachedTransactionTagsCompanion
    extends UpdateCompanion<CachedTransactionTag> {
  final Value<String> transactionId;
  final Value<String> tagId;
  final Value<String> ownerId;
  final Value<int> rowid;
  const CachedTransactionTagsCompanion({
    this.transactionId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedTransactionTagsCompanion.insert({
    required String transactionId,
    required String tagId,
    required String ownerId,
    this.rowid = const Value.absent(),
  }) : transactionId = Value(transactionId),
       tagId = Value(tagId),
       ownerId = Value(ownerId);
  static Insertable<CachedTransactionTag> custom({
    Expression<String>? transactionId,
    Expression<String>? tagId,
    Expression<String>? ownerId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (transactionId != null) 'transaction_id': transactionId,
      if (tagId != null) 'tag_id': tagId,
      if (ownerId != null) 'owner_id': ownerId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedTransactionTagsCompanion copyWith({
    Value<String>? transactionId,
    Value<String>? tagId,
    Value<String>? ownerId,
    Value<int>? rowid,
  }) {
    return CachedTransactionTagsCompanion(
      transactionId: transactionId ?? this.transactionId,
      tagId: tagId ?? this.tagId,
      ownerId: ownerId ?? this.ownerId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedTransactionTagsCompanion(')
          ..write('transactionId: $transactionId, ')
          ..write('tagId: $tagId, ')
          ..write('ownerId: $ownerId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxOperationsTable extends OutboxOperations
    with TableInfo<$OutboxOperationsTable, OutboxOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 24,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>('attempt_count >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    entityId,
    type,
    payloadJson,
    state,
    attemptCount,
    nextAttemptAt,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attemptCountMeta);
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxOperation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OutboxOperationsTable createAlias(String alias) {
    return $OutboxOperationsTable(attachedDatabase, alias);
  }
}

class OutboxOperation extends DataClass implements Insertable<OutboxOperation> {
  final String id;
  final String ownerId;
  final String entityId;
  final String type;
  final String payloadJson;
  final String state;
  final int attemptCount;
  final DateTime nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const OutboxOperation({
    required this.id,
    required this.ownerId,
    required this.entityId,
    required this.type,
    required this.payloadJson,
    required this.state,
    required this.attemptCount,
    required this.nextAttemptAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['entity_id'] = Variable<String>(entityId);
    map['type'] = Variable<String>(type);
    map['payload_json'] = Variable<String>(payloadJson);
    map['state'] = Variable<String>(state);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OutboxOperationsCompanion toCompanion(bool nullToAbsent) {
    return OutboxOperationsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      entityId: Value(entityId),
      type: Value(type),
      payloadJson: Value(payloadJson),
      state: Value(state),
      attemptCount: Value(attemptCount),
      nextAttemptAt: Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OutboxOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxOperation(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      entityId: serializer.fromJson<String>(json['entityId']),
      type: serializer.fromJson<String>(json['type']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      state: serializer.fromJson<String>(json['state']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'entityId': serializer.toJson<String>(entityId),
      'type': serializer.toJson<String>(type),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'state': serializer.toJson<String>(state),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OutboxOperation copyWith({
    String? id,
    String? ownerId,
    String? entityId,
    String? type,
    String? payloadJson,
    String? state,
    int? attemptCount,
    DateTime? nextAttemptAt,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => OutboxOperation(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    entityId: entityId ?? this.entityId,
    type: type ?? this.type,
    payloadJson: payloadJson ?? this.payloadJson,
    state: state ?? this.state,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OutboxOperation copyWithCompanion(OutboxOperationsCompanion data) {
    return OutboxOperation(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      type: data.type.present ? data.type.value : this.type,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      state: data.state.present ? data.state.value : this.state,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxOperation(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('entityId: $entityId, ')
          ..write('type: $type, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    entityId,
    type,
    payloadJson,
    state,
    attemptCount,
    nextAttemptAt,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxOperation &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.entityId == this.entityId &&
          other.type == this.type &&
          other.payloadJson == this.payloadJson &&
          other.state == this.state &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OutboxOperationsCompanion extends UpdateCompanion<OutboxOperation> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> entityId;
  final Value<String> type;
  final Value<String> payloadJson;
  final Value<String> state;
  final Value<int> attemptCount;
  final Value<DateTime> nextAttemptAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const OutboxOperationsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.entityId = const Value.absent(),
    this.type = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.state = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxOperationsCompanion.insert({
    required String id,
    required String ownerId,
    required String entityId,
    required String type,
    required String payloadJson,
    required String state,
    required int attemptCount,
    required DateTime nextAttemptAt,
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       entityId = Value(entityId),
       type = Value(type),
       payloadJson = Value(payloadJson),
       state = Value(state),
       attemptCount = Value(attemptCount),
       nextAttemptAt = Value(nextAttemptAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<OutboxOperation> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? entityId,
    Expression<String>? type,
    Expression<String>? payloadJson,
    Expression<String>? state,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (entityId != null) 'entity_id': entityId,
      if (type != null) 'type': type,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (state != null) 'state': state,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxOperationsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? entityId,
    Value<String>? type,
    Value<String>? payloadJson,
    Value<String>? state,
    Value<int>? attemptCount,
    Value<DateTime>? nextAttemptAt,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return OutboxOperationsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      entityId: entityId ?? this.entityId,
      type: type ?? this.type,
      payloadJson: payloadJson ?? this.payloadJson,
      state: state ?? this.state,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxOperationsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('entityId: $entityId, ')
          ..write('type: $type, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedAccountsTable cachedAccounts = $CachedAccountsTable(this);
  late final $CachedCategoriesTable cachedCategories = $CachedCategoriesTable(
    this,
  );
  late final $CachedTagsTable cachedTags = $CachedTagsTable(this);
  late final $CachedTransactionsTable cachedTransactions =
      $CachedTransactionsTable(this);
  late final $CachedTransactionTagsTable cachedTransactionTags =
      $CachedTransactionTagsTable(this);
  late final $OutboxOperationsTable outboxOperations = $OutboxOperationsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedAccounts,
    cachedCategories,
    cachedTags,
    cachedTransactions,
    cachedTransactionTags,
    outboxOperations,
  ];
}

typedef $$CachedAccountsTableCreateCompanionBuilder =
    CachedAccountsCompanion Function({
      required String id,
      required String ownerId,
      required String name,
      required String type,
      required String currency,
      required String openingBalanceAmount,
      required String calculatedBalanceAmount,
      required DateTime balanceAsOf,
      required DateTime openedAt,
      required bool includeInTotal,
      required bool allowNegative,
      required String status,
      required int sortOrder,
      Value<DateTime?> archivedAt,
      Value<DateTime?> closedAt,
      required int version,
      required DateTime createdAt,
      required DateTime updatedAt,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedAccountsTableUpdateCompanionBuilder =
    CachedAccountsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> name,
      Value<String> type,
      Value<String> currency,
      Value<String> openingBalanceAmount,
      Value<String> calculatedBalanceAmount,
      Value<DateTime> balanceAsOf,
      Value<DateTime> openedAt,
      Value<bool> includeInTotal,
      Value<bool> allowNegative,
      Value<String> status,
      Value<int> sortOrder,
      Value<DateTime?> archivedAt,
      Value<DateTime?> closedAt,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedAccountsTable> {
  $$CachedAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get openingBalanceAmount => $composableBuilder(
    column: $table.openingBalanceAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calculatedBalanceAmount => $composableBuilder(
    column: $table.calculatedBalanceAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get balanceAsOf => $composableBuilder(
    column: $table.balanceAsOf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeInTotal => $composableBuilder(
    column: $table.includeInTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowNegative => $composableBuilder(
    column: $table.allowNegative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedAccountsTable> {
  $$CachedAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openingBalanceAmount => $composableBuilder(
    column: $table.openingBalanceAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calculatedBalanceAmount => $composableBuilder(
    column: $table.calculatedBalanceAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get balanceAsOf => $composableBuilder(
    column: $table.balanceAsOf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeInTotal => $composableBuilder(
    column: $table.includeInTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowNegative => $composableBuilder(
    column: $table.allowNegative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedAccountsTable> {
  $$CachedAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get openingBalanceAmount => $composableBuilder(
    column: $table.openingBalanceAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calculatedBalanceAmount => $composableBuilder(
    column: $table.calculatedBalanceAmount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get balanceAsOf => $composableBuilder(
    column: $table.balanceAsOf,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<bool> get includeInTotal => $composableBuilder(
    column: $table.includeInTotal,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowNegative => $composableBuilder(
    column: $table.allowNegative,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedAccountsTable,
          CachedAccount,
          $$CachedAccountsTableFilterComposer,
          $$CachedAccountsTableOrderingComposer,
          $$CachedAccountsTableAnnotationComposer,
          $$CachedAccountsTableCreateCompanionBuilder,
          $$CachedAccountsTableUpdateCompanionBuilder,
          (
            CachedAccount,
            BaseReferences<_$AppDatabase, $CachedAccountsTable, CachedAccount>,
          ),
          CachedAccount,
          PrefetchHooks Function()
        > {
  $$CachedAccountsTableTableManager(
    _$AppDatabase db,
    $CachedAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> openingBalanceAmount = const Value.absent(),
                Value<String> calculatedBalanceAmount = const Value.absent(),
                Value<DateTime> balanceAsOf = const Value.absent(),
                Value<DateTime> openedAt = const Value.absent(),
                Value<bool> includeInTotal = const Value.absent(),
                Value<bool> allowNegative = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedAccountsCompanion(
                id: id,
                ownerId: ownerId,
                name: name,
                type: type,
                currency: currency,
                openingBalanceAmount: openingBalanceAmount,
                calculatedBalanceAmount: calculatedBalanceAmount,
                balanceAsOf: balanceAsOf,
                openedAt: openedAt,
                includeInTotal: includeInTotal,
                allowNegative: allowNegative,
                status: status,
                sortOrder: sortOrder,
                archivedAt: archivedAt,
                closedAt: closedAt,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String name,
                required String type,
                required String currency,
                required String openingBalanceAmount,
                required String calculatedBalanceAmount,
                required DateTime balanceAsOf,
                required DateTime openedAt,
                required bool includeInTotal,
                required bool allowNegative,
                required String status,
                required int sortOrder,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                required int version,
                required DateTime createdAt,
                required DateTime updatedAt,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedAccountsCompanion.insert(
                id: id,
                ownerId: ownerId,
                name: name,
                type: type,
                currency: currency,
                openingBalanceAmount: openingBalanceAmount,
                calculatedBalanceAmount: calculatedBalanceAmount,
                balanceAsOf: balanceAsOf,
                openedAt: openedAt,
                includeInTotal: includeInTotal,
                allowNegative: allowNegative,
                status: status,
                sortOrder: sortOrder,
                archivedAt: archivedAt,
                closedAt: closedAt,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedAccountsTable,
      CachedAccount,
      $$CachedAccountsTableFilterComposer,
      $$CachedAccountsTableOrderingComposer,
      $$CachedAccountsTableAnnotationComposer,
      $$CachedAccountsTableCreateCompanionBuilder,
      $$CachedAccountsTableUpdateCompanionBuilder,
      (
        CachedAccount,
        BaseReferences<_$AppDatabase, $CachedAccountsTable, CachedAccount>,
      ),
      CachedAccount,
      PrefetchHooks Function()
    >;
typedef $$CachedCategoriesTableCreateCompanionBuilder =
    CachedCategoriesCompanion Function({
      required String id,
      required String ownerId,
      required String name,
      required String kind,
      Value<String?> parentId,
      required bool isSeeded,
      Value<DateTime?> archivedAt,
      required int version,
      required DateTime createdAt,
      required DateTime updatedAt,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedCategoriesTableUpdateCompanionBuilder =
    CachedCategoriesCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> name,
      Value<String> kind,
      Value<String?> parentId,
      Value<bool> isSeeded,
      Value<DateTime?> archivedAt,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSeeded => $composableBuilder(
    column: $table.isSeeded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSeeded => $composableBuilder(
    column: $table.isSeeded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCategoriesTable> {
  $$CachedCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<bool> get isSeeded =>
      $composableBuilder(column: $table.isSeeded, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCategoriesTable,
          CachedCategory,
          $$CachedCategoriesTableFilterComposer,
          $$CachedCategoriesTableOrderingComposer,
          $$CachedCategoriesTableAnnotationComposer,
          $$CachedCategoriesTableCreateCompanionBuilder,
          $$CachedCategoriesTableUpdateCompanionBuilder,
          (
            CachedCategory,
            BaseReferences<
              _$AppDatabase,
              $CachedCategoriesTable,
              CachedCategory
            >,
          ),
          CachedCategory,
          PrefetchHooks Function()
        > {
  $$CachedCategoriesTableTableManager(
    _$AppDatabase db,
    $CachedCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<bool> isSeeded = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCategoriesCompanion(
                id: id,
                ownerId: ownerId,
                name: name,
                kind: kind,
                parentId: parentId,
                isSeeded: isSeeded,
                archivedAt: archivedAt,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String name,
                required String kind,
                Value<String?> parentId = const Value.absent(),
                required bool isSeeded,
                Value<DateTime?> archivedAt = const Value.absent(),
                required int version,
                required DateTime createdAt,
                required DateTime updatedAt,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedCategoriesCompanion.insert(
                id: id,
                ownerId: ownerId,
                name: name,
                kind: kind,
                parentId: parentId,
                isSeeded: isSeeded,
                archivedAt: archivedAt,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCategoriesTable,
      CachedCategory,
      $$CachedCategoriesTableFilterComposer,
      $$CachedCategoriesTableOrderingComposer,
      $$CachedCategoriesTableAnnotationComposer,
      $$CachedCategoriesTableCreateCompanionBuilder,
      $$CachedCategoriesTableUpdateCompanionBuilder,
      (
        CachedCategory,
        BaseReferences<_$AppDatabase, $CachedCategoriesTable, CachedCategory>,
      ),
      CachedCategory,
      PrefetchHooks Function()
    >;
typedef $$CachedTagsTableCreateCompanionBuilder =
    CachedTagsCompanion Function({
      required String id,
      required String ownerId,
      required String name,
      Value<String?> color,
      Value<DateTime?> archivedAt,
      required int version,
      required DateTime createdAt,
      required DateTime updatedAt,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedTagsTableUpdateCompanionBuilder =
    CachedTagsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> name,
      Value<String?> color,
      Value<DateTime?> archivedAt,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedTagsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedTagsTable> {
  $$CachedTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedTagsTable> {
  $$CachedTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedTagsTable> {
  $$CachedTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedTagsTable,
          CachedTag,
          $$CachedTagsTableFilterComposer,
          $$CachedTagsTableOrderingComposer,
          $$CachedTagsTableAnnotationComposer,
          $$CachedTagsTableCreateCompanionBuilder,
          $$CachedTagsTableUpdateCompanionBuilder,
          (
            CachedTag,
            BaseReferences<_$AppDatabase, $CachedTagsTable, CachedTag>,
          ),
          CachedTag,
          PrefetchHooks Function()
        > {
  $$CachedTagsTableTableManager(_$AppDatabase db, $CachedTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedTagsCompanion(
                id: id,
                ownerId: ownerId,
                name: name,
                color: color,
                archivedAt: archivedAt,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String name,
                Value<String?> color = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                required int version,
                required DateTime createdAt,
                required DateTime updatedAt,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedTagsCompanion.insert(
                id: id,
                ownerId: ownerId,
                name: name,
                color: color,
                archivedAt: archivedAt,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedTagsTable,
      CachedTag,
      $$CachedTagsTableFilterComposer,
      $$CachedTagsTableOrderingComposer,
      $$CachedTagsTableAnnotationComposer,
      $$CachedTagsTableCreateCompanionBuilder,
      $$CachedTagsTableUpdateCompanionBuilder,
      (CachedTag, BaseReferences<_$AppDatabase, $CachedTagsTable, CachedTag>),
      CachedTag,
      PrefetchHooks Function()
    >;
typedef $$CachedTransactionsTableCreateCompanionBuilder =
    CachedTransactionsCompanion Function({
      required String id,
      required String ownerId,
      required String accountId,
      required String type,
      required String effect,
      required String amount,
      required String currency,
      required DateTime occurredAt,
      required String status,
      Value<String?> categoryId,
      Value<String?> counterparty,
      Value<String?> note,
      Value<String?> parentTransactionId,
      Value<String?> reversalOfId,
      required String clientOperationId,
      required int version,
      required DateTime createdAt,
      required DateTime updatedAt,
      required DateTime cachedAt,
      required String syncState,
      Value<String?> pendingAction,
      Value<String?> lastSyncError,
      Value<int> rowid,
    });
typedef $$CachedTransactionsTableUpdateCompanionBuilder =
    CachedTransactionsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> accountId,
      Value<String> type,
      Value<String> effect,
      Value<String> amount,
      Value<String> currency,
      Value<DateTime> occurredAt,
      Value<String> status,
      Value<String?> categoryId,
      Value<String?> counterparty,
      Value<String?> note,
      Value<String?> parentTransactionId,
      Value<String?> reversalOfId,
      Value<String> clientOperationId,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime> cachedAt,
      Value<String> syncState,
      Value<String?> pendingAction,
      Value<String?> lastSyncError,
      Value<int> rowid,
    });

class $$CachedTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedTransactionsTable> {
  $$CachedTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effect => $composableBuilder(
    column: $table.effect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentTransactionId => $composableBuilder(
    column: $table.parentTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reversalOfId => $composableBuilder(
    column: $table.reversalOfId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientOperationId => $composableBuilder(
    column: $table.clientOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingAction => $composableBuilder(
    column: $table.pendingAction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSyncError => $composableBuilder(
    column: $table.lastSyncError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedTransactionsTable> {
  $$CachedTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effect => $composableBuilder(
    column: $table.effect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentTransactionId => $composableBuilder(
    column: $table.parentTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reversalOfId => $composableBuilder(
    column: $table.reversalOfId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientOperationId => $composableBuilder(
    column: $table.clientOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingAction => $composableBuilder(
    column: $table.pendingAction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncError => $composableBuilder(
    column: $table.lastSyncError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedTransactionsTable> {
  $$CachedTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get effect =>
      $composableBuilder(column: $table.effect, builder: (column) => column);

  GeneratedColumn<String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get parentTransactionId => $composableBuilder(
    column: $table.parentTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reversalOfId => $composableBuilder(
    column: $table.reversalOfId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientOperationId => $composableBuilder(
    column: $table.clientOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get pendingAction => $composableBuilder(
    column: $table.pendingAction,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSyncError => $composableBuilder(
    column: $table.lastSyncError,
    builder: (column) => column,
  );
}

class $$CachedTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedTransactionsTable,
          CachedTransaction,
          $$CachedTransactionsTableFilterComposer,
          $$CachedTransactionsTableOrderingComposer,
          $$CachedTransactionsTableAnnotationComposer,
          $$CachedTransactionsTableCreateCompanionBuilder,
          $$CachedTransactionsTableUpdateCompanionBuilder,
          (
            CachedTransaction,
            BaseReferences<
              _$AppDatabase,
              $CachedTransactionsTable,
              CachedTransaction
            >,
          ),
          CachedTransaction,
          PrefetchHooks Function()
        > {
  $$CachedTransactionsTableTableManager(
    _$AppDatabase db,
    $CachedTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> effect = const Value.absent(),
                Value<String> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> counterparty = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> parentTransactionId = const Value.absent(),
                Value<String?> reversalOfId = const Value.absent(),
                Value<String> clientOperationId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<String?> pendingAction = const Value.absent(),
                Value<String?> lastSyncError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedTransactionsCompanion(
                id: id,
                ownerId: ownerId,
                accountId: accountId,
                type: type,
                effect: effect,
                amount: amount,
                currency: currency,
                occurredAt: occurredAt,
                status: status,
                categoryId: categoryId,
                counterparty: counterparty,
                note: note,
                parentTransactionId: parentTransactionId,
                reversalOfId: reversalOfId,
                clientOperationId: clientOperationId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cachedAt: cachedAt,
                syncState: syncState,
                pendingAction: pendingAction,
                lastSyncError: lastSyncError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String accountId,
                required String type,
                required String effect,
                required String amount,
                required String currency,
                required DateTime occurredAt,
                required String status,
                Value<String?> categoryId = const Value.absent(),
                Value<String?> counterparty = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> parentTransactionId = const Value.absent(),
                Value<String?> reversalOfId = const Value.absent(),
                required String clientOperationId,
                required int version,
                required DateTime createdAt,
                required DateTime updatedAt,
                required DateTime cachedAt,
                required String syncState,
                Value<String?> pendingAction = const Value.absent(),
                Value<String?> lastSyncError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedTransactionsCompanion.insert(
                id: id,
                ownerId: ownerId,
                accountId: accountId,
                type: type,
                effect: effect,
                amount: amount,
                currency: currency,
                occurredAt: occurredAt,
                status: status,
                categoryId: categoryId,
                counterparty: counterparty,
                note: note,
                parentTransactionId: parentTransactionId,
                reversalOfId: reversalOfId,
                clientOperationId: clientOperationId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cachedAt: cachedAt,
                syncState: syncState,
                pendingAction: pendingAction,
                lastSyncError: lastSyncError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedTransactionsTable,
      CachedTransaction,
      $$CachedTransactionsTableFilterComposer,
      $$CachedTransactionsTableOrderingComposer,
      $$CachedTransactionsTableAnnotationComposer,
      $$CachedTransactionsTableCreateCompanionBuilder,
      $$CachedTransactionsTableUpdateCompanionBuilder,
      (
        CachedTransaction,
        BaseReferences<
          _$AppDatabase,
          $CachedTransactionsTable,
          CachedTransaction
        >,
      ),
      CachedTransaction,
      PrefetchHooks Function()
    >;
typedef $$CachedTransactionTagsTableCreateCompanionBuilder =
    CachedTransactionTagsCompanion Function({
      required String transactionId,
      required String tagId,
      required String ownerId,
      Value<int> rowid,
    });
typedef $$CachedTransactionTagsTableUpdateCompanionBuilder =
    CachedTransactionTagsCompanion Function({
      Value<String> transactionId,
      Value<String> tagId,
      Value<String> ownerId,
      Value<int> rowid,
    });

class $$CachedTransactionTagsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedTransactionTagsTable> {
  $$CachedTransactionTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedTransactionTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedTransactionTagsTable> {
  $$CachedTransactionTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedTransactionTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedTransactionTagsTable> {
  $$CachedTransactionTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);
}

class $$CachedTransactionTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedTransactionTagsTable,
          CachedTransactionTag,
          $$CachedTransactionTagsTableFilterComposer,
          $$CachedTransactionTagsTableOrderingComposer,
          $$CachedTransactionTagsTableAnnotationComposer,
          $$CachedTransactionTagsTableCreateCompanionBuilder,
          $$CachedTransactionTagsTableUpdateCompanionBuilder,
          (
            CachedTransactionTag,
            BaseReferences<
              _$AppDatabase,
              $CachedTransactionTagsTable,
              CachedTransactionTag
            >,
          ),
          CachedTransactionTag,
          PrefetchHooks Function()
        > {
  $$CachedTransactionTagsTableTableManager(
    _$AppDatabase db,
    $CachedTransactionTagsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTransactionTagsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CachedTransactionTagsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedTransactionTagsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> transactionId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedTransactionTagsCompanion(
                transactionId: transactionId,
                tagId: tagId,
                ownerId: ownerId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String transactionId,
                required String tagId,
                required String ownerId,
                Value<int> rowid = const Value.absent(),
              }) => CachedTransactionTagsCompanion.insert(
                transactionId: transactionId,
                tagId: tagId,
                ownerId: ownerId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedTransactionTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedTransactionTagsTable,
      CachedTransactionTag,
      $$CachedTransactionTagsTableFilterComposer,
      $$CachedTransactionTagsTableOrderingComposer,
      $$CachedTransactionTagsTableAnnotationComposer,
      $$CachedTransactionTagsTableCreateCompanionBuilder,
      $$CachedTransactionTagsTableUpdateCompanionBuilder,
      (
        CachedTransactionTag,
        BaseReferences<
          _$AppDatabase,
          $CachedTransactionTagsTable,
          CachedTransactionTag
        >,
      ),
      CachedTransactionTag,
      PrefetchHooks Function()
    >;
typedef $$OutboxOperationsTableCreateCompanionBuilder =
    OutboxOperationsCompanion Function({
      required String id,
      required String ownerId,
      required String entityId,
      required String type,
      required String payloadJson,
      required String state,
      required int attemptCount,
      required DateTime nextAttemptAt,
      Value<String?> lastError,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$OutboxOperationsTableUpdateCompanionBuilder =
    OutboxOperationsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> entityId,
      Value<String> type,
      Value<String> payloadJson,
      Value<String> state,
      Value<int> attemptCount,
      Value<DateTime> nextAttemptAt,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$OutboxOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxOperationsTable> {
  $$OutboxOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxOperationsTable> {
  $$OutboxOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxOperationsTable> {
  $$OutboxOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OutboxOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxOperationsTable,
          OutboxOperation,
          $$OutboxOperationsTableFilterComposer,
          $$OutboxOperationsTableOrderingComposer,
          $$OutboxOperationsTableAnnotationComposer,
          $$OutboxOperationsTableCreateCompanionBuilder,
          $$OutboxOperationsTableUpdateCompanionBuilder,
          (
            OutboxOperation,
            BaseReferences<
              _$AppDatabase,
              $OutboxOperationsTable,
              OutboxOperation
            >,
          ),
          OutboxOperation,
          PrefetchHooks Function()
        > {
  $$OutboxOperationsTableTableManager(
    _$AppDatabase db,
    $OutboxOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxOperationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxOperationsCompanion(
                id: id,
                ownerId: ownerId,
                entityId: entityId,
                type: type,
                payloadJson: payloadJson,
                state: state,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String entityId,
                required String type,
                required String payloadJson,
                required String state,
                required int attemptCount,
                required DateTime nextAttemptAt,
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxOperationsCompanion.insert(
                id: id,
                ownerId: ownerId,
                entityId: entityId,
                type: type,
                payloadJson: payloadJson,
                state: state,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxOperationsTable,
      OutboxOperation,
      $$OutboxOperationsTableFilterComposer,
      $$OutboxOperationsTableOrderingComposer,
      $$OutboxOperationsTableAnnotationComposer,
      $$OutboxOperationsTableCreateCompanionBuilder,
      $$OutboxOperationsTableUpdateCompanionBuilder,
      (
        OutboxOperation,
        BaseReferences<_$AppDatabase, $OutboxOperationsTable, OutboxOperation>,
      ),
      OutboxOperation,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedAccountsTableTableManager get cachedAccounts =>
      $$CachedAccountsTableTableManager(_db, _db.cachedAccounts);
  $$CachedCategoriesTableTableManager get cachedCategories =>
      $$CachedCategoriesTableTableManager(_db, _db.cachedCategories);
  $$CachedTagsTableTableManager get cachedTags =>
      $$CachedTagsTableTableManager(_db, _db.cachedTags);
  $$CachedTransactionsTableTableManager get cachedTransactions =>
      $$CachedTransactionsTableTableManager(_db, _db.cachedTransactions);
  $$CachedTransactionTagsTableTableManager get cachedTransactionTags =>
      $$CachedTransactionTagsTableTableManager(_db, _db.cachedTransactionTags);
  $$OutboxOperationsTableTableManager get outboxOperations =>
      $$OutboxOperationsTableTableManager(_db, _db.outboxOperations);
}
