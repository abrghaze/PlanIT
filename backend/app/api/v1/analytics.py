from __future__ import annotations

from datetime import date
from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Header, Query, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.analytics import (
    AnalyticsDashboardResponse,
    ExchangeRateCreateRequest,
    ExchangeRateListResponse,
    ExchangeRateResponse,
)
from app.application.analytics import AnalyticsService
from app.application.idempotency import OperationResponse, execute_idempotent
from app.domain.analytics.enums import AnalyticsGranularity, AnalyticsPreset

router = APIRouter(prefix="/analytics")


@router.get("/dashboard", response_model=AnalyticsDashboardResponse)
async def dashboard(
    principal: CurrentPrincipal,
    session: DatabaseSession,
    preset: AnalyticsPreset = AnalyticsPreset.THIS_MONTH,
    custom_from: Annotated[date | None, Query(alias="from")] = None,
    custom_to: Annotated[date | None, Query(alias="to")] = None,
    granularity: AnalyticsGranularity | None = None,
) -> AnalyticsDashboardResponse:
    value = await AnalyticsService(session).dashboard(
        user_id=principal.user.id,
        base_currency=principal.user.base_currency,
        timezone=principal.user.timezone,
        preset=preset,
        custom_from=custom_from,
        custom_to=custom_to,
        granularity=granularity,
    )
    return AnalyticsDashboardResponse.from_domain(value)


@router.get("/exchange-rates", response_model=ExchangeRateListResponse)
async def list_exchange_rates(
    principal: CurrentPrincipal,
    session: DatabaseSession,
) -> ExchangeRateListResponse:
    values = await AnalyticsService(session).list_exchange_rates(user_id=principal.user.id)
    return ExchangeRateListResponse(
        items=[ExchangeRateResponse.from_domain(value) for value in values]
    )


@router.post("/exchange-rates", status_code=status.HTTP_201_CREATED)
async def create_exchange_rate(
    payload: ExchangeRateCreateRequest,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(db: AsyncSession) -> OperationResponse:
        value = await AnalyticsService(db).create_exchange_rate(
            user_id=principal.user.id,
            command=payload.to_command(),
        )
        body = ExchangeRateResponse.from_domain(value).model_dump(mode="json")
        return OperationResponse(201, cast(dict[str, object], body))

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="analytics.exchange-rates.create",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
    )
    return JSONResponse(
        status_code=result.status_code,
        content=result.body,
        headers={"Idempotency-Replayed": str(result.replayed).lower()},
    )
