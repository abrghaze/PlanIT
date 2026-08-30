from __future__ import annotations

from datetime import date, datetime
from typing import Annotated, Literal, cast

from fastapi import APIRouter, Query, Request, Response, status

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.privacy import DeleteProfileRequest
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
    content = await PrivacyService(session).portable_backup(user_id=principal.user.id)
    return _attachment(
        content,
        media_type="application/json",
        filename=f"planit-backup-{datetime.now().date().isoformat()}.json",
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
