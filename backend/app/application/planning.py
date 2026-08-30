from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime
from decimal import Decimal
from uuid import UUID, uuid5

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.audit import add_audit_event
from app.application.transactions import CreateTransactionCommand, TransactionService
from app.db.models.planning import (
    GoalAllocationModel,
    RecurringOccurrenceModel,
    RecurringRuleModel,
    SavingsGoalModel,
)
from app.domain.catalog.enums import CategoryKind
from app.domain.catalog.policies import category_accepts
from app.domain.errors import DomainError
from app.domain.ledger.enums import TransactionKind
from app.domain.ledger.transactions import normalize_optional_text
from app.domain.money import Money
from app.domain.planning.entities import (
    GoalAllocationSnapshot,
    RecurringCommitmentTotal,
    RecurringOccurrenceSnapshot,
    RecurringRuleSnapshot,
    RecurringSummary,
    SavingsGoalSnapshot,
)
from app.domain.planning.enums import (
    GoalStatus,
    OccurrenceStatus,
    RecurringFrequency,
    RecurringMode,
    RecurringStatus,
)
from app.domain.planning.policies import (
    advance_due,
    normalize_due,
    normalize_name,
    normalize_timezone,
    progress_percent,
    recurring_equivalents,
)
from app.infrastructure.repositories.accounts import AccountRepository
from app.infrastructure.repositories.catalog import CatalogRepository
from app.infrastructure.repositories.planning import PlanningRepository
from app.infrastructure.repositories.purchases import PurchaseRepository


@dataclass(frozen=True, slots=True)
class CreateRecurringRuleCommand:
    id: UUID
    name: str
    kind: TransactionKind
    account_id: UUID
    category_id: UUID | None
    merchant_id: UUID | None
    amount: Money
    frequency: RecurringFrequency
    timezone: str
    next_due_at: datetime
    mode: RecurringMode
    note: str | None


@dataclass(frozen=True, slots=True)
class UpdateRecurringRuleCommand:
    version: int
    values: dict[str, object]


@dataclass(frozen=True, slots=True)
class CreateGoalCommand:
    id: UUID
    name: str
    target_amount: Money
    target_date: date | None
    linked_account_id: UUID | None


@dataclass(frozen=True, slots=True)
class UpdateGoalCommand:
    version: int
    values: dict[str, object]


@dataclass(frozen=True, slots=True)
class AllocateGoalCommand:
    id: UUID
    client_operation_id: UUID
    amount: Money
    note: str | None


