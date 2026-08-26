from __future__ import annotations

from datetime import datetime
from typing import Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.api.schemas.money import MoneyPayload
from app.api.schemas.transactions import TransactionResponse
from app.api.schemas.transfers import TransferResponse
from app.application.corrections import (
    CommitReallocationCommand,
    CommitReconciliationCommand,
    ReallocationPreviewCommand,
    ReconciliationPreviewCommand,
)
from app.domain.ledger.entities import (
    BalanceReconciliationSnapshot,
    ReallocationLineSnapshot,
    ReallocationSnapshot,
)
from app.domain.ledger.reallocation import ReallocationLine, ReallocationPreview
from app.domain.ledger.reconciliation import ReconciliationPreview


class ReconciliationPreviewRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    actual_balance: MoneyPayload
    effective_at: datetime
    reason: str | None = Field(default=None, strict=True, max_length=2000)

    def to_command(self, account_id: UUID) -> ReconciliationPreviewCommand:
        return ReconciliationPreviewCommand(
            account_id=account_id,
            actual_balance=self.actual_balance.to_domain(),
            effective_at=self.effective_at,
        )


class ReconciliationCommitRequest(ReconciliationPreviewRequest):
    id: UUID
    client_operation_id: UUID
    adjustment_transaction_id: UUID
    source_fingerprint: str = Field(
        min_length=64,
        max_length=64,
        pattern=r"^[0-9a-f]{64}$",
    )

    @model_validator(mode="after")
    def distinct_ids(self) -> Self:
        if self.id == self.adjustment_transaction_id:
            raise ValueError("Reconciliation and adjustment identifiers must be distinct.")
        return self

    def to_commit_command(self, account_id: UUID) -> CommitReconciliationCommand:
        return CommitReconciliationCommand(
            id=self.id,
            client_operation_id=self.client_operation_id,
            adjustment_transaction_id=self.adjustment_transaction_id,
            preview=self.to_command(account_id),
            source_fingerprint=self.source_fingerprint,
            reason=self.reason,
        )


class ReconciliationPreviewResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    account_id: UUID
    calculated_balance: MoneyPayload
    actual_balance: MoneyPayload
    delta: MoneyPayload
    effective_at: datetime
    source_fingerprint: str

    @classmethod
    def from_domain(cls, value: ReconciliationPreview) -> Self:
        return cls(
            account_id=value.account_id,
            calculated_balance=MoneyPayload.from_domain(value.calculated_balance),
            actual_balance=MoneyPayload.from_domain(value.actual_balance),
            delta=MoneyPayload.from_domain(value.delta),
            effective_at=value.effective_at,
            source_fingerprint=value.source_fingerprint,
        )


class ReconciliationResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    account_id: UUID
    calculated_balance: MoneyPayload
    actual_balance: MoneyPayload
    delta: MoneyPayload
    effective_at: datetime
    reason: str | None
    adjustment_transaction: TransactionResponse
    source_fingerprint: str
    client_operation_id: UUID
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: BalanceReconciliationSnapshot) -> Self:
        return cls(
            id=value.id,
            account_id=value.account_id,
            calculated_balance=MoneyPayload.from_domain(value.calculated_balance),
            actual_balance=MoneyPayload.from_domain(value.actual_balance),
            delta=MoneyPayload.from_domain(value.delta),
            effective_at=value.effective_at,
            reason=value.reason,
            adjustment_transaction=TransactionResponse.from_domain(value.adjustment_transaction),
            source_fingerprint=value.source_fingerprint,
            client_operation_id=value.client_operation_id,
            version=value.version,
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class RequestedAccountBalance(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    account_id: UUID
    balance: MoneyPayload


class ReallocationPreviewRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    account_ids: list[UUID] = Field(min_length=2, max_length=50)
    fixed_total: MoneyPayload
    balancing_account_id: UUID
    requested_balances: list[RequestedAccountBalance] = Field(
        default_factory=list,
        max_length=49,
    )
    occurred_at: datetime

    @model_validator(mode="after")
    def validate_accounts(self) -> Self:
        account_ids = set(self.account_ids)
        if len(account_ids) != len(self.account_ids):
            raise ValueError("Reallocation account identifiers must be unique.")
        if self.balancing_account_id not in account_ids:
            raise ValueError("Balancing account must be included in the reallocation.")
        requested_ids = [value.account_id for value in self.requested_balances]
        if len(set(requested_ids)) != len(requested_ids):
            raise ValueError("Requested account balances must be unique.")
        if self.balancing_account_id in requested_ids:
            raise ValueError("Balancing account balance is derived by the server.")
        if not set(requested_ids).issubset(account_ids):
            raise ValueError("Requested balances must belong to participating accounts.")
        return self

    def to_command(self) -> ReallocationPreviewCommand:
        return ReallocationPreviewCommand(
            account_ids=tuple(self.account_ids),
            fixed_total=self.fixed_total.to_domain(),
            balancing_account_id=self.balancing_account_id,
            requested_balances={
                value.account_id: value.balance.to_domain() for value in self.requested_balances
            },
            occurred_at=self.occurred_at,
        )


class ReallocationCommitRequest(ReallocationPreviewRequest):
    id: UUID
    client_operation_id: UUID
    source_fingerprint: str = Field(
        min_length=64,
        max_length=64,
        pattern=r"^[0-9a-f]{64}$",
    )
    note: str | None = Field(default=None, strict=True, max_length=2000)

    def to_commit_command(self) -> CommitReallocationCommand:
        return CommitReallocationCommand(
            id=self.id,
            client_operation_id=self.client_operation_id,
            preview=self.to_command(),
            source_fingerprint=self.source_fingerprint,
            note=self.note,
        )


class ReallocationLineResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    account_id: UUID
    before_balance: MoneyPayload
    requested_balance: MoneyPayload
    delta: MoneyPayload

    @classmethod
    def from_preview(cls, value: ReallocationLine) -> Self:
        return cls(
            account_id=value.account_id,
            before_balance=MoneyPayload.from_domain(value.before),
            requested_balance=MoneyPayload.from_domain(value.target),
            delta=MoneyPayload.from_domain(value.delta),
        )

    @classmethod
    def from_snapshot(cls, value: ReallocationLineSnapshot) -> Self:
        return cls(
            account_id=value.account_id,
            before_balance=MoneyPayload.from_domain(value.before_balance),
            requested_balance=MoneyPayload.from_domain(value.requested_balance),
            delta=MoneyPayload.from_domain(value.delta),
        )


class ReallocationPreviewResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    fixed_total: MoneyPayload
    balancing_account_id: UUID
    lines: list[ReallocationLineResponse]
    source_fingerprint: str

    @classmethod
    def from_domain(cls, value: ReallocationPreview) -> Self:
        return cls(
            fixed_total=MoneyPayload.from_domain(value.fixed_total),
            balancing_account_id=value.balancing_account_id,
            lines=[ReallocationLineResponse.from_preview(line) for line in value.lines],
            source_fingerprint=value.source_fingerprint,
        )


class ReallocationResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    fixed_total: MoneyPayload
    balancing_account_id: UUID
    source_fingerprint: str
    client_operation_id: UUID
    lines: list[ReallocationLineResponse]
    transfers: list[TransferResponse]
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: ReallocationSnapshot) -> Self:
        return cls(
            id=value.id,
            fixed_total=MoneyPayload.from_domain(value.fixed_total),
            balancing_account_id=value.balancing_account_id,
            source_fingerprint=value.source_fingerprint,
            client_operation_id=value.client_operation_id,
            lines=[ReallocationLineResponse.from_snapshot(line) for line in value.lines],
            transfers=[TransferResponse.from_domain(transfer) for transfer in value.transfers],
            created_at=value.created_at,
            updated_at=value.updated_at,
        )
