from __future__ import annotations

from collections.abc import Awaitable, Callable
from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Header, Query, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.purchases import (
    MerchantCreateRequest,
    MerchantListResponse,
    MerchantLocationCreateRequest,
    MerchantLocationUpdateRequest,
    MerchantResponse,
    MerchantUpdateRequest,
    ProductCreateRequest,
    ProductListResponse,
    ProductResponse,
    ProductUpdateRequest,
)
from app.application.idempotency import OperationResponse, execute_idempotent
from app.application.purchases import PurchaseCatalogService

router = APIRouter()


@router.get("/merchants", response_model=MerchantListResponse)
async def list_merchants(
    principal: CurrentPrincipal,
    session: DatabaseSession,
    search: Annotated[str | None, Query(max_length=160)] = None,
    include_archived: bool = False,
) -> MerchantListResponse:
    values = await PurchaseCatalogService(session).list_merchants(
        user_id=principal.user.id, search=search, include_archived=include_archived
    )
    return MerchantListResponse(items=[MerchantResponse.from_domain(x) for x in values])


@router.post("/merchants", status_code=status.HTTP_201_CREATED)
async def create_merchant(
    payload: MerchantCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(db: AsyncSession) -> OperationResponse:
        value = await PurchaseCatalogService(db).create_merchant(
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            operation_id=idempotency_key,
        )
        return OperationResponse(
            201,
            cast(dict[str, object], MerchantResponse.from_domain(value).model_dump(mode="json")),
        )

    return await _execute(
        session, principal.user.id, "merchants.create", idempotency_key, payload, operation
    )


@router.get("/merchants/{merchant_id}", response_model=MerchantResponse)
async def get_merchant(
    merchant_id: UUID,
    principal: CurrentPrincipal,
    session: DatabaseSession,
) -> MerchantResponse:
    value = await PurchaseCatalogService(session).get_merchant(
        user_id=principal.user.id,
        merchant_id=merchant_id,
    )
    return MerchantResponse.from_domain(value)


@router.patch("/merchants/{merchant_id}")
async def update_merchant(
    merchant_id: UUID,
    payload: MerchantUpdateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(db: AsyncSession) -> OperationResponse:
        value = await PurchaseCatalogService(db).update_merchant(
            merchant_id=merchant_id,
            user_id=principal.user.id,
            version=payload.version,
            values=payload.values(),
            request_id=str(request.state.request_id),
            operation_id=idempotency_key,
        )
        return OperationResponse(
            200,
            cast(dict[str, object], MerchantResponse.from_domain(value).model_dump(mode="json")),
        )

    return await _execute(
        session,
        principal.user.id,
        f"merchants.update:{merchant_id}",
        idempotency_key,
        payload,
        operation,
    )


@router.post("/merchants/{merchant_id}/locations", status_code=status.HTTP_201_CREATED)
async def create_location(
    merchant_id: UUID,
    payload: MerchantLocationCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(db: AsyncSession) -> OperationResponse:
        value = await PurchaseCatalogService(db).add_location(
            merchant_id=merchant_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            operation_id=idempotency_key,
        )
        return OperationResponse(
            201,
            cast(dict[str, object], MerchantResponse.from_domain(value).model_dump(mode="json")),
        )

    return await _execute(
        session,
        principal.user.id,
        f"merchant-locations.create:{merchant_id}",
        idempotency_key,
        payload,
        operation,
    )


@router.patch("/merchants/{merchant_id}/locations/{location_id}")
async def update_location(
    merchant_id: UUID,
    location_id: UUID,
    payload: MerchantLocationUpdateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(db: AsyncSession) -> OperationResponse:
        value = await PurchaseCatalogService(db).update_location(
            merchant_id=merchant_id,
            location_id=location_id,
            user_id=principal.user.id,
            version=payload.version,
            values=payload.values(),
            request_id=str(request.state.request_id),
            operation_id=idempotency_key,
        )
        return OperationResponse(
            200,
            cast(
                dict[str, object],
                MerchantResponse.from_domain(value).model_dump(mode="json"),
            ),
        )

    return await _execute(
        session,
        principal.user.id,
        f"merchant-locations.update:{location_id}",
        idempotency_key,
        payload,
        operation,
    )


@router.get("/products", response_model=ProductListResponse)
async def list_products(
    principal: CurrentPrincipal,
    session: DatabaseSession,
    search: Annotated[str | None, Query(max_length=160)] = None,
    merchant_id: UUID | None = None,
    include_archived: bool = False,
) -> ProductListResponse:
    values = await PurchaseCatalogService(session).list_products(
        user_id=principal.user.id,
        search=search,
        merchant_id=merchant_id,
        include_archived=include_archived,
    )
    return ProductListResponse(items=[ProductResponse.from_domain(x) for x in values])


@router.post("/products", status_code=status.HTTP_201_CREATED)
async def create_product(
    payload: ProductCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(db: AsyncSession) -> OperationResponse:
        value = await PurchaseCatalogService(db).create_product(
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            operation_id=idempotency_key,
        )
        return OperationResponse(
            201, cast(dict[str, object], ProductResponse.from_domain(value).model_dump(mode="json"))
        )

    return await _execute(
        session, principal.user.id, "products.create", idempotency_key, payload, operation
    )


@router.get("/products/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: UUID,
    principal: CurrentPrincipal,
    session: DatabaseSession,
) -> ProductResponse:
    value = await PurchaseCatalogService(session).get_product(
        user_id=principal.user.id,
        product_id=product_id,
    )
    return ProductResponse.from_domain(value)


@router.patch("/products/{product_id}")
async def update_product(
    product_id: UUID,
    payload: ProductUpdateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(db: AsyncSession) -> OperationResponse:
        value = await PurchaseCatalogService(db).update_product(
            product_id=product_id,
            user_id=principal.user.id,
            version=payload.version,
            values=payload.values(),
            request_id=str(request.state.request_id),
            operation_id=idempotency_key,
        )
        return OperationResponse(
            200, cast(dict[str, object], ProductResponse.from_domain(value).model_dump(mode="json"))
        )

    return await _execute(
        session,
        principal.user.id,
        f"products.update:{product_id}",
        idempotency_key,
        payload,
        operation,
    )


async def _execute(
    session: AsyncSession,
    user_id: UUID,
    scope: str,
    key: UUID,
    payload: MerchantCreateRequest
    | MerchantUpdateRequest
    | MerchantLocationCreateRequest
    | MerchantLocationUpdateRequest
    | ProductCreateRequest
    | ProductUpdateRequest,
    operation: Callable[[AsyncSession], Awaitable[OperationResponse]],
) -> JSONResponse:
    result = await execute_idempotent(
        session,
        user_id=user_id,
        scope=scope,
        key=key,
        request_payload=cast(
            dict[str, object], payload.model_dump(mode="json", exclude_unset=True)
        ),
        operation=operation,
    )
    return JSONResponse(
        status_code=result.status_code,
        content=result.body,
        headers={"Idempotency-Replayed": str(result.replayed).lower()},
    )
