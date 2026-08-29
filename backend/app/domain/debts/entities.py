from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from uuid import UUID

from app.domain.ledger.entities import TransactionSnapshot
from app.domain.money import Money


@dataclass(frozen=True, slots=True)
class PersonSnapshot:
    id: UUID
    user_id: UUID
    name: str
    contact: str | None
    notes: str | None
    archived_at: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class DebtPaymentSnapshot:
    id: UUID
    amount: Money
    paid_at: datetime
    transaction: TransactionSnapshot
    client_operation_id: UUID
    created_at: datetime


@dataclass(frozen=True, slots=True)
class DebtSnapshot:
    id: UUID
    user_id: UUID
    person_id: UUID
    direction: str
    origin_type: str
    origin_transaction: TransactionSnapshot | None
    original_amount: Money
    paid_amount: Money
    remaining_amount: Money
    due_date: date | None
    status: str
    overdue: bool
    note: str | None
    cancellation_reason: str | None
    client_operation_id: UUID
    version: int
    payments: tuple[DebtPaymentSnapshot, ...]
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class SharedExpenseShareSnapshot:
    id: UUID
    transaction_id: UUID
    person_id: UUID
    amount: Money
    debt: DebtSnapshot
    status: str
    client_operation_id: UUID
    version: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class RefundSnapshot:
    original_transaction_id: UUID
    refundable_amount: Money
    refund_transaction: TransactionSnapshot
