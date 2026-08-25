from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from app.domain.money import Money


@dataclass(frozen=True, slots=True)
class TransactionSnapshot:
    id: UUID
    user_id: UUID
    account_id: UUID
    kind: str
    effect: str
    amount: Money
    occurred_at: datetime
    status: str
    category_id: UUID | None
    counterparty: str | None
    note: str | None
    tag_ids: tuple[UUID, ...]
    parent_transaction_id: UUID | None
    reversal_of_id: UUID | None
    client_operation_id: UUID
    version: int
    created_at: datetime
    updated_at: datetime
