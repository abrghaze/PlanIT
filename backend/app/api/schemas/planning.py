from __future__ import annotations

from datetime import date, datetime
from typing import Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.api.schemas.money import MoneyPayload
from app.application.planning import (
    AllocateGoalCommand,
    CreateGoalCommand,
    CreateRecurringRuleCommand,
    UpdateGoalCommand,
    UpdateRecurringRuleCommand,
)
from app.domain.ledger.enums import TransactionKind
from app.domain.planning.entities import (
    GoalAllocationSnapshot,
    RecurringCommitmentTotal,
    RecurringOccurrenceSnapshot,
    RecurringRuleSnapshot,
    RecurringSummary,
    SavingsGoalSnapshot,
)
from app.domain.planning.enums import (
    GoalStatus,
    OccurrenceStatus,
    RecurringFrequency,
    RecurringMode,
    RecurringStatus,
)


class RecurringRuleCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    name: str = Field(strict=True, min_length=1, max_length=160)
    kind: TransactionKind
    account_id: UUID
    category_id: UUID | None = None
    merchant_id: UUID | None = None
    amount: MoneyPayload
    frequency: RecurringFrequency
    timezone: str = Field(strict=True, min_length=1, max_length=64)
    next_due_at: datetime
    mode: RecurringMode = RecurringMode.REMINDER
    note: str | None = Field(default=None, strict=True, max_length=2000)

    def to_command(self) -> CreateRecurringRuleCommand:
        return CreateRecurringRuleCommand(
            id=self.id,
            name=self.name,
            kind=self.kind,
            account_id=self.account_id,
            category_id=self.category_id,
            merchant_id=self.merchant_id,
            amount=self.amount.to_domain(),
            frequency=self.frequency,
            timezone=self.timezone,
            next_due_at=self.next_due_at,
            mode=self.mode,
            note=self.note,
        )


class RecurringRuleUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    version: int = Field(ge=1)
    name: str | None = Field(default=None, strict=True, min_length=1, max_length=160)
    account_id: UUID | None = None
    category_id: UUID | None = None
    merchant_id: UUID | None = None
    amount: MoneyPayload | None = None
    frequency: RecurringFrequency | None = None
    next_due_at: datetime | None = None
    mode: RecurringMode | None = None
    note: str | None = Field(default=None, strict=True, max_length=2000)
    status: RecurringStatus | None = None

    @model_validator(mode="after")
    def require_patch(self) -> Self:
        changed = self.model_fields_set - {"version"}
        if not changed:
            raise ValueError("At least one recurring-rule field must be supplied.")
        for required in (
            "name",
            "account_id",
            "amount",
            "frequency",
            "next_due_at",
            "mode",
            "status",
        ):
            if required in changed and getattr(self, required) is None:
                raise ValueError(f"{required} cannot be null.")
        return self

    def to_command(self) -> UpdateRecurringRuleCommand:
        values: dict[str, object] = {}
        for field in self.model_fields_set - {"version"}:
            value = getattr(self, field)
            values[field] = value.to_domain() if field == "amount" and value is not None else value
        return UpdateRecurringRuleCommand(version=self.version, values=values)


class RecurringRuleResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    name: str
    kind: TransactionKind
    account_id: UUID
    category_id: UUID | None
    merchant_id: UUID | None
    amount: MoneyPayload
    frequency: RecurringFrequency
    timezone: str
    next_due_at: datetime
    mode: RecurringMode
    note: str | None
    status: RecurringStatus
    monthly_equivalent: MoneyPayload
    annual_equivalent: MoneyPayload
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: RecurringRuleSnapshot) -> Self:
        return cls(
            id=value.id,
            name=value.name,
            kind=TransactionKind(value.kind),
            account_id=value.account_id,
            category_id=value.category_id,
            merchant_id=value.merchant_id,
            amount=MoneyPayload.from_domain(value.amount),
            frequency=RecurringFrequency(value.frequency),
            timezone=value.timezone,
            next_due_at=value.next_due_at,
            mode=RecurringMode(value.mode),
            note=value.note,
            status=RecurringStatus(value.status),
            monthly_equivalent=MoneyPayload.from_domain(value.monthly_equivalent),
            annual_equivalent=MoneyPayload.from_domain(value.annual_equivalent),
            version=value.version,
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class RecurringRuleListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    items: list[RecurringRuleResponse]


class RecurringOccurrenceResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    rule_id: UUID
    scheduled_for: datetime
    transaction_id: UUID | None
    status: OccurrenceStatus
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: RecurringOccurrenceSnapshot) -> Self:
        return cls(
            id=value.id,
            rule_id=value.rule_id,
            scheduled_for=value.scheduled_for,
            transaction_id=value.transaction_id,
            status=OccurrenceStatus(value.status),
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class RecurringOccurrenceListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    items: list[RecurringOccurrenceResponse]


class RecurringTotalResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    currency: str
    expense_monthly: MoneyPayload
    expense_annual: MoneyPayload
    income_monthly: MoneyPayload
    income_annual: MoneyPayload

    @classmethod
    def from_domain(cls, value: RecurringCommitmentTotal) -> Self:
        return cls(
            currency=value.currency,
            expense_monthly=MoneyPayload.from_domain(value.expense_monthly),
            expense_annual=MoneyPayload.from_domain(value.expense_annual),
            income_monthly=MoneyPayload.from_domain(value.income_monthly),
            income_annual=MoneyPayload.from_domain(value.income_annual),
        )


class RecurringSummaryResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    totals: list[RecurringTotalResponse]
    upcoming: list[RecurringOccurrenceResponse]

    @classmethod
    def from_domain(cls, value: RecurringSummary) -> Self:
        return cls(
            totals=[RecurringTotalResponse.from_domain(item) for item in value.totals],
            upcoming=[RecurringOccurrenceResponse.from_domain(item) for item in value.upcoming],
        )


class GoalCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    name: str = Field(strict=True, min_length=1, max_length=160)
    target_amount: MoneyPayload
    target_date: date | None = None
    linked_account_id: UUID | None = None

    def to_command(self) -> CreateGoalCommand:
        return CreateGoalCommand(
            id=self.id,
            name=self.name,
            target_amount=self.target_amount.to_domain(),
            target_date=self.target_date,
            linked_account_id=self.linked_account_id,
        )


class GoalUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    version: int = Field(ge=1)
    name: str | None = Field(default=None, strict=True, min_length=1, max_length=160)
    target_amount: MoneyPayload | None = None
    target_date: date | None = None
    status: GoalStatus | None = None

    @model_validator(mode="after")
    def require_patch(self) -> Self:
        changed = self.model_fields_set - {"version"}
        if not changed:
            raise ValueError("At least one goal field must be supplied.")
        for required in ("name", "target_amount", "status"):
            if required in changed and getattr(self, required) is None:
                raise ValueError(f"{required} cannot be null.")
        return self

    def to_command(self) -> UpdateGoalCommand:
        values: dict[str, object] = {}
        for field in self.model_fields_set - {"version"}:
            value = getattr(self, field)
            values[field] = (
                value.to_domain() if field == "target_amount" and value is not None else value
            )
        return UpdateGoalCommand(version=self.version, values=values)


class GoalAllocationCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    client_operation_id: UUID
    amount: MoneyPayload
    note: str | None = Field(default=None, strict=True, max_length=500)

    def to_command(self) -> AllocateGoalCommand:
        return AllocateGoalCommand(
            id=self.id,
            client_operation_id=self.client_operation_id,
            amount=self.amount.to_domain(),
            note=self.note,
        )


class GoalAllocationResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    amount: MoneyPayload
    note: str | None
    client_operation_id: UUID
    created_at: datetime

    @classmethod
    def from_domain(cls, value: GoalAllocationSnapshot) -> Self:
        return cls(
            id=value.id,
            amount=MoneyPayload.from_domain(value.amount),
            note=value.note,
            client_operation_id=value.client_operation_id,
            created_at=value.created_at,
        )


class GoalResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    name: str
    target_amount: MoneyPayload
    target_date: date | None
    linked_account_id: UUID | None
    progress: MoneyPayload
    progress_percent: str
    remaining: MoneyPayload
    status: GoalStatus
    version: int
    allocations: list[GoalAllocationResponse]
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: SavingsGoalSnapshot) -> Self:
        return cls(
            id=value.id,
            name=value.name,
            target_amount=MoneyPayload.from_domain(value.target_amount),
            target_date=value.target_date,
            linked_account_id=value.linked_account_id,
            progress=MoneyPayload.from_domain(value.progress),
            progress_percent=format(value.progress_percent, ".2f"),
            remaining=MoneyPayload.from_domain(value.remaining),
            status=GoalStatus(value.status),
            version=value.version,
            allocations=[GoalAllocationResponse.from_domain(item) for item in value.allocations],
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class GoalListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    items: list[GoalResponse]
