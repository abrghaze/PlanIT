from datetime import UTC, datetime
from uuid import uuid4

from app.domain.ledger.reconciliation import preview_reconciliation
from app.domain.money import Money


def test_reconciliation_delta_is_actual_minus_calculated() -> None:
    preview = preview_reconciliation(
        account_id=uuid4(),
        account_version=3,
        calculated_balance=Money.of("1020", "MAD"),
        actual_balance=Money.of("1000", "MAD"),
        effective_at=datetime.now(UTC),
    )
    assert preview.delta.to_api() == "-20.0000"
    assert len(preview.source_fingerprint) == 64
