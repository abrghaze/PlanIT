from __future__ import annotations

from datetime import datetime
from typing import Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.application.auth import AuthResult
from app.domain.identity.entities import UserIdentity


class RegisterRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    email: str = Field(strict=True, min_length=3, max_length=320)
    password: str = Field(strict=True, min_length=1, max_length=128)
    display_name: str = Field(strict=True, min_length=1, max_length=120)
    base_currency: str = Field(strict=True, min_length=3, max_length=3)
    timezone: str = Field(strict=True, min_length=1, max_length=64)
    device_label: str | None = Field(default=None, strict=True, max_length=160)


class LoginRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    email: str = Field(strict=True, min_length=1, max_length=320)
    password: str = Field(strict=True, min_length=1, max_length=128)
    device_label: str | None = Field(default=None, strict=True, max_length=160)


class RefreshRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    refresh_token: str = Field(strict=True, min_length=32, max_length=512)


class LogoutRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    refresh_token: str = Field(strict=True, min_length=1, max_length=512)


class UserResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    email: str
    display_name: str
    base_currency: str
    timezone: str
    status: str
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, user: UserIdentity) -> Self:
        return cls(
            id=user.id,
            email=user.email,
            display_name=user.display_name,
            base_currency=user.base_currency,
            timezone=user.timezone,
            status=user.status,
            created_at=user.created_at,
            updated_at=user.updated_at,
        )


class AuthResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    token_type: str = "bearer"
    access_token: str
    refresh_token: str
    access_expires_at: datetime
    refresh_expires_at: datetime
    user: UserResponse

    @classmethod
    def from_result(cls, result: AuthResult) -> Self:
        return cls(
            access_token=result.access_token,
            refresh_token=result.refresh_token,
            access_expires_at=result.access_expires_at,
            refresh_expires_at=result.refresh_expires_at,
            user=UserResponse.from_domain(result.user),
        )
