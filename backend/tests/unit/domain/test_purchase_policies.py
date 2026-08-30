from decimal import Decimal

import pytest
from app.domain.errors import DomainError
from app.domain.purchases.policies import calculate_line_total, validate_image


def test_line_total_uses_four_decimal_bankers_rounding() -> None:
    assert calculate_line_total(Decimal("2.5"), Decimal("3.3333"), Decimal("0.1000")) == Decimal(
        "8.2332"
    )


def test_line_total_rejects_discount_above_gross() -> None:
    with pytest.raises(DomainError, match="discount") as raised:
        calculate_line_total(Decimal("1"), Decimal("2"), Decimal("2.0001"))
    assert raised.value.code == "INVALID_LINE_TOTAL"


def test_private_image_policy_accepts_supported_bounded_file() -> None:
    validate_image(mime_type="image/webp", size_bytes=1024)


@pytest.mark.parametrize("mime_type", ["image/svg+xml", "application/pdf", "text/html"])
def test_private_image_policy_rejects_unsafe_types(mime_type: str) -> None:
    with pytest.raises(DomainError) as raised:
        validate_image(mime_type=mime_type, size_bytes=1024)
    assert raised.value.code == "UNSUPPORTED_MEDIA_TYPE"


def test_private_image_policy_rejects_oversize_file() -> None:
    with pytest.raises(DomainError) as raised:
        validate_image(mime_type="image/jpeg", size_bytes=10 * 1024 * 1024 + 1)
    assert raised.value.code == "INVALID_MEDIA_SIZE"
