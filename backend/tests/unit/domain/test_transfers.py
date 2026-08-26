from decimal import Decimal
from uuid import uuid4

import pytest
from app.domain.errors import DomainError
from app.domain.ledger.reallocation import AccountPosition
from app.domain.ledger.transfers import TransferFee, normalize_fx_rate, preview_transfer
from app.domain.money import Money


def test_same_currency_transfer_and_fee_project_each_account_once() -> None:
    source_id, destination_id = uuid4(), uuid4()

    preview = preview_transfer(
        positions=(
            AccountPosition(source_id, Money.of("200", "MAD"), False, 3),
            AccountPosition(destination_id, Money.of("50", "MAD"), False, 7),
        ),
        source_account_id=source_id,
        destination_account_id=destination_id,
        source_amount=Money.of("40", "MAD"),
        destination_amount=None,
        fx_rate=None,
        fee=TransferFee(source_id, Money.of("5", "MAD")),
    )

    impacts = {item.account_id: item for item in preview.impacts}
    assert preview.destination_amount.to_api() == "40.0000"
    assert impacts[source_id].delta.to_api() == "-45.0000"
    assert impacts[source_id].after.to_api() == "155.0000"
    assert impacts[destination_id].delta.to_api() == "40.0000"
    assert impacts[destination_id].after.to_api() == "90.0000"


def test_cross_currency_transfer_requires_exact_explicit_conversion() -> None:
    source_id, destination_id = uuid4(), uuid4()
    positions = (
        AccountPosition(source_id, Money.of("100", "EUR"), False, 1),
        AccountPosition(destination_id, Money.of("500", "MAD"), False, 1),
    )

    preview = preview_transfer(
        positions=positions,
        source_account_id=source_id,
        destination_account_id=destination_id,
        source_amount=Money.of("10", "EUR"),
        destination_amount=Money.of("107.25", "MAD"),
        fx_rate=Decimal("10.725"),
        fee=None,
    )

    assert preview.source_amount.to_api() == "10.0000"
    assert preview.destination_amount.to_api() == "107.2500"
    assert preview.fx_rate == Decimal("10.725000000000")

    with pytest.raises(DomainError) as error:
        preview_transfer(
            positions=positions,
            source_account_id=source_id,
            destination_account_id=destination_id,
            source_amount=Money.of("10", "EUR"),
            destination_amount=Money.of("107.24", "MAD"),
            fx_rate=Decimal("10.725"),
            fee=None,
        )
    assert error.value.code == "FX_AMOUNT_MISMATCH"


def test_cross_currency_transfer_uses_half_even_rounding_at_money_ties() -> None:
    source_id, destination_id = uuid4(), uuid4()

    preview = preview_transfer(
        positions=(
            AccountPosition(source_id, Money.of("10", "EUR"), False, 1),
            AccountPosition(destination_id, Money.zero("MAD"), False, 1),
        ),
        source_account_id=source_id,
        destination_account_id=destination_id,
        source_amount=Money.of("1", "EUR"),
        destination_amount=Money.of("1.2344", "MAD"),
        fx_rate=Decimal("1.23445"),
        fee=None,
    )

    assert preview.destination_amount.to_api() == "1.2344"
    assert preview.fx_rate == Decimal("1.234450000000")


def test_fx_rate_range_is_checked_without_decimal_context_overflow() -> None:
    maximum = Decimal("999999999999999999.999999999999")

    assert normalize_fx_rate(maximum) == maximum
    with pytest.raises(DomainError) as error:
        normalize_fx_rate(Decimal("1000000000000000000"))

    assert error.value.code == "INVALID_FX_RATE"


def test_transfer_rejects_a_forbidden_projected_negative_balance() -> None:
    source_id, destination_id = uuid4(), uuid4()

    with pytest.raises(DomainError) as error:
        preview_transfer(
            positions=(
                AccountPosition(source_id, Money.of("20", "MAD"), False, 1),
                AccountPosition(destination_id, Money.zero("MAD"), False, 1),
            ),
            source_account_id=source_id,
            destination_account_id=destination_id,
            source_amount=Money.of("21", "MAD"),
            destination_amount=None,
            fx_rate=None,
            fee=None,
        )

    assert error.value.code == "NEGATIVE_BALANCE_NOT_ALLOWED"
    assert error.value.details["account_id"] == str(source_id)
