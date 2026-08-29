from __future__ import annotations

from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Header, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.debts import (
    RefundCreateRequest,
    RefundResponse,
    SharedExpenseShareCreateRequest,
    SharedExpenseShareListResponse,
    SharedExpenseShareResponse,
    SharedExpenseShareUpdateRequest,
)
from app.application.idempotency import (
    FINANCIAL_IDEMPOTENCY_TTL,
    OperationResponse,
    execute_idempotent,
)
from app.application.sharing import SharingService
from app.domain.errors import DomainError

transaction_sharing_router = APIRouter(prefix="/transactions")
shares_router = APIRouter(prefix="/shared-expense-shares")


@transaction_sharing_router.post(
    "/{transaction_id}/shares",
    status_code=status.HTTP_201_CREATED,
    response_model=SharedExpenseShareResponse,
)
async def create_share(
    transaction_id: UUID,
    payload: SharedExpenseShareCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    _require_operation_id(payload.client_operation_id, idempotency_key)

    async def operation(value: AsyncSession) -> OperationResponse:
        share = await SharingService(value).create_share_in_transaction(
            transaction_id=transaction_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
        )
        return OperationResponse(
            201,
            cast(
                dict[str, object],
                SharedExpenseShareResponse.from_domain(share).model_dump(mode="json"),
            ),
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"shared-expenses.create:{transaction_id}",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
        ttl=FINANCIAL_IDEMPOTENCY_TTL,
    )
    return _response(result.status_code, result.body, result.replayed)


@transaction_sharing_router.get(
    "/{transaction_id}/shares", response_model=SharedExpenseShareListResponse
)
async def list_shares(
    transaction_id: UUID, principal: CurrentPrincipal, session: DatabaseSession
) -> SharedExpenseShareListResponse:
    values = await SharingService(session).list_shares(
        transaction_id=transaction_id, user_id=principal.user.id
    )
    return SharedExpenseShareListResponse(
        items=[SharedExpenseShareResponse.from_domain(value) for value in values]
    )


@shares_router.patch("/{share_id}", response_model=SharedExpenseShareResponse)
async def update_share(
    share_id: UUID,
    payload: SharedExpenseShareUpdateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(value: AsyncSession) -> OperationResponse:
        share = await SharingService(value).update_share_in_transaction(
            share_id=share_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        return OperationResponse(
            200,
            cast(
                dict[str, object],
                SharedExpenseShareResponse.from_domain(share).model_dump(mode="json"),
            ),
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"shared-expenses.update:{share_id}",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
        ttl=FINANCIAL_IDEMPOTENCY_TTL,
    )
    return _response(result.status_code, result.body, result.replayed)


@transaction_sharing_router.post(
    "/{transaction_id}/refund", status_code=status.HTTP_201_CREATED, response_model=RefundResponse
)
async def create_refund(
    transaction_id: UUID,
    payload: RefundCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    _require_operation_id(payload.client_operation_id, idempotency_key)

    async def operation(value: AsyncSession) -> OperationResponse:
        refund = await SharingService(value).refund_in_transaction(
            transaction_id=transaction_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
        )
        return OperationResponse(
            201, cast(dict[str, object], RefundResponse.from_domain(refund).model_dump(mode="json"))
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"refunds.create:{transaction_id}",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
        ttl=FINANCIAL_IDEMPOTENCY_TTL,
    )
    return _response(result.status_code, result.body, result.replayed)


def _require_operation_id(client_operation_id: UUID, idempotency_key: UUID) -> None:
    if client_operation_id != idempotency_key:
        raise DomainError(
            "OPERATION_ID_MISMATCH", "Client operation ID must match the Idempotency-Key header."
        )


def _response(status_code: int, body: dict[str, object], replayed: bool) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content=body,
        headers={"Idempotency-Replayed": str(replayed).lower()},
    )
