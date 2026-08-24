from uuid import uuid4

import pytest
from app.domain.errors import DomainError
from app.domain.ledger.reallocation import AccountPosition, preview_reallocation
from app.domain.money import Money


def test_keep_total_fixed_calculates_balancing_account() -> None:
    first, second, balancing = uuid4(), uuid4(), uuid4()
    positions = [
        AccountPosition(first, Money.of("100", "MAD"), False, 1),
        AccountPosition(second, Money.of("100", "MAD"), False, 1),
        AccountPosition(balancing, Money.of("100", "MAD"), False, 1),
    ]

    preview = preview_reallocation(
        positions=positions,
        fixed_total=Money.of("300", "MAD"),
        balancing_account_id=balancing,
        requested_balances={
            first: Money.of("130", "MAD"),
            second: Money.of("90", "MAD"),
        },
    )

    targets = {line.account_id: line.target.to_api() for line in preview.lines}
    assert targets == {
        first: "130.0000",
        second: "90.0000",
        balancing: "80.0000",
    }
    assert len(preview.source_fingerprint) == 64


def test_keep_total_fixed_rejects_forbidden_negative_result() -> None:
    first, balancing = uuid4(), uuid4()
    with pytest.raises(DomainError) as error:
        preview_reallocation(
            positions=[
                AccountPosition(first, Money.of("100", "MAD"), False, 1),
                AccountPosition(balancing, Money.of("100", "MAD"), False, 1),
            ],
            fixed_total=Money.of("200", "MAD"),
            balancing_account_id=balancing,
            requested_balances={first: Money.of("250", "MAD")},
        )
    assert error.value.code == "NEGATIVE_BALANCE_NOT_ALLOWED"


def test_keep_total_fixed_rejects_stale_total() -> None:
    first, balancing = uuid4(), uuid4()
    with pytest.raises(DomainError) as error:
        preview_reallocation(
            positions=[
                AccountPosition(first, Money.of("100", "MAD"), False, 1),
                AccountPosition(balancing, Money.of("101", "MAD"), False, 2),
            ],
            fixed_total=Money.of("200", "MAD"),
            balancing_account_id=balancing,
            requested_balances={},
        )
    assert error.value.code == "STALE_BALANCE"
