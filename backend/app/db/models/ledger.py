from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    Uuid,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.domain.accounts.enums import AccountType
from app.domain.catalog.enums import CategoryKind
from app.domain.ledger.enums import AccountStatus, TransactionStatus

MONEY = Numeric(19, 4, asdecimal=True)
FX_RATE = Numeric(30, 12, asdecimal=True)


class AccountModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "accounts"
    __table_args__ = (
        CheckConstraint("length(btrim(name)) BETWEEN 1 AND 120", name="name_not_blank"),
        CheckConstraint("currency ~ '^[A-Z]{3}$'", name="currency_format"),
        CheckConstraint(
            "type IN ('BANK','CASH','SAVINGS','CARD','PREPAID','INVESTMENT','OTHER')",
            name="type_valid",
        ),
        CheckConstraint("status IN ('ACTIVE','ARCHIVED','CLOSED')", name="status_valid"),
        CheckConstraint("version > 0", name="version_positive"),
        CheckConstraint("sort_order >= 0", name="sort_order_non_negative"),
        CheckConstraint(
            "allow_negative OR opening_balance >= 0",
            name="opening_balance_respects_negative_policy",
        ),
        CheckConstraint(
            "(status <> 'ARCHIVED' OR archived_at IS NOT NULL) AND "
            "(status <> 'CLOSED' OR closed_at IS NOT NULL)",
            name="lifecycle_timestamp_present",
        ),
        UniqueConstraint("id", "user_id", name="uq_accounts_id_user"),
        UniqueConstraint(
            "id",
            "user_id",
            "currency",
            name="uq_accounts_id_user_currency",
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


class CategoryModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "categories"
    __table_args__ = (
        CheckConstraint("length(btrim(name)) BETWEEN 1 AND 80", name="name_not_blank"),
        CheckConstraint("kind IN ('EXPENSE','INCOME','BOTH')", name="kind_valid"),
        CheckConstraint("version > 0", name="version_positive"),
        CheckConstraint("parent_id IS NULL OR parent_id <> id", name="parent_not_self"),
        ForeignKeyConstraint(
            ("parent_id", "user_id"),
            ("categories.id", "categories.user_id"),
            name="fk_categories_parent_owner",
            ondelete="RESTRICT",
        ),
        UniqueConstraint("id", "user_id", name="uq_categories_id_user"),
        Index(
            "uq_categories_user_active_normalized_name",
            "user_id",
            "normalized_name",
            unique=True,
            postgresql_where=text("archived_at IS NULL"),
        ),
        Index("ix_categories_user_kind_name", "user_id", "kind", "normalized_name"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    normalized_name: Mapped[str] = mapped_column(String(80), nullable=False)
    kind: Mapped[str] = mapped_column(String(16), nullable=False, default=CategoryKind.EXPENSE)
    parent_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True))
    is_seeded: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class TagModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "tags"
    __table_args__ = (
        CheckConstraint("length(btrim(name)) BETWEEN 1 AND 80", name="name_not_blank"),
        CheckConstraint("color IS NULL OR color ~ '^#[0-9A-F]{6}$'", name="color_format"),
        CheckConstraint("version > 0", name="version_positive"),
        UniqueConstraint("id", "user_id", name="uq_tags_id_user"),
        Index(
            "uq_tags_user_active_normalized_name",
            "user_id",
            "normalized_name",
            unique=True,
            postgresql_where=text("archived_at IS NULL"),
        ),
        Index("ix_tags_user_name", "user_id", "normalized_name"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    normalized_name: Mapped[str] = mapped_column(String(80), nullable=False)
    color: Mapped[str | None] = mapped_column(String(7))
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class TransactionModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "transactions"
    __table_args__ = (
        CheckConstraint("amount > 0", name="amount_positive"),
        CheckConstraint(
            "counterparty IS NULL OR length(btrim(counterparty)) BETWEEN 1 AND 160",
            name="counterparty_not_blank",
        ),
        CheckConstraint("currency ~ '^[A-Z]{3}$'", name="currency_format"),
        CheckConstraint("effect IN ('INFLOW','OUTFLOW')", name="effect_valid"),
        CheckConstraint("status IN ('DRAFT','POSTED','REVERSED','VOIDED')", name="status_valid"),
        CheckConstraint("version > 0", name="version_positive"),
        CheckConstraint(
            "type IN ("
            "'EXPENSE','INCOME','TRANSFER_OUT','TRANSFER_IN',"
            "'TRANSFER_FEE','REFUND','LOAN_PRINCIPAL_OUT','LOAN_PRINCIPAL_IN',"
            "'DEBT_REPAYMENT_IN','DEBT_REPAYMENT_OUT','RECONCILIATION_ADJUSTMENT','REVERSAL'"
            ")",
            name="type_valid",
        ),
        CheckConstraint(
            "(type IN ('EXPENSE','TRANSFER_OUT','TRANSFER_FEE','LOAN_PRINCIPAL_OUT',"
            "'DEBT_REPAYMENT_OUT') AND effect = 'OUTFLOW') OR "
            "(type IN ('INCOME','TRANSFER_IN','REFUND','LOAN_PRINCIPAL_IN',"
            "'DEBT_REPAYMENT_IN') AND effect = 'INFLOW') OR "
            "type IN ('RECONCILIATION_ADJUSTMENT','REVERSAL')",
            name="type_effect_coherent",
        ),
        CheckConstraint(
            "(type = 'REVERSAL') = (reversal_of_id IS NOT NULL)",
            name="reversal_link_coherent",
        ),
        CheckConstraint(
            "parent_transaction_id IS NULL OR parent_transaction_id <> id",
            name="parent_not_self",
        ),
        CheckConstraint(
            "reversal_of_id IS NULL OR reversal_of_id <> id",
            name="reversal_not_self",
        ),
        ForeignKeyConstraint(
            ("account_id", "user_id", "currency"),
            ("accounts.id", "accounts.user_id", "accounts.currency"),
            name="fk_transactions_account_owner_currency",
            ondelete="RESTRICT",
        ),
        ForeignKeyConstraint(
            ("category_id", "user_id"),
            ("categories.id", "categories.user_id"),
            name="fk_transactions_category_owner",
            ondelete="RESTRICT",
        ),
        ForeignKeyConstraint(
            ("parent_transaction_id", "user_id"),
            ("transactions.id", "transactions.user_id"),
            name="fk_transactions_parent_owner",
            ondelete="RESTRICT",
        ),
        ForeignKeyConstraint(
            ("reversal_of_id", "user_id", "account_id", "currency"),
            (
                "transactions.id",
                "transactions.user_id",
                "transactions.account_id",
                "transactions.currency",
            ),
            name="fk_transactions_reversal_owner_account_currency",
            ondelete="RESTRICT",
        ),
        UniqueConstraint("id", "user_id", name="uq_transactions_id_user"),
        UniqueConstraint(
            "id",
            "user_id",
            "account_id",
            "currency",
            name="uq_transactions_id_user_account_currency",
        ),
        UniqueConstraint(
            "user_id", "client_operation_id", name="uq_transactions_user_client_operation"
        ),
        Index("ix_transactions_user_occurred_id", "user_id", "occurred_at", "id"),
        Index("ix_transactions_account_occurred_id", "account_id", "occurred_at", "id"),
        Index("ix_transactions_category_occurred_id", "category_id", "occurred_at", "id"),
        Index("ix_transactions_parent_transaction_id", "parent_transaction_id"),
        Index("ix_transactions_reversal_of_id", "reversal_of_id"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    account_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    type: Mapped[str] = mapped_column(String(40), nullable=False)
    effect: Mapped[str] = mapped_column(String(16), nullable=False)
    amount: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default=TransactionStatus.DRAFT)
    category_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True))
    counterparty: Mapped[str | None] = mapped_column(String(160))
    note: Mapped[str | None] = mapped_column(Text)
    parent_transaction_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True))
    reversal_of_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True), unique=True)
    client_operation_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class TransactionTagModel(Base):
    __tablename__ = "transaction_tags"
    __table_args__ = (
        ForeignKeyConstraint(
            ("transaction_id", "user_id"),
            ("transactions.id", "transactions.user_id"),
            name="fk_transaction_tags_transaction_owner",
            ondelete="CASCADE",
        ),
        ForeignKeyConstraint(
            ("tag_id", "user_id"),
            ("tags.id", "tags.user_id"),
            name="fk_transaction_tags_tag_owner",
            ondelete="RESTRICT",
        ),
        Index("ix_transaction_tags_user_tag", "user_id", "tag_id", "transaction_id"),
    )

    transaction_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True)
    tag_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)


class TransferModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "transfers"
    __table_args__ = (
        CheckConstraint("source_amount > 0", name="source_amount_positive"),
        CheckConstraint("destination_amount > 0", name="destination_amount_positive"),
        CheckConstraint("fx_rate IS NULL OR fx_rate > 0", name="fx_rate_positive"),
        CheckConstraint(
            "source_transaction_id <> destination_transaction_id", name="transactions_different"
        ),
        CheckConstraint(
            "fee_transaction_id IS NULL OR "
            "(fee_transaction_id <> source_transaction_id AND "
            "fee_transaction_id <> destination_transaction_id)",
            name="fee_transaction_different",
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
