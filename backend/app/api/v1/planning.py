from __future__ import annotations

from datetime import UTC, datetime
from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Header, Query, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentPrincipal, DatabaseSession
from app.api.schemas.planning import (
    GoalAllocationCreateRequest,
    GoalCreateRequest,
    GoalListResponse,
    GoalResponse,
    GoalUpdateRequest,
    RecurringOccurrenceListResponse,
    RecurringOccurrenceResponse,
    RecurringRuleCreateRequest,
    RecurringRuleListResponse,
    RecurringRuleResponse,
    RecurringRuleUpdateRequest,
    RecurringSummaryResponse,
)
from app.application.idempotency import OperationResponse, execute_idempotent
from app.application.planning import PlanningService
from app.domain.errors import DomainError

recurring_router = APIRouter(prefix="/recurring")
goals_router = APIRouter(prefix="/goals")


@recurring_router.get("/rules", response_model=RecurringRuleListResponse)
async def list_recurring_rules(
    principal: CurrentPrincipal,
    session: DatabaseSession,
    include_archived: bool = False,
) -> RecurringRuleListResponse:
    values = await PlanningService(session).list_rules(
        user_id=principal.user.id, include_archived=include_archived
    )
    return RecurringRuleListResponse(
        items=[RecurringRuleResponse.from_domain(value) for value in values]
    )


@recurring_router.post(
    "/rules", status_code=status.HTTP_201_CREATED, response_model=RecurringRuleResponse
)
async def create_recurring_rule(
    payload: RecurringRuleCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(value: AsyncSession) -> OperationResponse:
        created = await PlanningService(value).create_rule_in_transaction(
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        return OperationResponse(
            201,
            cast(
                dict[str, object],
                RecurringRuleResponse.from_domain(created).model_dump(mode="json"),
            ),
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="recurring.create",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
    )
    return _response(result.status_code, result.body, result.replayed)


@recurring_router.patch("/rules/{rule_id}", response_model=RecurringRuleResponse)
async def update_recurring_rule(
    rule_id: UUID,
    payload: RecurringRuleUpdateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(value: AsyncSession) -> OperationResponse:
        updated = await PlanningService(value).update_rule_in_transaction(
            rule_id=rule_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        return OperationResponse(
            200,
            cast(
                dict[str, object],
                RecurringRuleResponse.from_domain(updated).model_dump(mode="json"),
            ),
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"recurring.update:{rule_id}",
        key=idempotency_key,
        request_payload=cast(
            dict[str, object], payload.model_dump(mode="json", exclude_unset=True)
        ),
        operation=operation,
    )
    return _response(result.status_code, result.body, result.replayed)


@recurring_router.post("/process-due", response_model=RecurringOccurrenceListResponse)
async def process_due_rules(
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> JSONResponse:
    async def operation(value: AsyncSession) -> OperationResponse:
        occurrences = await PlanningService(value).process_due_in_transaction(
            user_id=principal.user.id,
            now=datetime.now(UTC),
            limit=limit,
            request_id=str(request.state.request_id),
        )
        body = RecurringOccurrenceListResponse(
            items=[RecurringOccurrenceResponse.from_domain(item) for item in occurrences]
        )
        return OperationResponse(200, cast(dict[str, object], body.model_dump(mode="json")))

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="recurring.process-due",
        key=idempotency_key,
        request_payload={"limit": limit},
        operation=operation,
    )
    return _response(result.status_code, result.body, result.replayed)


@recurring_router.post(
    "/occurrences/{occurrence_id}/record", response_model=RecurringOccurrenceResponse
)
async def record_occurrence(
    occurrence_id: UUID,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(value: AsyncSession) -> OperationResponse:
        occurrence = await PlanningService(value).record_occurrence_in_transaction(
            occurrence_id=occurrence_id,
            user_id=principal.user.id,
            request_id=str(request.state.request_id),
        )
        return OperationResponse(
            200,
            cast(
                dict[str, object],
                RecurringOccurrenceResponse.from_domain(occurrence).model_dump(mode="json"),
            ),
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"recurring.record:{occurrence_id}",
        key=idempotency_key,
        request_payload={},
        operation=operation,
    )
    return _response(result.status_code, result.body, result.replayed)


@recurring_router.get("/summary", response_model=RecurringSummaryResponse)
async def get_recurring_summary(
    principal: CurrentPrincipal, session: DatabaseSession
) -> RecurringSummaryResponse:
    return RecurringSummaryResponse.from_domain(
        await PlanningService(session).recurring_summary(user_id=principal.user.id)
    )


@goals_router.get("", response_model=GoalListResponse)
async def list_goals(
    principal: CurrentPrincipal,
    session: DatabaseSession,
    include_archived: bool = False,
) -> GoalListResponse:
    values = await PlanningService(session).list_goals(
        user_id=principal.user.id, include_archived=include_archived
    )
    return GoalListResponse(items=[GoalResponse.from_domain(value) for value in values])


@goals_router.post("", status_code=status.HTTP_201_CREATED, response_model=GoalResponse)
async def create_goal(
    payload: GoalCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(value: AsyncSession) -> OperationResponse:
        created = await PlanningService(value).create_goal_in_transaction(
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        return OperationResponse(
            201, cast(dict[str, object], GoalResponse.from_domain(created).model_dump(mode="json"))
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope="goals.create",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
    )
    return _response(result.status_code, result.body, result.replayed)


@goals_router.patch("/{goal_id}", response_model=GoalResponse)
async def update_goal(
    goal_id: UUID,
    payload: GoalUpdateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    async def operation(value: AsyncSession) -> OperationResponse:
        updated = await PlanningService(value).update_goal_in_transaction(
            goal_id=goal_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
            client_operation_id=idempotency_key,
        )
        return OperationResponse(
            200, cast(dict[str, object], GoalResponse.from_domain(updated).model_dump(mode="json"))
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"goals.update:{goal_id}",
        key=idempotency_key,
        request_payload=cast(
            dict[str, object], payload.model_dump(mode="json", exclude_unset=True)
        ),
        operation=operation,
    )
    return _response(result.status_code, result.body, result.replayed)


@goals_router.post("/{goal_id}/allocations", response_model=GoalResponse)
async def allocate_goal(
    goal_id: UUID,
    payload: GoalAllocationCreateRequest,
    request: Request,
    principal: CurrentPrincipal,
    session: DatabaseSession,
    idempotency_key: Annotated[UUID, Header(alias="Idempotency-Key")],
) -> JSONResponse:
    if payload.client_operation_id != idempotency_key:
        raise DomainError(
            "OPERATION_ID_MISMATCH", "Client operation ID must match the Idempotency-Key header."
        )

    async def operation(value: AsyncSession) -> OperationResponse:
        updated = await PlanningService(value).allocate_goal_in_transaction(
            goal_id=goal_id,
            user_id=principal.user.id,
            command=payload.to_command(),
            request_id=str(request.state.request_id),
        )
        return OperationResponse(
            200, cast(dict[str, object], GoalResponse.from_domain(updated).model_dump(mode="json"))
        )

    result = await execute_idempotent(
        session,
        user_id=principal.user.id,
        scope=f"goals.allocate:{goal_id}",
        key=idempotency_key,
        request_payload=cast(dict[str, object], payload.model_dump(mode="json")),
        operation=operation,
    )
    return _response(result.status_code, result.body, result.replayed)


def _response(status_code: int, body: dict[str, object], replayed: bool) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content=body,
        headers={"Idempotency-Replayed": str(replayed).lower()},
    )
