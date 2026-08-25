from __future__ import annotations

from collections.abc import Collection

from app.domain.errors import DomainError
from app.domain.ledger.enums import AccountStatus
from app.domain.money import Money


def normalize_account_name(value: str) -> str:
    normalized = " ".join(value.strip().split())
    if not normalized:
        raise DomainError("INVALID_ACCOUNT_NAME", "Account name cannot be blank.")
    if len(normalized) > 120:
        raise DomainError(
            "INVALID_ACCOUNT_NAME",
            "Account name cannot exceed 120 characters.",
        )
    return normalized


def validate_negative_policy(opening_balance: Money, *, allow_negative: bool) -> None:
    if not allow_negative and opening_balance.amount < 0:
        raise DomainError(
            "NEGATIVE_BALANCE_NOT_ALLOWED",
            "This account does not allow a negative balance.",
        )


def validate_account_edit(
    *,
    current_status: AccountStatus,
    requested_status: AccountStatus,
    changed_fields: Collection[str],
) -> None:
    if current_status is AccountStatus.ACTIVE:
        return

    if changed_fields != {"status"}:
        raise DomainError(
            "ACCOUNT_READ_ONLY",
            "Archived and closed accounts must be restored before editing.",
        )

    allowed_target = (
        requested_status in {AccountStatus.ACTIVE, AccountStatus.CLOSED}
        if current_status is AccountStatus.ARCHIVED
        else requested_status is AccountStatus.ACTIVE
    )
    if not allowed_target:
        raise DomainError(
            "ACCOUNT_READ_ONLY",
            "The requested account lifecycle transition is not allowed.",
        )


def require_financial_fields_mutable(*, has_posted_activity: bool) -> None:
    if has_posted_activity:
        raise DomainError(
            "ACCOUNT_HAS_ACTIVITY",
            "Opening balance and currency cannot change after financial activity is posted.",
        )
