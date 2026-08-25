from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app.domain.errors import DomainError
from app.domain.ledger.enums import AccountEffect, TransactionKind, TransactionStatus

_CORE_KINDS = {TransactionKind.EXPENSE, TransactionKind.INCOME}


def require_core_kind(kind: TransactionKind) -> None:
    if kind not in _CORE_KINDS:
        raise DomainError(
            "UNSUPPORTED_TRANSACTION_TYPE",
            "Milestone 2 supports expense and income transactions only.",
        )


def effect_for(kind: TransactionKind) -> AccountEffect:
    require_core_kind(kind)
    return AccountEffect.OUTFLOW if kind is TransactionKind.EXPENSE else AccountEffect.INFLOW


def normalize_timestamp(value: datetime) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        raise DomainError("INVALID_TIMESTAMP", "Transaction time must include a timezone.")
    return value.astimezone(UTC)


def require_not_future(value: datetime, *, now: datetime | None = None) -> None:
    current = now or datetime.now(UTC)
    if value > current + timedelta(minutes=5):
        raise DomainError(
            "TRANSACTION_IN_FUTURE",
            "Posted transactions cannot be more than five minutes in the future.",
        )


def normalize_optional_text(
    value: str | None,
    *,
    field: str,
    maximum: int,
) -> str | None:
    if value is None:
        return None
    normalized = " ".join(value.strip().split()) if field == "counterparty" else value.strip()
    if not normalized:
        return None
    if len(normalized) > maximum:
        raise DomainError(
            "INVALID_TRANSACTION_TEXT",
            f"{field.replace('_', ' ').title()} cannot exceed {maximum} characters.",
            details={"field": field, "max_length": maximum},
        )
    return normalized


def require_draft(status: TransactionStatus) -> None:
    if status is not TransactionStatus.DRAFT:
        raise DomainError(
            "TRANSACTION_NOT_DRAFT",
            "Only draft transactions can be edited or posted.",
        )


def require_reversible(status: TransactionStatus, kind: TransactionKind) -> None:
    if kind is TransactionKind.REVERSAL:
        raise DomainError(
            "REVERSAL_OF_REVERSAL_NOT_ALLOWED",
            "A reversal cannot target another reversal.",
        )
    if status is TransactionStatus.REVERSED:
        raise DomainError(
            "TRANSACTION_ALREADY_REVERSED",
            "This transaction has already been reversed.",
        )
    if status is not TransactionStatus.POSTED:
        raise DomainError(
            "TRANSACTION_NOT_POSTED",
            "Only a posted transaction can be reversed.",
        )
