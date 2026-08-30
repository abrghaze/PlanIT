from datetime import UTC, datetime
from decimal import Decimal

import pytest
from app.domain.errors import DomainError
from app.domain.money import Money
from app.domain.planning.enums import RecurringFrequency
from app.domain.planning.policies import advance_due, progress_percent, recurring_equivalents


def test_monthly_recurrence_clamps_month_end_without_drifting_local_time() -> None:
    due = datetime(2027, 1, 31, 14, 30, tzinfo=UTC)
    assert advance_due(due, RecurringFrequency.MONTHLY, "UTC") == datetime(
        2027, 2, 28, 14, 30, tzinfo=UTC
    )


def test_monthly_recurrence_preserves_wall_clock_across_dst() -> None:
    due = datetime(2027, 2, 14, 14, 0, tzinfo=UTC)  # 09:00 New York
    advanced = advance_due(due, RecurringFrequency.MONTHLY, "America/New_York")
    assert advanced == datetime(2027, 3, 14, 13, 0, tzinfo=UTC)  # still 09:00 local


@pytest.mark.parametrize(
    ("frequency", "monthly", "annual"),
    [
        (RecurringFrequency.WEEKLY, "43.3333", "520.0000"),
        (RecurringFrequency.MONTHLY, "10.0000", "120.0000"),
        (RecurringFrequency.QUARTERLY, "3.3333", "40.0000"),
        (RecurringFrequency.YEARLY, "0.8333", "10.0000"),
    ],
)
def test_recurring_equivalents_use_decimal_bankers_rounding(
    frequency: RecurringFrequency, monthly: str, annual: str
) -> None:
    actual_monthly, actual_annual = recurring_equivalents(Money.of("10", "MAD"), frequency)
    assert actual_monthly.amount == Decimal(monthly)
    assert actual_annual.amount == Decimal(annual)


def test_goal_progress_is_capped_and_currency_safe() -> None:
    assert progress_percent(Money.of("125", "MAD"), Money.of("100", "MAD")) == Decimal("100.00")
    with pytest.raises(DomainError) as raised:
        progress_percent(Money.of("10", "EUR"), Money.of("100", "MAD"))
    assert raised.value.code == "CURRENCY_MISMATCH"
