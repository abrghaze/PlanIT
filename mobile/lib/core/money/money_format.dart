import 'package:planit_mobile/core/money/money.dart';

extension MoneyDisplay on Money {
  String toDisplayString() {
    final raw = toApiString();
    final negative = raw.startsWith('-');
    final unsigned = negative ? raw.substring(1) : raw;
    final parts = unsigned.split('.');
    final digits = parts.first;
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      final start = end > 3 ? end - 3 : 0;
      groups.add(digits.substring(start, end));
    }
    final whole = groups.reversed.join(',');
    var fraction = parts.last;
    while (fraction.length > 2 && fraction.endsWith('0')) {
      fraction = fraction.substring(0, fraction.length - 1);
    }
    return '${negative ? '-' : ''}$whole.$fraction $currency';
  }
}