class PlanningService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._planning = PlanningRepository(session)
        self._accounts = AccountRepository(session)
        self._catalog = CatalogRepository(session)
        self._purchases = PurchaseRepository(session)

    async def create_rule_in_transaction(
        self,
        *,
        user_id: UUID,
        command: CreateRecurringRuleCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> RecurringRuleSnapshot:
        if command.kind not in {TransactionKind.EXPENSE, TransactionKind.INCOME}:
            raise DomainError(
                "INVALID_RECURRING_KIND", "Recurring rules support income or expense."
            )
        command.amount.require_positive()
        await self._require_rule_references(
            user_id=user_id,
            kind=command.kind,
            account_id=command.account_id,
            category_id=command.category_id,
            merchant_id=command.merchant_id,
            amount=command.amount,
        )
        model = RecurringRuleModel(
            id=command.id,
            user_id=user_id,
            name=normalize_name(command.name),
            kind=command.kind.value,
            account_id=command.account_id,
            category_id=command.category_id,
            merchant_id=command.merchant_id,
            amount=command.amount.amount,
            currency=command.amount.currency,
            frequency=command.frequency.value,
            timezone=normalize_timezone(command.timezone),
            next_due_at=normalize_due(command.next_due_at),
            mode=command.mode.value,
            note=normalize_optional_text(command.note, field="note", maximum=2000),
            status=RecurringStatus.ACTIVE.value,
            version=1,
        )
        self._planning.add_rule(model)
        await self._flush(
            "RECURRING_RULE_CONFLICT", "This recurring rule identifier is unavailable."
        )
        self._audit_rule(model, "CREATE", request_id, client_operation_id)
        await self._session.flush()
        return self._rule_snapshot(model)

    async def update_rule_in_transaction(
        self,
        *,
        rule_id: UUID,
        user_id: UUID,
        command: UpdateRecurringRuleCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> RecurringRuleSnapshot:
        model = await self._planning.get_rule(rule_id=rule_id, user_id=user_id, for_update=True)
        if model is None:
            raise DomainError("RECURRING_RULE_NOT_FOUND", "Recurring rule was not found.")
        self._require_version(model.version, command.version)
        before = self._rule_audit(model)
        values = command.values
        amount = Money(model.amount, model.currency)
        raw_amount = values.get("amount")
        if isinstance(raw_amount, Money):
            amount = raw_amount
        account_id = model.account_id
        raw_account_id = values.get("account_id")
        if isinstance(raw_account_id, UUID):
            account_id = raw_account_id
        category_id = model.category_id
        if "category_id" in values:
            category_id = values["category_id"] if isinstance(values["category_id"], UUID) else None
        merchant_id = model.merchant_id
        if "merchant_id" in values:
            merchant_id = values["merchant_id"] if isinstance(values["merchant_id"], UUID) else None
        await self._require_rule_references(
            user_id=user_id,
            kind=TransactionKind(model.kind),
            account_id=account_id,
            category_id=category_id,
            merchant_id=merchant_id,
            amount=amount,
        )
        model.account_id = account_id
        model.category_id = category_id
        model.merchant_id = merchant_id
        model.amount = amount.amount
        model.currency = amount.currency
        if "name" in values:
            model.name = normalize_name(str(values["name"]))
        if "next_due_at" in values:
            value = values["next_due_at"]
            if not isinstance(value, datetime):
                raise DomainError("INVALID_TIMESTAMP", "Next due time is invalid.")
            model.next_due_at = normalize_due(value)
        if "frequency" in values:
            model.frequency = RecurringFrequency(str(values["frequency"])).value
        if "mode" in values:
            model.mode = RecurringMode(str(values["mode"])).value
        if "status" in values:
            model.status = RecurringStatus(str(values["status"])).value
        if "note" in values:
            note = values["note"]
            model.note = normalize_optional_text(
                note if isinstance(note, str) else None, field="note", maximum=2000
            )
        model.version += 1
        await self._session.flush()
        self._audit_rule(model, "UPDATE", request_id, client_operation_id, before=before)
        await self._session.flush()
        await self._session.refresh(model)
        return self._rule_snapshot(model)

    async def list_rules(
        self, *, user_id: UUID, include_archived: bool = False
    ) -> list[RecurringRuleSnapshot]:
        return [
            self._rule_snapshot(value)
            for value in await self._planning.list_rules(
                user_id=user_id, include_archived=include_archived
            )
        ]

    async def process_due_in_transaction(
        self,
        *,
        user_id: UUID,
        now: datetime,
        limit: int,
        request_id: str | None,
    ) -> list[RecurringOccurrenceSnapshot]:
        current = normalize_due(now)
        rules = await self._planning.due_rules(user_id=user_id, due_at=current, limit=limit)
        results: list[RecurringOccurrenceSnapshot] = []
        for rule in rules:
            scheduled = rule.next_due_at
            existing = await self._planning.occurrence_for(rule_id=rule.id, scheduled_for=scheduled)
            if existing is None:
                occurrence = RecurringOccurrenceModel(
                    id=uuid5(rule.id, scheduled.isoformat()),
                    user_id=user_id,
                    rule_id=rule.id,
                    scheduled_for=scheduled,
                    status=OccurrenceStatus.DUE.value,
                )
                if rule.mode == RecurringMode.AUTO_DRAFT.value:
                    occurrence.transaction_id = await self._create_occurrence_draft(
                        rule=rule,
                        occurrence_id=occurrence.id,
                        scheduled_for=scheduled,
                        request_id=request_id,
                    )
                    occurrence.status = OccurrenceStatus.DRAFT_CREATED.value
                self._planning.add_occurrence(occurrence)
                await self._session.flush()
                add_audit_event(
                    self._session,
                    user_id=user_id,
                    actor_user_id=user_id,
                    entity_type="recurring_occurrence",
                    entity_id=occurrence.id,
                    action=occurrence.status,
                    after={"rule_id": str(rule.id), "scheduled_for": scheduled.isoformat()},
                    request_id=request_id,
                )
                results.append(self._occurrence_snapshot(occurrence))
            rule.next_due_at = advance_due(
                scheduled, RecurringFrequency(rule.frequency), rule.timezone
            )
            rule.version += 1
        await self._session.flush()
        return results

    async def record_occurrence_in_transaction(
        self,
        *,
        occurrence_id: UUID,
        user_id: UUID,
        request_id: str | None,
    ) -> RecurringOccurrenceSnapshot:
        occurrence = await self._planning.get_occurrence(
            occurrence_id=occurrence_id, user_id=user_id, for_update=True
        )
        if occurrence is None:
            raise DomainError("OCCURRENCE_NOT_FOUND", "Recurring occurrence was not found.")
        if occurrence.status == OccurrenceStatus.DRAFT_CREATED.value:
            return self._occurrence_snapshot(occurrence)
        if occurrence.status != OccurrenceStatus.DUE.value:
            raise DomainError("OCCURRENCE_NOT_RECORDABLE", "This occurrence cannot be recorded.")
        rule = await self._planning.get_rule(
            rule_id=occurrence.rule_id, user_id=user_id, for_update=True
        )
        if rule is None:
            raise DomainError("RECURRING_RULE_NOT_FOUND", "Recurring rule was not found.")
        occurrence.transaction_id = await self._create_occurrence_draft(
            rule=rule,
            occurrence_id=occurrence.id,
            scheduled_for=occurrence.scheduled_for,
            request_id=request_id,
        )
        occurrence.status = OccurrenceStatus.DRAFT_CREATED.value
        await self._session.flush()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="recurring_occurrence",
            entity_id=occurrence.id,
            action="CREATE_DRAFT",
            after={"transaction_id": str(occurrence.transaction_id)},
            request_id=request_id,
        )
        await self._session.flush()
        await self._session.refresh(occurrence)
        return self._occurrence_snapshot(occurrence)

    async def recurring_summary(self, *, user_id: UUID) -> RecurringSummary:
        rules = await self._planning.list_rules(user_id=user_id)
        active = [value for value in rules if value.status == RecurringStatus.ACTIVE.value]
        totals: dict[str, dict[str, list[Money]]] = {}
        for rule in active:
            if rule.currency not in totals:
                totals[rule.currency] = {
                    "EXPENSE": [Money.zero(rule.currency), Money.zero(rule.currency)],
                    "INCOME": [Money.zero(rule.currency), Money.zero(rule.currency)],
                }
            monthly, annual = recurring_equivalents(
                Money(rule.amount, rule.currency), RecurringFrequency(rule.frequency)
            )
            totals[rule.currency][rule.kind][0] = totals[rule.currency][rule.kind][0] + monthly
            totals[rule.currency][rule.kind][1] = totals[rule.currency][rule.kind][1] + annual
        upcoming = await self._planning.list_occurrences(
            user_id=user_id, statuses={OccurrenceStatus.DUE.value}, limit=20
        )
        return RecurringSummary(
            totals=tuple(
                RecurringCommitmentTotal(
                    currency=currency,
                    expense_monthly=values["EXPENSE"][0],
                    expense_annual=values["EXPENSE"][1],
                    income_monthly=values["INCOME"][0],
                    income_annual=values["INCOME"][1],
                )
                for currency, values in sorted(totals.items())
            ),
            upcoming=tuple(self._occurrence_snapshot(value) for value in upcoming),
        )

    async def create_goal_in_transaction(
        self,
        *,
        user_id: UUID,
        command: CreateGoalCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> SavingsGoalSnapshot:
        command.target_amount.require_positive(code="INVALID_GOAL_TARGET")
        if command.linked_account_id is not None:
            await self._require_account(user_id, command.linked_account_id, command.target_amount)
        model = SavingsGoalModel(
            id=command.id,
            user_id=user_id,
            name=normalize_name(command.name),
            target_amount=command.target_amount.amount,
            currency=command.target_amount.currency,
            target_date=command.target_date,
            linked_account_id=command.linked_account_id,
            manual_progress=Decimal("0"),
            status=GoalStatus.ACTIVE.value,
            version=1,
        )
        self._planning.add_goal(model)
        await self._flush("GOAL_CONFLICT", "This savings goal identifier is unavailable.")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="savings_goal",
            entity_id=model.id,
            action="CREATE",
            after=self._goal_audit(model),
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        await self._session.flush()
        return await self._goal_snapshot(model, ())

    async def update_goal_in_transaction(
        self,
        *,
        goal_id: UUID,
        user_id: UUID,
        command: UpdateGoalCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> SavingsGoalSnapshot:
        model = await self._planning.get_goal(goal_id=goal_id, user_id=user_id, for_update=True)
        if model is None:
            raise DomainError("GOAL_NOT_FOUND", "Savings goal was not found.")
        self._require_version(model.version, command.version)
        before = self._goal_audit(model)
        if "name" in command.values:
            model.name = normalize_name(str(command.values["name"]))
        if "target_date" in command.values:
            value = command.values["target_date"]
            model.target_date = value if isinstance(value, date) else None
        if "target_amount" in command.values:
            target = command.values["target_amount"]
            if not isinstance(target, Money):
                raise DomainError("INVALID_GOAL_TARGET", "Goal target is invalid.")
            target.require_positive(code="INVALID_GOAL_TARGET")
            if target.currency != model.currency:
                raise DomainError("CURRENCY_MISMATCH", "Goal target currency cannot be changed.")
            model.target_amount = target.amount
        if "status" in command.values:
            model.status = GoalStatus(str(command.values["status"])).value
        model.version += 1
        await self._session.flush()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="savings_goal",
            entity_id=model.id,
            action="UPDATE",
            before=before,
            after=self._goal_audit(model),
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        await self._session.flush()
        await self._session.refresh(model)
        allocations = (await self._planning.allocations(goal_ids={model.id}))[model.id]
        return await self._goal_snapshot(model, tuple(allocations))

    async def allocate_goal_in_transaction(
        self,
        *,
        goal_id: UUID,
        user_id: UUID,
        command: AllocateGoalCommand,
        request_id: str | None,
    ) -> SavingsGoalSnapshot:
        goal = await self._planning.get_goal(goal_id=goal_id, user_id=user_id, for_update=True)
        if goal is None:
            raise DomainError("GOAL_NOT_FOUND", "Savings goal was not found.")
        if goal.linked_account_id is not None:
            raise DomainError(
                "LINKED_GOAL_ALLOCATION", "Linked goals derive progress from the account balance."
            )
        if goal.status == GoalStatus.ARCHIVED.value:
            raise DomainError("GOAL_ARCHIVED", "An archived goal cannot receive allocations.")
        if command.amount.currency != goal.currency:
            raise DomainError("CURRENCY_MISMATCH", "Allocation currency must match the goal.")
        if command.amount.amount == 0:
            raise DomainError("ZERO_ALLOCATION", "Allocation amount cannot be zero.")
        updated = Money(goal.manual_progress, goal.currency) + command.amount
        updated.require_non_negative(code="GOAL_PROGRESS_NEGATIVE")
        allocation = GoalAllocationModel(
            id=command.id,
            user_id=user_id,
            goal_id=goal.id,
            amount=command.amount.amount,
            currency=command.amount.currency,
            note=normalize_optional_text(command.note, field="note", maximum=500),
            client_operation_id=command.client_operation_id,
        )
        self._planning.add_allocation(allocation)
        goal.manual_progress = updated.amount
        goal.status = (
            GoalStatus.COMPLETED.value
            if updated.amount >= goal.target_amount
            else GoalStatus.ACTIVE.value
        )
        goal.version += 1
        await self._flush("GOAL_ALLOCATION_CONFLICT", "This allocation was already recorded.")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="savings_goal",
            entity_id=goal.id,
            action="ALLOCATE",
            after={"amount": command.amount.to_api(), "progress": updated.to_api()},
            request_id=request_id,
            client_operation_id=command.client_operation_id,
        )
        await self._session.flush()
        await self._session.refresh(goal)
        allocations = (await self._planning.allocations(goal_ids={goal.id}))[goal.id]
        return await self._goal_snapshot(goal, tuple(allocations))

    async def list_goals(
        self, *, user_id: UUID, include_archived: bool = False
    ) -> list[SavingsGoalSnapshot]:
        goals = await self._planning.list_goals(user_id=user_id, include_archived=include_archived)
        allocations = await self._planning.allocations(goal_ids={value.id for value in goals})
        return [await self._goal_snapshot(value, tuple(allocations[value.id])) for value in goals]

    async def _create_occurrence_draft(
        self,
        *,
        rule: RecurringRuleModel,
        occurrence_id: UUID,
        scheduled_for: datetime,
        request_id: str | None,
    ) -> UUID:
        transaction_id = uuid5(occurrence_id, "transaction")
        await TransactionService(self._session).create_draft_in_transaction(
            user_id=rule.user_id,
            command=CreateTransactionCommand(
                id=transaction_id,
                client_operation_id=uuid5(occurrence_id, "transaction-operation"),
                account_id=rule.account_id,
                kind=TransactionKind(rule.kind),
                amount=Money(rule.amount, rule.currency),
                occurred_at=scheduled_for,
                category_id=rule.category_id,
                merchant_id=rule.merchant_id,
                merchant_location_id=None,
                counterparty=None,
                note=rule.note or f"Recurring: {rule.name}",
                tag_ids=(),
                items=(),
            ),
            request_id=request_id,
        )
        return transaction_id

    async def _goal_snapshot(
        self, goal: SavingsGoalModel, allocations: tuple[GoalAllocationModel, ...]
    ) -> SavingsGoalSnapshot:
        progress = Money(goal.manual_progress, goal.currency)
        if goal.linked_account_id is not None:
            account = await self._accounts.get_snapshot(
                account_id=goal.linked_account_id,
                user_id=goal.user_id,
                as_of=datetime.now(UTC),
            )
            if account is None:
                raise DomainError("ACCOUNT_NOT_FOUND", "Linked goal account was not found.")
            progress = Money.calculated(
                max(Decimal(0), account.calculated_balance.amount), goal.currency
            )
        target = Money(goal.target_amount, goal.currency)
        remaining = Money.calculated(
            max(Decimal(0), target.amount - progress.amount), goal.currency
        )
        effective_status = goal.status
        if effective_status != GoalStatus.ARCHIVED.value and progress.amount >= target.amount:
            effective_status = GoalStatus.COMPLETED.value
        return SavingsGoalSnapshot(
            id=goal.id,
            name=goal.name,
            target_amount=target,
            target_date=goal.target_date,
            linked_account_id=goal.linked_account_id,
            progress=progress,
            progress_percent=progress_percent(progress, target),
            remaining=remaining,
            status=effective_status,
            version=goal.version,
            allocations=tuple(
                GoalAllocationSnapshot(
                    id=value.id,
                    amount=Money(value.amount, value.currency),
                    note=value.note,
                    client_operation_id=value.client_operation_id,
                    created_at=value.created_at,
                )
                for value in allocations
            ),
            created_at=goal.created_at,
            updated_at=goal.updated_at,
        )

    @staticmethod
    def _rule_snapshot(model: RecurringRuleModel) -> RecurringRuleSnapshot:
        amount = Money(model.amount, model.currency)
        monthly, annual = recurring_equivalents(amount, RecurringFrequency(model.frequency))
        return RecurringRuleSnapshot(
            id=model.id,
            name=model.name,
            kind=model.kind,
            account_id=model.account_id,
            category_id=model.category_id,
            merchant_id=model.merchant_id,
            amount=amount,
            frequency=model.frequency,
            timezone=model.timezone,
            next_due_at=model.next_due_at,
            mode=model.mode,
            note=model.note,
            status=model.status,
            monthly_equivalent=monthly,
            annual_equivalent=annual,
            version=model.version,
            created_at=model.created_at,
            updated_at=model.updated_at,
        )

    @staticmethod
    def _occurrence_snapshot(model: RecurringOccurrenceModel) -> RecurringOccurrenceSnapshot:
        return RecurringOccurrenceSnapshot(
            id=model.id,
            rule_id=model.rule_id,
            scheduled_for=model.scheduled_for,
            transaction_id=model.transaction_id,
            status=model.status,
            created_at=model.created_at,
            updated_at=model.updated_at,
        )

    async def _require_account(self, user_id: UUID, account_id: UUID, amount: Money) -> None:
        account = await self._accounts.get_owned(account_id=account_id, user_id=user_id)
        if account is None:
            raise DomainError("ACCOUNT_NOT_FOUND", "Account was not found.")
        if account.currency != amount.currency:
            raise DomainError("CURRENCY_MISMATCH", "Currency must match the selected account.")

    async def _require_rule_references(
        self,
        *,
        user_id: UUID,
        kind: TransactionKind,
        account_id: UUID,
        category_id: UUID | None,
        merchant_id: UUID | None,
        amount: Money,
    ) -> None:
        await self._require_account(user_id, account_id, amount)
        if category_id is not None:
            category = await self._catalog.get_category(category_id=category_id, user_id=user_id)
            if category is None or category.archived_at is not None:
                raise DomainError("CATEGORY_NOT_FOUND", "Category was not found.")
            if not category_accepts(
                category_kind=CategoryKind(category.kind), transaction_kind=kind.value
            ):
                raise DomainError(
                    "CATEGORY_KIND_MISMATCH",
                    "This category cannot classify the recurring transaction type.",
                )
        if merchant_id is not None:
            if kind is not TransactionKind.EXPENSE:
                raise DomainError(
                    "MERCHANT_EXPENSE_ONLY", "A shop can only be used for an expense rule."
                )
            merchant = await self._purchases.get_merchant(merchant_id=merchant_id, user_id=user_id)
            if merchant is None or merchant.archived_at is not None:
                raise DomainError("MERCHANT_NOT_FOUND", "Shop was not found.")

    async def _flush(self, code: str, message: str) -> None:
        try:
            await self._session.flush()
        except IntegrityError as exc:
            raise DomainError(code, message) from exc

    @staticmethod
    def _require_version(current: int, requested: int) -> None:
        if current != requested:
            raise DomainError(
                "VERSION_CONFLICT",
                "This planning record changed since it was loaded.",
                details={"current_version": current},
            )

    def _audit_rule(
        self,
        model: RecurringRuleModel,
        action: str,
        request_id: str | None,
        client_operation_id: UUID,
        *,
        before: dict[str, object] | None = None,
    ) -> None:
        add_audit_event(
            self._session,
            user_id=model.user_id,
            actor_user_id=model.user_id,
            entity_type="recurring_rule",
            entity_id=model.id,
            action=action,
            before=before,
            after=self._rule_audit(model),
            request_id=request_id,
            client_operation_id=client_operation_id,
        )

    @staticmethod
    def _rule_audit(model: RecurringRuleModel) -> dict[str, object]:
        return {
            "name": model.name,
            "amount": format(model.amount, ".4f"),
            "currency": model.currency,
            "frequency": model.frequency,
            "next_due_at": model.next_due_at.isoformat(),
            "mode": model.mode,
            "status": model.status,
            "version": model.version,
        }

    @staticmethod
    def _goal_audit(model: SavingsGoalModel) -> dict[str, object]:
        return {
            "name": model.name,
            "target_amount": format(model.target_amount, ".4f"),
            "currency": model.currency,
            "target_date": model.target_date.isoformat() if model.target_date else None,
            "linked_account_id": str(model.linked_account_id) if model.linked_account_id else None,
            "manual_progress": format(model.manual_progress, ".4f"),
            "status": model.status,
            "version": model.version,
        }
