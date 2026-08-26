from __future__ import annotations

from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Header, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.transfers import (
    TransferCommitRequest,
    TransferPreviewRequest,
    TransferPreviewResponse,
    TransferResponse,
)
from app.application.idempotency import (
    FINANCIAL_IDEMPOTENCY_TTL,
    OperationResponse,
    execute_idempotent,
)
from app.application.transfers import TransferService
from app.domain.errors import DomainError

router = APIRouter(prefix="/transfers")


@router.post("/preview", response_model=TransferPreviewResponse)
async def preview_transfer(
    payload: TransferPreviewRequest,
    principal: CurrentPrincipal,
    session: DatabaseSession,
) -> TransferPreviewResponse:
    preview = await TransferService(session).preview(
        user_id=principal.user.id,
        command=payload.to_command(),
    )
    return TransferPreviewResponse.from_domain(preview)


@router.post(
    "/commit",
    status_code=status.HTTP_201_CREATED,
    response_model=TransferResponse,
)
async def commit_transfer(
    payload: TransferCommitRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    _require_operation_id(payload.client_operation_id, idempotency_key)

    async def operation(_session: AsyncSession) -> OperationResponse:
        value = await TransferService(_session).commit_in_transaction(
            user_id=principal.user.id,
            command=payload.to_commit_command(),
            request_id=str(request.state.request_id),
        )
        body = TransferResponse.from_domain(value).model_dump(mode="json")
        return OperationResponse(
            status_code=status.HTTP_201_CREATED,
            body=cast(dict[str, object], body),
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="transfers.commit",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
        ttl=FINANCIAL_IDEMPOTENCY_TTL,
    )
    return JSONResponse(
        status_code=result.status_code,
        content=result.body,
        headers={"Idempotency-Replayed": str(result.replayed).lower()},
    )


@router.get("/{transfer_id}", response_model=TransferResponse)
async def get_transfer(
    transfer_id: UUID,
    principal: CurrentPrincipal,
    session: DatabaseSession,
) -> TransferResponse:
    value = await TransferService(session).get_transfer(
        transfer_id=transfer_id,
        user_id=principal.user.id,
    )
    return TransferResponse.from_domain(value)


def _require_operation_id(client_operation_id: UUID, idempotency_key: UUID) -> None:
    if client_operation_id != idempotency_key:
        raise DomainError(
            "OPERATION_ID_MISMATCH",
            "Client operation ID must match the Idempotency-Key header.",
        )
