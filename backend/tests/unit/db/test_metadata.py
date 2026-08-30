from app.db import models  # noqa: F401
from app.db.base import Base
from sqlalchemy.dialects import postgresql
from sqlalchemy.schema import CreateTable

EXPECTED_TABLES = {
    "accounts",
    "auth_throttles",
    "audit_events",
    "balance_reconciliations",
    "categories",
    "debt_payments",
    "debts",
    "exchange_rates",
    "entity_media",
    "goal_allocations",
    "idempotency_keys",
    "media_assets",
    "merchant_locations",
    "merchants",
    "people",
    "products",
    "reallocation_lines",
    "reallocation_sessions",
    "recurring_occurrences",
    "recurring_rules",
    "refresh_sessions",
    "savings_goals",
    "shared_expense_shares",
    "tags",
    "transaction_tags",
    "transaction_items",
    "transactions",
    "transfers",
    "users",
}


def test_migrated_metadata_is_complete() -> None:
    assert set(Base.metadata.tables) == EXPECTED_TABLES


def test_every_table_compiles_for_postgresql() -> None:
    dialect = postgresql.dialect()

    for table in Base.metadata.sorted_tables:
        ddl = str(CreateTable(table).compile(dialect=dialect))
        assert f"CREATE TABLE {table.name}" in ddl
