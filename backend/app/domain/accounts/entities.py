from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from app.domain.money import Money


@dataclass(frozen=True, slots=True)
class AccountSnapshot:
    id: UUID
    user_id: UUID
    name: str
    type: str
    currency: str
    opening_balance: Money
    calculated_balance: Money
    opened_at: datetime
    include_in_total: bool
    allow_negative: bool
    status: str
    sort_order: int
    archived_at: datetime | None
    closed_at: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime
    balance_as_of: datetime
