"""Strengthen foundation financial and idempotency constraints.

Revision ID: 20260824_0002
Revises: 20260824_0001
Create Date: 2026-08-24
"""

from collections.abc import Sequence

from alembic import op

revision: str = "20260824_0002"
down_revision: str | None = "20260824_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_check_constraint("version_positive", "accounts", "version > 0")
    op.create_check_constraint(
        "opening_balance_respects_negative_policy",
        "accounts",
        "allow_negative OR opening_balance >= 0",
    )
    op.create_unique_constraint(op.f("uq_accounts_id_user"), "accounts", ["id", "user_id"])
    op.create_unique_constraint(
        op.f("uq_accounts_id_user_currency"),
        "accounts",
        ["id", "user_id", "currency"],
    )

    op.create_check_constraint("version_positive", "transactions", "version > 0")
    op.create_check_constraint(
        "type_effect_coherent",
        "transactions",
        "(type IN ('EXPENSE','TRANSFER_OUT','TRANSFER_FEE','LOAN_PRINCIPAL_OUT',"
        "'DEBT_REPAYMENT_OUT') AND effect = 'OUTFLOW') OR "
        "(type IN ('INCOME','TRANSFER_IN','REFUND','LOAN_PRINCIPAL_IN',"
        "'DEBT_REPAYMENT_IN') AND effect = 'INFLOW') OR "
        "type IN ('RECONCILIATION_ADJUSTMENT','REVERSAL')",
    )
    op.create_check_constraint(
        "reversal_link_coherent",
        "transactions",
        "(type = 'REVERSAL') = (reversal_of_id IS NOT NULL)",
    )
    op.create_check_constraint(
        "parent_not_self",
        "transactions",
        "parent_transaction_id IS NULL OR parent_transaction_id <> id",
    )
    op.create_check_constraint(
        "reversal_not_self",
        "transactions",
        "reversal_of_id IS NULL OR reversal_of_id <> id",
    )
    op.create_unique_constraint(
        op.f("uq_transactions_id_user"),
        "transactions",
        ["id", "user_id"],
    )
    op.create_unique_constraint(
        op.f("uq_transactions_id_user_account_currency"),
        "transactions",
        ["id", "user_id", "account_id", "currency"],
    )
    op.drop_constraint(
        op.f("fk_transactions_account_id_accounts"),
        "transactions",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_transactions_parent_transaction_id_transactions"),
        "transactions",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_transactions_reversal_of_id_transactions"),
        "transactions",
        type_="foreignkey",
    )
    op.create_foreign_key(
        op.f("fk_transactions_account_owner_currency"),
        "transactions",
        "accounts",
        ["account_id", "user_id", "currency"],
        ["id", "user_id", "currency"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        op.f("fk_transactions_parent_owner"),
        "transactions",
        "transactions",
        ["parent_transaction_id", "user_id"],
        ["id", "user_id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        op.f("fk_transactions_reversal_owner_account_currency"),
        "transactions",
        "transactions",
        ["reversal_of_id", "user_id", "account_id", "currency"],
        ["id", "user_id", "account_id", "currency"],
        ondelete="RESTRICT",
    )

    op.create_check_constraint(
        "fee_transaction_different",
        "transfers",
        "fee_transaction_id IS NULL OR "
        "(fee_transaction_id <> source_transaction_id AND "
        "fee_transaction_id <> destination_transaction_id)",
    )

    op.create_check_constraint(
        "response_pair_coherent",
        "idempotency_keys",
        "(response_status IS NULL) = (response_json IS NULL)",
    )
    op.create_check_constraint(
        "response_status_valid",
        "idempotency_keys",
        "response_status IS NULL OR response_status BETWEEN 200 AND 599",
    )
    op.create_check_constraint(
        "expiry_after_creation",
        "idempotency_keys",
        "expires_at > created_at",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_idempotency_keys_expiry_after_creation"),
        "idempotency_keys",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_idempotency_keys_response_status_valid"),
        "idempotency_keys",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_idempotency_keys_response_pair_coherent"),
        "idempotency_keys",
        type_="check",
    )

    op.drop_constraint(op.f("ck_transfers_fee_transaction_different"), "transfers", type_="check")

    op.drop_constraint(
        op.f("fk_transactions_reversal_owner_account_currency"),
        "transactions",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_transactions_parent_owner"),
        "transactions",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_transactions_account_owner_currency"),
        "transactions",
        type_="foreignkey",
    )
    op.create_foreign_key(
        op.f("fk_transactions_reversal_of_id_transactions"),
        "transactions",
        "transactions",
        ["reversal_of_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        op.f("fk_transactions_parent_transaction_id_transactions"),
        "transactions",
        "transactions",
        ["parent_transaction_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        op.f("fk_transactions_account_id_accounts"),
        "transactions",
        "accounts",
        ["account_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.drop_constraint(
        op.f("uq_transactions_id_user_account_currency"),
        "transactions",
        type_="unique",
    )
    op.drop_constraint(
        op.f("uq_transactions_id_user"),
        "transactions",
        type_="unique",
    )

    op.drop_constraint(op.f("ck_transactions_reversal_not_self"), "transactions", type_="check")
    op.drop_constraint(op.f("ck_transactions_parent_not_self"), "transactions", type_="check")
    op.drop_constraint(
        op.f("ck_transactions_reversal_link_coherent"), "transactions", type_="check"
    )
    op.drop_constraint(op.f("ck_transactions_type_effect_coherent"), "transactions", type_="check")
    op.drop_constraint(op.f("ck_transactions_version_positive"), "transactions", type_="check")

    op.drop_constraint(
        op.f("ck_accounts_opening_balance_respects_negative_policy"),
        "accounts",
        type_="check",
    )
    op.drop_constraint(op.f("ck_accounts_version_positive"), "accounts", type_="check")
    op.drop_constraint(
        op.f("uq_accounts_id_user_currency"),
        "accounts",
        type_="unique",
    )
    op.drop_constraint(op.f("uq_accounts_id_user"), "accounts", type_="unique")
