from decimal import Decimal

import pytest
from app.domain.debts.enums import DebtDirection, DebtOriginType, DebtStatus
from app.domain.debts.policies import require_origin_direction, status_for
from app.domain.errors import DomainError


def test_debt_status_is_derived_from_payment_history() -> None:
    assert status_for(original=Decimal("100.0000"), paid=Decimal("0")) is DebtStatus.OPEN
    assert (
        status_for(original=Decimal("100.0000"), paid=Decimal("40.0000"))
        is DebtStatus.PARTIALLY_PAID
    )
    assert status_for(original=Decimal("100.0000"), paid=Decimal("100.0000")) is DebtStatus.SETTLED


def test_overpayment_and_invalid_origin_direction_are_rejected() -> None:
    with pytest.raises(DomainError, match="Payment exceeds") as overpayment:
        status_for(original=Decimal("100.0000"), paid=Decimal("100.0001"))
    assert overpayment.value.code == "DEBT_OVERPAYMENT"

    with pytest.raises(DomainError) as mismatch:
        require_origin_direction(
            origin=DebtOriginType.LEND_NOW,
            direction=DebtDirection.PAYABLE,
        )
    assert mismatch.value.code == "DEBT_DIRECTION_MISMATCH"
