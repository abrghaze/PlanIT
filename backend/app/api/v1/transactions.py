from __future__ import annotations

from datetime import datetime
from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Header, Query, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.transactions import (
    TransactionCreateRequest,
    TransactionListResponse,
    TransactionPostRequest,
    TransactionResponse,
    TransactionReversalResponse,
    TransactionReverseRequest,
    TransactionUpdateRequest,
)
from app.application.idempotency import OperationResponse, execute_idempotent
from app.application.transactions import TransactionService
from app.domain.errors import DomainError
from app.domain.ledger.enums import TransactionKind, TransactionStatus

router = APIRouter(prefix="/transactions")


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_transaction(
    payload: TransactionCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    _require_operation_id(payload.client_operation_id, idempotency_key)

    async def operation(_session: AsyncSession) -> OperationResponse:
        value = await TransactionService(_session).create_draft_in_transaction(
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
        )
        body = TransactionResponse.from_domain(value).model_dump(mode="json")
        return OperationResponse(status_code=201, body=cast(dict[str, object], body))

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="transactions.create",
        key=idempotency_key,
        request_payload=cast(
            dict[str, object],
            payload.model_dump(mode="json", exclude_unset=True),
        ),
        operation=operation,
    )
    return _json_response(result.status_code, result.body, replayed=result.replayed)


@router.get("", response_model=TransactionListResponse)
async def list_transactions(
    principal: CurrentPrincipal,
    session: DatabaseSession,
    transaction_statuses: Annotated[
        list[TransactionStatus] | None,
        Query(alias="status"),
    ] = None,
    transaction_types: Annotated[
        list[TransactionKind] | None,
        Query(alias="type"),
    ] = None,
    account_id: UUID | None = None,
    category_id: UUID | None = None,
    tag_id: UUID | None = None,
    occurred_from: datetime | None = None,
    occurred_to: datetime | None = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> TransactionListResponse:
    values = await TransactionService(session).list_transactions(
        user_id=principal.user.id,
        statuses=set(transaction_statuses) if transaction_statuses else None,
        kinds=set(transaction_types) if transaction_types else None,
        account_id=account_id,
        category_id=category_id,
        tag_id=tag_id,
        occurred_from=occurred_from,
        occurred_to=occurred_to,
        limit=limit,
        offset=offset,
    )
    return TransactionListResponse(
        items=[TransactionResponse.from_domain(value) for value in values]
    )


@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: UUID,
    principal: CurrentPrincipal,
    session: DatabaseSession,
) -> TransactionResponse:
    value = await TransactionService(session).get_transaction(
        transaction_id=transaction_id,
        user_id=principal.user.id,
    )
    return TransactionResponse.from_domain(value)


@router.patch("/{transaction_id}")
async def update_transaction(
    transaction_id: UUID,
    payload: TransactionUpdateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(_session: AsyncSession) -> OperationResponse:
        value = await TransactionService(_session).update_draft_in_transaction(
            transaction_id=transaction_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        body = TransactionResponse.from_domain(value).model_dump(mode="json")
        return OperationResponse(status_code=200, body=cast(dict[str, object], body))

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"transactions.update:{transaction_id}",
        key=idempotency_key,
        request_payload=cast(
            dict[str, object],
            payload.model_dump(mode="json", exclude_unset=True),
        ),
        operation=operation,
    )
    return _json_response(result.status_code, result.body, replayed=result.replayed)


@router.post("/{transaction_id}/post")
async def post_transaction(
    transaction_id: UUID,
    payload: TransactionPostRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(_session: AsyncSession) -> OperationResponse:
        value = await TransactionService(_session).post_in_transaction(
            transaction_id=transaction_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        body = TransactionResponse.from_domain(value).model_dump(mode="json")
        return OperationResponse(status_code=200, body=cast(dict[str, object], body))

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"transactions.post:{transaction_id}",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
    )
    return _json_response(result.status_code, result.body, replayed=result.replayed)


@router.post("/{transaction_id}/reverse", status_code=status.HTTP_201_CREATED)
async def reverse_transaction(
    transaction_id: UUID,
    payload: TransactionReverseRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    _require_operation_id(payload.client_operation_id, idempotency_key)

    async def operation(_session: AsyncSession) -> OperationResponse:
        value = await TransactionService(_session).reverse_in_transaction(
            transaction_id=transaction_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
        )
        body = TransactionReversalResponse.from_domain(value).model_dump(mode="json")
        return OperationResponse(status_code=201, body=cast(dict[str, object], body))

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"transactions.reverse:{transaction_id}",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
    )
    return _json_response(result.status_code, result.body, replayed=result.replayed)


def _require_operation_id(client_operation_id: UUID, idempotency_key: UUID) -> None:
    if client_operation_id != idempotency_key:
        raise DomainError(
            "OPERATION_ID_MISMATCH",
            "Client operation ID must match the Idempotency-Key header.",
        )


def _json_response(
    status_code: int,
    body: dict[str, object],
    *,
    replayed: bool,
) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content=body,
        headers={"Idempotency-Replayed": str(replayed).lower()},
    )
