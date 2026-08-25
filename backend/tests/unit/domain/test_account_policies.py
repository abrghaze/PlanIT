import pytest
from app.domain.accounts.policies import (
    normalize_account_name,
    require_financial_fields_mutable,
    validate_account_edit,
    validate_negative_policy,
)
from app.domain.errors import DomainError
from app.domain.ledger.enums import AccountStatus
from app.domain.money import Money


def test_account_name_and_negative_policy() -> None:
    assert normalize_account_name("  Daily   cash  ") == "Daily cash"
    validate_negative_policy(Money.of("-1.0000", "MAD"), allow_negative=True)

    with pytest.raises(DomainError) as error:
        validate_negative_policy(Money.of("-1.0000", "MAD"), allow_negative=False)
    assert error.value.code == "NEGATIVE_BALANCE_NOT_ALLOWED"


def test_archived_and_closed_accounts_only_accept_lifecycle_actions() -> None:
    validate_account_edit(
        current_status=AccountStatus.ARCHIVED,
        requested_status=AccountStatus.ACTIVE,
        changed_fields={"status"},
    )
    validate_account_edit(
        current_status=AccountStatus.CLOSED,
        requested_status=AccountStatus.ACTIVE,
        changed_fields={"status"},
    )

    with pytest.raises(DomainError) as error:
        validate_account_edit(
            current_status=AccountStatus.ARCHIVED,
            requested_status=AccountStatus.ARCHIVED,
            changed_fields={"name"},
        )
    assert error.value.code == "ACCOUNT_READ_ONLY"


def test_financial_fields_lock_after_posting() -> None:
    with pytest.raises(DomainError) as error:
        require_financial_fields_mutable(has_posted_activity=True)
    assert error.value.code == "ACCOUNT_HAS_ACTIVITY"
