from datetime import UTC, date, datetime
from decimal import Decimal

import pytest
from app.domain.analytics.enums import AnalyticsGranularity, AnalyticsPreset
from app.domain.analytics.policies import (
    ExchangeRatePoint,
    bucket_start,
    convert_amount,
    normalized_package_quantity,
    resolve_period,
)
from app.domain.errors import DomainError


def test_custom_period_respects_user_timezone_and_dst_boundaries() -> None:
    period = resolve_period(
        preset=AnalyticsPreset.CUSTOM,
        timezone="America/New_York",
        custom_from=date(2026, 3, 8),
        custom_to=date(2026, 3, 8),
    )

    assert period.utc_from == datetime(2026, 3, 8, 5, tzinfo=UTC)
    assert period.utc_to == datetime(2026, 3, 9, 4, tzinfo=UTC)
    assert period.granularity is AnalyticsGranularity.DAY
    assert bucket_start(
        datetime(2026, 3, 9, 3, 59, tzinfo=UTC),
        timezone="America/New_York",
        granularity=AnalyticsGranularity.DAY,
    ) == date(2026, 3, 8)


def test_historical_exchange_rate_uses_latest_effective_direct_or_inverse_rate() -> None:
    rates = (
        ExchangeRatePoint("EUR", "MAD", Decimal("10"), datetime(2026, 1, 1, tzinfo=UTC)),
        ExchangeRatePoint("EUR", "MAD", Decimal("11"), datetime(2026, 2, 1, tzinfo=UTC)),
    )

    assert convert_amount(
        Decimal("2"),
        source_currency="EUR",
        target_currency="MAD",
        at=datetime(2026, 1, 15, tzinfo=UTC),
        rates=rates,
    ) == Decimal("20.0000")
    assert convert_amount(
        Decimal("22"),
        source_currency="MAD",
        target_currency="EUR",
        at=datetime(2026, 2, 2, tzinfo=UTC),
        rates=rates,
    ) == Decimal("2.0000")
    assert (
        convert_amount(
            Decimal("1"),
            source_currency="USD",
            target_currency="MAD",
            at=datetime(2026, 2, 2, tzinfo=UTC),
            rates=rates,
        )
        is None
    )


def test_normalized_package_quantity_only_compares_compatible_units() -> None:
    assert normalized_package_quantity(Decimal("1.5"), "KG") == (Decimal("1500.0"), "G")
    assert normalized_package_quantity(Decimal("2"), "L") == (Decimal("2000"), "ML")
    assert normalized_package_quantity(Decimal("6"), "COUNT") == (Decimal("6"), "COUNT")
    assert normalized_package_quantity(None, "KG") is None


def test_custom_period_rejects_missing_or_reversed_dates() -> None:
    with pytest.raises(DomainError, match="both from and to"):
        resolve_period(
            preset=AnalyticsPreset.CUSTOM,
            timezone="UTC",
            custom_from=date(2026, 1, 1),
        )
    with pytest.raises(DomainError, match="must not follow"):
        resolve_period(
            preset=AnalyticsPreset.CUSTOM,
            timezone="UTC",
            custom_from=date(2026, 2, 1),
            custom_to=date(2026, 1, 1),
        )
