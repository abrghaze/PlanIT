/// A fixed four-decimal money value. No binary floating point is accepted.
final class Money {
  Money._(this.scaledAmount, this.currency);

  static const int scale = 4;
  static final BigInt _factor = BigInt.from(10000);
  static final BigInt _maxScaledAmount = BigInt.parse('9999999999999999999');
  static final RegExp _currencyPattern = RegExp(r'^[A-Z]{3}$');
  static final RegExp _amountPattern = RegExp(r'^-?\d+(?:\.\d{1,4})?$');

  final BigInt scaledAmount;
  final String currency;

  factory Money.parse(String amount, String currency) {
    final normalizedCurrency = currency.trim().toUpperCase();
    if (!_currencyPattern.hasMatch(normalizedCurrency)) {
      throw const FormatException('Currency must be a three-letter code.');
    }
    if (!_amountPattern.hasMatch(amount)) {
      throw const FormatException(
        'Amount must be a decimal string with at most four places.',
      );
    }

    final negative = amount.startsWith('-');
    final unsigned = negative ? amount.substring(1) : amount;
    final parts = unsigned.split('.');
    final whole = BigInt.parse(parts.first);
    final fractionText = parts.length == 1
        ? ''
        : parts.last.padRight(scale, '0');
    final fraction = fractionText.isEmpty
        ? BigInt.zero
        : BigInt.parse(fractionText);
    final absolute = whole * _factor + fraction;
    if (absolute > _maxScaledAmount) {
      throw const FormatException(
        'Amount exceeds NUMERIC(19,4) storage range.',
      );
    }
    return Money._(negative ? -absolute : absolute, normalizedCurrency);
  }

  factory Money.zero(String currency) => Money.parse('0', currency);

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money._checked(scaledAmount + other.scaledAmount, currency);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money._checked(scaledAmount - other.scaledAmount, currency);
  }

  Money operator -() => Money._checked(-scaledAmount, currency);

  factory Money._checked(BigInt scaledAmount, String currency) {
    if (scaledAmount.abs() > _maxScaledAmount) {
      throw RangeError('Money arithmetic exceeds NUMERIC(19,4) storage range.');
    }
    return Money._(scaledAmount, currency);
  }

  void _requireSameCurrency(Money other) {
    if (currency != other.currency) {
      throw StateError('Cannot combine $currency and ${other.currency}.');
    }
  }

  String toApiString() {
    final negative = scaledAmount.isNegative;
    final absolute = scaledAmount.abs();
    final whole = absolute ~/ _factor;
    final fraction = (absolute % _factor).toString().padLeft(scale, '0');
    return '${negative ? '-' : ''}$whole.$fraction';
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      scaledAmount == other.scaledAmount &&
      currency == other.currency;

  @override
  int get hashCode => Object.hash(scaledAmount, currency);

  @override
  String toString() => '${toApiString()} $currency';
}
