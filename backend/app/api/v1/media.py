from __future__ import annotations

from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Header, Query, Request
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.media import (
    MediaAssetResponse,
    MediaFinalizeRequest,
    MediaListResponse,
    MediaReadResponse,
    MediaUploadRequest,
    MediaUploadResponse,
)
from app.application.idempotency import OperationResponse, execute_idempotent
from app.application.media import MediaService
from app.core.config import Settings
from app.infrastructure.storage import PrivateObjectStorage

router = APIRouter(prefix="/media")


def _service(session: AsyncSession, request: Request) -> MediaService:
    return MediaService(session, PrivateObjectStorage(cast(Settings, request.app.state.settings)))


@router.post("/uploads")
async def create_upload(
    payload: MediaUploadRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(db: AsyncSession) -> OperationResponse:
        value = await _service(db, request).create_pending(
            media_id=payload.id,
            user_id=principal.user.id,
            entity_type=payload.entity_type,
            entity_id=payload.entity_id,
            mime_type=payload.mime_type,
            size_bytes=payload.size_bytes,
            request_id=str(request.state.request_id),
            operation_id=idempotency_key,
        )
        return OperationResponse(
            201,
            cast(dict[str, object], MediaUploadResponse.from_domain(value).model_dump(mode="json")),
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="media.uploads.create",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
    )
    return _json(result.status_code, result.body, result.replayed)


@router.post("/uploads/{media_id}/finalize")
async def finalize_upload(
    media_id: UUID,
    payload: MediaFinalizeRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    if payload.id != media_id:
        from app.domain.errors import DomainError

        raise DomainError("MEDIA_ID_MISMATCH", "Media identifier in the path and body must match.")

    async def operation(db: AsyncSession) -> OperationResponse:
        value = await _service(db, request).finalize(
            media_id=media_id,
            user_id=principal.user.id,
            request_id=str(request.state.request_id),
            operation_id=idempotency_key,
        )
        return OperationResponse(
            200,
            cast(dict[str, object], MediaAssetResponse.from_domain(value).model_dump(mode="json")),
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"media.uploads.finalize:{media_id}",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
    )
    return _json(result.status_code, result.body, result.replayed)


@router.get("/{media_id}/read-url", response_model=MediaReadResponse)
async def media_read_url(
    media_id: UUID, request: Request, principal: CurrentPrincipal, session: DatabaseSession
) -> MediaReadResponse:
    asset, url, expires = await _service(session, request).read_url(
        media_id=media_id, user_id=principal.user.id
    )
    return MediaReadResponse(
        asset=MediaAssetResponse.from_domain(asset), read_url=url, expires_in_seconds=expires
    )


@router.get("", response_model=MediaListResponse)
async def list_media(
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    entity_type: Annotated[str, Query(pattern="^(MERCHANT|PRODUCT|TRANSACTION)$")],
    entity_id: UUID,
) -> MediaListResponse:
    values = await _service(session, request).list_entity(
        user_id=principal.user.id, entity_type=entity_type, entity_id=entity_id
    )
    return MediaListResponse(items=[MediaAssetResponse.from_domain(x) for x in values])


def _json(status_code: int, body: dict[str, object], replayed: bool) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content=body,
        headers={"Idempotency-Replayed": str(replayed).lower()},
    )
