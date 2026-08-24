from decimal import Decimal

import pytest
from app.domain.errors import CurrencyMismatchError, DomainError
from app.domain.money import Money


def test_money_serializes_at_authoritative_scale() -> None:
    assert Money.of("12.5", "mad").to_api() == "12.5000"


def test_money_rejects_float_input() -> None:
    with pytest.raises(TypeError):
        Money.of(0.1, "MAD")  # type: ignore[arg-type]


def test_money_rejects_boolean_input() -> None:
    with pytest.raises(TypeError):
        Money.of(True, "MAD")


def test_money_rejects_excess_input_precision() -> None:
    with pytest.raises(DomainError, match="four fractional") as error:
        Money.of("1.00001", "MAD")
    assert error.value.code == "AMOUNT_PRECISION_EXCEEDED"


def test_money_uses_half_even_for_derived_values() -> None:
    value = Money.of("1.0000", "MAD").multiply(Decimal("1.00005"))
    assert value.to_api() == "1.0000"


def test_money_refuses_cross_currency_arithmetic() -> None:
    with pytest.raises(CurrencyMismatchError):
        _ = Money.of("1", "MAD") + Money.of("1", "EUR")


def test_money_maps_invalid_factor_to_domain_error() -> None:
    with pytest.raises(DomainError) as error:
        Money.of("1", "MAD").multiply("not-a-number")

    assert error.value.code == "INVALID_FACTOR"
