from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, datetime

from app.domain.errors import DomainError
from app.domain.ledger.enums import AccountEffect, TransactionKind, TransactionStatus
from app.domain.money import Money


@dataclass(frozen=True, slots=True)
class LedgerMovement:
    amount: Money
    effect: AccountEffect
    kind: TransactionKind
    status: TransactionStatus
    occurred_at: datetime

    def __post_init__(self) -> None:
        self.amount.require_positive()
        if self.occurred_at.tzinfo is None or self.occurred_at.utcoffset() is None:
            raise DomainError("INVALID_TIMESTAMP", "Ledger timestamps must include a timezone.")
        object.__setattr__(self, "occurred_at", self.occurred_at.astimezone(UTC))

    @property
    def signed_effect(self) -> Money:
        return self.amount if self.effect is AccountEffect.INFLOW else -self.amount


def calculate_account_balance(
    opening_balance: Money,
    movements: Iterable[LedgerMovement],
    *,
    as_of: datetime | None = None,
) -> Money:
    if as_of is not None:
        if as_of.tzinfo is None or as_of.utcoffset() is None:
            raise DomainError("INVALID_TIMESTAMP", "Balance timestamps must include a timezone.")
        as_of = as_of.astimezone(UTC)
    balance = opening_balance
    for movement in movements:
        if movement.amount.currency != opening_balance.currency:
            raise DomainError(
                "CURRENCY_MISMATCH",
                "An account movement must use the account currency.",
            )
        if not movement.status.affects_balance:
            continue
        if as_of is not None and movement.occurred_at > as_of:
            continue
        balance += movement.signed_effect
    return balance
