"""Add Milestone 2 categories, tags, and core transaction lifecycle.

Revision ID: 20260825_0004
Revises: 20260825_0003
Create Date: 2026-08-25
"""

from collections.abc import Sequence
from uuid import UUID, uuid5

import sqlalchemy as sa
from alembic import op

revision: str = "20260825_0004"
down_revision: str | None = "20260825_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_DEFAULT_CATEGORIES = (
    ("Food & dining", "EXPENSE"),
    ("Transport", "EXPENSE"),
    ("Housing", "EXPENSE"),
    ("Utilities", "EXPENSE"),
    ("Health", "EXPENSE"),
    ("Shopping", "EXPENSE"),
    ("Entertainment", "EXPENSE"),
    ("Other expense", "EXPENSE"),
    ("Salary", "INCOME"),
    ("Gifts", "INCOME"),
    ("Sales", "INCOME"),
    ("Other income", "INCOME"),
)


def upgrade() -> None:
    op.create_table(
        "categories",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("normalized_name", sa.String(length=80), nullable=False),
        sa.Column("kind", sa.String(length=16), nullable=False),
        sa.Column("parent_id", sa.Uuid()),
        sa.Column("is_seeded", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("archived_at", sa.DateTime(timezone=True)),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
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
        sa.CheckConstraint("length(btrim(name)) BETWEEN 1 AND 80", name="name_not_blank"),
        sa.CheckConstraint("kind IN ('EXPENSE','INCOME','BOTH')", name="kind_valid"),
        sa.CheckConstraint("version > 0", name="version_positive"),
        sa.CheckConstraint("parent_id IS NULL OR parent_id <> id", name="parent_not_self"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
            name="fk_categories_user_id_users",
        ),
        sa.ForeignKeyConstraint(
            ["parent_id", "user_id"],
            ["categories.id", "categories.user_id"],
            ondelete="RESTRICT",
            name="fk_categories_parent_owner",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_categories"),
        sa.UniqueConstraint("id", "user_id", name="uq_categories_id_user"),
    )
    op.create_index(
        "uq_categories_user_active_normalized_name",
        "categories",
        ["user_id", "normalized_name"],
        unique=True,
        postgresql_where=sa.text("archived_at IS NULL"),
    )
    op.create_index(
        "ix_categories_user_kind_name",
        "categories",
        ["user_id", "kind", "normalized_name"],
    )

    op.create_table(
        "tags",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("normalized_name", sa.String(length=80), nullable=False),
        sa.Column("color", sa.String(length=7)),
        sa.Column("archived_at", sa.DateTime(timezone=True)),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
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
        sa.CheckConstraint("length(btrim(name)) BETWEEN 1 AND 80", name="name_not_blank"),
        sa.CheckConstraint("color IS NULL OR color ~ '^#[0-9A-F]{6}$'", name="color_format"),
        sa.CheckConstraint("version > 0", name="version_positive"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
            name="fk_tags_user_id_users",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_tags"),
        sa.UniqueConstraint("id", "user_id", name="uq_tags_id_user"),
    )
    op.create_index(
        "uq_tags_user_active_normalized_name",
        "tags",
        ["user_id", "normalized_name"],
        unique=True,
        postgresql_where=sa.text("archived_at IS NULL"),
    )
    op.create_index("ix_tags_user_name", "tags", ["user_id", "normalized_name"])

    _seed_existing_users()

    op.add_column("transactions", sa.Column("category_id", sa.Uuid()))
    op.add_column("transactions", sa.Column("counterparty", sa.String(length=160)))
    op.create_check_constraint(
        "counterparty_not_blank",
        "transactions",
        "counterparty IS NULL OR length(btrim(counterparty)) BETWEEN 1 AND 160",
    )
    op.create_foreign_key(
        "fk_transactions_category_owner",
        "transactions",
        "categories",
        ["category_id", "user_id"],
        ["id", "user_id"],
        ondelete="RESTRICT",
    )
    op.create_index(
        "ix_transactions_category_occurred_id",
        "transactions",
        ["category_id", "occurred_at", "id"],
    )

    op.create_table(
        "transaction_tags",
        sa.Column("transaction_id", sa.Uuid(), nullable=False),
        sa.Column("tag_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.ForeignKeyConstraint(
            ["transaction_id", "user_id"],
            ["transactions.id", "transactions.user_id"],
            ondelete="CASCADE",
            name="fk_transaction_tags_transaction_owner",
        ),
        sa.ForeignKeyConstraint(
            ["tag_id", "user_id"],
            ["tags.id", "tags.user_id"],
            ondelete="RESTRICT",
            name="fk_transaction_tags_tag_owner",
        ),
        sa.PrimaryKeyConstraint("transaction_id", "tag_id", name="pk_transaction_tags"),
    )
    op.create_index(
        "ix_transaction_tags_user_tag",
        "transaction_tags",
        ["user_id", "tag_id", "transaction_id"],
    )

    op.execute(
        """
        CREATE FUNCTION planit_guard_transaction_history()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
            IF TG_OP = 'DELETE' THEN
                IF OLD.status IN ('POSTED', 'REVERSED') AND EXISTS (
                    SELECT 1 FROM users WHERE id = OLD.user_id
                ) THEN
                    RAISE EXCEPTION
                        USING ERRCODE = '23514',
                              CONSTRAINT = 'posted_transaction_cannot_be_deleted',
                              MESSAGE = 'posted transaction history cannot be deleted';
                END IF;
                RETURN OLD;
            END IF;

            IF OLD.status IN ('POSTED', 'REVERSED') AND (
                OLD.user_id IS DISTINCT FROM NEW.user_id
                OR OLD.account_id IS DISTINCT FROM NEW.account_id
                OR OLD.type IS DISTINCT FROM NEW.type
                OR OLD.effect IS DISTINCT FROM NEW.effect
                OR OLD.amount IS DISTINCT FROM NEW.amount
                OR OLD.currency IS DISTINCT FROM NEW.currency
                OR OLD.occurred_at IS DISTINCT FROM NEW.occurred_at
                OR OLD.category_id IS DISTINCT FROM NEW.category_id
                OR OLD.counterparty IS DISTINCT FROM NEW.counterparty
                OR OLD.note IS DISTINCT FROM NEW.note
                OR OLD.parent_transaction_id IS DISTINCT FROM NEW.parent_transaction_id
                OR OLD.reversal_of_id IS DISTINCT FROM NEW.reversal_of_id
                OR OLD.client_operation_id IS DISTINCT FROM NEW.client_operation_id
            ) THEN
                RAISE EXCEPTION
                    USING ERRCODE = '23514',
                          CONSTRAINT = 'posted_transaction_fields_immutable',
                          MESSAGE = 'posted transaction fields are immutable';
            END IF;

            IF OLD.status = 'DRAFT' AND NEW.status NOT IN ('DRAFT', 'POSTED', 'VOIDED') THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'transaction_status_transition_valid';
            ELSIF OLD.status = 'POSTED' AND NEW.status NOT IN ('POSTED', 'REVERSED') THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'transaction_status_transition_valid';
            ELSIF OLD.status IN ('REVERSED', 'VOIDED') AND NEW.status <> OLD.status THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'transaction_status_transition_valid';
            END IF;
            RETURN NEW;
        END;
        $$
        """
    )
    op.execute(
        """
        CREATE TRIGGER trg_transactions_guard_history
        BEFORE UPDATE OR DELETE ON transactions
        FOR EACH ROW EXECUTE FUNCTION planit_guard_transaction_history()
        """
    )
    op.execute(
        """
        CREATE FUNCTION planit_guard_transaction_tags()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        DECLARE current_status text;
        BEGIN
            IF TG_OP = 'DELETE' THEN
                SELECT status INTO current_status
                FROM transactions
                WHERE id = OLD.transaction_id;
            ELSE
                SELECT status INTO current_status
                FROM transactions
                WHERE id = NEW.transaction_id;
            END IF;
            IF FOUND AND current_status <> 'DRAFT' THEN
                RAISE EXCEPTION
                    USING ERRCODE = '23514',
                          CONSTRAINT = 'posted_transaction_tags_immutable',
                          MESSAGE = 'posted transaction tags are immutable';
            END IF;
            IF TG_OP = 'DELETE' THEN
                RETURN OLD;
            END IF;
            RETURN NEW;
        END;
        $$
        """
    )
    op.execute(
        """
        CREATE TRIGGER trg_transaction_tags_guard_history
        BEFORE INSERT OR UPDATE OR DELETE ON transaction_tags
        FOR EACH ROW EXECUTE FUNCTION planit_guard_transaction_tags()
        """
    )


def _seed_existing_users() -> None:
    connection = op.get_bind()
    user_ids = [UUID(str(row[0])) for row in connection.execute(sa.text("SELECT id FROM users"))]
    if not user_ids:
        return
    categories = sa.table(
        "categories",
        sa.column("id", sa.Uuid()),
        sa.column("user_id", sa.Uuid()),
        sa.column("name", sa.String()),
        sa.column("normalized_name", sa.String()),
        sa.column("kind", sa.String()),
        sa.column("is_seeded", sa.Boolean()),
    )
    rows: list[dict[str, object]] = []
    for user_id in user_ids:
        for name, kind in _DEFAULT_CATEGORIES:
            normalized = " ".join(name.strip().split()).casefold()
            rows.append(
                {
                    "id": uuid5(user_id, f"planit-category:{kind}:{normalized}"),
                    "user_id": user_id,
                    "name": name,
                    "normalized_name": normalized,
                    "kind": kind,
                    "is_seeded": True,
                }
            )
    op.bulk_insert(categories, rows)


def downgrade() -> None:
    op.execute("DROP TRIGGER trg_transaction_tags_guard_history ON transaction_tags")
    op.execute("DROP FUNCTION planit_guard_transaction_tags()")
    op.execute("DROP TRIGGER trg_transactions_guard_history ON transactions")
    op.execute("DROP FUNCTION planit_guard_transaction_history()")

    op.drop_index("ix_transaction_tags_user_tag", table_name="transaction_tags")
    op.drop_table("transaction_tags")

    op.drop_index("ix_transactions_category_occurred_id", table_name="transactions")
    op.drop_constraint("fk_transactions_category_owner", "transactions", type_="foreignkey")
    op.drop_constraint(
        op.f("ck_transactions_counterparty_not_blank"),
        "transactions",
        type_="check",
    )
    op.drop_column("transactions", "counterparty")
    op.drop_column("transactions", "category_id")

    op.drop_index("ix_tags_user_name", table_name="tags")
    op.drop_index("uq_tags_user_active_normalized_name", table_name="tags")
    op.drop_table("tags")

    op.drop_index("ix_categories_user_kind_name", table_name="categories")
    op.drop_index("uq_categories_user_active_normalized_name", table_name="categories")
    op.drop_table("categories")
