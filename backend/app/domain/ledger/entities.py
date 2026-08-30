from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from uuid import UUID

from app.domain.money import Money
from app.domain.purchases.entities import TransactionItemSnapshot


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
    merchant_id: UUID | None
    merchant_location_id: UUID | None
    counterparty: str | None
    note: str | None
    tag_ids: tuple[UUID, ...]
    items: tuple[TransactionItemSnapshot, ...]
    parent_transaction_id: UUID | None
    reversal_of_id: UUID | None
    client_operation_id: UUID
    version: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class TransferSnapshot:
    id: UUID
    user_id: UUID
    source_transaction: TransactionSnapshot
    destination_transaction: TransactionSnapshot
    fee_transaction: TransactionSnapshot | None
    source_amount: Money
    destination_amount: Money
    fx_rate: Decimal | None
    reallocation_session_id: UUID | None
    source_fingerprint: str
    client_operation_id: UUID
    version: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class BalanceReconciliationSnapshot:
    id: UUID
    user_id: UUID
    account_id: UUID
    calculated_balance: Money
    actual_balance: Money
    delta: Money
    effective_at: datetime
    reason: str | None
    adjustment_transaction: TransactionSnapshot
    source_fingerprint: str
    client_operation_id: UUID
    version: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class ReallocationLineSnapshot:
    account_id: UUID
    before_balance: Money
    requested_balance: Money
    delta: Money


@dataclass(frozen=True, slots=True)
class ReallocationSnapshot:
    id: UUID
    user_id: UUID
    fixed_total: Money
    balancing_account_id: UUID
    source_fingerprint: str
    client_operation_id: UUID
    lines: tuple[ReallocationLineSnapshot, ...]
    transfers: tuple[TransferSnapshot, ...]
    created_at: datetime
    updated_at: datetime
