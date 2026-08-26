from __future__ import annotations

from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Header, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.corrections import (
    ReallocationCommitRequest,
    ReallocationPreviewRequest,
    ReallocationPreviewResponse,
    ReallocationResponse,
    ReconciliationCommitRequest,
    ReconciliationPreviewRequest,
    ReconciliationPreviewResponse,
    ReconciliationResponse,
)
from app.application.corrections import CorrectionService
from app.application.idempotency import (
    FINANCIAL_IDEMPOTENCY_TTL,
    OperationResponse,
    execute_idempotent,
)
from app.domain.errors import DomainError

router = APIRouter()


@router.post(
    "/accounts/{account_id}/reconciliations/preview",
    response_model=ReconciliationPreviewResponse,
)
async def preview_reconciliation(
    account_id: UUID,
    payload: ReconciliationPreviewRequest,
    principal: CurrentPrincipal,
    session: DatabaseSession,
) -> ReconciliationPreviewResponse:
    preview = await CorrectionService(session).preview_reconciliation(
        user_id=principal.user.id,
        command=payload.to_command(account_id),
    )
    return ReconciliationPreviewResponse.from_domain(preview)


@router.post(
    "/accounts/{account_id}/reconciliations/commit",
    status_code=status.HTTP_201_CREATED,
    response_model=ReconciliationResponse,
)
async def commit_reconciliation(
    account_id: UUID,
    payload: ReconciliationCommitRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    _require_operation_id(payload.client_operation_id, idempotency_key)

    async def operation(_session: AsyncSession) -> OperationResponse:
        value = await CorrectionService(_session).commit_reconciliation_in_transaction(
            user_id=principal.user.id,
            command=payload.to_commit_command(account_id),
            request_id=str(request.state.request_id),
        )
        body = ReconciliationResponse.from_domain(value).model_dump(mode="json")
        return OperationResponse(
            status_code=status.HTTP_201_CREATED,
            body=cast(dict[str, object], body),
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"accounts.reconciliations.commit:{account_id}",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
        ttl=FINANCIAL_IDEMPOTENCY_TTL,
    )
    return _json_response(result.status_code, result.body, replayed=result.replayed)


@router.post("/reallocations/preview", response_model=ReallocationPreviewResponse)
async def preview_reallocation(
    payload: ReallocationPreviewRequest,
    principal: CurrentPrincipal,
    session: DatabaseSession,
) -> ReallocationPreviewResponse:
    preview = await CorrectionService(session).preview_reallocation(
        user_id=principal.user.id,
        command=payload.to_command(),
    )
    return ReallocationPreviewResponse.from_domain(preview)


@router.post(
    "/reallocations/commit",
    status_code=status.HTTP_201_CREATED,
    response_model=ReallocationResponse,
)
async def commit_reallocation(
    payload: ReallocationCommitRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    _require_operation_id(payload.client_operation_id, idempotency_key)

    async def operation(_session: AsyncSession) -> OperationResponse:
        value = await CorrectionService(_session).commit_reallocation_in_transaction(
            user_id=principal.user.id,
            command=payload.to_commit_command(),
            request_id=str(request.state.request_id),
        )
        body = ReallocationResponse.from_domain(value).model_dump(mode="json")
        return OperationResponse(
            status_code=status.HTTP_201_CREATED,
            body=cast(dict[str, object], body),
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="reallocations.commit",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
        ttl=FINANCIAL_IDEMPOTENCY_TTL,
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
