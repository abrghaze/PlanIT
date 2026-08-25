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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedAccountsTable cachedAccounts = $CachedAccountsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedAccounts];
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedAccountsTableTableManager get cachedAccounts =>
      $$CachedAccountsTableTableManager(_db, _db.cachedAccounts);
}
