import pytest
from app.domain.errors import DomainError
from app.domain.identity.policies import (
    normalize_display_name,
    normalize_email,
    validate_password,
    validate_timezone,
)


def test_identity_values_are_normalized_and_validated() -> None:
    canonical, normalized = normalize_email("  Person@Example.COM ")

    assert canonical == "Person@example.com"
    assert normalized == "person@example.com"
    assert normalize_display_name("  Ada   Lovelace ") == "Ada Lovelace"
    assert validate_timezone("Africa/Casablanca") == "Africa/Casablanca"
    validate_password("A sufficiently long password 9!")


@pytest.mark.parametrize(
    "password",
    [
        "lowercase only password 9!",
        "UPPERCASE ONLY PASSWORD 9!",
        "No number in this password!",
        "No symbol in this password 9",
    ],
)
def test_password_requires_upper_lower_number_and_symbol(password: str) -> None:
    with pytest.raises(DomainError) as error:
        validate_password(password)
    assert error.value.code == "WEAK_PASSWORD"


@pytest.mark.parametrize(
    ("call", "code"),
    [
        (lambda: normalize_email("not-an-email"), "INVALID_EMAIL"),
        (lambda: normalize_display_name("   "), "INVALID_DISPLAY_NAME"),
        (lambda: validate_password("too short"), "WEAK_PASSWORD"),
        (lambda: validate_timezone("Mars/Olympus_Mons"), "INVALID_TIMEZONE"),
    ],
)
def test_invalid_identity_values_have_stable_domain_errors(call, code: str) -> None:
    with pytest.raises(DomainError) as error:
        call()
    assert error.value.code == code
