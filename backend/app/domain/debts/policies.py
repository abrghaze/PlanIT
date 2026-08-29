from __future__ import annotations

from decimal import Decimal

from app.domain.debts.enums import DebtDirection, DebtOriginType, DebtStatus
from app.domain.errors import DomainError


def require_origin_direction(*, origin: DebtOriginType, direction: DebtDirection) -> None:
    expected = {
        DebtOriginType.LEND_NOW: DebtDirection.RECEIVABLE,
        DebtOriginType.BORROW_NOW: DebtDirection.PAYABLE,
        DebtOriginType.SHARED_EXPENSE: DebtDirection.RECEIVABLE,
    }.get(origin)
    if expected is not None and direction is not expected:
        raise DomainError(
            "DEBT_DIRECTION_MISMATCH",
            f"{origin.value.replace('_', ' ').title()} requires a {expected.value.lower()}.",
        )


def remaining_amount(*, original: Decimal, paid: Decimal) -> Decimal:
    remaining = original - paid
    if remaining < 0:
        raise DomainError(
            "DEBT_OVERPAYMENT",
            "Payment exceeds the remaining debt.",
            details={"remaining_amount": format(max(original - paid, Decimal("0")), ".4f")},
        )
    return remaining


def status_for(*, original: Decimal, paid: Decimal) -> DebtStatus:
    remaining = remaining_amount(original=original, paid=paid)
    if remaining == 0:
        return DebtStatus.SETTLED
    if paid > 0:
        return DebtStatus.PARTIALLY_PAID
    return DebtStatus.OPEN
