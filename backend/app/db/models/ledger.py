from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from enum import StrEnum
from uuid import UUID

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.domain.ledger.enums import AccountStatus, TransactionStatus

MONEY = Numeric(19, 4, asdecimal=True)
FX_RATE = Numeric(30, 12, asdecimal=True)


class AccountType(StrEnum):
    BANK = "BANK"
    CASH = "CASH"
    SAVINGS = "SAVINGS"
    CARD = "CARD"
    PREPAID = "PREPAID"
    INVESTMENT = "INVESTMENT"
    OTHER = "OTHER"


class AccountModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "accounts"
    __table_args__ = (
        CheckConstraint("currency ~ '^[A-Z]{3}$'", name="currency_format"),
        CheckConstraint(
            "type IN ('BANK','CASH','SAVINGS','CARD','PREPAID','INVESTMENT','OTHER')",
            name="type_valid",
        ),
        CheckConstraint("status IN ('ACTIVE','ARCHIVED','CLOSED')", name="status_valid"),
        CheckConstraint(
            "(status <> 'ARCHIVED' OR archived_at IS NOT NULL) AND "
            "(status <> 'CLOSED' OR closed_at IS NOT NULL)",
            name="lifecycle_timestamp_present",
        ),
        Index("ix_accounts_user_status_order", "user_id", "status", "sort_order"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    type: Mapped[str] = mapped_column(String(24), nullable=False, default=AccountType.BANK)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    opening_balance: Mapped[Decimal] = mapped_column(MONEY, nullable=False, default=Decimal("0"))
    opened_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    include_in_total: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    allow_negative: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default=AccountStatus.ACTIVE)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class TransactionModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "transactions"
    __table_args__ = (
        CheckConstraint("amount > 0", name="amount_positive"),
        CheckConstraint("currency ~ '^[A-Z]{3}$'", name="currency_format"),
        CheckConstraint("effect IN ('INFLOW','OUTFLOW')", name="effect_valid"),
        CheckConstraint("status IN ('DRAFT','POSTED','REVERSED','VOIDED')", name="status_valid"),
        CheckConstraint(
            "type IN ("
            "'EXPENSE','INCOME','TRANSFER_OUT','TRANSFER_IN',"
            "'TRANSFER_FEE','REFUND','LOAN_PRINCIPAL_OUT','LOAN_PRINCIPAL_IN',"
            "'DEBT_REPAYMENT_IN','DEBT_REPAYMENT_OUT','RECONCILIATION_ADJUSTMENT','REVERSAL'"
            ")",
            name="type_valid",
        ),
        UniqueConstraint(
            "user_id", "client_operation_id", name="uq_transactions_user_client_operation"
        ),
        Index("ix_transactions_user_occurred_id", "user_id", "occurred_at", "id"),
        Index("ix_transactions_account_occurred_id", "account_id", "occurred_at", "id"),
        Index("ix_transactions_parent_transaction_id", "parent_transaction_id"),
        Index("ix_transactions_reversal_of_id", "reversal_of_id"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    account_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("accounts.id", ondelete="RESTRICT"), nullable=False
    )
    type: Mapped[str] = mapped_column(String(40), nullable=False)
    effect: Mapped[str] = mapped_column(String(16), nullable=False)
    amount: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default=TransactionStatus.DRAFT)
    note: Mapped[str | None] = mapped_column(Text)
    parent_transaction_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("transactions.id", ondelete="RESTRICT")
    )
    reversal_of_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("transactions.id", ondelete="RESTRICT"), unique=True
    )
    client_operation_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class TransferModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "transfers"
    __table_args__ = (
        CheckConstraint("source_amount > 0", name="source_amount_positive"),
        CheckConstraint("destination_amount > 0", name="destination_amount_positive"),
        CheckConstraint("fx_rate IS NULL OR fx_rate > 0", name="fx_rate_positive"),
        CheckConstraint(
            "source_transaction_id <> destination_transaction_id", name="transactions_different"
        ),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    source_transaction_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("transactions.id", ondelete="RESTRICT"),
        nullable=False,
        unique=True,
    )
    destination_transaction_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("transactions.id", ondelete="RESTRICT"),
        nullable=False,
        unique=True,
    )
    fee_transaction_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("transactions.id", ondelete="RESTRICT"), unique=True
    )
    source_amount: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    destination_amount: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    fx_rate: Mapped[Decimal | None] = mapped_column(FX_RATE)


class BalanceReconciliationModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "balance_reconciliations"
    __table_args__ = (
        CheckConstraint("delta = actual_balance - calculated_balance", name="delta_matches"),
        Index(
            "ix_balance_reconciliations_account_effective",
            "account_id",
            "effective_at",
        ),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    account_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("accounts.id", ondelete="RESTRICT"), nullable=False
    )
    calculated_balance: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    actual_balance: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    delta: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    effective_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    reason: Mapped[str | None] = mapped_column(Text)
    adjustment_transaction_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("transactions.id", ondelete="RESTRICT"),
        nullable=False,
        unique=True,
    )


class ReallocationSessionModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "reallocation_sessions"
    __table_args__ = (
        CheckConstraint("currency ~ '^[A-Z]{3}$'", name="currency_format"),
        UniqueConstraint(
            "user_id",
            "client_operation_id",
            name="uq_reallocation_sessions_user_client_operation",
        ),
        Index("ix_reallocation_sessions_user_created", "user_id", "created_at"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    fixed_total: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    balancing_account_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("accounts.id", ondelete="RESTRICT"), nullable=False
    )
    source_fingerprint: Mapped[str] = mapped_column(String(64), nullable=False)
    client_operation_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)


class ReallocationLineModel(Base):
    __tablename__ = "reallocation_lines"
    __table_args__ = (
        CheckConstraint("delta = requested_balance - before_balance", name="delta_matches"),
    )

    session_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("reallocation_sessions.id", ondelete="CASCADE"),
        primary_key=True,
    )
    account_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("accounts.id", ondelete="RESTRICT"),
        primary_key=True,
    )
    before_balance: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    requested_balance: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    delta: Mapped[Decimal] = mapped_column(MONEY, nullable=False)


class ExchangeRateModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "exchange_rates"
    __table_args__ = (
        CheckConstraint("base_currency ~ '^[A-Z]{3}$'", name="base_currency_format"),
        CheckConstraint("quote_currency ~ '^[A-Z]{3}$'", name="quote_currency_format"),
        CheckConstraint("base_currency <> quote_currency", name="currencies_different"),
        CheckConstraint("rate > 0", name="rate_positive"),
        UniqueConstraint(
            "user_id",
            "base_currency",
            "quote_currency",
            "effective_at",
            name="uq_exchange_rates_user_pair_effective",
        ),
        Index(
            "ix_exchange_rates_user_pair_effective",
            "user_id",
            "base_currency",
            "quote_currency",
            "effective_at",
        ),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    base_currency: Mapped[str] = mapped_column(String(3), nullable=False)
    quote_currency: Mapped[str] = mapped_column(String(3), nullable=False)
    rate: Mapped[Decimal] = mapped_column(FX_RATE, nullable=False)
    effective_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    source: Mapped[str] = mapped_column(String(120), nullable=False, default="manual")
