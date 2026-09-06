from __future__ import annotations

from datetime import date, datetime
from typing import Annotated, Literal, cast
from uuid import UUID

from fastapi import APIRouter, Header, Query, Request, Response, status
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.privacy import (
    DeleteProfileRequest,
    RestoreBackupRequest,
    RestoreBackupResponse,
)
from app.application.idempotency import OperationResponse, execute_idempotent
from app.application.privacy import PrivacyService
from app.core.config import Settings
from app.infrastructure.storage import PrivateObjectStorage

router = APIRouter(prefix="/privacy")


def _attachment(content: bytes, *, media_type: str, filename: str) -> Response:
    return Response(
        content=content,
        media_type=media_type,
        headers={
            "Cache-Control": "no-store",
            "Content-Disposition": f'attachment; filename="{filename}"',
            "X-Content-Type-Options": "nosniff",
        },
    )


@router.get("/export.csv")
async def export_csv(
    principal: CurrentPrincipal,
    session: DatabaseSession,
    data_type: Annotated[Literal["transactions", "accounts"], Query()] = "transactions",
    date_from: date | None = None,
    date_to: date | None = None,
    as_of: datetime | None = None,
) -> Response:
    async with session.begin():
        await session.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
        service = PrivacyService(session)
        if data_type == "accounts":
            content = await service.accounts_csv(user_id=principal.user.id, as_of=as_of)
        else:
            content = await service.transactions_csv(
                user_id=principal.user.id,
                date_from=date_from,
                date_to=date_to,
            )
    today = datetime.now().date().isoformat()
    return _attachment(
        content,
        media_type="text/csv; charset=utf-8",
        filename=f"planit-{data_type}-{today}.csv",
    )


@router.get("/backup.json")
async def portable_backup(
    principal: CurrentPrincipal,
    session: DatabaseSession,
) -> Response:
    async with session.begin():
        await session.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
        content = await PrivacyService(session).portable_backup(user_id=principal.user.id)
    return _attachment(
        content,
        media_type="application/json",
        filename=f"planit-backup-{datetime.now().date().isoformat()}.json",
    )


@router.post("/restore", response_model=RestoreBackupResponse)
async def restore_portable_backup(
    payload: RestoreBackupRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(db: AsyncSession) -> OperationResponse:
        restored, ignored_receipts = await PrivacyService(
            db
        ).restore_portable_backup_in_transaction(
            user_id=principal.user.id,
            password=payload.password,
            document=payload.backup,
            request_id=str(request.state.request_id),
            operation_id=idempotency_key,
        )
        body = RestoreBackupResponse(
            restored_rows=restored,
            ignored_receipt_files=ignored_receipts,
        ).model_dump(mode="json")
        return OperationResponse(200, cast(dict[str, object], body))

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="privacy.restore",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
    )
    return JSONResponse(
        status_code=result.status_code,
        content=result.body,
        headers={
            "Cache-Control": "no-store",
            "Idempotency-Replayed": str(result.replayed).lower(),
        },
    )


@router.delete("/profile", status_code=status.HTTP_204_NO_CONTENT)
async def delete_profile(
    payload: DeleteProfileRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
) -> Response:
    settings = cast(Settings, request.app.state.settings)
    storage = None
    if settings.s3_access_key_id and settings.s3_secret_access_key:
        storage = PrivateObjectStorage(settings)
    await PrivacyService(session).delete_profile(
        user_id=principal.user.id,
        password=payload.password,
        storage=storage,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT, headers={"Cache-Control": "no-store"})
