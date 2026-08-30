from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from app.domain.money import Money


@dataclass(frozen=True, slots=True)
class RecurringRuleSnapshot:
    id: UUID
    name: str
    kind: str
    account_id: UUID
    category_id: UUID | None
    merchant_id: UUID | None
    amount: Money
    frequency: str
    timezone: str
    next_due_at: datetime
    mode: str
    note: str | None
    status: str
    monthly_equivalent: Money
    annual_equivalent: Money
    version: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class RecurringOccurrenceSnapshot:
    id: UUID
    rule_id: UUID
    scheduled_for: datetime
    transaction_id: UUID | None
    status: str
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class RecurringCommitmentTotal:
    currency: str
    expense_monthly: Money
    expense_annual: Money
    income_monthly: Money
    income_annual: Money


@dataclass(frozen=True, slots=True)
class RecurringSummary:
    totals: tuple[RecurringCommitmentTotal, ...]
    upcoming: tuple[RecurringOccurrenceSnapshot, ...]


@dataclass(frozen=True, slots=True)
class GoalAllocationSnapshot:
    id: UUID
    amount: Money
    note: str | None
    client_operation_id: UUID
    created_at: datetime


@dataclass(frozen=True, slots=True)
class SavingsGoalSnapshot:
    id: UUID
    name: str
    target_amount: Money
    target_date: date | None
    linked_account_id: UUID | None
    progress: Money
    progress_percent: Decimal
    remaining: Money
    status: str
    version: int
    allocations: tuple[GoalAllocationSnapshot, ...]
    created_at: datetime
    updated_at: datetime
