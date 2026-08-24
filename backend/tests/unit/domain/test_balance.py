from datetime import UTC, datetime, timedelta

import pytest
from app.domain.errors import DomainError
from app.domain.ledger.balance import LedgerMovement, calculate_account_balance
from app.domain.ledger.enums import AccountEffect, TransactionKind, TransactionStatus
from app.domain.money import Money


def movement(
    amount: str,
    effect: AccountEffect,
    *,
    status: TransactionStatus = TransactionStatus.POSTED,
    occurred_at: datetime,
) -> LedgerMovement:
    return LedgerMovement(
        amount=Money.of(amount, "MAD"),
        effect=effect,
        kind=TransactionKind.EXPENSE,
        status=status,
        occurred_at=occurred_at,
    )


def test_balance_uses_only_effective_financial_history() -> None:
    now = datetime.now(UTC)
    balance = calculate_account_balance(
        Money.of("100", "MAD"),
        [
            movement("25", AccountEffect.OUTFLOW, occurred_at=now),
            movement(
                "999",
                AccountEffect.OUTFLOW,
                status=TransactionStatus.DRAFT,
                occurred_at=now,
            ),
            movement("10", AccountEffect.INFLOW, occurred_at=now + timedelta(days=1)),
        ],
        as_of=now,
    )
    assert balance.to_api() == "75.0000"


def test_reversed_original_and_posted_reversal_offset_each_other() -> None:
    now = datetime.now(UTC)
    balance = calculate_account_balance(
        Money.of("100", "MAD"),
        [
            movement(
                "25",
                AccountEffect.OUTFLOW,
                status=TransactionStatus.REVERSED,
                occurred_at=now,
            ),
            movement("25", AccountEffect.INFLOW, occurred_at=now),
        ],
    )
    assert balance.to_api() == "100.0000"


def test_ledger_movement_must_be_strictly_positive() -> None:
    with pytest.raises(DomainError) as error:
        LedgerMovement(
            amount=Money.zero("MAD"),
            effect=AccountEffect.INFLOW,
            kind=TransactionKind.INCOME,
            status=TransactionStatus.POSTED,
            occurred_at=datetime(2026, 1, 1, tzinfo=UTC),
        )

    assert error.value.code == "NON_POSITIVE_AMOUNT"
