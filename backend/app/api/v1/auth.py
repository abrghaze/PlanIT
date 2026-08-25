from __future__ import annotations

from fastapi import APIRouter, Request, Response, status

from app.api.dependencies import AppSettings, CurrentPrincipal, DatabaseSession
from app.api.schemas.auth import (
    AuthResponse,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    UserResponse,
)
from app.application.auth import AuthService

router = APIRouter(prefix="/auth")


def _request_id(request: Request) -> str:
    return str(request.state.request_id)


def _client_address(request: Request) -> str:
    return request.client.host if request.client is not None else "unknown"


def _prevent_token_caching(response: Response) -> None:
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(
    payload: RegisterRequest,
    request: Request,
    response: Response,
    session: DatabaseSession,
    settings: AppSettings,
) -> AuthResponse:
    result = await AuthService(session, settings).register(
        email=payload.email,
        password=payload.password,
        display_name=payload.display_name,
        base_currency=payload.base_currency,
        timezone=payload.timezone,
        device_label=payload.device_label,
        request_id=_request_id(request),
    )
    _prevent_token_caching(response)
    return AuthResponse.from_result(result)


@router.post("/login", response_model=AuthResponse)
async def login(
    payload: LoginRequest,
    request: Request,
    response: Response,
    session: DatabaseSession,
    settings: AppSettings,
) -> AuthResponse:
    result = await AuthService(session, settings).login(
        email=payload.email,
        password=payload.password,
        device_label=payload.device_label,
        client_address=_client_address(request),
        request_id=_request_id(request),
    )
    _prevent_token_caching(response)
    return AuthResponse.from_result(result)


@router.post("/refresh", response_model=AuthResponse)
async def refresh(
    payload: RefreshRequest,
    request: Request,
    response: Response,
    session: DatabaseSession,
    settings: AppSettings,
) -> AuthResponse:
    result = await AuthService(session, settings).refresh(
        raw_refresh_token=payload.refresh_token,
        request_id=_request_id(request),
    )
    _prevent_token_caching(response)
    return AuthResponse.from_result(result)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    payload: LogoutRequest,
    request: Request,
    session: DatabaseSession,
    settings: AppSettings,
) -> Response:
    await AuthService(session, settings).logout(
        raw_refresh_token=payload.refresh_token,
        request_id=_request_id(request),
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT, headers={"Cache-Control": "no-store"})


@router.get("/me", response_model=UserResponse)
async def me(principal: CurrentPrincipal) -> UserResponse:
    return UserResponse.from_domain(principal.user)
