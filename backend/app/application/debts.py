from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime
from uuid import UUID, uuid5

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.audit import add_audit_event
from app.application.ledger_posting import build_posted_movement
from app.db.models.ledger import (
    AccountModel,
    DebtModel,
    DebtPaymentModel,
    PersonModel,
)
from app.domain.debts.entities import DebtSnapshot, PersonSnapshot
from app.domain.debts.enums import DebtDirection, DebtOriginType, DebtStatus
from app.domain.debts.policies import require_origin_direction, status_for
from app.domain.errors import DomainError
from app.domain.ledger.enums import AccountEffect, AccountStatus, TransactionKind
from app.domain.ledger.transactions import (
    normalize_optional_text,
    normalize_timestamp,
    require_not_future,
)
from app.domain.money import Money
from app.infrastructure.repositories.accounts import AccountRepository
from app.infrastructure.repositories.debts import DebtRepository, PeopleRepository
from app.infrastructure.repositories.transactions import TransactionRepository


def _name(value: str) -> tuple[str, str]:
    clean = " ".join(value.strip().split())
    if not 1 <= len(clean) <= 120:
        raise DomainError("INVALID_PERSON_NAME", "Person name must contain 1 to 120 characters.")
    return clean, clean.casefold()


@dataclass(frozen=True, slots=True)
class CreatePersonCommand:
    id: UUID
    name: str
    contact: str | None
    notes: str | None


@dataclass(frozen=True, slots=True)
class UpdatePersonCommand:
    version: int
    values: dict[str, object]


