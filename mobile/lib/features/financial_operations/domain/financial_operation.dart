import 'package:planit_mobile/core/money/money.dart';

final class TransferFeeInput {
  const TransferFeeInput({required this.accountId, required this.amount});

  final String accountId;
  final Money amount;

  Map<String, Object?> toJson() => <String, Object?>{
    'account_id': accountId,
    'amount': _moneyToJson(amount),
  };
}

final class TransferPreviewRequest {
  const TransferPreviewRequest({
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.sourceAmount,
    required this.destinationAmount,
    required this.fxRate,
    required this.fee,
    required this.occurredAt,
  });

  final String sourceAccountId;
  final String destinationAccountId;
  final Money sourceAmount;
  final Money? destinationAmount;
  final String? fxRate;
  final TransferFeeInput? fee;
  final DateTime occurredAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'source_account_id': sourceAccountId,
    'destination_account_id': destinationAccountId,
    'source_amount': _moneyToJson(sourceAmount),
    if (destinationAmount != null)
      'destination_amount': _moneyToJson(destinationAmount!),
    if (fxRate != null) 'fx_rate': fxRate,
    if (fee != null) 'fee': fee!.toJson(),
    'occurred_at': occurredAt.toUtc().toIso8601String(),
  };
}

final class TransferAccountImpact {
  const TransferAccountImpact({
    required this.accountId,
    required this.before,
    required this.delta,
    required this.after,
    required this.version,
  });

  final String accountId;
  final Money before;
  final Money delta;
  final Money after;
  final int version;

  factory TransferAccountImpact.fromJson(Map<String, Object?> json) {
    return TransferAccountImpact(
      accountId: _requiredString(json, 'account_id'),
      before: _moneyFromJson(json, 'before'),
      delta: _moneyFromJson(json, 'delta'),
      after: _moneyFromJson(json, 'after'),
      version: _requiredInt(json, 'version'),
    );
  }
}

final class TransferPreview {
  const TransferPreview({
    required this.sourceAmount,
    required this.destinationAmount,
    required this.fxRate,
    required this.impacts,
    required this.sourceFingerprint,
  });

  final Money sourceAmount;
  final Money destinationAmount;
  final String? fxRate;
  final List<TransferAccountImpact> impacts;
  final String sourceFingerprint;

  factory TransferPreview.fromJson(Map<String, Object?> json) {
    final rawImpacts = json['impacts'];
    if (rawImpacts is! List) {
      throw const FormatException('Transfer preview impacts are missing.');
    }
    return TransferPreview(
      sourceAmount: _moneyFromJson(json, 'source_amount'),
      destinationAmount: _moneyFromJson(json, 'destination_amount'),
      fxRate: json['fx_rate'] as String?,
      impacts: rawImpacts
          .map(
            (value) => TransferAccountImpact.fromJson(
              Map<String, Object?>.from(value as Map),
            ),
          )
          .toList(growable: false),
      sourceFingerprint: _requiredFingerprint(json),
    );
  }
}

final class ReconciliationPreviewRequest {
  const ReconciliationPreviewRequest({
    required this.accountId,
    required this.actualBalance,
    required this.effectiveAt,
  });

  final String accountId;
  final Money actualBalance;
  final DateTime effectiveAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'actual_balance': _moneyToJson(actualBalance),
    'effective_at': effectiveAt.toUtc().toIso8601String(),
  };
}

final class ReconciliationPreview {
  const ReconciliationPreview({
    required this.accountId,
    required this.calculatedBalance,
    required this.actualBalance,
    required this.delta,
    required this.effectiveAt,
    required this.sourceFingerprint,
  });

  final String accountId;
  final Money calculatedBalance;
  final Money actualBalance;
  final Money delta;
  final DateTime effectiveAt;
  final String sourceFingerprint;

  factory ReconciliationPreview.fromJson(Map<String, Object?> json) {
    return ReconciliationPreview(
      accountId: _requiredString(json, 'account_id'),
      calculatedBalance: _moneyFromJson(json, 'calculated_balance'),
      actualBalance: _moneyFromJson(json, 'actual_balance'),
      delta: _moneyFromJson(json, 'delta'),
      effectiveAt: DateTime.parse(
        _requiredString(json, 'effective_at'),
      ).toUtc(),
      sourceFingerprint: _requiredFingerprint(json),
    );
  }
}

final class ReallocationPreviewRequest {
  ReallocationPreviewRequest({
    required List<String> accountIds,
    required this.fixedTotal,
    required this.balancingAccountId,
    required Map<String, Money> requestedBalances,
    required this.occurredAt,
  }) : accountIds = List<String>.unmodifiable(accountIds),
       requestedBalances = Map<String, Money>.unmodifiable(requestedBalances);

  final List<String> accountIds;
  final Money fixedTotal;
  final String balancingAccountId;
  final Map<String, Money> requestedBalances;
  final DateTime occurredAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'account_ids': accountIds,
    'fixed_total': _moneyToJson(fixedTotal),
    'balancing_account_id': balancingAccountId,
    'requested_balances': requestedBalances.entries
        .map(
          (entry) => <String, Object?>{
            'account_id': entry.key,
            'balance': _moneyToJson(entry.value),
          },
        )
        .toList(growable: false),
    'occurred_at': occurredAt.toUtc().toIso8601String(),
  };
}

final class ReallocationLinePreview {
  const ReallocationLinePreview({
    required this.accountId,
    required this.beforeBalance,
    required this.requestedBalance,
    required this.delta,
  });

  final String accountId;
  final Money beforeBalance;
  final Money requestedBalance;
  final Money delta;

  factory ReallocationLinePreview.fromJson(Map<String, Object?> json) {
    return ReallocationLinePreview(
      accountId: _requiredString(json, 'account_id'),
      beforeBalance: _moneyFromJson(json, 'before_balance'),
      requestedBalance: _moneyFromJson(json, 'requested_balance'),
      delta: _moneyFromJson(json, 'delta'),
    );
  }
}

final class ReallocationPreview {
  const ReallocationPreview({
    required this.fixedTotal,
    required this.balancingAccountId,
    required this.lines,
    required this.sourceFingerprint,
  });

  final Money fixedTotal;
  final String balancingAccountId;
  final List<ReallocationLinePreview> lines;
  final String sourceFingerprint;

  factory ReallocationPreview.fromJson(Map<String, Object?> json) {
    final rawLines = json['lines'];
    if (rawLines is! List) {
      throw const FormatException('Reallocation preview lines are missing.');
    }
    return ReallocationPreview(
      fixedTotal: _moneyFromJson(json, 'fixed_total'),
      balancingAccountId: _requiredString(json, 'balancing_account_id'),
      lines: rawLines
          .map(
            (value) => ReallocationLinePreview.fromJson(
              Map<String, Object?>.from(value as Map),
            ),
          )
          .toList(growable: false),
      sourceFingerprint: _requiredFingerprint(json),
    );
  }
}

Map<String, Object?> _moneyToJson(Money value) => <String, Object?>{
  'amount': value.toApiString(),
  'currency': value.currency,
};

Money _moneyFromJson(Map<String, Object?> json, String key) {
  final raw = json[key];
  if (raw is! Map) {
    throw FormatException('$key is not a money object.');
  }
  final money = Map<String, Object?>.from(raw);
  return Money.parse(
    _requiredString(money, 'amount'),
    _requiredString(money, 'currency'),
  );
}

String _requiredFingerprint(Map<String, Object?> json) {
  final value = _requiredString(json, 'source_fingerprint');
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw const FormatException('Source fingerprint is invalid.');
  }
  return value;
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key must be an integer.');
  }
  return value;
}
