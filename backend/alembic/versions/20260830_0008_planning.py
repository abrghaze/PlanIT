"""Add recurring commitments and savings goals.

Revision ID: 20260830_0008
Revises: 20260829_0007
Create Date: 2026-08-30
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260830_0008"
down_revision: str | None = "20260829_0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

MONEY = sa.Numeric(19, 4)


def _identity() -> list[sa.Column[object]]:
    return [
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    ]


def upgrade() -> None:
    op.create_table(
        "recurring_rules",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("kind", sa.String(16), nullable=False),
        sa.Column("account_id", sa.Uuid(), nullable=False),
        sa.Column("category_id", sa.Uuid(), nullable=True),
        sa.Column("merchant_id", sa.Uuid(), nullable=True),
        sa.Column("amount", MONEY, nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("frequency", sa.String(16), nullable=False),
        sa.Column("timezone", sa.String(64), nullable=False),
        sa.Column("next_due_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("mode", sa.String(16), nullable=False, server_default="REMINDER"),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("status", sa.String(16), nullable=False, server_default="ACTIVE"),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        *_identity(),
        sa.CheckConstraint(
            "length(btrim(name)) BETWEEN 1 AND 160", name=op.f("ck_recurring_rules_name_not_blank")
        ),
        sa.CheckConstraint(
            "kind IN ('EXPENSE','INCOME')", name=op.f("ck_recurring_rules_kind_valid")
        ),
        sa.CheckConstraint("amount > 0", name=op.f("ck_recurring_rules_amount_positive")),
        sa.CheckConstraint(
            "currency ~ '^[A-Z]{3}$'", name=op.f("ck_recurring_rules_currency_format")
        ),
        sa.CheckConstraint(
            "frequency IN ('WEEKLY','MONTHLY','QUARTERLY','YEARLY')",
            name=op.f("ck_recurring_rules_frequency_valid"),
        ),
        sa.CheckConstraint(
            "mode IN ('REMINDER','AUTO_DRAFT')", name=op.f("ck_recurring_rules_mode_valid")
        ),
        sa.CheckConstraint(
            "status IN ('ACTIVE','PAUSED','ARCHIVED')",
            name=op.f("ck_recurring_rules_status_valid"),
        ),
        sa.CheckConstraint("version > 0", name=op.f("ck_recurring_rules_version_positive")),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["account_id", "user_id", "currency"],
            ["accounts.id", "accounts.user_id", "accounts.currency"],
            name="fk_recurring_rules_account_owner_currency",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["category_id", "user_id"],
            ["categories.id", "categories.user_id"],
            name="fk_recurring_rules_category_owner",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["merchant_id", "user_id"],
            ["merchants.id", "merchants.user_id"],
            name="fk_recurring_rules_merchant_owner",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("id", "user_id", name=op.f("uq_recurring_rules_id_user")),
    )
    op.create_index(
        "ix_recurring_rules_user_status_due",
        "recurring_rules",
        ["user_id", "status", "next_due_at"],
    )

    op.create_table(
        "savings_goals",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("target_amount", MONEY, nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("target_date", sa.Date(), nullable=True),
        sa.Column("linked_account_id", sa.Uuid(), nullable=True),
        sa.Column("manual_progress", MONEY, nullable=False, server_default="0"),
        sa.Column("status", sa.String(16), nullable=False, server_default="ACTIVE"),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        *_identity(),
        sa.CheckConstraint(
            "length(btrim(name)) BETWEEN 1 AND 160", name=op.f("ck_savings_goals_name_not_blank")
        ),
        sa.CheckConstraint("target_amount > 0", name=op.f("ck_savings_goals_target_positive")),
        sa.CheckConstraint(
            "manual_progress >= 0", name=op.f("ck_savings_goals_manual_progress_non_negative")
        ),
        sa.CheckConstraint(
            "currency ~ '^[A-Z]{3}$'", name=op.f("ck_savings_goals_currency_format")
        ),
        sa.CheckConstraint(
            "status IN ('ACTIVE','COMPLETED','ARCHIVED')",
            name=op.f("ck_savings_goals_status_valid"),
        ),
        sa.CheckConstraint("version > 0", name=op.f("ck_savings_goals_version_positive")),
        sa.CheckConstraint(
            "linked_account_id IS NULL OR manual_progress = 0",
            name=op.f("ck_savings_goals_linked_or_manual_progress"),
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["linked_account_id", "user_id", "currency"],
            ["accounts.id", "accounts.user_id", "accounts.currency"],
            name="fk_savings_goals_account_owner_currency",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("id", "user_id", name=op.f("uq_savings_goals_id_user")),
        sa.UniqueConstraint("id", "user_id", "currency", name="uq_savings_goals_id_user_currency"),
    )
    op.create_index(
        "ix_savings_goals_user_status_target",
        "savings_goals",
        ["user_id", "status", "target_date"],
    )

    op.create_table(
        "recurring_occurrences",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("rule_id", sa.Uuid(), nullable=False),
        sa.Column("scheduled_for", sa.DateTime(timezone=True), nullable=False),
        sa.Column("transaction_id", sa.Uuid(), nullable=True),
        sa.Column("status", sa.String(20), nullable=False),
        *_identity(),
        sa.CheckConstraint(
            "status IN ('DUE','DRAFT_CREATED','RECORDED','SKIPPED')",
            name=op.f("ck_recurring_occurrences_status_valid"),
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["rule_id", "user_id"],
            ["recurring_rules.id", "recurring_rules.user_id"],
            name="fk_recurring_occurrences_rule_owner",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["transaction_id", "user_id"],
            ["transactions.id", "transactions.user_id"],
            name="fk_recurring_occurrences_transaction_owner",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("rule_id", "scheduled_for", name="uq_occurrence_rule_scheduled"),
        sa.UniqueConstraint("transaction_id", name=op.f("uq_occurrence_transaction")),
    )
    op.create_index(
        "ix_occurrences_user_status_scheduled",
        "recurring_occurrences",
        ["user_id", "status", "scheduled_for"],
    )

    op.create_table(
        "goal_allocations",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("goal_id", sa.Uuid(), nullable=False),
        sa.Column("amount", MONEY, nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("note", sa.String(500), nullable=True),
        sa.Column("client_operation_id", sa.Uuid(), nullable=False),
        *_identity(),
        sa.CheckConstraint("amount <> 0", name=op.f("ck_goal_allocations_amount_non_zero")),
        sa.CheckConstraint(
            "currency ~ '^[A-Z]{3}$'", name=op.f("ck_goal_allocations_currency_format")
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["goal_id", "user_id", "currency"],
            ["savings_goals.id", "savings_goals.user_id", "savings_goals.currency"],
            name="fk_goal_allocations_goal_owner_currency",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id", "client_operation_id", name="uq_goal_allocations_user_operation"
        ),
    )
    op.create_index(
        "ix_goal_allocations_goal_created",
        "goal_allocations",
        ["goal_id", "created_at", "id"],
    )


def downgrade() -> None:
    connection = op.get_bind()
    for table in (
        "goal_allocations",
        "recurring_occurrences",
        "savings_goals",
        "recurring_rules",
    ):
        if connection.execute(sa.text(f"SELECT EXISTS (SELECT 1 FROM {table})")).scalar():
            raise RuntimeError("Refusing to downgrade Milestone 7 while planning data exists.")
    op.drop_table("goal_allocations")
    op.drop_table("recurring_occurrences")
    op.drop_table("savings_goals")
    op.drop_table("recurring_rules")
