from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from decimal import ROUND_HALF_EVEN, Decimal
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.domain.analytics.enums import AnalyticsGranularity, AnalyticsPreset
from app.domain.errors import DomainError


@dataclass(frozen=True, slots=True)
class AnalyticsPeriod:
    preset: AnalyticsPreset
    local_from: date
    local_to: date
    utc_from: datetime
    utc_to: datetime
    timezone: str
    granularity: AnalyticsGranularity


@dataclass(frozen=True, slots=True)
class ExchangeRatePoint:
    base_currency: str
    quote_currency: str
    rate: Decimal
    effective_at: datetime


def resolve_period(
    *,
    preset: AnalyticsPreset,
    timezone: str,
    custom_from: date | None = None,
    custom_to: date | None = None,
    granularity: AnalyticsGranularity | None = None,
    now: datetime | None = None,
) -> AnalyticsPeriod:
    zone = _zone(timezone)
    current = (now or datetime.now(UTC)).astimezone(zone).date()
    if preset is AnalyticsPreset.TODAY:
        local_from = local_to = current
    elif preset is AnalyticsPreset.YESTERDAY:
        local_from = local_to = current - timedelta(days=1)
    elif preset is AnalyticsPreset.THIS_WEEK:
        local_from = current - timedelta(days=current.weekday())
        local_to = current
    elif preset is AnalyticsPreset.LAST_7_DAYS:
        local_from, local_to = current - timedelta(days=6), current
    elif preset is AnalyticsPreset.THIS_MONTH:
        local_from, local_to = current.replace(day=1), current
    elif preset is AnalyticsPreset.LAST_MONTH:
        this_month = current.replace(day=1)
        local_to = this_month - timedelta(days=1)
        local_from = local_to.replace(day=1)
    elif preset is AnalyticsPreset.LAST_30_DAYS:
        local_from, local_to = current - timedelta(days=29), current
    elif preset is AnalyticsPreset.THIS_YEAR:
        local_from, local_to = current.replace(month=1, day=1), current
    else:
        if custom_from is None or custom_to is None:
            raise DomainError(
                "ANALYTICS_RANGE_REQUIRED",
                "Custom analytics requires both from and to dates.",
            )
        local_from, local_to = custom_from, custom_to
    if local_from > local_to:
        raise DomainError("INVALID_ANALYTICS_RANGE", "Analytics start must not follow its end.")
    days = (local_to - local_from).days + 1
    if days > 366 * 5:
        raise DomainError(
            "ANALYTICS_RANGE_TOO_LARGE",
            "Analytics ranges may cover at most five years.",
        )
    resolved_granularity = granularity or _default_granularity(days)
    utc_from = datetime.combine(local_from, time.min, tzinfo=zone).astimezone(UTC)
    utc_to = datetime.combine(local_to + timedelta(days=1), time.min, tzinfo=zone).astimezone(UTC)
    return AnalyticsPeriod(
        preset=preset,
        local_from=local_from,
        local_to=local_to,
        utc_from=utc_from,
        utc_to=utc_to,
        timezone=timezone,
        granularity=resolved_granularity,
    )


def bucket_start(
    occurred_at: datetime,
    *,
    timezone: str,
    granularity: AnalyticsGranularity,
) -> date:
    local = occurred_at.astimezone(_zone(timezone)).date()
    if granularity is AnalyticsGranularity.WEEK:
        return local - timedelta(days=local.weekday())
    if granularity is AnalyticsGranularity.MONTH:
        return local.replace(day=1)
    return local


def convert_amount(
    amount: Decimal,
    *,
    source_currency: str,
    target_currency: str,
    at: datetime,
    rates: tuple[ExchangeRatePoint, ...],
) -> Decimal | None:
    if source_currency == target_currency:
        return amount.quantize(Decimal("0.0001"), rounding=ROUND_HALF_EVEN)
    candidates = [
        point
        for point in rates
        if point.effective_at <= at
        and {
            point.base_currency,
            point.quote_currency,
        }
        == {source_currency, target_currency}
    ]
    if not candidates:
        return None
    point = max(candidates, key=lambda value: value.effective_at)
    converted = (
        amount * point.rate if point.base_currency == source_currency else amount / point.rate
    )
    return converted.quantize(Decimal("0.0001"), rounding=ROUND_HALF_EVEN)


def normalized_package_quantity(
    size_value: Decimal | None,
    size_unit: str | None,
) -> tuple[Decimal, str] | None:
    if size_value is None or size_unit is None:
        return None
    if size_unit == "KG":
        return size_value * Decimal("1000"), "G"
    if size_unit == "L":
        return size_value * Decimal("1000"), "ML"
    return size_value, size_unit


def _default_granularity(days: int) -> AnalyticsGranularity:
    if days <= 45:
        return AnalyticsGranularity.DAY
    if days <= 270:
        return AnalyticsGranularity.WEEK
    return AnalyticsGranularity.MONTH


def _zone(value: str) -> ZoneInfo:
    try:
        return ZoneInfo(value)
    except ZoneInfoNotFoundError as exc:
        raise DomainError("INVALID_TIMEZONE", "Timezone must be a valid IANA name.") from exc
