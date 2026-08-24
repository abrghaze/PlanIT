import pytest
from app.api.schemas.money import MoneyPayload
from app.domain.errors import DomainError
from pydantic import ValidationError


def test_money_payload_normalizes_through_domain_value() -> None:
    payload = MoneyPayload(amount="12.5", currency="mad")

    assert payload.to_domain().to_api() == "12.5000"
    assert MoneyPayload.from_domain(payload.to_domain()).model_dump() == {
        "amount": "12.5000",
        "currency": "MAD",
    }


@pytest.mark.parametrize("amount", [12.5, 12, None])
def test_money_payload_rejects_non_string_json_amounts(amount: object) -> None:
    with pytest.raises(ValidationError):
        MoneyPayload.model_validate({"amount": amount, "currency": "MAD"})


def test_money_payload_preserves_precision_rule() -> None:
    with pytest.raises(ValidationError) as error:
        MoneyPayload(amount="1.00001", currency="MAD")

    assert "four fractional digits" in str(error.value)


def test_domain_money_still_exposes_machine_readable_error() -> None:
    with pytest.raises(DomainError) as error:
        MoneyPayload.model_construct(amount="bad", currency="MAD").to_domain()

    assert error.value.code == "INVALID_AMOUNT"
