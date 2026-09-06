"""Preserve recurrence and purchase-history calculation anchors.

Revision ID: 20260906_0010
Revises: 20260901_0009
Create Date: 2026-09-06
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260906_0010"
down_revision: str | None = "20260901_0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

QUANTITY = sa.Numeric(19, 6)


def upgrade() -> None:
    op.add_column("recurring_rules", sa.Column("anchor_day", sa.Integer(), nullable=True))
    op.execute(
        "UPDATE recurring_rules SET anchor_day = "
        "EXTRACT(DAY FROM (next_due_at AT TIME ZONE timezone))::integer"
    )
    op.alter_column("recurring_rules", "anchor_day", nullable=False)
    op.create_check_constraint(
        op.f("ck_recurring_rules_anchor_day_valid"),
        "recurring_rules",
        "anchor_day BETWEEN 1 AND 31",
    )

    op.add_column(
        "transaction_items", sa.Column("package_size_value_snapshot", QUANTITY, nullable=True)
    )
    op.add_column(
        "transaction_items", sa.Column("package_size_unit_snapshot", sa.String(12), nullable=True)
    )
    op.execute(
        "UPDATE transaction_items AS item "
        "SET package_size_value_snapshot = product.size_value, "
        "package_size_unit_snapshot = product.size_unit "
        "FROM products AS product "
        "WHERE item.product_id = product.id AND item.user_id = product.user_id"
    )
    op.create_check_constraint(
        op.f("ck_transaction_items_package_snapshot_coherent"),
        "transaction_items",
        "(package_size_value_snapshot IS NULL) = (package_size_unit_snapshot IS NULL)",
    )
    op.create_check_constraint(
        op.f("ck_transaction_items_package_snapshot_positive"),
        "transaction_items",
        "package_size_value_snapshot IS NULL OR package_size_value_snapshot > 0",
    )
    op.create_check_constraint(
        op.f("ck_transaction_items_package_snapshot_unit_valid"),
        "transaction_items",
        "package_size_unit_snapshot IS NULL OR "
        "package_size_unit_snapshot IN ('COUNT','G','KG','ML','L')",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_transaction_items_package_snapshot_unit_valid"),
        "transaction_items",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_transaction_items_package_snapshot_positive"),
        "transaction_items",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_transaction_items_package_snapshot_coherent"),
        "transaction_items",
        type_="check",
    )
    op.drop_column("transaction_items", "package_size_unit_snapshot")
    op.drop_column("transaction_items", "package_size_value_snapshot")
    op.drop_constraint(
        op.f("ck_recurring_rules_anchor_day_valid"), "recurring_rules", type_="check"
    )
    op.drop_column("recurring_rules", "anchor_day")
