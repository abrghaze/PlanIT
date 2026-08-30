from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UuidPrimaryKeyMixin
from app.db.models.ledger import MONEY


class RecurringRuleModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "recurring_rules"
    __table_args__ = (
        CheckConstraint("length(btrim(name)) BETWEEN 1 AND 160", name="name_not_blank"),
        CheckConstraint("kind IN ('EXPENSE','INCOME')", name="kind_valid"),
        CheckConstraint("amount > 0", name="amount_positive"),
        CheckConstraint("currency ~ '^[A-Z]{3}$'", name="currency_format"),
        CheckConstraint(
            "frequency IN ('WEEKLY','MONTHLY','QUARTERLY','YEARLY')",
            name="frequency_valid",
        ),
        CheckConstraint("mode IN ('REMINDER','AUTO_DRAFT')", name="mode_valid"),
        CheckConstraint("status IN ('ACTIVE','PAUSED','ARCHIVED')", name="status_valid"),
        CheckConstraint("version > 0", name="version_positive"),
        ForeignKeyConstraint(
            ("account_id", "user_id", "currency"),
            ("accounts.id", "accounts.user_id", "accounts.currency"),
            name="fk_recurring_rules_account_owner_currency",
            ondelete="RESTRICT",
        ),
        ForeignKeyConstraint(
            ("category_id", "user_id"),
            ("categories.id", "categories.user_id"),
            name="fk_recurring_rules_category_owner",
            ondelete="RESTRICT",
        ),
        ForeignKeyConstraint(
            ("merchant_id", "user_id"),
            ("merchants.id", "merchants.user_id"),
            name="fk_recurring_rules_merchant_owner",
            ondelete="RESTRICT",
        ),
        UniqueConstraint("id", "user_id", name="uq_recurring_rules_id_user"),
        Index("ix_recurring_rules_user_status_due", "user_id", "status", "next_due_at"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    kind: Mapped[str] = mapped_column(String(16), nullable=False)
    account_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    category_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True))
    merchant_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True))
    amount: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    frequency: Mapped[str] = mapped_column(String(16), nullable=False)
    timezone: Mapped[str] = mapped_column(String(64), nullable=False)
    next_due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    mode: Mapped[str] = mapped_column(String(16), nullable=False, default="REMINDER")
    note: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="ACTIVE")
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class RecurringOccurrenceModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "recurring_occurrences"
    __table_args__ = (
        CheckConstraint(
            "status IN ('DUE','DRAFT_CREATED','RECORDED','SKIPPED')", name="status_valid"
        ),
        ForeignKeyConstraint(
            ("rule_id", "user_id"),
            ("recurring_rules.id", "recurring_rules.user_id"),
            name="fk_recurring_occurrences_rule_owner",
            ondelete="CASCADE",
        ),
        ForeignKeyConstraint(
            ("transaction_id", "user_id"),
            ("transactions.id", "transactions.user_id"),
            name="fk_recurring_occurrences_transaction_owner",
            ondelete="RESTRICT",
        ),
        UniqueConstraint("rule_id", "scheduled_for", name="uq_occurrence_rule_scheduled"),
        UniqueConstraint("transaction_id", name="uq_occurrence_transaction"),
        Index("ix_occurrences_user_status_scheduled", "user_id", "status", "scheduled_for"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    rule_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    scheduled_for: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    transaction_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True))
    status: Mapped[str] = mapped_column(String(20), nullable=False)


class SavingsGoalModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "savings_goals"
    __table_args__ = (
        CheckConstraint("length(btrim(name)) BETWEEN 1 AND 160", name="name_not_blank"),
        CheckConstraint("target_amount > 0", name="target_positive"),
        CheckConstraint("manual_progress >= 0", name="manual_progress_non_negative"),
        CheckConstraint("currency ~ '^[A-Z]{3}$'", name="currency_format"),
        CheckConstraint("status IN ('ACTIVE','COMPLETED','ARCHIVED')", name="status_valid"),
        CheckConstraint("version > 0", name="version_positive"),
        CheckConstraint(
            "linked_account_id IS NULL OR manual_progress = 0",
            name="linked_or_manual_progress",
        ),
        ForeignKeyConstraint(
            ("linked_account_id", "user_id", "currency"),
            ("accounts.id", "accounts.user_id", "accounts.currency"),
            name="fk_savings_goals_account_owner_currency",
            ondelete="RESTRICT",
        ),
        UniqueConstraint("id", "user_id", name="uq_savings_goals_id_user"),
        UniqueConstraint("id", "user_id", "currency", name="uq_savings_goals_id_user_currency"),
        Index("ix_savings_goals_user_status_target", "user_id", "status", "target_date"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    target_amount: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    target_date: Mapped[date | None] = mapped_column(Date)
    linked_account_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True))
    manual_progress: Mapped[Decimal] = mapped_column(MONEY, nullable=False, default=Decimal("0"))
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="ACTIVE")
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class GoalAllocationModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "goal_allocations"
    __table_args__ = (
        CheckConstraint("amount <> 0", name="amount_non_zero"),
        CheckConstraint("currency ~ '^[A-Z]{3}$'", name="currency_format"),
        ForeignKeyConstraint(
            ("goal_id", "user_id", "currency"),
            ("savings_goals.id", "savings_goals.user_id", "savings_goals.currency"),
            name="fk_goal_allocations_goal_owner_currency",
            ondelete="RESTRICT",
        ),
        UniqueConstraint(
            "user_id", "client_operation_id", name="uq_goal_allocations_user_operation"
        ),
        Index("ix_goal_allocations_goal_created", "goal_id", "created_at", "id"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    goal_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    amount: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    note: Mapped[str | None] = mapped_column(String(500))
    client_operation_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
