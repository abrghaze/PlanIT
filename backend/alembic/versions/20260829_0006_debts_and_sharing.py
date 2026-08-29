"""Activate Milestone 4 debts, sharing, and refunds.

Revision ID: 20260829_0006
Revises: 20260825_0005
Create Date: 2026-08-29
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260829_0006"
down_revision: str | None = "20260825_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

MONEY = sa.Numeric(19, 4)


def upgrade() -> None:
    op.create_table(
        "people",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("normalized_name", sa.String(120), nullable=False),
        sa.Column("contact", sa.String(240), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "length(btrim(name)) BETWEEN 1 AND 120", name=op.f("ck_people_name_not_blank")
        ),
        sa.CheckConstraint("version > 0", name=op.f("ck_people_version_positive")),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_people_user_id_users"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_people")),
        sa.UniqueConstraint("id", "user_id", name=op.f("uq_people_id_user")),
    )
    op.create_index("ix_people_user_name", "people", ["user_id", "normalized_name", "id"])

    op.create_table(
        "debts",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("person_id", sa.Uuid(), nullable=False),
        sa.Column("direction", sa.String(16), nullable=False),
        sa.Column("origin_type", sa.String(24), nullable=False),
        sa.Column("origin_transaction_id", sa.Uuid(), nullable=True),
        sa.Column("original_amount", MONEY, nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("due_date", sa.Date(), nullable=True),
        sa.Column("status", sa.String(24), nullable=False, server_default="OPEN"),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancellation_reason", sa.Text(), nullable=True),
        sa.Column("client_operation_id", sa.Uuid(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint(
            "direction IN ('RECEIVABLE','PAYABLE')", name=op.f("ck_debts_direction_valid")
        ),
        sa.CheckConstraint(
            "origin_type IN ('EXISTING','LEND_NOW','BORROW_NOW','SHARED_EXPENSE')",
            name=op.f("ck_debts_origin_type_valid"),
        ),
        sa.CheckConstraint(
            "status IN ('OPEN','PARTIALLY_PAID','SETTLED','CANCELLED')",
            name=op.f("ck_debts_status_valid"),
        ),
        sa.CheckConstraint("original_amount > 0", name=op.f("ck_debts_original_amount_positive")),
        sa.CheckConstraint("currency ~ '^[A-Z]{3}$'", name=op.f("ck_debts_currency_format")),
        sa.CheckConstraint("version > 0", name=op.f("ck_debts_version_positive")),
        sa.CheckConstraint(
            "(origin_type = 'EXISTING' AND origin_transaction_id IS NULL) OR (origin_type <> 'EXISTING' AND origin_transaction_id IS NOT NULL)",
            name=op.f("ck_debts_origin_transaction_required"),
        ),
        sa.CheckConstraint(
            "(origin_type <> 'LEND_NOW' OR direction = 'RECEIVABLE') AND (origin_type <> 'BORROW_NOW' OR direction = 'PAYABLE') AND (origin_type <> 'SHARED_EXPENSE' OR direction = 'RECEIVABLE')",
            name=op.f("ck_debts_origin_direction_coherent"),
        ),
        sa.CheckConstraint(
            "(status = 'CANCELLED') = (cancelled_at IS NOT NULL)",
            name=op.f("ck_debts_cancellation_coherent"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_debts_user_id_users"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["person_id", "user_id"],
            ["people.id", "people.user_id"],
            name="fk_debts_person_owner",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["origin_transaction_id", "user_id"],
            ["transactions.id", "transactions.user_id"],
            name="fk_debts_origin_transaction_owner",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_debts")),
        sa.UniqueConstraint("id", "user_id", name=op.f("uq_debts_id_user")),
        sa.UniqueConstraint(
            "user_id", "client_operation_id", name=op.f("uq_debts_user_client_operation")
        ),
    )
    op.create_index("ix_debts_user_status_due", "debts", ["user_id", "status", "due_date"])
    op.create_index("ix_debts_person_status", "debts", ["person_id", "status"])
    op.create_index(
        "uq_debts_cash_origin_transaction",
        "debts",
        ["origin_transaction_id"],
        unique=True,
        postgresql_where=sa.text("origin_type IN ('LEND_NOW','BORROW_NOW')"),
    )

    op.create_table(
        "debt_payments",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("debt_id", sa.Uuid(), nullable=False),
        sa.Column("transaction_id", sa.Uuid(), nullable=False),
        sa.Column("amount", MONEY, nullable=False),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("client_operation_id", sa.Uuid(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("amount > 0", name=op.f("ck_debt_payments_amount_positive")),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_debt_payments_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["debt_id", "user_id"],
            ["debts.id", "debts.user_id"],
            name="fk_debt_payments_debt_owner",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["transaction_id", "user_id"],
            ["transactions.id", "transactions.user_id"],
            name="fk_debt_payments_transaction_owner",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_debt_payments")),
        sa.UniqueConstraint("transaction_id", name=op.f("uq_debt_payments_transaction")),
        sa.UniqueConstraint(
            "user_id", "client_operation_id", name=op.f("uq_debt_payments_user_client_operation")
        ),
    )
    op.create_index("ix_debt_payments_debt_paid", "debt_payments", ["debt_id", "paid_at", "id"])

    op.create_table(
        "shared_expense_shares",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("transaction_id", sa.Uuid(), nullable=False),
        sa.Column("person_id", sa.Uuid(), nullable=False),
        sa.Column("amount", MONEY, nullable=False),
        sa.Column("debt_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="ACTIVE"),
        sa.Column("client_operation_id", sa.Uuid(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("amount > 0", name=op.f("ck_shared_expense_shares_amount_positive")),
        sa.CheckConstraint(
            "status IN ('ACTIVE','CANCELLED')", name=op.f("ck_shared_expense_shares_status_valid")
        ),
        sa.CheckConstraint("version > 0", name=op.f("ck_shared_expense_shares_version_positive")),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_shared_expense_shares_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["transaction_id", "user_id"],
            ["transactions.id", "transactions.user_id"],
            name="fk_shared_expense_shares_transaction_owner",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["person_id", "user_id"],
            ["people.id", "people.user_id"],
            name="fk_shared_expense_shares_person_owner",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["debt_id", "user_id"],
            ["debts.id", "debts.user_id"],
            name="fk_shared_expense_shares_debt_owner",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_shared_expense_shares")),
        sa.UniqueConstraint(
            "transaction_id", "person_id", name=op.f("uq_shared_expense_shares_transaction_person")
        ),
        sa.UniqueConstraint("debt_id", name=op.f("uq_shared_expense_shares_debt")),
        sa.UniqueConstraint(
            "user_id",
            "client_operation_id",
            name=op.f("uq_shared_expense_shares_user_client_operation"),
        ),
    )
    op.create_index(
        "ix_shared_expense_shares_transaction_status",
        "shared_expense_shares",
        ["transaction_id", "status"],
    )
    _create_integrity_triggers()


def _create_integrity_triggers() -> None:
    op.execute(
        """
        CREATE FUNCTION planit_validate_debt_group()
        RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE debt_id_value uuid; debt_row debts%ROWTYPE; paid numeric; expected_status text;
        BEGIN
          IF TG_TABLE_NAME = 'debts' THEN debt_id_value := CASE WHEN TG_OP='DELETE' THEN OLD.id ELSE NEW.id END;
          ELSE debt_id_value := CASE WHEN TG_OP='DELETE' THEN OLD.debt_id ELSE NEW.debt_id END; END IF;
          SELECT * INTO debt_row FROM debts WHERE id=debt_id_value;
          IF NOT FOUND THEN IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW; END IF;
          SELECT coalesce(sum(amount),0) INTO paid FROM debt_payments WHERE debt_id=debt_row.id;
          IF paid > debt_row.original_amount THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='debt_overpayment'; END IF;
          expected_status := CASE WHEN paid=0 THEN 'OPEN' WHEN paid=debt_row.original_amount THEN 'SETTLED' ELSE 'PARTIALLY_PAID' END;
          IF debt_row.status <> 'CANCELLED' AND debt_row.status <> expected_status THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='debt_status_coherent'; END IF;
          IF debt_row.origin_type='EXISTING' AND debt_row.origin_transaction_id IS NOT NULL THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='debt_origin_coherent'; END IF;
          IF debt_row.origin_type IN ('LEND_NOW','BORROW_NOW') AND NOT EXISTS (
            SELECT 1 FROM transactions t WHERE t.id=debt_row.origin_transaction_id AND t.user_id=debt_row.user_id
              AND t.amount=debt_row.original_amount AND t.currency=debt_row.currency AND t.status IN ('POSTED','REVERSED')
              AND ((debt_row.origin_type='LEND_NOW' AND t.type='LOAN_PRINCIPAL_OUT' AND t.effect='OUTFLOW') OR (debt_row.origin_type='BORROW_NOW' AND t.type='LOAN_PRINCIPAL_IN' AND t.effect='INFLOW'))
          ) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='debt_origin_coherent'; END IF;
          IF EXISTS (
            SELECT 1 FROM debt_payments p LEFT JOIN transactions t ON t.id=p.transaction_id AND t.user_id=p.user_id
            WHERE p.debt_id=debt_row.id AND (t.id IS NULL OR t.amount<>p.amount OR t.currency<>debt_row.currency OR t.occurred_at<>p.paid_at OR t.status NOT IN ('POSTED','REVERSED') OR (debt_row.direction='RECEIVABLE' AND (t.type<>'DEBT_REPAYMENT_IN' OR t.effect<>'INFLOW')) OR (debt_row.direction='PAYABLE' AND (t.type<>'DEBT_REPAYMENT_OUT' OR t.effect<>'OUTFLOW')))
          ) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='debt_payment_coherent'; END IF;
          IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
        END $$
        """
    )
    for table in ("debts", "debt_payments"):
        events = "INSERT OR UPDATE" if table == "debts" else "INSERT OR UPDATE OR DELETE"
        op.execute(
            f"CREATE CONSTRAINT TRIGGER trg_{table}_validate_group AFTER {events} ON {table} DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION planit_validate_debt_group()"
        )

    op.execute(
        """
        CREATE FUNCTION planit_validate_expense_recovery()
        RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE expense_id uuid; expense_row transactions%ROWTYPE; refund_total numeric; share_total numeric;
        BEGIN
          IF TG_TABLE_NAME='shared_expense_shares' THEN expense_id := CASE WHEN TG_OP='DELETE' THEN OLD.transaction_id ELSE NEW.transaction_id END;
          ELSE
            IF TG_OP='INSERT' AND NEW.type<>'REFUND' THEN RETURN NEW;
            ELSIF TG_OP='DELETE' AND OLD.type<>'REFUND' THEN RETURN OLD;
            ELSIF TG_OP='UPDATE' AND NEW.type<>'REFUND' AND OLD.type<>'REFUND' THEN RETURN NEW;
            END IF;
            expense_id := CASE WHEN TG_OP='DELETE' THEN OLD.parent_transaction_id ELSE NEW.parent_transaction_id END;
          END IF;
          IF expense_id IS NULL THEN IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW; END IF;
          SELECT * INTO expense_row FROM transactions WHERE id=expense_id;
          IF NOT FOUND THEN
            IF TG_OP='DELETE' THEN RETURN OLD; END IF;
            RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='recoverable_expense_required';
          END IF;
          IF expense_row.type<>'EXPENSE' OR expense_row.status NOT IN ('POSTED','REVERSED') THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='recoverable_expense_required'; END IF;
          SELECT coalesce(sum(amount),0) INTO refund_total FROM transactions WHERE parent_transaction_id=expense_id AND type='REFUND' AND status IN ('POSTED','REVERSED');
          SELECT coalesce(sum(amount),0) INTO share_total FROM shared_expense_shares WHERE transaction_id=expense_id AND status='ACTIVE';
          IF refund_total > expense_row.amount THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='refund_exceeds_remaining'; END IF;
          IF share_total > expense_row.amount-refund_total THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='shared_expense_cap'; END IF;
          IF EXISTS (
            SELECT 1 FROM transactions r WHERE r.parent_transaction_id=expense_id AND r.type='REFUND' AND (r.user_id<>expense_row.user_id OR r.currency<>expense_row.currency OR r.effect<>'INFLOW' OR r.status NOT IN ('POSTED','REVERSED'))
          ) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='refund_transaction_coherent'; END IF;
          IF EXISTS (
            SELECT 1 FROM shared_expense_shares s JOIN debts d ON d.id=s.debt_id AND d.user_id=s.user_id
            WHERE s.transaction_id=expense_id AND (s.user_id<>expense_row.user_id OR d.origin_type<>'SHARED_EXPENSE' OR d.direction<>'RECEIVABLE' OR d.person_id<>s.person_id OR d.origin_transaction_id<>s.transaction_id OR d.original_amount<>s.amount OR d.currency<>expense_row.currency OR (s.status='ACTIVE' AND d.status='CANCELLED'))
          ) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='shared_expense_debt_coherent'; END IF;
          IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
        END $$
        """
    )
    op.execute(
        "CREATE CONSTRAINT TRIGGER trg_shared_expense_shares_validate AFTER INSERT OR UPDATE OR DELETE ON shared_expense_shares DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION planit_validate_expense_recovery()"
    )
    op.execute(
        "CREATE CONSTRAINT TRIGGER trg_refund_transactions_validate AFTER INSERT OR UPDATE OR DELETE ON transactions DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION planit_validate_expense_recovery()"
    )

    op.execute(
        """
        CREATE OR REPLACE FUNCTION planit_require_specialized_transaction_link()
        RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          IF NEW.type='TRANSFER_OUT' AND NOT EXISTS (SELECT 1 FROM transfers WHERE source_transaction_id=NEW.id AND user_id=NEW.user_id) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='transfer_out_link_required';
          ELSIF NEW.type='TRANSFER_IN' AND NOT EXISTS (SELECT 1 FROM transfers WHERE destination_transaction_id=NEW.id AND user_id=NEW.user_id) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='transfer_in_link_required';
          ELSIF NEW.type='TRANSFER_FEE' AND NOT EXISTS (SELECT 1 FROM transfers WHERE fee_transaction_id=NEW.id AND user_id=NEW.user_id) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='transfer_fee_link_required';
          ELSIF NEW.type='RECONCILIATION_ADJUSTMENT' AND NOT EXISTS (SELECT 1 FROM balance_reconciliations WHERE adjustment_transaction_id=NEW.id AND user_id=NEW.user_id) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='reconciliation_adjustment_link_required';
          ELSIF NEW.type IN ('LOAN_PRINCIPAL_OUT','LOAN_PRINCIPAL_IN') AND NOT EXISTS (SELECT 1 FROM debts WHERE origin_transaction_id=NEW.id AND user_id=NEW.user_id) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='debt_origin_link_required';
          ELSIF NEW.type IN ('DEBT_REPAYMENT_IN','DEBT_REPAYMENT_OUT') AND NOT EXISTS (SELECT 1 FROM debt_payments WHERE transaction_id=NEW.id AND user_id=NEW.user_id) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='debt_payment_link_required';
          ELSIF NEW.type='REFUND' AND (NEW.parent_transaction_id IS NULL OR NOT EXISTS (SELECT 1 FROM transactions p WHERE p.id=NEW.parent_transaction_id AND p.user_id=NEW.user_id AND p.type='EXPENSE')) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='refund_parent_required'; END IF;
          IF NEW.type IN ('TRANSFER_OUT','TRANSFER_IN','TRANSFER_FEE') AND NOT EXISTS (SELECT 1 FROM transfers tr JOIN transactions s ON s.id=tr.source_transaction_id AND s.user_id=tr.user_id JOIN transactions d ON d.id=tr.destination_transaction_id AND d.user_id=tr.user_id LEFT JOIN transactions f ON f.id=tr.fee_transaction_id AND f.user_id=tr.user_id WHERE tr.user_id=NEW.user_id AND NEW.id IN (tr.source_transaction_id,tr.destination_transaction_id,tr.fee_transaction_id) AND s.status=d.status AND (f.id IS NULL OR f.status=s.status)) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='transfer_status_coherent';
          ELSIF NEW.type='RECONCILIATION_ADJUSTMENT' AND NOT EXISTS (SELECT 1 FROM balance_reconciliations r WHERE r.adjustment_transaction_id=NEW.id AND r.user_id=NEW.user_id AND NEW.status IN ('POSTED','REVERSED') AND NEW.amount=abs(r.delta) AND NEW.occurred_at=r.effective_at AND ((r.delta>0 AND NEW.effect='INFLOW') OR (r.delta<0 AND NEW.effect='OUTFLOW'))) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='reconciliation_adjustment_coherent'; END IF;
          RETURN NEW;
        END $$
        """
    )


def downgrade() -> None:
    has_rows = (
        op.get_bind()
        .execute(
            sa.text(
                "SELECT EXISTS(SELECT 1 FROM debts) OR EXISTS(SELECT 1 FROM shared_expense_shares) OR EXISTS(SELECT 1 FROM transactions WHERE type='REFUND')"
            )
        )
        .scalar_one()
    )
    if has_rows:
        raise RuntimeError(
            "Refusing to downgrade Milestone 4 while debt, sharing, or refund history exists."
        )
    op.execute("DROP TRIGGER trg_refund_transactions_validate ON transactions")
    op.execute("DROP TRIGGER trg_shared_expense_shares_validate ON shared_expense_shares")
    op.execute("DROP FUNCTION planit_validate_expense_recovery()")
    op.execute("DROP TRIGGER trg_debt_payments_validate_group ON debt_payments")
    op.execute("DROP TRIGGER trg_debts_validate_group ON debts")
    op.execute("DROP FUNCTION planit_validate_debt_group()")
    _restore_milestone_three_specialized_function()
    op.drop_table("shared_expense_shares")
    op.drop_table("debt_payments")
    op.drop_table("debts")
    op.drop_table("people")


def _restore_milestone_three_specialized_function() -> None:
    op.execute(
        """
        CREATE OR REPLACE FUNCTION planit_require_specialized_transaction_link()
        RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          IF NEW.type='TRANSFER_OUT' AND NOT EXISTS (SELECT 1 FROM transfers WHERE source_transaction_id=NEW.id AND user_id=NEW.user_id) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='transfer_out_link_required';
          ELSIF NEW.type='TRANSFER_IN' AND NOT EXISTS (SELECT 1 FROM transfers WHERE destination_transaction_id=NEW.id AND user_id=NEW.user_id) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='transfer_in_link_required';
          ELSIF NEW.type='TRANSFER_FEE' AND NOT EXISTS (SELECT 1 FROM transfers WHERE fee_transaction_id=NEW.id AND user_id=NEW.user_id) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='transfer_fee_link_required';
          ELSIF NEW.type='RECONCILIATION_ADJUSTMENT' AND NOT EXISTS (SELECT 1 FROM balance_reconciliations WHERE adjustment_transaction_id=NEW.id AND user_id=NEW.user_id) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='reconciliation_adjustment_link_required'; END IF;
          IF NEW.type IN ('TRANSFER_OUT','TRANSFER_IN','TRANSFER_FEE') AND NOT EXISTS (
            SELECT 1 FROM transfers tr JOIN transactions s ON s.id=tr.source_transaction_id AND s.user_id=tr.user_id JOIN transactions d ON d.id=tr.destination_transaction_id AND d.user_id=tr.user_id LEFT JOIN transactions f ON f.id=tr.fee_transaction_id AND f.user_id=tr.user_id
            WHERE tr.user_id=NEW.user_id AND (tr.source_transaction_id=NEW.id OR tr.destination_transaction_id=NEW.id OR tr.fee_transaction_id=NEW.id) AND s.status=d.status AND (f.id IS NULL OR f.status=s.status)
          ) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='transfer_status_coherent';
          ELSIF NEW.type='RECONCILIATION_ADJUSTMENT' AND NOT EXISTS (
            SELECT 1 FROM balance_reconciliations r WHERE r.adjustment_transaction_id=NEW.id AND r.user_id=NEW.user_id AND NEW.status IN ('POSTED','REVERSED') AND NEW.amount=abs(r.delta) AND NEW.occurred_at=r.effective_at AND ((r.delta>0 AND NEW.effect='INFLOW') OR (r.delta<0 AND NEW.effect='OUTFLOW'))
          ) THEN RAISE EXCEPTION USING ERRCODE='23514', CONSTRAINT='reconciliation_adjustment_coherent'; END IF;
          RETURN NEW;
        END $$
        """
    )
