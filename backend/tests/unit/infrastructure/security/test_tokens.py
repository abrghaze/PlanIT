from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from app.core.config import Settings
from app.domain.errors import DomainError
from app.infrastructure.security.tokens import TokenService


def _service() -> TokenService:
    return TokenService(
        Settings(
            app_env="test",
            debug=False,
            access_token_secret="test-access-secret-with-at-least-32-characters",
            refresh_token_pepper="test-refresh-pepper-with-at-least-32-characters",
        )
    )


def test_access_token_round_trip_and_tamper_rejection() -> None:
    service = _service()
    user_id = uuid4()
    session_id = uuid4()

    token = service.issue_access_token(user_id=user_id, session_id=session_id)
    claims = service.decode_access_token(token.value)

    assert claims.user_id == user_id
    assert claims.session_id == session_id
    assert claims.expires_at == token.expires_at.replace(microsecond=0)

    header, payload, signature = token.value.split(".")
    replacement = "A" if signature[0] != "A" else "B"
    tampered = ".".join((header, payload, f"{replacement}{signature[1:]}"))
    with pytest.raises(DomainError) as error:
        service.decode_access_token(tampered)
    assert error.value.code == "INVALID_CREDENTIALS"


def test_non_canonical_signature_encoding_is_rejected() -> None:
    service = _service()
    token = service.issue_access_token(user_id=uuid4(), session_id=uuid4())
    header, payload, signature = token.value.split(".")
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    final_index = alphabet.index(signature[-1])

    assert final_index % 4 == 0
    non_canonical = ".".join((header, payload, f"{signature[:-1]}{alphabet[final_index + 1]}"))

    with pytest.raises(DomainError) as error:
        service.decode_access_token(non_canonical)
    assert error.value.code == "INVALID_CREDENTIALS"


def test_expired_access_token_is_rejected() -> None:
    service = _service()
    token = service.issue_access_token(
        user_id=uuid4(),
        session_id=uuid4(),
        now=datetime.now(UTC) - timedelta(hours=1),
    )

    with pytest.raises(DomainError) as error:
        service.decode_access_token(token.value)
    assert error.value.code == "INVALID_CREDENTIALS"


def test_refresh_tokens_are_opaque_and_hashed_deterministically() -> None:
    service = _service()

    token = service.issue_refresh_token()

    assert token.value != token.digest
    assert len(token.digest) == 64
    assert service.hash_refresh_token(token.value) == token.digest
    assert service.issue_refresh_token().digest != token.digest
