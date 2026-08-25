from __future__ import annotations

from datetime import datetime
from typing import Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.api.schemas.money import MoneyPayload
from app.application.transactions import (
    CreateTransactionCommand,
    PostTransactionCommand,
    ReversalResult,
    ReverseTransactionCommand,
    UpdateTransactionCommand,
)
from app.domain.ledger.entities import TransactionSnapshot
from app.domain.ledger.enums import AccountEffect, TransactionKind, TransactionStatus


class TransactionCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    client_operation_id: UUID
    account_id: UUID
    type: TransactionKind
    amount: MoneyPayload
    occurred_at: datetime
    category_id: UUID | None = None
    counterparty: str | None = Field(default=None, strict=True, max_length=160)
    note: str | None = Field(default=None, strict=True, max_length=2000)
    tag_ids: list[UUID] = Field(default_factory=list, max_length=20)

    @model_validator(mode="after")
    def unique_tags(self) -> Self:
        if len(set(self.tag_ids)) != len(self.tag_ids):
            raise ValueError("Tag identifiers must be unique.")
        return self

    def to_command(self) -> CreateTransactionCommand:
        return CreateTransactionCommand(
            id=self.id,
            client_operation_id=self.client_operation_id,
            account_id=self.account_id,
            kind=self.type,
            amount=self.amount.to_domain(),
            occurred_at=self.occurred_at,
            category_id=self.category_id,
            counterparty=self.counterparty,
            note=self.note,
            tag_ids=tuple(self.tag_ids),
        )


class TransactionUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    version: int = Field(ge=1)
    account_id: UUID | None = None
    type: TransactionKind | None = None
    amount: MoneyPayload | None = None
    occurred_at: datetime | None = None
    category_id: UUID | None = None
    counterparty: str | None = Field(default=None, strict=True, max_length=160)
    note: str | None = Field(default=None, strict=True, max_length=2000)
    tag_ids: list[UUID] | None = Field(default=None, max_length=20)

    @model_validator(mode="after")
    def validate_patch(self) -> Self:
        changed = self.model_fields_set - {"version"}
        if not changed:
            raise ValueError("At least one transaction field must be supplied.")
        nullable = {"category_id", "counterparty", "note"}
        if any(getattr(self, field) is None for field in changed - nullable):
            raise ValueError("Financial transaction fields cannot be null.")
        if self.tag_ids is not None and len(set(self.tag_ids)) != len(self.tag_ids):
            raise ValueError("Tag identifiers must be unique.")
        return self

    def to_command(self) -> UpdateTransactionCommand:
        values: dict[str, object] = {}
        for field in self.model_fields_set - {"version"}:
            value = getattr(self, field)
            if field == "type" and isinstance(value, TransactionKind):
                values["kind"] = value.value
            elif field == "amount" and isinstance(value, MoneyPayload):
                values[field] = value.to_domain()
            elif field == "tag_ids" and isinstance(value, list):
                values[field] = tuple(value)
            else:
                values[field] = value
        return UpdateTransactionCommand(version=self.version, values=values)


class TransactionPostRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    version: int = Field(ge=1)

    def to_command(self) -> PostTransactionCommand:
        return PostTransactionCommand(version=self.version)


class TransactionReverseRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    client_operation_id: UUID
    version: int = Field(ge=1)
    occurred_at: datetime
    note: str | None = Field(default=None, strict=True, max_length=2000)

    def to_command(self) -> ReverseTransactionCommand:
        return ReverseTransactionCommand(
            id=self.id,
            client_operation_id=self.client_operation_id,
            version=self.version,
            occurred_at=self.occurred_at,
            note=self.note,
        )


class TransactionResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    account_id: UUID
    type: TransactionKind
    effect: AccountEffect
    amount: MoneyPayload
    occurred_at: datetime
    status: TransactionStatus
    category_id: UUID | None
    counterparty: str | None
    note: str | None
    tag_ids: list[UUID]
    parent_transaction_id: UUID | None
    reversal_of_id: UUID | None
    client_operation_id: UUID
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: TransactionSnapshot) -> Self:
        return cls(
            id=value.id,
            account_id=value.account_id,
            type=TransactionKind(value.kind),
            effect=AccountEffect(value.effect),
            amount=MoneyPayload.from_domain(value.amount),
            occurred_at=value.occurred_at,
            status=TransactionStatus(value.status),
            category_id=value.category_id,
            counterparty=value.counterparty,
            note=value.note,
            tag_ids=list(value.tag_ids),
            parent_transaction_id=value.parent_transaction_id,
            reversal_of_id=value.reversal_of_id,
            client_operation_id=value.client_operation_id,
            version=value.version,
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class TransactionListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    items: list[TransactionResponse]


class TransactionReversalResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    original: TransactionResponse
    reversal: TransactionResponse

    @classmethod
    def from_domain(cls, value: ReversalResult) -> Self:
        return cls(
            original=TransactionResponse.from_domain(value.original),
            reversal=TransactionResponse.from_domain(value.reversal),
        )
