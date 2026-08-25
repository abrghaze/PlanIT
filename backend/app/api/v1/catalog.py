from __future__ import annotations

from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Header, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.catalog import (
    CategoryCreateRequest,
    CategoryListResponse,
    CategoryResponse,
    CategoryUpdateRequest,
    TagCreateRequest,
    TagListResponse,
    TagResponse,
    TagUpdateRequest,
)
from app.application.catalog import CatalogService
from app.application.idempotency import OperationResponse, execute_idempotent

router = APIRouter()


@router.post("/categories", status_code=status.HTTP_201_CREATED)
async def create_category(
    payload: CategoryCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(_session: AsyncSession) -> OperationResponse:
        result = await CatalogService(_session).create_category_in_transaction(
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        body = CategoryResponse.from_domain(result).model_dump(mode="json")
        return OperationResponse(status_code=201, body=cast(dict[str, object], body))

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="categories.create",
        key=idempotency_key,
        request_payload=cast(
            dict[str, object],
            payload.model_dump(mode="json", exclude_unset=True),
        ),
        operation=operation,
    )
    return _json_response(result.status_code, result.body, replayed=result.replayed)


@router.get("/categories", response_model=CategoryListResponse)
async def list_categories(
    principal: CurrentPrincipal,
    session: DatabaseSession,
    include_archived: bool = False,
) -> CategoryListResponse:
    values = await CatalogService(session).list_categories(
        user_id=principal.user.id,
        include_archived=include_archived,
    )
    return CategoryListResponse(items=[CategoryResponse.from_domain(value) for value in values])


@router.patch("/categories/{category_id}")
async def update_category(
    category_id: UUID,
    payload: CategoryUpdateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(_session: AsyncSession) -> OperationResponse:
        result = await CatalogService(_session).update_category_in_transaction(
            category_id=category_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        body = CategoryResponse.from_domain(result).model_dump(mode="json")
        return OperationResponse(status_code=200, body=cast(dict[str, object], body))

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"categories.update:{category_id}",
        key=idempotency_key,
        request_payload=cast(
            dict[str, object],
            payload.model_dump(mode="json", exclude_unset=True),
        ),
        operation=operation,
    )
    return _json_response(result.status_code, result.body, replayed=result.replayed)


@router.post("/tags", status_code=status.HTTP_201_CREATED)
async def create_tag(
    payload: TagCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(_session: AsyncSession) -> OperationResponse:
        result = await CatalogService(_session).create_tag_in_transaction(
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        body = TagResponse.from_domain(result).model_dump(mode="json")
        return OperationResponse(status_code=201, body=cast(dict[str, object], body))

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="tags.create",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
    )
    return _json_response(result.status_code, result.body, replayed=result.replayed)


@router.get("/tags", response_model=TagListResponse)
async def list_tags(
    principal: CurrentPrincipal,
    session: DatabaseSession,
    include_archived: bool = False,
) -> TagListResponse:
    values = await CatalogService(session).list_tags(
        user_id=principal.user.id,
        include_archived=include_archived,
    )
    return TagListResponse(items=[TagResponse.from_domain(value) for value in values])


@router.patch("/tags/{tag_id}")
async def update_tag(
    tag_id: UUID,
    payload: TagUpdateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(_session: AsyncSession) -> OperationResponse:
        result = await CatalogService(_session).update_tag_in_transaction(
            tag_id=tag_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        body = TagResponse.from_domain(result).model_dump(mode="json")
        return OperationResponse(status_code=200, body=cast(dict[str, object], body))

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"tags.update:{tag_id}",
        key=idempotency_key,
        request_payload=cast(
            dict[str, object],
            payload.model_dump(mode="json", exclude_unset=True),
        ),
        operation=operation,
    )
    return _json_response(result.status_code, result.body, replayed=result.replayed)


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
