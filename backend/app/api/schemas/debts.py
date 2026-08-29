from __future__ import annotations

from datetime import date, datetime
from typing import Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.api.schemas.money import MoneyPayload
from app.api.schemas.transactions import TransactionResponse
from app.application.debts import (
    CancelDebtCommand,
    CreateDebtCommand,
    CreatePersonCommand,
    RepayDebtCommand,
    UpdatePersonCommand,
)
from app.application.sharing import CreateRefundCommand, CreateShareCommand, UpdateShareCommand
from app.domain.debts.entities import (
    DebtPaymentSnapshot,
    DebtSnapshot,
    PersonSnapshot,
    RefundSnapshot,
    SharedExpenseShareSnapshot,
)
from app.domain.debts.enums import (
    DebtDirection,
    DebtOriginType,
    DebtStatus,
    SharedExpenseShareStatus,
)


class PersonCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    name: str = Field(strict=True, min_length=1, max_length=120)
    contact: str | None = Field(default=None, strict=True, max_length=240)
    notes: str | None = Field(default=None, strict=True, max_length=2000)

    def to_command(self) -> CreatePersonCommand:
        return CreatePersonCommand(
            id=self.id, name=self.name, contact=self.contact, notes=self.notes
        )


class PersonUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    version: int = Field(ge=1)
    name: str | None = Field(default=None, strict=True, min_length=1, max_length=120)
    contact: str | None = Field(default=None, strict=True, max_length=240)
    notes: str | None = Field(default=None, strict=True, max_length=2000)
    archived: bool | None = None

    @model_validator(mode="after")
    def require_patch(self) -> Self:
        changed = self.model_fields_set - {"version"}
        if not changed:
            raise ValueError("At least one person field must be supplied.")
        if "name" in changed and self.name is None:
            raise ValueError("Name cannot be null.")
        if "archived" in changed and self.archived is None:
            raise ValueError("Archived cannot be null.")
        return self

    def to_command(self) -> UpdatePersonCommand:
        return UpdatePersonCommand(
            version=self.version,
            values={field: getattr(self, field) for field in self.model_fields_set - {"version"}},
        )


class PersonResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    name: str
    contact: str | None
    notes: str | None
    archived_at: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: PersonSnapshot) -> Self:
        return cls(
            id=value.id,
            name=value.name,
            contact=value.contact,
            notes=value.notes,
            archived_at=value.archived_at,
            version=value.version,
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class PersonListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    items: list[PersonResponse]


class DebtCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    client_operation_id: UUID
    person_id: UUID
    direction: DebtDirection
    origin_type: DebtOriginType
    amount: MoneyPayload
    due_date: date | None = None
    note: str | None = Field(default=None, strict=True, max_length=2000)
    account_id: UUID | None = None
    transaction_id: UUID | None = None
    occurred_at: datetime | None = None

    @model_validator(mode="after")
    def validate_origin_fields(self) -> Self:
        supplied = (
            self.account_id is not None,
            self.transaction_id is not None,
            self.occurred_at is not None,
        )
        cash = self.origin_type in {DebtOriginType.LEND_NOW, DebtOriginType.BORROW_NOW}
        if cash and not all(supplied):
            raise ValueError(
                "Lend-now and borrow-now require account_id, transaction_id, and occurred_at."
            )
        if not cash and any(supplied):
            raise ValueError("Existing debts do not create a cash transaction.")
        return self

    def to_command(self) -> CreateDebtCommand:
        return CreateDebtCommand(
            id=self.id,
            client_operation_id=self.client_operation_id,
            person_id=self.person_id,
            direction=self.direction,
            origin_type=self.origin_type,
            amount=self.amount.to_domain(),
            due_date=self.due_date,
            note=self.note,
            account_id=self.account_id,
            transaction_id=self.transaction_id,
            occurred_at=self.occurred_at,
        )


class DebtPaymentCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    client_operation_id: UUID
    transaction_id: UUID
    account_id: UUID
    amount: MoneyPayload
    paid_at: datetime
    note: str | None = Field(default=None, strict=True, max_length=2000)

    def to_command(self) -> RepayDebtCommand:
        return RepayDebtCommand(
            id=self.id,
            client_operation_id=self.client_operation_id,
            transaction_id=self.transaction_id,
            account_id=self.account_id,
            amount=self.amount.to_domain(),
            paid_at=self.paid_at,
            note=self.note,
        )


class DebtCancelRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    version: int = Field(ge=1)
    reason: str = Field(strict=True, min_length=1, max_length=1000)

    def to_command(self) -> CancelDebtCommand:
        return CancelDebtCommand(version=self.version, reason=self.reason)


class DebtPaymentResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    amount: MoneyPayload
    paid_at: datetime
    transaction: TransactionResponse
    client_operation_id: UUID
    created_at: datetime

    @classmethod
    def from_domain(cls, value: DebtPaymentSnapshot) -> Self:
        return cls(
            id=value.id,
            amount=MoneyPayload.from_domain(value.amount),
            paid_at=value.paid_at,
            transaction=TransactionResponse.from_domain(value.transaction),
            client_operation_id=value.client_operation_id,
            created_at=value.created_at,
        )


class DebtResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    person_id: UUID
    direction: DebtDirection
    origin_type: DebtOriginType
    origin_transaction: TransactionResponse | None
    original_amount: MoneyPayload
    paid_amount: MoneyPayload
    remaining_amount: MoneyPayload
    due_date: date | None
    status: DebtStatus
    overdue: bool
    note: str | None
    cancellation_reason: str | None
    client_operation_id: UUID
    version: int
    payments: list[DebtPaymentResponse]
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: DebtSnapshot) -> Self:
        return cls(
            id=value.id,
            person_id=value.person_id,
            direction=DebtDirection(value.direction),
            origin_type=DebtOriginType(value.origin_type),
            origin_transaction=TransactionResponse.from_domain(value.origin_transaction)
            if value.origin_transaction
            else None,
            original_amount=MoneyPayload.from_domain(value.original_amount),
            paid_amount=MoneyPayload.from_domain(value.paid_amount),
            remaining_amount=MoneyPayload.from_domain(value.remaining_amount),
            due_date=value.due_date,
            status=DebtStatus(value.status),
            overdue=value.overdue,
            note=value.note,
            cancellation_reason=value.cancellation_reason,
            client_operation_id=value.client_operation_id,
            version=value.version,
            payments=[DebtPaymentResponse.from_domain(item) for item in value.payments],
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class DebtListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    items: list[DebtResponse]


class SharedExpenseShareCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    debt_id: UUID
    client_operation_id: UUID
    person_id: UUID
    amount: MoneyPayload
    due_date: date | None = None
    note: str | None = Field(default=None, strict=True, max_length=2000)

    def to_command(self) -> CreateShareCommand:
        return CreateShareCommand(
            id=self.id,
            debt_id=self.debt_id,
            client_operation_id=self.client_operation_id,
            person_id=self.person_id,
            amount=self.amount.to_domain(),
            due_date=self.due_date,
            note=self.note,
        )


class SharedExpenseShareUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    version: int = Field(ge=1)
    amount: MoneyPayload | None = None
    cancel: bool = False
    reason: str | None = Field(default=None, strict=True, max_length=1000)

    @model_validator(mode="after")
    def validate_change(self) -> Self:
        if self.cancel == (self.amount is not None):
            raise ValueError("Supply either a new amount or cancel=true.")
        if self.cancel and not self.reason:
            raise ValueError("A cancellation reason is required.")
        return self

    def to_command(self) -> UpdateShareCommand:
        return UpdateShareCommand(
            version=self.version,
            amount=self.amount.to_domain() if self.amount else None,
            cancel=self.cancel,
            reason=self.reason,
        )


class SharedExpenseShareResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    transaction_id: UUID
    person_id: UUID
    amount: MoneyPayload
    debt: DebtResponse
    status: SharedExpenseShareStatus
    client_operation_id: UUID
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: SharedExpenseShareSnapshot) -> Self:
        return cls(
            id=value.id,
            transaction_id=value.transaction_id,
            person_id=value.person_id,
            amount=MoneyPayload.from_domain(value.amount),
            debt=DebtResponse.from_domain(value.debt),
            status=SharedExpenseShareStatus(value.status),
            client_operation_id=value.client_operation_id,
            version=value.version,
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class SharedExpenseShareListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    items: list[SharedExpenseShareResponse]


class RefundCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    client_operation_id: UUID
    account_id: UUID
    amount: MoneyPayload
    occurred_at: datetime
    note: str | None = Field(default=None, strict=True, max_length=2000)

    def to_command(self) -> CreateRefundCommand:
        return CreateRefundCommand(
            id=self.id,
            client_operation_id=self.client_operation_id,
            account_id=self.account_id,
            amount=self.amount.to_domain(),
            occurred_at=self.occurred_at,
            note=self.note,
        )


class RefundResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    original_transaction_id: UUID
    refundable_amount: MoneyPayload
    refund_transaction: TransactionResponse

    @classmethod
    def from_domain(cls, value: RefundSnapshot) -> Self:
        return cls(
            original_transaction_id=value.original_transaction_id,
            refundable_amount=MoneyPayload.from_domain(value.refundable_amount),
            refund_transaction=TransactionResponse.from_domain(value.refund_transaction),
        )
