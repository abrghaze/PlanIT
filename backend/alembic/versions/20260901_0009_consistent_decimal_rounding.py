"""Use the ledger's banker rounding for persisted item totals.

Revision ID: 20260901_0009
Revises: 20260830_0008
Create Date: 2026-09-01
"""

from collections.abc import Sequence

from alembic import op

revision: str = "20260901_0009"
down_revision: str | None = "20260830_0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_constraint(
        op.f("ck_transaction_items_line_total_exact"),
        "transaction_items",
        type_="check",
    )
    op.create_check_constraint(
        op.f("ck_transaction_items_line_total_exact"),
        "transaction_items",
        "line_total = planit_round_half_even(quantity * unit_price - discount, 4)",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_transaction_items_line_total_exact"),
        "transaction_items",
        type_="check",
    )
    op.create_check_constraint(
        op.f("ck_transaction_items_line_total_exact"),
        "transaction_items",
        "line_total = round(quantity * unit_price - discount, 4)",
    )
