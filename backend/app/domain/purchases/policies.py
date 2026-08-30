from __future__ import annotations

from decimal import ROUND_HALF_EVEN, Decimal

from app.domain.errors import DomainError

MONEY_QUANTUM = Decimal("0.0001")
ALLOWED_IMAGE_MIME_TYPES = frozenset({"image/jpeg", "image/png", "image/webp"})
MAX_IMAGE_BYTES = 10 * 1024 * 1024


def calculate_line_total(quantity: Decimal, unit_price: Decimal, discount: Decimal) -> Decimal:
    if quantity <= 0:
        raise DomainError("INVALID_ITEM_QUANTITY", "Item quantity must be greater than zero.")
    if unit_price < 0 or discount < 0:
        raise DomainError("INVALID_LINE_TOTAL", "Item price and discount cannot be negative.")
    total = (quantity * unit_price - discount).quantize(MONEY_QUANTUM, rounding=ROUND_HALF_EVEN)
    if total < 0:
        raise DomainError("INVALID_LINE_TOTAL", "Item discount cannot exceed its gross total.")
    return total


def validate_image(*, mime_type: str, size_bytes: int) -> None:
    if mime_type not in ALLOWED_IMAGE_MIME_TYPES:
        raise DomainError("UNSUPPORTED_MEDIA_TYPE", "Use a JPEG, PNG, or WebP image.")
    if size_bytes <= 0 or size_bytes > MAX_IMAGE_BYTES:
        raise DomainError(
            "INVALID_MEDIA_SIZE",
            "Image size must be between 1 byte and 10 MB.",
            details={"maximum_bytes": MAX_IMAGE_BYTES},
        )
