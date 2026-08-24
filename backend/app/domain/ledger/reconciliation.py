from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from app.domain.errors import CurrencyMismatchError, DomainError
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
    if account_version <= 0:
        raise DomainError("INVALID_VERSION", "Account version must be positive.")
    if effective_at.tzinfo is None or effective_at.utcoffset() is None:
        raise DomainError(
            "INVALID_TIMESTAMP", "Reconciliation effective time must include a timezone."
        )
    normalized_effective_at = effective_at.astimezone(UTC)
    if calculated_balance.currency != actual_balance.currency:
        raise CurrencyMismatchError(calculated_balance.currency, actual_balance.currency)
    delta = actual_balance - calculated_balance
    source = (
        f"{account_id}:{account_version}:{calculated_balance.to_api()}:"
        f"{normalized_effective_at.isoformat()}"
    )
    return ReconciliationPreview(
        account_id=account_id,
        calculated_balance=calculated_balance,
        actual_balance=actual_balance,
        delta=delta,
        effective_at=normalized_effective_at,
        source_fingerprint=hashlib.sha256(source.encode()).hexdigest(),
    )
