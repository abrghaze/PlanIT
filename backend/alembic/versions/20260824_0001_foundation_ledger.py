"""Create identity, ledger, retry-safety, and audit foundation.

Revision ID: 20260824_0001
Revises: None
Create Date: 2026-08-24
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260824_0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

MONEY = sa.Numeric(19, 4)
FX_RATE = sa.Numeric(30, 12)


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("email", sa.String(320), nullable=False),
        sa.Column("email_normalized", sa.String(320), nullable=False),
        sa.Column("password_hash", sa.Text(), nullable=False),
        sa.Column("display_name", sa.String(120), nullable=False),
        sa.Column("base_currency", sa.String(3), nullable=False),
        sa.Column("timezone", sa.String(64), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("base_currency ~ '^[A-Z]{3}$'", name="base_currency_format"),
        sa.CheckConstraint(
            "status IN ('ACTIVE', 'DISABLED', 'PENDING_DELETION')",
            name="status_valid",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_users"),
        sa.UniqueConstraint("email_normalized", name="uq_users_email_normalized"),
    )

    op.create_table(
        "refresh_sessions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("token_hash", sa.String(128), nullable=False),
        sa.Column("device_label", sa.String(160)),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
        sa.Column("replaced_by_id", sa.Uuid()),
        sa.Column("compromised", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], ondelete="CASCADE", name="fk_refresh_sessions_user_id_users"
        ),
        sa.ForeignKeyConstraint(
            ["replaced_by_id"],
            ["refresh_sessions.id"],
            ondelete="SET NULL",
            name="fk_refresh_sessions_replaced_by_id_refresh_sessions",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_refresh_sessions"),
        sa.UniqueConstraint("token_hash", name="uq_refresh_sessions_token_hash"),
    )
    op.create_index(
        "ix_refresh_sessions_user_active",
        "refresh_sessions",
        ["user_id", "revoked_at", "expires_at"],
    )

    op.create_table(
        "accounts",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("type", sa.String(24), nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("opening_balance", MONEY, nullable=False, server_default="0"),
        sa.Column("opened_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("include_in_total", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("allow_negative", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("archived_at", sa.DateTime(timezone=True)),
        sa.Column("closed_at", sa.DateTime(timezone=True)),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("currency ~ '^[A-Z]{3}$'", name="currency_format"),
        sa.CheckConstraint(
            "type IN ('BANK','CASH','SAVINGS','CARD','PREPAID','INVESTMENT','OTHER')",
            name="type_valid",
        ),
        sa.CheckConstraint("status IN ('ACTIVE','ARCHIVED','CLOSED')", name="status_valid"),
        sa.CheckConstraint(
            "(status <> 'ARCHIVED' OR archived_at IS NOT NULL) AND (status <> 'CLOSED' OR closed_at IS NOT NULL)",
            name="lifecycle_timestamp_present",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], ondelete="CASCADE", name="fk_accounts_user_id_users"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_accounts"),
    )
    op.create_index(
        "ix_accounts_user_status_order", "accounts", ["user_id", "status", "sort_order"]
    )

    op.create_table(
        "transactions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("account_id", sa.Uuid(), nullable=False),
        sa.Column("type", sa.String(40), nullable=False),
        sa.Column("effect", sa.String(16), nullable=False),
        sa.Column("amount", MONEY, nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("note", sa.Text()),
        sa.Column("parent_transaction_id", sa.Uuid()),
        sa.Column("reversal_of_id", sa.Uuid()),
        sa.Column("client_operation_id", sa.Uuid(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("amount > 0", name="amount_positive"),
        sa.CheckConstraint("currency ~ '^[A-Z]{3}$'", name="currency_format"),
        sa.CheckConstraint("effect IN ('INFLOW','OUTFLOW')", name="effect_valid"),
        sa.CheckConstraint("status IN ('DRAFT','POSTED','REVERSED','VOIDED')", name="status_valid"),
        sa.CheckConstraint(
            "type IN ('EXPENSE','INCOME','TRANSFER_OUT','TRANSFER_IN','TRANSFER_FEE','REFUND','LOAN_PRINCIPAL_OUT','LOAN_PRINCIPAL_IN','DEBT_REPAYMENT_IN','DEBT_REPAYMENT_OUT','RECONCILIATION_ADJUSTMENT','REVERSAL')",
            name="type_valid",
        ),
        sa.ForeignKeyConstraint(
            ["account_id"],
            ["accounts.id"],
            ondelete="RESTRICT",
            name="fk_transactions_account_id_accounts",
        ),
        sa.ForeignKeyConstraint(
            ["parent_transaction_id"],
            ["transactions.id"],
            ondelete="RESTRICT",
            name="fk_transactions_parent_transaction_id_transactions",
        ),
        sa.ForeignKeyConstraint(
            ["reversal_of_id"],
            ["transactions.id"],
            ondelete="RESTRICT",
            name="fk_transactions_reversal_of_id_transactions",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], ondelete="CASCADE", name="fk_transactions_user_id_users"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_transactions"),
        sa.UniqueConstraint("reversal_of_id", name="uq_transactions_reversal_of_id"),
        sa.UniqueConstraint(
            "user_id", "client_operation_id", name="uq_transactions_user_client_operation"
        ),
    )
    op.create_index(
        "ix_transactions_user_occurred_id", "transactions", ["user_id", "occurred_at", "id"]
    )
    op.create_index(
        "ix_transactions_account_occurred_id", "transactions", ["account_id", "occurred_at", "id"]
    )
    op.create_index(
        "ix_transactions_parent_transaction_id", "transactions", ["parent_transaction_id"]
    )
    op.create_index("ix_transactions_reversal_of_id", "transactions", ["reversal_of_id"])

    op.create_table(
        "transfers",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("source_transaction_id", sa.Uuid(), nullable=False),
        sa.Column("destination_transaction_id", sa.Uuid(), nullable=False),
        sa.Column("fee_transaction_id", sa.Uuid()),
        sa.Column("source_amount", MONEY, nullable=False),
        sa.Column("destination_amount", MONEY, nullable=False),
        sa.Column("fx_rate", FX_RATE),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("source_amount > 0", name="source_amount_positive"),
        sa.CheckConstraint("destination_amount > 0", name="destination_amount_positive"),
        sa.CheckConstraint("fx_rate IS NULL OR fx_rate > 0", name="fx_rate_positive"),
        sa.CheckConstraint(
            "source_transaction_id <> destination_transaction_id", name="transactions_different"
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], ondelete="CASCADE", name="fk_transfers_user_id_users"
        ),
        sa.ForeignKeyConstraint(
            ["source_transaction_id"],
            ["transactions.id"],
            ondelete="RESTRICT",
            name="fk_transfers_source_transaction_id_transactions",
        ),
        sa.ForeignKeyConstraint(
            ["destination_transaction_id"],
            ["transactions.id"],
            ondelete="RESTRICT",
            name="fk_transfers_destination_transaction_id_transactions",
        ),
        sa.ForeignKeyConstraint(
            ["fee_transaction_id"],
            ["transactions.id"],
            ondelete="RESTRICT",
            name="fk_transfers_fee_transaction_id_transactions",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_transfers"),
        sa.UniqueConstraint("source_transaction_id", name="uq_transfers_source_transaction_id"),
        sa.UniqueConstraint(
            "destination_transaction_id", name="uq_transfers_destination_transaction_id"
        ),
        sa.UniqueConstraint("fee_transaction_id", name="uq_transfers_fee_transaction_id"),
    )

    op.create_table(
        "balance_reconciliations",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("account_id", sa.Uuid(), nullable=False),
        sa.Column("calculated_balance", MONEY, nullable=False),
        sa.Column("actual_balance", MONEY, nullable=False),
        sa.Column("delta", MONEY, nullable=False),
        sa.Column("effective_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("reason", sa.Text()),
        sa.Column("adjustment_transaction_id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("delta = actual_balance - calculated_balance", name="delta_matches"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
            name="fk_balance_reconciliations_user_id_users",
        ),
        sa.ForeignKeyConstraint(
            ["account_id"],
            ["accounts.id"],
            ondelete="RESTRICT",
            name="fk_balance_reconciliations_account_id_accounts",
        ),
        sa.ForeignKeyConstraint(
            ["adjustment_transaction_id"],
            ["transactions.id"],
            ondelete="RESTRICT",
            name="fk_reconciliation_adjustment_transaction",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_balance_reconciliations"),
        sa.UniqueConstraint(
            "adjustment_transaction_id", name="uq_balance_reconciliations_adjustment_transaction_id"
        ),
    )
    op.create_index(
        "ix_balance_reconciliations_account_effective",
        "balance_reconciliations",
        ["account_id", "effective_at"],
    )

    op.create_table(
        "reallocation_sessions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("fixed_total", MONEY, nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("balancing_account_id", sa.Uuid(), nullable=False),
        sa.Column("source_fingerprint", sa.String(64), nullable=False),
        sa.Column("client_operation_id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("currency ~ '^[A-Z]{3}$'", name="currency_format"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
            name="fk_reallocation_sessions_user_id_users",
        ),
        sa.ForeignKeyConstraint(
            ["balancing_account_id"],
            ["accounts.id"],
            ondelete="RESTRICT",
            name="fk_reallocation_sessions_balancing_account_id_accounts",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_reallocation_sessions"),
        sa.UniqueConstraint(
            "user_id", "client_operation_id", name="uq_reallocation_sessions_user_client_operation"
        ),
    )
    op.create_index(
        "ix_reallocation_sessions_user_created", "reallocation_sessions", ["user_id", "created_at"]
    )

    op.create_table(
        "reallocation_lines",
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("account_id", sa.Uuid(), nullable=False),
        sa.Column("before_balance", MONEY, nullable=False),
        sa.Column("requested_balance", MONEY, nullable=False),
        sa.Column("delta", MONEY, nullable=False),
        sa.CheckConstraint("delta = requested_balance - before_balance", name="delta_matches"),
        sa.ForeignKeyConstraint(
            ["session_id"],
            ["reallocation_sessions.id"],
            ondelete="CASCADE",
            name="fk_reallocation_lines_session_id_reallocation_sessions",
        ),
        sa.ForeignKeyConstraint(
            ["account_id"],
            ["accounts.id"],
            ondelete="RESTRICT",
            name="fk_reallocation_lines_account_id_accounts",
        ),
        sa.PrimaryKeyConstraint("session_id", "account_id", name="pk_reallocation_lines"),
    )

    op.create_table(
        "exchange_rates",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("base_currency", sa.String(3), nullable=False),
        sa.Column("quote_currency", sa.String(3), nullable=False),
        sa.Column("rate", FX_RATE, nullable=False),
        sa.Column("effective_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("source", sa.String(120), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("base_currency ~ '^[A-Z]{3}$'", name="base_currency_format"),
        sa.CheckConstraint("quote_currency ~ '^[A-Z]{3}$'", name="quote_currency_format"),
        sa.CheckConstraint("base_currency <> quote_currency", name="currencies_different"),
        sa.CheckConstraint("rate > 0", name="rate_positive"),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], ondelete="CASCADE", name="fk_exchange_rates_user_id_users"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_exchange_rates"),
        sa.UniqueConstraint(
            "user_id",
            "base_currency",
            "quote_currency",
            "effective_at",
            name="uq_exchange_rates_user_pair_effective",
        ),
    )
    op.create_index(
        "ix_exchange_rates_user_pair_effective",
        "exchange_rates",
        ["user_id", "base_currency", "quote_currency", "effective_at"],
    )

    op.create_table(
        "idempotency_keys",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("scope", sa.String(80), nullable=False),
        sa.Column("key", sa.Uuid(), nullable=False),
        sa.Column("request_hash", sa.String(64), nullable=False),
        sa.Column("response_status", sa.Integer()),
        sa.Column("response_json", sa.JSON()),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], ondelete="CASCADE", name="fk_idempotency_keys_user_id_users"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_idempotency_keys"),
        sa.UniqueConstraint("user_id", "scope", "key", name="uq_idempotency_user_scope_key"),
    )
    op.create_index("ix_idempotency_keys_expires_at", "idempotency_keys", ["expires_at"])

    op.create_table(
        "audit_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("actor_user_id", sa.Uuid()),
        sa.Column("entity_type", sa.String(80), nullable=False),
        sa.Column("entity_id", sa.Uuid(), nullable=False),
        sa.Column("action", sa.String(80), nullable=False),
        sa.Column("before_json", sa.JSON()),
        sa.Column("after_json", sa.JSON()),
        sa.Column("request_id", sa.String(80)),
        sa.Column("client_operation_id", sa.Uuid()),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], ondelete="CASCADE", name="fk_audit_events_user_id_users"
        ),
        sa.ForeignKeyConstraint(
            ["actor_user_id"],
            ["users.id"],
            ondelete="SET NULL",
            name="fk_audit_events_actor_user_id_users",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_audit_events"),
    )
    op.create_index(
        "ix_audit_events_user_entity_created",
        "audit_events",
        ["user_id", "entity_type", "entity_id", "created_at"],
    )
    op.create_index("ix_audit_events_request_id", "audit_events", ["request_id"])
    op.create_index("ix_audit_events_client_operation_id", "audit_events", ["client_operation_id"])


def downgrade() -> None:
    op.drop_table("audit_events")
    op.drop_table("idempotency_keys")
    op.drop_table("exchange_rates")
    op.drop_table("reallocation_lines")
    op.drop_table("reallocation_sessions")
    op.drop_table("balance_reconciliations")
    op.drop_table("transfers")
    op.drop_table("transactions")
    op.drop_table("accounts")
    op.drop_table("refresh_sessions")
    op.drop_table("users")
