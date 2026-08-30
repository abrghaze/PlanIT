from __future__ import annotations

import calendar
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.domain.errors import DomainError
from app.domain.money import Money
from app.domain.planning.enums import RecurringFrequency


def normalize_name(value: str, *, field: str = "name") -> str:
    clean = " ".join(value.strip().split())
    if not 1 <= len(clean) <= 160:
        raise DomainError(
            "INVALID_PLANNING_NAME",
            f"{field.replace('_', ' ').title()} must contain 1 to 160 characters.",
        )
    return clean


def normalize_timezone(value: str) -> str:
    clean = value.strip()
    try:
        ZoneInfo(clean)
    except (ZoneInfoNotFoundError, ValueError) as exc:
        raise DomainError("INVALID_TIMEZONE", "Timezone must be a valid IANA timezone.") from exc
    return clean


def normalize_due(value: datetime) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        raise DomainError("INVALID_TIMESTAMP", "Next due time must include a timezone.")
    return value.astimezone(UTC)


def advance_due(value: datetime, frequency: RecurringFrequency, timezone: str) -> datetime:
    local = normalize_due(value).astimezone(ZoneInfo(normalize_timezone(timezone)))
    if frequency is RecurringFrequency.WEEKLY:
        return (local + timedelta(days=7)).astimezone(UTC)
    months = {
        RecurringFrequency.MONTHLY: 1,
        RecurringFrequency.QUARTERLY: 3,
        RecurringFrequency.YEARLY: 12,
    }[frequency]
    month_index = local.year * 12 + local.month - 1 + months
    year, zero_month = divmod(month_index, 12)
    month = zero_month + 1
    day = min(local.day, calendar.monthrange(year, month)[1])
    return local.replace(year=year, month=month, day=day).astimezone(UTC)


def recurring_equivalents(amount: Money, frequency: RecurringFrequency) -> tuple[Money, Money]:
    annual_factor = {
        RecurringFrequency.WEEKLY: Decimal(52),
        RecurringFrequency.MONTHLY: Decimal(12),
        RecurringFrequency.QUARTERLY: Decimal(4),
        RecurringFrequency.YEARLY: Decimal(1),
    }[frequency]
    annual = amount.multiply(annual_factor)
    return annual.multiply(Decimal(1) / Decimal(12)), annual


def progress_percent(progress: Money, target: Money) -> Decimal:
    if progress.currency != target.currency:
        raise DomainError("CURRENCY_MISMATCH", "Progress and target currencies must match.")
    if target.amount <= 0:
        raise DomainError("INVALID_GOAL_TARGET", "Goal target must be greater than zero.")
    return min(Decimal(100), progress.amount * Decimal(100) / target.amount).quantize(
        Decimal("0.01")
    )
