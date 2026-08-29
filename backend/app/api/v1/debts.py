from __future__ import annotations

from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Header, Query, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.debts import (
    DebtCancelRequest,
    DebtCreateRequest,
    DebtListResponse,
    DebtPaymentCreateRequest,
    DebtResponse,
    PersonCreateRequest,
    PersonListResponse,
    PersonResponse,
    PersonUpdateRequest,
)
from app.application.debts import DebtService, PeopleService
from app.application.idempotency import (
    FINANCIAL_IDEMPOTENCY_TTL,
    OperationResponse,
    execute_idempotent,
)
from app.domain.debts.enums import DebtDirection, DebtStatus
from app.domain.errors import DomainError

people_router = APIRouter(prefix="/people")
debts_router = APIRouter(prefix="/debts")


@people_router.post("", status_code=status.HTTP_201_CREATED, response_model=PersonResponse)
async def create_person(
    payload: PersonCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(value: AsyncSession) -> OperationResponse:
        person = await PeopleService(value).create_in_transaction(
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        return OperationResponse(
            201, cast(dict[str, object], PersonResponse.from_domain(person).model_dump(mode="json"))
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="people.create",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
    )
    return _response(result.status_code, result.body, result.replayed)


@people_router.get("", response_model=PersonListResponse)
async def list_people(
    principal: CurrentPrincipal, session: DatabaseSession, include_archived: bool = False
) -> PersonListResponse:
    values = await PeopleService(session).list_people(
        user_id=principal.user.id, include_archived=include_archived
    )
    return PersonListResponse(items=[PersonResponse.from_domain(value) for value in values])


@people_router.patch("/{person_id}", response_model=PersonResponse)
async def update_person(
    person_id: UUID,
    payload: PersonUpdateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(value: AsyncSession) -> OperationResponse:
        person = await PeopleService(value).update_in_transaction(
            person_id=person_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        return OperationResponse(
            200, cast(dict[str, object], PersonResponse.from_domain(person).model_dump(mode="json"))
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"people.update:{person_id}",
        key=idempotency_key,
        request_payload=cast(
            dict[str, object], payload.model_dump(mode="json", exclude_unset=True)
        ),
        operation=operation,
    )
    return _response(result.status_code, result.body, result.replayed)


@debts_router.post("", status_code=status.HTTP_201_CREATED, response_model=DebtResponse)
async def create_debt(
    payload: DebtCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    _require_operation_id(payload.client_operation_id, idempotency_key)

    async def operation(value: AsyncSession) -> OperationResponse:
        debt = await DebtService(value).create_in_transaction(
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
        )
        return OperationResponse(
            201, cast(dict[str, object], DebtResponse.from_domain(debt).model_dump(mode="json"))
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="debts.create",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
        ttl=FINANCIAL_IDEMPOTENCY_TTL,
    )
    return _response(result.status_code, result.body, result.replayed)


@debts_router.get("", response_model=DebtListResponse)
async def list_debts(
    principal: CurrentPrincipal,
    session: DatabaseSession,
    person_id: UUID | None = None,
    statuses: Annotated[list[DebtStatus] | None, Query(alias="status")] = None,
    directions: Annotated[list[DebtDirection] | None, Query(alias="direction")] = None,
) -> DebtListResponse:
    values = await DebtService(session).list_debts(
        user_id=principal.user.id,
        person_id=person_id,
        statuses=set(statuses) if statuses else None,
        directions=set(directions) if directions else None,
    )
    return DebtListResponse(items=[DebtResponse.from_domain(value) for value in values])


@debts_router.get("/{debt_id}", response_model=DebtResponse)
async def get_debt(
    debt_id: UUID, principal: CurrentPrincipal, session: DatabaseSession
) -> DebtResponse:
    return DebtResponse.from_domain(
        await DebtService(session).get_debt(debt_id=debt_id, user_id=principal.user.id)
    )


@debts_router.post(
    "/{debt_id}/payments", status_code=status.HTTP_201_CREATED, response_model=DebtResponse
)
async def repay_debt(
    debt_id: UUID,
    payload: DebtPaymentCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    _require_operation_id(payload.client_operation_id, idempotency_key)

    async def operation(value: AsyncSession) -> OperationResponse:
        debt = await DebtService(value).repay_in_transaction(
            debt_id=debt_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
        )
        return OperationResponse(
            201, cast(dict[str, object], DebtResponse.from_domain(debt).model_dump(mode="json"))
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"debts.payment:{debt_id}",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
        ttl=FINANCIAL_IDEMPOTENCY_TTL,
    )
    return _response(result.status_code, result.body, result.replayed)


@debts_router.post("/{debt_id}/cancel", response_model=DebtResponse)
async def cancel_debt(
    debt_id: UUID,
    payload: DebtCancelRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(value: AsyncSession) -> OperationResponse:
        debt = await DebtService(value).cancel_in_transaction(
            debt_id=debt_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        return OperationResponse(
            200, cast(dict[str, object], DebtResponse.from_domain(debt).model_dump(mode="json"))
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"debts.cancel:{debt_id}",
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
