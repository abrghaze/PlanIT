from __future__ import annotations

from typing import Annotated, cast

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.auth import AuthService
from app.core.config import Settings
from app.db.session import get_db_session
from app.domain.errors import DomainError
from app.domain.identity.entities import AuthenticatedPrincipal

_bearer = HTTPBearer(auto_error=False)

DatabaseSession = Annotated[AsyncSession, Depends(get_db_session)]


def get_app_settings(request: Request) -> Settings:
    return cast(Settings, request.app.state.settings)


AppSettings = Annotated[Settings, Depends(get_app_settings)]


async def get_current_principal(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
    session: DatabaseSession,
    settings: AppSettings,
) -> AuthenticatedPrincipal:
    if credentials is None or credentials.scheme.casefold() != "bearer":
        raise DomainError(
            "INVALID_CREDENTIALS",
            "Authentication credentials are invalid or expired.",
        )
    return await AuthService(session, settings).authenticate_access_token(credentials.credentials)


CurrentPrincipal = Annotated[AuthenticatedPrincipal, Depends(get_current_principal)]
