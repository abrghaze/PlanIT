from __future__ import annotations

import hashlib
import hmac
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import cast
from uuid import UUID, uuid4

import jwt
from jwt import InvalidTokenError

from app.core.config import Settings
from app.domain.errors import DomainError


@dataclass(frozen=True, slots=True)
class AccessToken:
    value: str
    expires_at: datetime


@dataclass(frozen=True, slots=True)
class AccessTokenClaims:
    user_id: UUID
    session_id: UUID
    expires_at: datetime


@dataclass(frozen=True, slots=True)
class RefreshToken:
    value: str
    digest: str
    expires_at: datetime


class TokenService:
    def __init__(self, settings: Settings) -> None:
        self._access_secret = settings.access_token_secret.get_secret_value()
        self._refresh_pepper = settings.refresh_token_pepper.get_secret_value().encode("utf-8")
        self._access_ttl = timedelta(minutes=settings.access_token_ttl_minutes)
        self._refresh_ttl = timedelta(days=settings.refresh_token_ttl_days)
        self._issuer = settings.jwt_issuer
        self._audience = settings.jwt_audience

    def issue_access_token(
        self,
        *,
        user_id: UUID,
        session_id: UUID,
        now: datetime | None = None,
    ) -> AccessToken:
        issued_at = (now or datetime.now(UTC)).astimezone(UTC)
        expires_at = issued_at + self._access_ttl
        payload = {
            "sub": str(user_id),
            "sid": str(session_id),
            "jti": str(uuid4()),
            "iss": self._issuer,
            "aud": self._audience,
            "iat": issued_at,
            "exp": expires_at,
        }
        return AccessToken(
            value=jwt.encode(payload, self._access_secret, algorithm="HS256"),
            expires_at=expires_at,
        )

    def decode_access_token(self, token: str) -> AccessTokenClaims:
        try:
            payload = jwt.decode(
                token,
                self._access_secret,
                algorithms=["HS256"],
                audience=self._audience,
                issuer=self._issuer,
                options={"require": ["sub", "sid", "jti", "iss", "aud", "iat", "exp"]},
            )
            user_id = UUID(cast(str, payload["sub"]))
            session_id = UUID(cast(str, payload["sid"]))
            expires_at = datetime.fromtimestamp(cast(int, payload["exp"]), tz=UTC)
        except (InvalidTokenError, KeyError, TypeError, ValueError) as exc:
            raise DomainError(
                "INVALID_CREDENTIALS",
                "Authentication credentials are invalid or expired.",
            ) from exc
        return AccessTokenClaims(
            user_id=user_id,
            session_id=session_id,
            expires_at=expires_at,
        )

    def issue_refresh_token(self, *, now: datetime | None = None) -> RefreshToken:
        issued_at = (now or datetime.now(UTC)).astimezone(UTC)
        value = secrets.token_urlsafe(48)
        return RefreshToken(
            value=value,
            digest=self.hash_refresh_token(value),
            expires_at=issued_at + self._refresh_ttl,
        )

    def hash_refresh_token(self, token: str) -> str:
        return hmac.new(
            self._refresh_pepper,
            token.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()

    def hash_private_identifier(self, value: str) -> str:
        return hmac.new(
            self._refresh_pepper,
            value.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
