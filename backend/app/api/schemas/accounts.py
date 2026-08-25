from __future__ import annotations

from datetime import datetime
from typing import Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.api.schemas.money import MoneyPayload
from app.application.accounts import CreateAccountCommand, UpdateAccountCommand
from app.domain.accounts.entities import AccountSnapshot
from app.domain.accounts.enums import AccountType
from app.domain.ledger.enums import AccountStatus


class AccountCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    name: str = Field(strict=True, min_length=1, max_length=120)
    type: AccountType
    opening_balance: MoneyPayload
    opened_at: datetime
    include_in_total: bool = True
    allow_negative: bool = False
    sort_order: int = Field(default=0, ge=0)

    def to_command(self) -> CreateAccountCommand:
        return CreateAccountCommand(
            id=self.id,
            name=self.name,
            type=self.type,
            opening_balance=self.opening_balance.to_domain(),
            opened_at=self.opened_at,
            include_in_total=self.include_in_total,
            allow_negative=self.allow_negative,
            sort_order=self.sort_order,
        )


class AccountUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    version: int = Field(ge=1)
    name: str | None = Field(default=None, strict=True, min_length=1, max_length=120)
    type: AccountType | None = None
    opening_balance: MoneyPayload | None = None
    opened_at: datetime | None = None
    include_in_total: bool | None = None
    allow_negative: bool | None = None
    status: AccountStatus | None = None
    sort_order: int | None = Field(default=None, ge=0)

    @model_validator(mode="after")
    def require_change(self) -> Self:
        changed_fields = self.model_fields_set - {"version"}
        if not changed_fields:
            raise ValueError("At least one account field must be supplied.")
        if any(getattr(self, field) is None for field in changed_fields):
            raise ValueError("Account update fields cannot be null.")
        return self

    def to_command(self) -> UpdateAccountCommand:
        values: dict[str, object] = {}
        for field in self.model_fields_set - {"version"}:
            value = getattr(self, field)
            if value is None:
                continue
            if field == "opening_balance":
                values[field] = value.to_domain()
            elif isinstance(value, (AccountType, AccountStatus)):
                values[field] = value.value
            else:
                values[field] = value
        return UpdateAccountCommand(version=self.version, values=values)


class AccountResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    name: str
    type: AccountType
    currency: str
    opening_balance: MoneyPayload
    calculated_balance: MoneyPayload
    balance_as_of: datetime
    opened_at: datetime
    include_in_total: bool
    allow_negative: bool
    status: AccountStatus
    sort_order: int
    archived_at: datetime | None
    closed_at: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, account: AccountSnapshot) -> Self:
        return cls(
            id=account.id,
            name=account.name,
            type=AccountType(account.type),
            currency=account.currency,
            opening_balance=MoneyPayload.from_domain(account.opening_balance),
            calculated_balance=MoneyPayload.from_domain(account.calculated_balance),
            balance_as_of=account.balance_as_of,
            opened_at=account.opened_at,
            include_in_total=account.include_in_total,
            allow_negative=account.allow_negative,
            status=AccountStatus(account.status),
            sort_order=account.sort_order,
            archived_at=account.archived_at,
            closed_at=account.closed_at,
            version=account.version,
            created_at=account.created_at,
            updated_at=account.updated_at,
        )


class AccountListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    items: list[AccountResponse]


class AccountBalanceResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    account_id: UUID
    balance: MoneyPayload
    as_of: datetime
    version: int

    @classmethod
    def from_domain(cls, account: AccountSnapshot) -> Self:
        return cls(
            account_id=account.id,
            balance=MoneyPayload.from_domain(account.calculated_balance),
            as_of=account.balance_as_of,
            version=account.version,
        )