class PeopleService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._people = PeopleRepository(session)

    async def create_in_transaction(
        self,
        *,
        user_id: UUID,
        command: CreatePersonCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> PersonSnapshot:
        name, normalized = _name(command.name)
        person = PersonModel(
            id=command.id,
            user_id=user_id,
            name=name,
            normalized_name=normalized,
            contact=normalize_optional_text(command.contact, field="contact", maximum=240),
            notes=normalize_optional_text(command.notes, field="notes", maximum=2000),
            version=1,
        )
        self._people.add(person)
        await self._flush("PERSON_ID_CONFLICT", "This person identifier is unavailable.")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="person",
            entity_id=person.id,
            action="CREATE",
            after={"name": name},
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        await self._session.flush()
        return self._people.snapshot(person)

    async def list_people(self, *, user_id: UUID, include_archived: bool) -> list[PersonSnapshot]:
        return [
            self._people.snapshot(value)
            for value in await self._people.list_owned(
                user_id=user_id, include_archived=include_archived
            )
        ]

    async def update_in_transaction(
        self,
        *,
        person_id: UUID,
        user_id: UUID,
        command: UpdatePersonCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> PersonSnapshot:
        person = await self._people.get_owned(person_id=person_id, user_id=user_id, for_update=True)
        if person is None:
            raise DomainError("PERSON_NOT_FOUND", "Person was not found.")
        if person.version != command.version:
            raise DomainError(
                "VERSION_CONFLICT",
                "This person changed since it was loaded.",
                details={"current_version": person.version},
            )
        before = {
            "name": person.name,
            "archived_at": person.archived_at.isoformat() if person.archived_at else None,
            "version": person.version,
        }
        if "name" in command.values:
            person.name, person.normalized_name = _name(str(command.values["name"]))
        if "contact" in command.values:
            person.contact = normalize_optional_text(
                command.values["contact"] if isinstance(command.values["contact"], str) else None,
                field="contact",
                maximum=240,
            )
        if "notes" in command.values:
            person.notes = normalize_optional_text(
                command.values["notes"] if isinstance(command.values["notes"], str) else None,
                field="notes",
                maximum=2000,
            )
        if "archived" in command.values:
            person.archived_at = datetime.now(UTC) if bool(command.values["archived"]) else None
        person.version += 1
        await self._session.flush()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="person",
            entity_id=person.id,
            action="UPDATE",
            before=before,
            after={
                "name": person.name,
                "archived_at": person.archived_at.isoformat() if person.archived_at else None,
                "version": person.version,
            },
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        return self._people.snapshot(person)

    async def _flush(self, code: str, message: str) -> None:
        try:
            await self._session.flush()
        except IntegrityError as exc:
            raise DomainError(code, message) from exc


@dataclass(frozen=True, slots=True)
class CreateDebtCommand:
    id: UUID
    client_operation_id: UUID
    person_id: UUID
    direction: DebtDirection
    origin_type: DebtOriginType
    amount: Money
    due_date: date | None
    note: str | None
    account_id: UUID | None
    transaction_id: UUID | None
    occurred_at: datetime | None


@dataclass(frozen=True, slots=True)
class RepayDebtCommand:
    id: UUID
    client_operation_id: UUID
    transaction_id: UUID
    account_id: UUID
    amount: Money
    paid_at: datetime
    note: str | None


@dataclass(frozen=True, slots=True)
class CancelDebtCommand:
    version: int
    reason: str


class DebtService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._debts = DebtRepository(session)
        self._people = PeopleRepository(session)
        self._accounts = AccountRepository(session)
        self._transactions = TransactionRepository(session)

    async def create_in_transaction(
        self, *, user_id: UUID, command: CreateDebtCommand, request_id: str | None
    ) -> DebtSnapshot:
        command.amount.require_positive()
        require_origin_direction(origin=command.origin_type, direction=command.direction)
        person = await self._people.get_owned(person_id=command.person_id, user_id=user_id)
        if person is None or person.archived_at is not None:
            raise DomainError("PERSON_NOT_FOUND", "Person was not found.")
        cash_origin = command.origin_type in {DebtOriginType.LEND_NOW, DebtOriginType.BORROW_NOW}
        if cash_origin != (
            command.account_id is not None
            and command.transaction_id is not None
            and command.occurred_at is not None
        ):
            raise DomainError(
                "INVALID_DEBT_ORIGIN",
                "Cash debt origins require an account, transaction ID, and occurrence time; "
                "existing debts require none.",
            )
        movement = None
        if cash_origin:
            if (
                command.account_id is None
                or command.transaction_id is None
                or command.occurred_at is None
            ):
                raise RuntimeError("Validated cash debt origin is incomplete.")
            occurred_at = normalize_timestamp(command.occurred_at)
            require_not_future(occurred_at)
            account = await self._require_account(
                user_id=user_id,
                account_id=command.account_id,
                money=command.amount,
                for_update=True,
            )
            if occurred_at < account.opened_at:
                raise DomainError(
                    "TRANSACTION_BEFORE_ACCOUNT_OPENED",
                    "Debt movement cannot be before the account opening time.",
                )
            kind = (
                TransactionKind.LOAN_PRINCIPAL_OUT
                if command.origin_type is DebtOriginType.LEND_NOW
                else TransactionKind.LOAN_PRINCIPAL_IN
            )
            effect = (
                AccountEffect.OUTFLOW
                if kind is TransactionKind.LOAN_PRINCIPAL_OUT
                else AccountEffect.INFLOW
            )
            await self._require_projected_balance(
                account=account,
                user_id=user_id,
                amount=command.amount,
                effect=effect,
                effective_at=occurred_at,
            )
            movement = build_posted_movement(
                transaction_id=command.transaction_id,
                user_id=user_id,
                account=account,
                kind=kind,
                effect=effect,
                amount=command.amount,
                occurred_at=occurred_at,
                counterparty=person.name,
                note=normalize_optional_text(command.note, field="note", maximum=2000),
                client_operation_id=uuid5(command.client_operation_id, "debt-origin"),
            )
            self._transactions.add(movement)
            await self._session.flush()
            account.version += 1
        debt = DebtModel(
            id=command.id,
            user_id=user_id,
            person_id=person.id,
            direction=command.direction.value,
            origin_type=command.origin_type.value,
            origin_transaction_id=movement.id if movement else None,
            original_amount=command.amount.amount,
            currency=command.amount.currency,
            due_date=command.due_date,
            status=DebtStatus.OPEN.value,
            note=normalize_optional_text(command.note, field="note", maximum=2000),
            client_operation_id=command.client_operation_id,
            version=1,
        )
        self._debts.add_debt(debt)
        await self._flush_conflicts()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="debt",
            entity_id=debt.id,
            action="CREATE",
            after={
                "person_id": str(person.id),
                "direction": debt.direction,
                "origin_type": debt.origin_type,
                "amount": command.amount.to_api(),
                "currency": command.amount.currency,
                "origin_transaction_id": str(movement.id) if movement else None,
            },
            request_id=request_id,
            client_operation_id=command.client_operation_id,
        )
        await self._session.flush()
        return await self._debts.snapshot_for(debt)

    async def list_debts(
        self,
        *,
        user_id: UUID,
        person_id: UUID | None,
        statuses: set[DebtStatus] | None,
        directions: set[DebtDirection] | None,
    ) -> list[DebtSnapshot]:
        models = await self._debts.list_owned(
            user_id=user_id,
            person_id=person_id,
            statuses={v.value for v in statuses} if statuses else None,
            directions={v.value for v in directions} if directions else None,
        )
        return [await self._debts.snapshot_for(model) for model in models]

    async def get_debt(self, *, debt_id: UUID, user_id: UUID) -> DebtSnapshot:
        debt = await self._debts.get_owned(debt_id=debt_id, user_id=user_id)
        if debt is None:
            raise DomainError("DEBT_NOT_FOUND", "Debt was not found.")
        return await self._debts.snapshot_for(debt)

    async def repay_in_transaction(
        self, *, debt_id: UUID, user_id: UUID, command: RepayDebtCommand, request_id: str | None
    ) -> DebtSnapshot:
        command.amount.require_positive()
        paid_at = normalize_timestamp(command.paid_at)
        require_not_future(paid_at)
        debt = await self._debts.get_owned(debt_id=debt_id, user_id=user_id, for_update=True)
        if debt is None:
            raise DomainError("DEBT_NOT_FOUND", "Debt was not found.")
        if debt.status not in {DebtStatus.OPEN.value, DebtStatus.PARTIALLY_PAID.value}:
            raise DomainError(
                "DEBT_NOT_OPEN", "Only an open or partially paid debt accepts a payment."
            )
        if command.amount.currency != debt.currency:
            raise DomainError("CURRENCY_MISMATCH", "Payment currency must match the debt.")
        paid = await self._debts.paid_amount(debt_id=debt.id, user_id=user_id)
        remaining = debt.original_amount - paid
        if command.amount.amount > remaining:
            raise DomainError(
                "DEBT_OVERPAYMENT",
                "Payment exceeds the remaining debt.",
                details={"remaining_amount": format(remaining, ".4f"), "currency": debt.currency},
            )
        account = await self._require_account(
            user_id=user_id, account_id=command.account_id, money=command.amount, for_update=True
        )
        if paid_at < account.opened_at:
            raise DomainError(
                "TRANSACTION_BEFORE_ACCOUNT_OPENED",
                "Debt payment cannot be before the account opening time.",
            )
        direction = DebtDirection(debt.direction)
        kind = (
            TransactionKind.DEBT_REPAYMENT_IN
            if direction is DebtDirection.RECEIVABLE
            else TransactionKind.DEBT_REPAYMENT_OUT
        )
        effect = (
            AccountEffect.INFLOW if direction is DebtDirection.RECEIVABLE else AccountEffect.OUTFLOW
        )
        await self._require_projected_balance(
            account=account,
            user_id=user_id,
            amount=command.amount,
            effect=effect,
            effective_at=paid_at,
        )
        person = await self._people.get_owned(person_id=debt.person_id, user_id=user_id)
        movement = build_posted_movement(
            transaction_id=command.transaction_id,
            user_id=user_id,
            account=account,
            kind=kind,
            effect=effect,
            amount=command.amount,
            occurred_at=paid_at,
            counterparty=person.name if person else None,
            note=normalize_optional_text(command.note, field="note", maximum=2000),
            client_operation_id=uuid5(command.client_operation_id, "debt-payment"),
        )
        payment = DebtPaymentModel(
            id=command.id,
            user_id=user_id,
            debt_id=debt.id,
            transaction_id=movement.id,
            amount=command.amount.amount,
            paid_at=paid_at,
            client_operation_id=command.client_operation_id,
        )
        self._transactions.add(movement)
        await self._session.flush()
        self._debts.add_payment(payment)
        debt.status = status_for(
            original=debt.original_amount, paid=paid + command.amount.amount
        ).value
        debt.version += 1
        account.version += 1
        await self._flush_conflicts()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="debt",
            entity_id=debt.id,
            action="PAYMENT",
            after={
                "payment_id": str(payment.id),
                "transaction_id": str(movement.id),
                "amount": command.amount.to_api(),
                "remaining_amount": format(remaining - command.amount.amount, ".4f"),
                "status": debt.status,
            },
            request_id=request_id,
            client_operation_id=command.client_operation_id,
        )
        await self._session.flush()
        return await self._debts.snapshot_for(debt)

    async def cancel_in_transaction(
        self,
        *,
        debt_id: UUID,
        user_id: UUID,
        command: CancelDebtCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> DebtSnapshot:
        debt = await self._debts.get_owned(debt_id=debt_id, user_id=user_id, for_update=True)
        if debt is None:
            raise DomainError("DEBT_NOT_FOUND", "Debt was not found.")
        if debt.version != command.version:
            raise DomainError(
                "VERSION_CONFLICT",
                "This debt changed since it was loaded.",
                details={"current_version": debt.version},
            )
        if debt.status == DebtStatus.SETTLED.value:
            raise DomainError("DEBT_ALREADY_SETTLED", "A settled debt cannot be cancelled.")
        reason = normalize_optional_text(command.reason, field="reason", maximum=1000)
        if reason is None:
            raise DomainError(
                "CANCELLATION_REASON_REQUIRED", "Explain why the debt is being cancelled."
            )
        debt.status = DebtStatus.CANCELLED.value
        debt.cancelled_at = datetime.now(UTC)
        debt.cancellation_reason = reason
        debt.version += 1
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="debt",
            entity_id=debt.id,
            action="CANCEL",
            after={"status": debt.status, "reason": reason, "version": debt.version},
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        await self._session.flush()
        return await self._debts.snapshot_for(debt)

    async def _require_account(
        self, *, user_id: UUID, account_id: UUID, money: Money, for_update: bool
    ) -> AccountModel:
        account = await self._accounts.get_owned(
            account_id=account_id, user_id=user_id, for_update=for_update
        )
        if account is None:
            raise DomainError("ACCOUNT_NOT_FOUND", "Account was not found.")
        if account.currency != money.currency:
            raise DomainError(
                "CURRENCY_MISMATCH", "Debt movement currency must match the selected account."
            )
        if AccountStatus(account.status) is not AccountStatus.ACTIVE:
            code = (
                "ACCOUNT_CLOSED"
                if account.status == AccountStatus.CLOSED.value
                else "ACCOUNT_READ_ONLY"
            )
            raise DomainError(code, "Only an active account accepts debt movements.")
        return account

    async def _require_projected_balance(
        self,
        *,
        account: AccountModel,
        user_id: UUID,
        amount: Money,
        effect: AccountEffect,
        effective_at: datetime,
    ) -> None:
        if account.allow_negative or effect is AccountEffect.INFLOW:
            return
        snapshot = await self._accounts.get_snapshot(
            account_id=account.id, user_id=user_id, as_of=max(datetime.now(UTC), effective_at)
        )
        if snapshot is None:
            raise DomainError("ACCOUNT_NOT_FOUND", "Account was not found.")
        projected = snapshot.calculated_balance - amount
        if projected.amount < 0:
            raise DomainError(
                "NEGATIVE_BALANCE_NOT_ALLOWED",
                "This debt movement would make the account balance negative.",
                details={
                    "current_balance": snapshot.calculated_balance.to_api(),
                    "projected_balance": projected.to_api(),
                    "currency": account.currency,
                },
            )

    async def _flush_conflicts(self) -> None:
        try:
            await self._session.flush()
        except IntegrityError as exc:
            constraint = getattr(getattr(exc.orig, "__cause__", None), "constraint_name", None)
            if constraint in {"pk_debts", "pk_debt_payments", "pk_transactions"}:
                raise DomainError(
                    "DEBT_ID_CONFLICT", "A debt operation identifier is unavailable."
                ) from exc
            if constraint in {
                "uq_debts_user_client_operation",
                "uq_debt_payments_user_client_operation",
                "uq_transactions_user_client_operation",
            }:
                raise DomainError(
                    "DEBT_OPERATION_CONFLICT",
                    "This client operation already belongs to another debt operation.",
                ) from exc
            raise
