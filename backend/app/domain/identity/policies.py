from __future__ import annotations

from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from email_validator import EmailNotValidError, validate_email

from app.domain.errors import DomainError
from app.domain.money import Money


def normalize_email(value: str) -> tuple[str, str]:
    try:
        validated = validate_email(value.strip(), check_deliverability=False)
    except EmailNotValidError as exc:
        raise DomainError("INVALID_EMAIL", "Enter a valid email address.") from exc
    canonical = validated.normalized
    return canonical, canonical.casefold()


def normalize_display_name(value: str) -> str:
    normalized = " ".join(value.strip().split())
    if not normalized:
        raise DomainError("INVALID_DISPLAY_NAME", "Display name cannot be blank.")
    if len(normalized) > 120:
        raise DomainError(
            "INVALID_DISPLAY_NAME",
            "Display name cannot exceed 120 characters.",
        )
    return normalized


def validate_password(value: str) -> None:
    if len(value) < 12:
        raise DomainError(
            "WEAK_PASSWORD",
            "Password must contain at least 12 characters.",
        )
    if len(value) > 128:
        raise DomainError(
            "INVALID_PASSWORD",
            "Password cannot exceed 128 characters.",
        )


def normalize_currency(value: str) -> str:
    return Money.zero(value).currency


def validate_timezone(value: str) -> str:
    normalized = value.strip()
    try:
        ZoneInfo(normalized)
    except (ValueError, ZoneInfoNotFoundError) as exc:
        raise DomainError("INVALID_TIMEZONE", "Enter a valid IANA timezone.") from exc
    return normalized
