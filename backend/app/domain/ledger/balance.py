from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from datetime import datetime

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

    @property
    def signed_effect(self) -> Money:
        return self.amount if self.effect is AccountEffect.INFLOW else -self.amount


def calculate_account_balance(
    opening_balance: Money,
    movements: Iterable[LedgerMovement],
    *,
    as_of: datetime | None = None,
) -> Money:
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
