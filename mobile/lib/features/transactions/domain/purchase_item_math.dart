import 'package:planit_mobile/core/money/exact_decimal.dart';

/// Canonical item arithmetic matching the backend's Decimal/ROUND_HALF_EVEN
/// policy and PostgreSQL constraint.
final class PurchaseItemAmounts {
  const PurchaseItemAmounts({
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
  });

  final String quantity;
  final String unitPrice;
  final String discount;
  final String lineTotal;

  static PurchaseItemAmounts parse({
    required String quantity,
    required String unitPrice,
    required String discount,
  }) {
    final exactQuantity = ExactDecimal.parse(
      quantity,
      scale: 6,
      maximumDigits: 19,
    );
    final exactUnitPrice = ExactDecimal.parse(
      unitPrice,
      scale: 4,
      maximumDigits: 19,
    );
    final exactDiscount = ExactDecimal.parse(
      discount,
      scale: 4,
      maximumDigits: 19,
    );
    if (!exactQuantity.isPositive) {
      throw const FormatException('Quantity must be greater than zero.');
    }
    if (exactUnitPrice.isNegative || exactDiscount.isNegative) {
      throw const FormatException('Price and discount cannot be negative.');
    }
    final unboundedTotal = ExactDecimal.multiplyThenSubtract(
      exactQuantity,
      exactUnitPrice,
      exactDiscount,
      resultScale: 4,
    );
    if (unboundedTotal.isNegative) {
      throw const FormatException('Discount cannot exceed the item total.');
    }
    final total = ExactDecimal.parse(
      unboundedTotal.toFixedString(),
      scale: 4,
      maximumDigits: 19,
    );
    return PurchaseItemAmounts(
      quantity: exactQuantity.toFixedString(),
      unitPrice: exactUnitPrice.toFixedString(),
      discount: exactDiscount.toFixedString(),
      lineTotal: total.toFixedString(),
    );
  }

  static PurchaseItemAmounts? tryParse({
    required String quantity,
    required String unitPrice,
    required String discount,
  }) {
    try {
      return parse(
        quantity: quantity,
        unitPrice: unitPrice,
        discount: discount,
      );
    } on FormatException {
      return null;
    }
  }
}
