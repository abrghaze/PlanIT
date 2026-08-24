from datetime import UTC, datetime, timedelta, timezone
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


def test_reconciliation_normalizes_effective_time_to_utc() -> None:
    preview = preview_reconciliation(
        account_id=uuid4(),
        account_version=1,
        calculated_balance=Money.of("1", "MAD"),
        actual_balance=Money.of("1", "MAD"),
        effective_at=datetime(2026, 8, 24, 20, tzinfo=timezone(timedelta(hours=1))),
    )

    assert preview.effective_at == datetime(2026, 8, 24, 19, tzinfo=UTC)
