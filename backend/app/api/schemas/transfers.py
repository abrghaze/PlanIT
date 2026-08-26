from __future__ import annotations

from datetime import datetime
from decimal import Decimal, InvalidOperation
from typing import Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.api.schemas.money import MoneyPayload
from app.api.schemas.transactions import TransactionResponse
from app.application.transfers import CommitTransferCommand, TransferPreviewCommand
from app.domain.ledger.entities import TransferSnapshot
from app.domain.ledger.transfers import TransferAccountImpact, TransferPreview, normalize_fx_rate


class TransferFeeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    account_id: UUID
    amount: MoneyPayload


class TransferPreviewRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    source_account_id: UUID
    destination_account_id: UUID
    source_amount: MoneyPayload
    destination_amount: MoneyPayload | None = None
    fx_rate: str | None = Field(default=None, strict=True, min_length=1, max_length=40)
    fee: TransferFeeRequest | None = None
    occurred_at: datetime

    @model_validator(mode="after")
    def validate_accounts_and_rate(self) -> Self:
        if self.source_account_id == self.destination_account_id:
            raise ValueError("Source and destination accounts must be different.")
        self.fx_rate_decimal()
        return self

    def fx_rate_decimal(self) -> Decimal | None:
        if self.fx_rate is None:
            return None
        try:
            value = Decimal(self.fx_rate)
        except InvalidOperation as exc:
            raise ValueError("FX rate must be a decimal string.") from exc
        return normalize_fx_rate(value)

    def to_command(self) -> TransferPreviewCommand:
        return TransferPreviewCommand(
            source_account_id=self.source_account_id,
            destination_account_id=self.destination_account_id,
            source_amount=self.source_amount.to_domain(),
            destination_amount=(
                self.destination_amount.to_domain() if self.destination_amount else None
            ),
            fx_rate=self.fx_rate_decimal(),
            fee_account_id=self.fee.account_id if self.fee else None,
            fee_amount=self.fee.amount.to_domain() if self.fee else None,
            occurred_at=self.occurred_at,
        )


class TransferCommitRequest(TransferPreviewRequest):
    id: UUID
    client_operation_id: UUID
    source_transaction_id: UUID
    destination_transaction_id: UUID
    fee_transaction_id: UUID | None = None
    source_fingerprint: str = Field(
        min_length=64,
        max_length=64,
        pattern=r"^[0-9a-f]{64}$",
    )
    note: str | None = Field(default=None, strict=True, max_length=2000)

    @model_validator(mode="after")
    def validate_identifiers(self) -> Self:
        identifiers = {
            self.id,
            self.source_transaction_id,
            self.destination_transaction_id,
        }
        if self.fee_transaction_id is not None:
            identifiers.add(self.fee_transaction_id)
        expected = 4 if self.fee_transaction_id is not None else 3
        if len(identifiers) != expected:
            raise ValueError("Transfer and movement identifiers must be distinct.")
        if (self.fee is None) != (self.fee_transaction_id is None):
            raise ValueError("Fee and fee transaction identifier must be supplied together.")
        return self

    def to_commit_command(self) -> CommitTransferCommand:
        return CommitTransferCommand(
            id=self.id,
            client_operation_id=self.client_operation_id,
            source_transaction_id=self.source_transaction_id,
            destination_transaction_id=self.destination_transaction_id,
            fee_transaction_id=self.fee_transaction_id,
            preview=self.to_command(),
            source_fingerprint=self.source_fingerprint,
            note=self.note,
        )


class TransferAccountImpactResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    account_id: UUID
    before: MoneyPayload
    delta: MoneyPayload
    after: MoneyPayload
    version: int

    @classmethod
    def from_domain(cls, value: TransferAccountImpact) -> Self:
        return cls(
            account_id=value.account_id,
            before=MoneyPayload.from_domain(value.before),
            delta=MoneyPayload.from_domain(value.delta),
            after=MoneyPayload.from_domain(value.after),
            version=value.version,
        )


class TransferPreviewResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    source_account_id: UUID
    destination_account_id: UUID
    source_amount: MoneyPayload
    destination_amount: MoneyPayload
    fx_rate: str | None
    fee: TransferFeeRequest | None
    impacts: list[TransferAccountImpactResponse]
    source_fingerprint: str

    @classmethod
    def from_domain(cls, value: TransferPreview) -> Self:
        return cls(
            source_account_id=value.source_account_id,
            destination_account_id=value.destination_account_id,
            source_amount=MoneyPayload.from_domain(value.source_amount),
            destination_amount=MoneyPayload.from_domain(value.destination_amount),
            fx_rate=format(value.fx_rate, ".12f") if value.fx_rate else None,
            fee=(
                TransferFeeRequest(
                    account_id=value.fee.account_id,
                    amount=MoneyPayload.from_domain(value.fee.amount),
                )
                if value.fee
                else None
            ),
            impacts=[TransferAccountImpactResponse.from_domain(item) for item in value.impacts],
            source_fingerprint=value.source_fingerprint,
        )


class TransferResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    source_transaction: TransactionResponse
    destination_transaction: TransactionResponse
    fee_transaction: TransactionResponse | None
    source_amount: MoneyPayload
    destination_amount: MoneyPayload
    fx_rate: str | None
    reallocation_session_id: UUID | None
    source_fingerprint: str
    client_operation_id: UUID
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: TransferSnapshot) -> Self:
        return cls(
            id=value.id,
            source_transaction=TransactionResponse.from_domain(value.source_transaction),
            destination_transaction=TransactionResponse.from_domain(value.destination_transaction),
            fee_transaction=(
                TransactionResponse.from_domain(value.fee_transaction)
                if value.fee_transaction
                else None
            ),
            source_amount=MoneyPayload.from_domain(value.source_amount),
            destination_amount=MoneyPayload.from_domain(value.destination_amount),
            fx_rate=format(value.fx_rate, ".12f") if value.fx_rate else None,
            reallocation_session_id=value.reallocation_session_id,
            source_fingerprint=value.source_fingerprint,
            client_operation_id=value.client_operation_id,
            version=value.version,
            created_at=value.created_at,
            updated_at=value.updated_at,
        )
