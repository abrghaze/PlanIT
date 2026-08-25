from __future__ import annotations

from datetime import datetime
from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Header, Query, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.accounts import (
    AccountBalanceResponse,
    AccountCreateRequest,
    AccountListResponse,
    AccountResponse,
    AccountUpdateRequest,
)
from app.application.accounts import AccountService
from app.application.idempotency import OperationResponse, execute_idempotent
from app.domain.ledger.enums import AccountStatus

router = APIRouter(prefix="/accounts")


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_account(
    payload: AccountCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(_session: AsyncSession) -> OperationResponse:
        account = await AccountService(_session).create_in_transaction(
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        body = AccountResponse.from_domain(account).model_dump(mode="json")
        return OperationResponse(
            status_code=status.HTTP_201_CREATED, body=cast(dict[str, object], body)
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="accounts.create",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
    )
    return JSONResponse(
        status_code=result.status_code,
        content=result.body,
        headers={"Idempotency-Replayed": str(result.replayed).lower()},
    )


@router.get("", response_model=AccountListResponse)
async def list_accounts(
    principal: CurrentPrincipal,
    session: DatabaseSession,
    account_statuses: Annotated[list[AccountStatus] | None, Query(alias="status")] = None,
    as_of: datetime | None = None,
) -> AccountListResponse:
    accounts = await AccountService(session).list_accounts(
        user_id=principal.user.id,
        statuses=set(account_statuses) if account_statuses else None,
        as_of=as_of,
    )
    return AccountListResponse(items=[AccountResponse.from_domain(item) for item in accounts])


@router.get("/{account_id}", response_model=AccountResponse)
async def get_account(
    account_id: UUID,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    as_of: datetime | None = None,
) -> AccountResponse:
    account = await AccountService(session).get_account(
        account_id=account_id,
        user_id=principal.user.id,
        as_of=as_of,
    )
    return AccountResponse.from_domain(account)


@router.get("/{account_id}/balance", response_model=AccountBalanceResponse)
async def get_account_balance(
    account_id: UUID,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    as_of: datetime | None = None,
) -> AccountBalanceResponse:
    account = await AccountService(session).get_account(
        account_id=account_id,
        user_id=principal.user.id,
        as_of=as_of,
    )
    return AccountBalanceResponse.from_domain(account)


@router.patch("/{account_id}", response_model=AccountResponse)
async def update_account(
    account_id: UUID,
    payload: AccountUpdateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
) -> AccountResponse:
    account = await AccountService(session).update(
        account_id=account_id,
        user_id=principal.user.id,
        command=payload.to_command(),
        request_id=str(request.state.request_id),
    )
    return AccountResponse.from_domain(account)
