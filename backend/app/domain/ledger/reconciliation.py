from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from app.domain.errors import CurrencyMismatchError
from app.domain.money import Money


@dataclass(frozen=True, slots=True)
class ReconciliationPreview:
    account_id: UUID
    calculated_balance: Money
    actual_balance: Money
    delta: Money
    effective_at: datetime
    source_fingerprint: str


def preview_reconciliation(
    *,
    account_id: UUID,
    account_version: int,
    calculated_balance: Money,
    actual_balance: Money,
    effective_at: datetime,
) -> ReconciliationPreview:
    if calculated_balance.currency != actual_balance.currency:
        raise CurrencyMismatchError(calculated_balance.currency, actual_balance.currency)
    delta = actual_balance - calculated_balance
    source = (
        f"{account_id}:{account_version}:{calculated_balance.to_api()}:{effective_at.isoformat()}"
    )
    return ReconciliationPreview(
        account_id=account_id,
        calculated_balance=calculated_balance,
        actual_balance=actual_balance,
        delta=delta,
        effective_at=effective_at,
        source_fingerprint=hashlib.sha256(source.encode()).hexdigest(),
    )
