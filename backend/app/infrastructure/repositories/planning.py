from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.planning import (
    GoalAllocationModel,
    RecurringOccurrenceModel,
    RecurringRuleModel,
    SavingsGoalModel,
)


class PlanningRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def add_rule(self, value: RecurringRuleModel) -> None:
        self._session.add(value)

    async def get_rule(
        self, *, rule_id: UUID, user_id: UUID, for_update: bool = False
    ) -> RecurringRuleModel | None:
        statement = select(RecurringRuleModel).where(
            RecurringRuleModel.id == rule_id, RecurringRuleModel.user_id == user_id
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    async def list_rules(
        self, *, user_id: UUID, include_archived: bool = False
    ) -> list[RecurringRuleModel]:
        statement = select(RecurringRuleModel).where(RecurringRuleModel.user_id == user_id)
        if not include_archived:
            statement = statement.where(RecurringRuleModel.status != "ARCHIVED")
        statement = statement.order_by(RecurringRuleModel.next_due_at, RecurringRuleModel.id)
        return list((await self._session.scalars(statement)).all())

    async def due_rules(
        self, *, user_id: UUID, due_at: datetime, limit: int
    ) -> list[RecurringRuleModel]:
        statement = (
            select(RecurringRuleModel)
            .where(
                RecurringRuleModel.user_id == user_id,
                RecurringRuleModel.status == "ACTIVE",
                RecurringRuleModel.next_due_at <= due_at,
            )
            .order_by(RecurringRuleModel.next_due_at, RecurringRuleModel.id)
            .limit(limit)
            .with_for_update(skip_locked=True)
        )
        return list((await self._session.scalars(statement)).all())

    def add_occurrence(self, value: RecurringOccurrenceModel) -> None:
        self._session.add(value)

    async def get_occurrence(
        self, *, occurrence_id: UUID, user_id: UUID, for_update: bool = False
    ) -> RecurringOccurrenceModel | None:
        statement = select(RecurringOccurrenceModel).where(
            RecurringOccurrenceModel.id == occurrence_id,
            RecurringOccurrenceModel.user_id == user_id,
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    async def occurrence_for(
        self, *, rule_id: UUID, scheduled_for: datetime
    ) -> RecurringOccurrenceModel | None:
        return (
            await self._session.execute(
                select(RecurringOccurrenceModel).where(
                    RecurringOccurrenceModel.rule_id == rule_id,
                    RecurringOccurrenceModel.scheduled_for == scheduled_for,
                )
            )
        ).scalar_one_or_none()

    async def list_occurrences(
        self, *, user_id: UUID, statuses: set[str] | None = None, limit: int = 50
    ) -> list[RecurringOccurrenceModel]:
        statement = select(RecurringOccurrenceModel).where(
            RecurringOccurrenceModel.user_id == user_id
        )
        if statuses:
            statement = statement.where(RecurringOccurrenceModel.status.in_(statuses))
        statement = statement.order_by(
            RecurringOccurrenceModel.scheduled_for, RecurringOccurrenceModel.id
        ).limit(limit)
        return list((await self._session.scalars(statement)).all())

    def add_goal(self, value: SavingsGoalModel) -> None:
        self._session.add(value)

    async def get_goal(
        self, *, goal_id: UUID, user_id: UUID, for_update: bool = False
    ) -> SavingsGoalModel | None:
        statement = select(SavingsGoalModel).where(
            SavingsGoalModel.id == goal_id, SavingsGoalModel.user_id == user_id
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    async def list_goals(
        self, *, user_id: UUID, include_archived: bool = False
    ) -> list[SavingsGoalModel]:
        statement = select(SavingsGoalModel).where(SavingsGoalModel.user_id == user_id)
        if not include_archived:
            statement = statement.where(SavingsGoalModel.status != "ARCHIVED")
        statement = statement.order_by(
            SavingsGoalModel.target_date.asc().nulls_last(), SavingsGoalModel.created_at
        )
        return list((await self._session.scalars(statement)).all())

    def add_allocation(self, value: GoalAllocationModel) -> None:
        self._session.add(value)

    async def allocations(self, *, goal_ids: set[UUID]) -> dict[UUID, list[GoalAllocationModel]]:
        if not goal_ids:
            return {}
        values = (
            await self._session.scalars(
                select(GoalAllocationModel)
                .where(GoalAllocationModel.goal_id.in_(goal_ids))
                .order_by(GoalAllocationModel.created_at, GoalAllocationModel.id)
            )
        ).all()
        result: dict[UUID, list[GoalAllocationModel]] = {goal_id: [] for goal_id in goal_ids}
        for value in values:
            result[value.goal_id].append(value)
        return result
