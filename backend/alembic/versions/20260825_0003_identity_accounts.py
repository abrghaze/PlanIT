"""Add Milestone 1 identity and account safeguards.

Revision ID: 20260825_0003
Revises: 20260824_0002
Create Date: 2026-08-25
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260825_0003"
down_revision: str | None = "20260824_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "refresh_sessions",
        "token_hash",
        existing_type=sa.String(length=128),
        type_=sa.String(length=64),
        existing_nullable=False,
    )
    op.create_check_constraint(
        "expiry_after_creation",
        "refresh_sessions",
        "expires_at > created_at",
    )
    op.create_check_constraint(
        "replacement_requires_revocation",
        "refresh_sessions",
        "replaced_by_id IS NULL OR revoked_at IS NOT NULL",
    )
    op.create_check_constraint(
        "compromise_requires_revocation",
        "refresh_sessions",
        "NOT compromised OR revoked_at IS NOT NULL",
    )
    op.create_check_constraint(
        "replacement_not_self",
        "refresh_sessions",
        "replaced_by_id IS NULL OR replaced_by_id <> id",
    )
    op.create_check_constraint(
        "token_hash_format",
        "refresh_sessions",
        "token_hash ~ '^[0-9a-f]{64}$'",
    )

    op.create_table(
        "auth_throttles",
        sa.Column("key_hash", sa.String(length=64), nullable=False),
        sa.Column("failure_count", sa.Integer(), nullable=False),
        sa.Column("window_started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("blocked_until", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint("failure_count >= 0", name="failure_count_non_negative"),
        sa.PrimaryKeyConstraint("key_hash", name="pk_auth_throttles"),
    )
    op.create_index(
        "ix_auth_throttles_blocked_until",
        "auth_throttles",
        ["blocked_until"],
    )

    op.create_check_constraint(
        "name_not_blank",
        "accounts",
        "length(btrim(name)) BETWEEN 1 AND 120",
    )
    op.create_check_constraint(
        "sort_order_non_negative",
        "accounts",
        "sort_order >= 0",
    )

    op.execute(
        """
        CREATE FUNCTION planit_guard_account_financial_fields()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
            IF (
                OLD.opening_balance IS DISTINCT FROM NEW.opening_balance
                OR OLD.currency IS DISTINCT FROM NEW.currency
                OR OLD.opened_at IS DISTINCT FROM NEW.opened_at
            ) AND EXISTS (
                SELECT 1
                FROM transactions
                WHERE account_id = OLD.id
                  AND status IN ('POSTED', 'REVERSED')
            ) THEN
                RAISE EXCEPTION
                    USING ERRCODE = '23514',
                          CONSTRAINT = 'account_financial_fields_immutable_after_posting',
                          MESSAGE = 'account financial fields are immutable after posting';
            END IF;
            RETURN NEW;
        END;
        $$
        """
    )
    op.execute(
        """
        CREATE TRIGGER trg_accounts_guard_financial_fields
        BEFORE UPDATE OF opening_balance, currency, opened_at ON accounts
        FOR EACH ROW
        EXECUTE FUNCTION planit_guard_account_financial_fields()
        """
    )


def downgrade() -> None:
    op.execute("DROP TRIGGER trg_accounts_guard_financial_fields ON accounts")
    op.execute("DROP FUNCTION planit_guard_account_financial_fields()")

    op.drop_constraint(
        op.f("ck_accounts_sort_order_non_negative"),
        "accounts",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_accounts_name_not_blank"),
        "accounts",
        type_="check",
    )

    op.drop_index("ix_auth_throttles_blocked_until", table_name="auth_throttles")
    op.drop_table("auth_throttles")

    op.drop_constraint(
        op.f("ck_refresh_sessions_token_hash_format"),
        "refresh_sessions",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_refresh_sessions_replacement_not_self"),
        "refresh_sessions",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_refresh_sessions_compromise_requires_revocation"),
        "refresh_sessions",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_refresh_sessions_replacement_requires_revocation"),
        "refresh_sessions",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_refresh_sessions_expiry_after_creation"),
        "refresh_sessions",
        type_="check",
    )
    op.alter_column(
        "refresh_sessions",
        "token_hash",
        existing_type=sa.String(length=64),
        type_=sa.String(length=128),
        existing_nullable=False,
    )
