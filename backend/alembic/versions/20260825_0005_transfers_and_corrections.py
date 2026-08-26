"""Activate Milestone 3 transfers and correction workflows.

Revision ID: 20260825_0005
Revises: 20260825_0004
Create Date: 2026-08-25
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260825_0005"
down_revision: str | None = "20260825_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_check_constraint(
        "source_fingerprint_format",
        "reallocation_sessions",
        "source_fingerprint ~ '^[0-9a-f]{64}$'",
    )
    op.create_unique_constraint(
        op.f("uq_reallocation_sessions_id_user"),
        "reallocation_sessions",
        ["id", "user_id"],
    )
    op.drop_constraint(
        op.f("fk_reallocation_sessions_balancing_account_id_accounts"),
        "reallocation_sessions",
        type_="foreignkey",
    )
    op.create_foreign_key(
        op.f("fk_reallocation_sessions_balancing_account_owner"),
        "reallocation_sessions",
        "accounts",
        ["balancing_account_id", "user_id"],
        ["id", "user_id"],
        ondelete="RESTRICT",
    )

    op.add_column("reallocation_lines", sa.Column("user_id", sa.Uuid()))
    op.execute(
        """
        UPDATE reallocation_lines AS line
        SET user_id = session.user_id
        FROM reallocation_sessions AS session
        WHERE session.id = line.session_id
        """
    )
    op.alter_column("reallocation_lines", "user_id", nullable=False)
    op.create_foreign_key(
        op.f("fk_reallocation_lines_user_id_users"),
        "reallocation_lines",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.drop_constraint(
        op.f("fk_reallocation_lines_session_id_reallocation_sessions"),
        "reallocation_lines",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_reallocation_lines_account_id_accounts"),
        "reallocation_lines",
        type_="foreignkey",
    )
    op.create_foreign_key(
        op.f("fk_reallocation_lines_session_owner"),
        "reallocation_lines",
        "reallocation_sessions",
        ["session_id", "user_id"],
        ["id", "user_id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        op.f("fk_reallocation_lines_account_owner"),
        "reallocation_lines",
        "accounts",
        ["account_id", "user_id"],
        ["id", "user_id"],
        ondelete="RESTRICT",
    )
    op.create_index(
        "ix_reallocation_lines_user_session",
        "reallocation_lines",
        ["user_id", "session_id"],
    )

    op.add_column("transfers", sa.Column("reallocation_session_id", sa.Uuid()))
    op.add_column("transfers", sa.Column("source_fingerprint", sa.String(length=64)))
    op.add_column("transfers", sa.Column("client_operation_id", sa.Uuid()))
    op.add_column(
        "transfers",
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
    )
    op.execute(
        """
        UPDATE transfers
        SET source_fingerprint = repeat('0', 64),
            client_operation_id = id
        """
    )
    op.alter_column("transfers", "source_fingerprint", nullable=False)
    op.alter_column("transfers", "client_operation_id", nullable=False)
    op.create_check_constraint("version_positive", "transfers", "version > 0")
    op.create_check_constraint(
        "source_fingerprint_format",
        "transfers",
        "source_fingerprint ~ '^[0-9a-f]{64}$'",
    )
    op.create_unique_constraint(
        op.f("uq_transfers_id_user"),
        "transfers",
        ["id", "user_id"],
    )
    op.create_unique_constraint(
        op.f("uq_transfers_user_client_operation"),
        "transfers",
        ["user_id", "client_operation_id"],
    )
    op.drop_constraint(
        op.f("fk_transfers_source_transaction_id_transactions"),
        "transfers",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_transfers_destination_transaction_id_transactions"),
        "transfers",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_transfers_fee_transaction_id_transactions"),
        "transfers",
        type_="foreignkey",
    )
    op.create_foreign_key(
        op.f("fk_transfers_source_transaction_owner"),
        "transfers",
        "transactions",
        ["source_transaction_id", "user_id"],
        ["id", "user_id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        op.f("fk_transfers_destination_transaction_owner"),
        "transfers",
        "transactions",
        ["destination_transaction_id", "user_id"],
        ["id", "user_id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        op.f("fk_transfers_fee_transaction_owner"),
        "transfers",
        "transactions",
        ["fee_transaction_id", "user_id"],
        ["id", "user_id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        op.f("fk_transfers_reallocation_session_owner"),
        "transfers",
        "reallocation_sessions",
        ["reallocation_session_id", "user_id"],
        ["id", "user_id"],
        ondelete="RESTRICT",
    )
    op.create_index("ix_transfers_user_created", "transfers", ["user_id", "created_at"])
    op.create_index(
        "ix_transfers_reallocation_session",
        "transfers",
        ["reallocation_session_id"],
    )

    op.add_column(
        "balance_reconciliations",
        sa.Column("source_fingerprint", sa.String(length=64)),
    )
    op.add_column(
        "balance_reconciliations",
        sa.Column("client_operation_id", sa.Uuid()),
    )
    op.add_column(
        "balance_reconciliations",
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
    )
    op.execute(
        """
        UPDATE balance_reconciliations
        SET source_fingerprint = repeat('0', 64),
            client_operation_id = id
        """
    )
    op.alter_column("balance_reconciliations", "source_fingerprint", nullable=False)
    op.alter_column("balance_reconciliations", "client_operation_id", nullable=False)
    op.create_check_constraint(
        "delta_non_zero",
        "balance_reconciliations",
        "delta <> 0",
    )
    op.create_check_constraint(
        "version_positive",
        "balance_reconciliations",
        "version > 0",
    )
    op.create_check_constraint(
        "source_fingerprint_format",
        "balance_reconciliations",
        "source_fingerprint ~ '^[0-9a-f]{64}$'",
    )
    op.create_unique_constraint(
        op.f("uq_balance_reconciliations_user_client_operation"),
        "balance_reconciliations",
        ["user_id", "client_operation_id"],
    )
    op.drop_constraint(
        op.f("fk_balance_reconciliations_account_id_accounts"),
        "balance_reconciliations",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_reconciliation_adjustment_transaction"),
        "balance_reconciliations",
        type_="foreignkey",
    )
    op.create_foreign_key(
        op.f("fk_balance_reconciliations_account_owner"),
        "balance_reconciliations",
        "accounts",
        ["account_id", "user_id"],
        ["id", "user_id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        op.f("fk_balance_reconciliations_adjustment_owner"),
        "balance_reconciliations",
        "transactions",
        ["adjustment_transaction_id", "user_id"],
        ["id", "user_id"],
        ondelete="RESTRICT",
    )

    _create_specialized_ledger_triggers()


def _create_specialized_ledger_triggers() -> None:
    op.execute(
        """
        CREATE FUNCTION planit_round_half_even(value numeric, scale integer)
        RETURNS numeric
        LANGUAGE plpgsql
        IMMUTABLE STRICT PARALLEL SAFE
        AS $$
        DECLARE
            factor numeric := power(10::numeric, scale);
            shifted numeric := value * factor;
            lower_value numeric := floor(shifted);
            fraction numeric := shifted - lower_value;
        BEGIN
            IF fraction < 0.5 THEN
                RETURN lower_value / factor;
            ELSIF fraction > 0.5 THEN
                RETURN (lower_value + 1) / factor;
            ELSIF mod(abs(lower_value), 2) = 0 THEN
                RETURN lower_value / factor;
            END IF;
            RETURN (lower_value + 1) / factor;
        END;
        $$
        """
    )
    op.execute(
        """
        CREATE FUNCTION planit_validate_transfer_group()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        DECLARE
            source_row transactions%ROWTYPE;
            destination_row transactions%ROWTYPE;
            fee_row transactions%ROWTYPE;
            session_currency text;
        BEGIN
            SELECT * INTO source_row FROM transactions WHERE id = NEW.source_transaction_id;
            IF NOT FOUND THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'transfer_source_transaction_required';
            END IF;
            SELECT * INTO destination_row
            FROM transactions WHERE id = NEW.destination_transaction_id;
            IF NOT FOUND THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'transfer_destination_transaction_required';
            END IF;

            IF source_row.user_id <> NEW.user_id
                OR destination_row.user_id <> NEW.user_id
                OR source_row.account_id = destination_row.account_id
                OR source_row.type <> 'TRANSFER_OUT'
                OR source_row.effect <> 'OUTFLOW'
                OR destination_row.type <> 'TRANSFER_IN'
                OR destination_row.effect <> 'INFLOW'
                OR source_row.status NOT IN ('POSTED', 'REVERSED')
                OR destination_row.status NOT IN ('POSTED', 'REVERSED')
                OR source_row.status <> destination_row.status
                OR source_row.amount <> NEW.source_amount
                OR destination_row.amount <> NEW.destination_amount
                OR source_row.occurred_at <> destination_row.occurred_at
            THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'transfer_pair_coherent';
            END IF;

            IF source_row.currency = destination_row.currency THEN
                IF NEW.fx_rate IS NOT NULL OR NEW.source_amount <> NEW.destination_amount THEN
                    RAISE EXCEPTION USING ERRCODE = '23514',
                        CONSTRAINT = 'same_currency_transfer_coherent';
                END IF;
            ELSIF NEW.fx_rate IS NULL
                OR planit_round_half_even(NEW.source_amount * NEW.fx_rate, 4)
                    <> NEW.destination_amount
            THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'fx_transfer_coherent';
            END IF;

            IF NEW.fee_transaction_id IS NOT NULL THEN
                SELECT * INTO fee_row FROM transactions WHERE id = NEW.fee_transaction_id;
                IF NOT FOUND
                    OR fee_row.user_id <> NEW.user_id
                    OR fee_row.type <> 'TRANSFER_FEE'
                    OR fee_row.effect <> 'OUTFLOW'
                    OR fee_row.status NOT IN ('POSTED', 'REVERSED')
                    OR fee_row.status <> source_row.status
                    OR fee_row.occurred_at <> source_row.occurred_at
                THEN
                    RAISE EXCEPTION USING ERRCODE = '23514',
                        CONSTRAINT = 'transfer_fee_coherent';
                END IF;
            END IF;

            IF NEW.reallocation_session_id IS NOT NULL THEN
                SELECT currency INTO session_currency
                FROM reallocation_sessions
                WHERE id = NEW.reallocation_session_id AND user_id = NEW.user_id;
                IF NOT FOUND
                    OR NEW.fx_rate IS NOT NULL
                    OR NEW.fee_transaction_id IS NOT NULL
                    OR source_row.currency <> session_currency
                    OR destination_row.currency <> session_currency
                    OR NOT EXISTS (
                        SELECT 1 FROM reallocation_lines
                        WHERE session_id = NEW.reallocation_session_id
                          AND account_id = source_row.account_id
                          AND user_id = NEW.user_id
                    )
                    OR NOT EXISTS (
                        SELECT 1 FROM reallocation_lines
                        WHERE session_id = NEW.reallocation_session_id
                          AND account_id = destination_row.account_id
                          AND user_id = NEW.user_id
                    )
                THEN
                    RAISE EXCEPTION USING ERRCODE = '23514',
                        CONSTRAINT = 'reallocation_transfer_coherent';
                END IF;
            END IF;
            RETURN NEW;
        END;
        $$
        """
    )
    op.execute(
        """
        CREATE CONSTRAINT TRIGGER trg_transfers_validate_group
        AFTER INSERT OR UPDATE ON transfers
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION planit_validate_transfer_group()
        """
    )
    op.execute(
        """
        CREATE FUNCTION planit_validate_reconciliation_group()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        DECLARE adjustment_row transactions%ROWTYPE;
        BEGIN
            SELECT * INTO adjustment_row
            FROM transactions WHERE id = NEW.adjustment_transaction_id;
            IF NOT FOUND
                OR adjustment_row.user_id <> NEW.user_id
                OR adjustment_row.account_id <> NEW.account_id
                OR adjustment_row.type <> 'RECONCILIATION_ADJUSTMENT'
                OR adjustment_row.status NOT IN ('POSTED', 'REVERSED')
                OR adjustment_row.amount <> abs(NEW.delta)
                OR adjustment_row.occurred_at <> NEW.effective_at
                OR (NEW.delta > 0 AND adjustment_row.effect <> 'INFLOW')
                OR (NEW.delta < 0 AND adjustment_row.effect <> 'OUTFLOW')
            THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'reconciliation_adjustment_coherent';
            END IF;
            RETURN NEW;
        END;
        $$
        """
    )
    op.execute(
        """
        CREATE CONSTRAINT TRIGGER trg_reconciliations_validate_group
        AFTER INSERT OR UPDATE ON balance_reconciliations
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION planit_validate_reconciliation_group()
        """
    )
    op.execute(
        """
        CREATE FUNCTION planit_validate_reallocation_group()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        DECLARE
            session_id_value uuid;
            user_id_value uuid;
            session_row reallocation_sessions%ROWTYPE;
            line_count integer;
            balancing_line_count integer;
            expected_transfer_count integer;
            actual_transfer_count integer;
            before_total numeric;
            requested_total numeric;
        BEGIN
            IF TG_TABLE_NAME = 'reallocation_sessions' THEN
                session_id_value := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
                user_id_value := CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END;
            ELSIF TG_TABLE_NAME = 'reallocation_lines' THEN
                session_id_value := CASE
                    WHEN TG_OP = 'DELETE' THEN OLD.session_id ELSE NEW.session_id
                END;
                user_id_value := CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END;
            ELSE
                session_id_value := CASE
                    WHEN TG_OP = 'DELETE' THEN OLD.reallocation_session_id
                    ELSE NEW.reallocation_session_id
                END;
                user_id_value := CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END;
                IF session_id_value IS NULL THEN
                    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
                    RETURN NEW;
                END IF;
            END IF;

            SELECT * INTO session_row
            FROM reallocation_sessions
            WHERE id = session_id_value AND user_id = user_id_value;
            IF NOT FOUND THEN
                IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
                RETURN NEW;
            END IF;

            SELECT count(*),
                   count(*) FILTER (WHERE account_id = session_row.balancing_account_id),
                   count(*) FILTER (
                       WHERE account_id <> session_row.balancing_account_id AND delta <> 0
                   ),
                   coalesce(sum(before_balance), 0),
                   coalesce(sum(requested_balance), 0)
            INTO line_count, balancing_line_count, expected_transfer_count,
                 before_total, requested_total
            FROM reallocation_lines
            WHERE session_id = session_row.id AND user_id = session_row.user_id;

            SELECT count(*) INTO actual_transfer_count
            FROM transfers
            WHERE reallocation_session_id = session_row.id
              AND user_id = session_row.user_id;

            IF line_count < 2
                OR balancing_line_count <> 1
                OR before_total <> session_row.fixed_total
                OR requested_total <> session_row.fixed_total
                OR actual_transfer_count <> expected_transfer_count
                OR EXISTS (
                    SELECT 1
                    FROM reallocation_lines AS line
                    LEFT JOIN accounts AS account
                      ON account.id = line.account_id AND account.user_id = line.user_id
                    WHERE line.session_id = session_row.id
                      AND line.user_id = session_row.user_id
                      AND (
                          account.id IS NULL
                          OR account.currency <> session_row.currency
                          OR (NOT account.allow_negative AND line.requested_balance < 0)
                      )
                )
                OR EXISTS (
                    SELECT 1
                    FROM reallocation_lines AS line
                    WHERE line.session_id = session_row.id
                      AND line.user_id = session_row.user_id
                      AND line.account_id <> session_row.balancing_account_id
                      AND line.delta <> 0
                      AND 1 <> (
                          SELECT count(*)
                          FROM transfers AS transfer
                          JOIN transactions AS source_tx
                            ON source_tx.id = transfer.source_transaction_id
                           AND source_tx.user_id = transfer.user_id
                          JOIN transactions AS destination_tx
                            ON destination_tx.id = transfer.destination_transaction_id
                           AND destination_tx.user_id = transfer.user_id
                          WHERE transfer.reallocation_session_id = session_row.id
                            AND transfer.user_id = session_row.user_id
                            AND transfer.source_fingerprint = session_row.source_fingerprint
                            AND transfer.fx_rate IS NULL
                            AND transfer.fee_transaction_id IS NULL
                            AND transfer.source_amount = abs(line.delta)
                            AND transfer.destination_amount = abs(line.delta)
                            AND (
                                (line.delta > 0
                                 AND source_tx.account_id = session_row.balancing_account_id
                                 AND destination_tx.account_id = line.account_id)
                                OR
                                (line.delta < 0
                                 AND source_tx.account_id = line.account_id
                                 AND destination_tx.account_id = session_row.balancing_account_id)
                            )
                      )
                )
            THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'reallocation_session_coherent';
            END IF;

            IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
            RETURN NEW;
        END;
        $$
        """
    )
    op.execute(
        """
        CREATE CONSTRAINT TRIGGER trg_reallocation_sessions_validate_group
        AFTER INSERT OR UPDATE ON reallocation_sessions
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION planit_validate_reallocation_group()
        """
    )
    op.execute(
        """
        CREATE CONSTRAINT TRIGGER trg_reallocation_lines_validate_group
        AFTER INSERT OR UPDATE OR DELETE ON reallocation_lines
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION planit_validate_reallocation_group()
        """
    )
    op.execute(
        """
        CREATE CONSTRAINT TRIGGER trg_reallocation_transfers_validate_group
        AFTER INSERT OR UPDATE OR DELETE ON transfers
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION planit_validate_reallocation_group()
        """
    )
    op.execute(
        """
        CREATE FUNCTION planit_require_specialized_transaction_link()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
            IF NEW.type = 'TRANSFER_OUT' AND NOT EXISTS (
                SELECT 1 FROM transfers
                WHERE source_transaction_id = NEW.id AND user_id = NEW.user_id
            ) THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'transfer_out_link_required';
            ELSIF NEW.type = 'TRANSFER_IN' AND NOT EXISTS (
                SELECT 1 FROM transfers
                WHERE destination_transaction_id = NEW.id AND user_id = NEW.user_id
            ) THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'transfer_in_link_required';
            ELSIF NEW.type = 'TRANSFER_FEE' AND NOT EXISTS (
                SELECT 1 FROM transfers
                WHERE fee_transaction_id = NEW.id AND user_id = NEW.user_id
            ) THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'transfer_fee_link_required';
            ELSIF NEW.type = 'RECONCILIATION_ADJUSTMENT' AND NOT EXISTS (
                SELECT 1 FROM balance_reconciliations
                WHERE adjustment_transaction_id = NEW.id AND user_id = NEW.user_id
            ) THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'reconciliation_adjustment_link_required';
            END IF;

            IF NEW.type IN ('TRANSFER_OUT', 'TRANSFER_IN', 'TRANSFER_FEE')
                AND NOT EXISTS (
                    SELECT 1
                    FROM transfers AS transfer
                    JOIN transactions AS source_tx
                      ON source_tx.id = transfer.source_transaction_id
                     AND source_tx.user_id = transfer.user_id
                    JOIN transactions AS destination_tx
                      ON destination_tx.id = transfer.destination_transaction_id
                     AND destination_tx.user_id = transfer.user_id
                    LEFT JOIN transactions AS fee_tx
                      ON fee_tx.id = transfer.fee_transaction_id
                     AND fee_tx.user_id = transfer.user_id
                    WHERE transfer.user_id = NEW.user_id
                      AND (
                          transfer.source_transaction_id = NEW.id
                          OR transfer.destination_transaction_id = NEW.id
                          OR transfer.fee_transaction_id = NEW.id
                      )
                      AND source_tx.status = destination_tx.status
                      AND (fee_tx.id IS NULL OR fee_tx.status = source_tx.status)
                )
            THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'transfer_status_coherent';
            ELSIF NEW.type = 'RECONCILIATION_ADJUSTMENT' AND NOT EXISTS (
                SELECT 1
                FROM balance_reconciliations AS reconciliation
                WHERE reconciliation.adjustment_transaction_id = NEW.id
                  AND reconciliation.user_id = NEW.user_id
                  AND NEW.status IN ('POSTED', 'REVERSED')
                  AND NEW.amount = abs(reconciliation.delta)
                  AND NEW.occurred_at = reconciliation.effective_at
                  AND (reconciliation.delta > 0 AND NEW.effect = 'INFLOW'
                       OR reconciliation.delta < 0 AND NEW.effect = 'OUTFLOW')
            ) THEN
                RAISE EXCEPTION USING ERRCODE = '23514',
                    CONSTRAINT = 'reconciliation_adjustment_coherent';
            END IF;
            RETURN NEW;
        END;
        $$
        """
    )
    op.execute(
        """
        CREATE FUNCTION planit_protect_financial_group()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        DECLARE owner_id uuid;
        BEGIN
            owner_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END;
            IF TG_OP = 'UPDATE' AND OLD IS NOT DISTINCT FROM NEW THEN
                RETURN NEW;
            END IF;
            IF TG_OP = 'DELETE' AND NOT EXISTS (
                SELECT 1 FROM users WHERE id = owner_id
            ) THEN
                RETURN OLD;
            END IF;
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'financial_group_immutable';
        END;
        $$
        """
    )
    op.execute(
        """
        CREATE CONSTRAINT TRIGGER trg_transactions_require_specialized_link
        AFTER INSERT OR UPDATE ON transactions
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION planit_require_specialized_transaction_link()
        """
    )
    for table_name in (
        "transfers",
        "balance_reconciliations",
        "reallocation_sessions",
        "reallocation_lines",
    ):
        op.execute(
            f"""
            CREATE TRIGGER trg_{table_name}_immutable
            BEFORE UPDATE OR DELETE ON {table_name}
            FOR EACH ROW EXECUTE FUNCTION planit_protect_financial_group()
            """
        )

    # Force all pre-existing foundation rows through the new deferred invariants.
    op.execute("UPDATE transfers SET id = id")
    op.execute("UPDATE balance_reconciliations SET id = id")
    op.execute("UPDATE reallocation_sessions SET id = id")
    op.execute("UPDATE reallocation_lines SET session_id = session_id")
    op.execute(
        """
        UPDATE transactions
        SET id = id
        WHERE type IN (
            'TRANSFER_OUT', 'TRANSFER_IN', 'TRANSFER_FEE', 'RECONCILIATION_ADJUSTMENT'
        )
        """
    )
    op.execute("SET CONSTRAINTS ALL IMMEDIATE")
    op.execute("SET CONSTRAINTS ALL DEFERRED")


def downgrade() -> None:
    has_financial_groups = (
        op.get_bind()
        .execute(
            sa.text(
                """
            SELECT EXISTS (SELECT 1 FROM transfers)
                OR EXISTS (SELECT 1 FROM balance_reconciliations)
                OR EXISTS (SELECT 1 FROM reallocation_sessions)
            """
            )
        )
        .scalar_one()
    )
    if has_financial_groups:
        raise RuntimeError(
            "Refusing to downgrade Milestone 3 while financial groups exist; "
            "the older schema cannot preserve their integrity metadata."
        )

    for table_name in (
        "transfers",
        "balance_reconciliations",
        "reallocation_sessions",
        "reallocation_lines",
    ):
        op.execute(f"DROP TRIGGER trg_{table_name}_immutable ON {table_name}")
    op.execute("DROP FUNCTION planit_protect_financial_group()")
    op.execute("DROP TRIGGER trg_transactions_require_specialized_link ON transactions")
    op.execute("DROP FUNCTION planit_require_specialized_transaction_link()")
    op.execute("DROP TRIGGER trg_reallocation_transfers_validate_group ON transfers")
    op.execute("DROP TRIGGER trg_reallocation_lines_validate_group ON reallocation_lines")
    op.execute("DROP TRIGGER trg_reallocation_sessions_validate_group ON reallocation_sessions")
    op.execute("DROP FUNCTION planit_validate_reallocation_group()")
    op.execute("DROP TRIGGER trg_reconciliations_validate_group ON balance_reconciliations")
    op.execute("DROP FUNCTION planit_validate_reconciliation_group()")
    op.execute("DROP TRIGGER trg_transfers_validate_group ON transfers")
    op.execute("DROP FUNCTION planit_validate_transfer_group()")
    op.execute("DROP FUNCTION planit_round_half_even(numeric, integer)")

    op.drop_constraint(
        op.f("fk_balance_reconciliations_adjustment_owner"),
        "balance_reconciliations",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_balance_reconciliations_account_owner"),
        "balance_reconciliations",
        type_="foreignkey",
    )
    op.create_foreign_key(
        op.f("fk_balance_reconciliations_account_id_accounts"),
        "balance_reconciliations",
        "accounts",
        ["account_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        op.f("fk_reconciliation_adjustment_transaction"),
        "balance_reconciliations",
        "transactions",
        ["adjustment_transaction_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.drop_constraint(
        op.f("uq_balance_reconciliations_user_client_operation"),
        "balance_reconciliations",
        type_="unique",
    )
    op.drop_constraint(
        op.f("ck_balance_reconciliations_source_fingerprint_format"),
        "balance_reconciliations",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_balance_reconciliations_version_positive"),
        "balance_reconciliations",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_balance_reconciliations_delta_non_zero"),
        "balance_reconciliations",
        type_="check",
    )
    op.drop_column("balance_reconciliations", "version")
    op.drop_column("balance_reconciliations", "client_operation_id")
    op.drop_column("balance_reconciliations", "source_fingerprint")

    op.drop_index("ix_transfers_reallocation_session", table_name="transfers")
    op.drop_index("ix_transfers_user_created", table_name="transfers")
    op.drop_constraint(
        op.f("fk_transfers_reallocation_session_owner"),
        "transfers",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_transfers_fee_transaction_owner"),
        "transfers",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_transfers_destination_transaction_owner"),
        "transfers",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_transfers_source_transaction_owner"),
        "transfers",
        type_="foreignkey",
    )
    op.create_foreign_key(
        op.f("fk_transfers_source_transaction_id_transactions"),
        "transfers",
        "transactions",
        ["source_transaction_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        op.f("fk_transfers_destination_transaction_id_transactions"),
        "transfers",
        "transactions",
        ["destination_transaction_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        op.f("fk_transfers_fee_transaction_id_transactions"),
        "transfers",
        "transactions",
        ["fee_transaction_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.drop_constraint(
        op.f("uq_transfers_user_client_operation"),
        "transfers",
        type_="unique",
    )
    op.drop_constraint(op.f("uq_transfers_id_user"), "transfers", type_="unique")
    op.drop_constraint(
        op.f("ck_transfers_source_fingerprint_format"),
        "transfers",
        type_="check",
    )
    op.drop_constraint(op.f("ck_transfers_version_positive"), "transfers", type_="check")
    op.drop_column("transfers", "version")
    op.drop_column("transfers", "client_operation_id")
    op.drop_column("transfers", "source_fingerprint")
    op.drop_column("transfers", "reallocation_session_id")

    op.drop_index("ix_reallocation_lines_user_session", table_name="reallocation_lines")
    op.drop_constraint(
        op.f("fk_reallocation_lines_account_owner"),
        "reallocation_lines",
        type_="foreignkey",
    )
    op.drop_constraint(
        op.f("fk_reallocation_lines_session_owner"),
        "reallocation_lines",
        type_="foreignkey",
    )
    op.execute(
        "ALTER TABLE reallocation_lines "
        "DROP CONSTRAINT IF EXISTS fk_reallocation_lines_user_id_users"
    )
    op.create_foreign_key(
        op.f("fk_reallocation_lines_session_id_reallocation_sessions"),
        "reallocation_lines",
        "reallocation_sessions",
        ["session_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        op.f("fk_reallocation_lines_account_id_accounts"),
        "reallocation_lines",
        "accounts",
        ["account_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.drop_column("reallocation_lines", "user_id")
    op.drop_constraint(
        op.f("fk_reallocation_sessions_balancing_account_owner"),
        "reallocation_sessions",
        type_="foreignkey",
    )
    op.create_foreign_key(
        op.f("fk_reallocation_sessions_balancing_account_id_accounts"),
        "reallocation_sessions",
        "accounts",
        ["balancing_account_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.drop_constraint(
        op.f("uq_reallocation_sessions_id_user"),
        "reallocation_sessions",
        type_="unique",
    )
    op.drop_constraint(
        op.f("ck_reallocation_sessions_source_fingerprint_format"),
        "reallocation_sessions",
        type_="check",
    )
