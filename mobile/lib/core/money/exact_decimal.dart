/// A decimal value represented as a scaled integer.
///
/// This utility is for non-currency decimal input such as quantities and
/// package sizes. It never converts through binary floating point.
final class ExactDecimal {
  const ExactDecimal.fromScaled(this.scaledValue, this.scale)
    : assert(scale >= 0);

  final BigInt scaledValue;
  final int scale;

  static ExactDecimal parse(
    String input, {
    required int scale,
    int? maximumDigits,
  }) {
    if (scale < 0) {
      throw const FormatException('Decimal scale cannot be negative.');
    }
    final normalized = input.trim().replaceAll(',', '.');
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$').firstMatch(normalized);
    if (match == null) {
      throw const FormatException('Enter a valid decimal number.');
    }
    final fraction = match.group(3) ?? '';
    if (fraction.length > scale) {
      throw FormatException('Use no more than $scale decimal places.');
    }
    final whole = match.group(2)!;
    final factor = BigInt.from(10).pow(scale);
    final fractionValue = fraction.isEmpty
        ? BigInt.zero
        : BigInt.parse(fraction.padRight(scale, '0'));
    final absolute = BigInt.parse(whole) * factor + fractionValue;
    if (maximumDigits != null && absolute.toString().length > maximumDigits) {
      throw FormatException('Use no more than $maximumDigits digits.');
    }
    return ExactDecimal.fromScaled(
      match.group(1) == '-' ? -absolute : absolute,
      scale,
    );
  }

  static ExactDecimal? tryParse(
    String input, {
    required int scale,
    int? maximumDigits,
  }) {
    try {
      return parse(input, scale: scale, maximumDigits: maximumDigits);
    } on FormatException {
      return null;
    }
  }

  bool get isPositive => scaledValue > BigInt.zero;
  bool get isNegative => scaledValue < BigInt.zero;
  bool get isZero => scaledValue == BigInt.zero;

  String toFixedString() {
    final negative = scaledValue.isNegative;
    final absolute = scaledValue.abs();
    if (scale == 0) {
      return '${negative ? '-' : ''}$absolute';
    }
    final factor = BigInt.from(10).pow(scale);
    final whole = absolute ~/ factor;
    final fraction = (absolute % factor).toString().padLeft(scale, '0');
    return '${negative ? '-' : ''}$whole.$fraction';
  }

  static ExactDecimal multiply(
    ExactDecimal left,
    ExactDecimal right, {
    required int resultScale,
  }) {
    final product = left.scaledValue * right.scaledValue;
    return _rescale(product, left.scale + right.scale, resultScale);
  }

  static ExactDecimal multiplyThenSubtract(
    ExactDecimal left,
    ExactDecimal right,
    ExactDecimal subtraction, {
    required int resultScale,
  }) {
    final productScale = left.scale + right.scale;
    final commonScale = productScale > subtraction.scale
        ? productScale
        : subtraction.scale;
    final product = left.scaledValue * right.scaledValue;
    final alignedProduct =
        product * BigInt.from(10).pow(commonScale - productScale);
    final alignedSubtraction =
        subtraction.scaledValue *
        BigInt.from(10).pow(commonScale - subtraction.scale);
    return _rescale(
      alignedProduct - alignedSubtraction,
      commonScale,
      resultScale,
    );
  }

  static ExactDecimal _rescale(BigInt value, int valueScale, int resultScale) {
    if (valueScale <= resultScale) {
      return ExactDecimal.fromScaled(
        value * BigInt.from(10).pow(resultScale - valueScale),
        resultScale,
      );
    }
    return ExactDecimal.fromScaled(
      _divideHalfEven(value, BigInt.from(10).pow(valueScale - resultScale)),
      resultScale,
    );
  }

  static BigInt _divideHalfEven(BigInt value, BigInt divisor) {
    if (divisor <= BigInt.zero) {
      throw ArgumentError.value(divisor, 'divisor', 'Must be positive.');
    }
    final negative = value.isNegative;
    final absolute = value.abs();
    var quotient = absolute ~/ divisor;
    final remainder = absolute % divisor;
    final comparison = (remainder * BigInt.from(2)).compareTo(divisor);
    if (comparison > 0 || (comparison == 0 && quotient.isOdd)) {
      quotient += BigInt.one;
    }
    return negative ? -quotient : quotient;
  }
}
