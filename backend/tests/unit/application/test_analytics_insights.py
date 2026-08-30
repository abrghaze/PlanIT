from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from uuid import uuid4

from app.application.analytics import _spending_insights
from app.db.models.ledger import TransactionModel


def _transaction(amount: str) -> tuple[TransactionModel, Decimal]:
    value = Decimal(amount)
    return (
        TransactionModel(
            id=uuid4(),
            user_id=uuid4(),
            account_id=uuid4(),
            type="EXPENSE",
            effect="OUTFLOW",
            amount=value,
            currency="MAD",
            occurred_at=datetime(2026, 8, 30, tzinfo=UTC),
            status="POSTED",
            client_operation_id=uuid4(),
            version=1,
        ),
        value,
    )


def test_spending_insights_require_history_and_explain_outliers() -> None:
    assert _spending_insights([_transaction("50")], currency="MAD") == ()

    insights = _spending_insights(
        [_transaction(value) for value in ("10", "11", "12", "13", "50")],
        currency="MAD",
    )

    assert len(insights) == 1
    assert insights[0].amount.amount == Decimal("50.0000")
    assert insights[0].baseline.amount == Decimal("12.0000")
    assert insights[0].multiple == Decimal("4.17")
    assert "median" in insights[0].explanation
