from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.audit import add_audit_event
from app.application.ledger_posting import build_posted_movement
from app.db.models.ledger import DebtModel, SharedExpenseShareModel, TransactionModel
from app.domain.debts.entities import RefundSnapshot, SharedExpenseShareSnapshot
from app.domain.debts.enums import (
    DebtDirection,
    DebtOriginType,
    DebtStatus,
    SharedExpenseShareStatus,
)
from app.domain.errors import DomainError
from app.domain.ledger.enums import AccountEffect, AccountStatus, TransactionKind, TransactionStatus
from app.domain.ledger.transactions import (
    normalize_optional_text,
    normalize_timestamp,
    require_not_future,
)
from app.domain.money import Money
from app.infrastructure.repositories.accounts import AccountRepository
from app.infrastructure.repositories.debts import DebtRepository, PeopleRepository
from app.infrastructure.repositories.transactions import TransactionRepository


@dataclass(frozen=True, slots=True)
class CreateShareCommand:
    id: UUID
    debt_id: UUID
    client_operation_id: UUID
    person_id: UUID
    amount: Money
    due_date: date | None
    note: str | None


@dataclass(frozen=True, slots=True)
class UpdateShareCommand:
    version: int
    amount: Money | None
    cancel: bool
    reason: str | None


@dataclass(frozen=True, slots=True)
class CreateRefundCommand:
    id: UUID
    client_operation_id: UUID
    account_id: UUID
    amount: Money
    occurred_at: datetime
    note: str | None


class SharingService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._debts = DebtRepository(session)
        self._people = PeopleRepository(session)
        self._transactions = TransactionRepository(session)
        self._accounts = AccountRepository(session)

    async def create_share_in_transaction(
        self,
        *,
        transaction_id: UUID,
        user_id: UUID,
        command: CreateShareCommand,
        request_id: str | None,
    ) -> SharedExpenseShareSnapshot:
        command.amount.require_positive()
        expense = await self._require_expense(
            transaction_id=transaction_id,
            user_id=user_id,
            for_update=True,
        )
        if command.amount.currency != expense.currency:
            raise DomainError("CURRENCY_MISMATCH", "Share currency must match the expense.")
        person = await self._people.get_owned(person_id=command.person_id, user_id=user_id)
        if person is None or person.archived_at is not None:
            raise DomainError("PERSON_NOT_FOUND", "Person was not found.")
        refunds = await self._debts.refund_total(transaction_id=expense.id, user_id=user_id)
        shares = await self._debts.active_share_total(transaction_id=expense.id, user_id=user_id)
        available = expense.amount - refunds - shares
        if command.amount.amount > available:
            raise DomainError(
                "SHARED_EXPENSE_CAP_EXCEEDED",
                "Share exceeds the amount still available on this expense.",
                details={
                    "available_amount": format(available, ".4f"),
                    "currency": expense.currency,
                },
            )
        note = normalize_optional_text(command.note, field="note", maximum=2000)
        debt = DebtModel(
            id=command.debt_id,
            user_id=user_id,
            person_id=person.id,
            direction=DebtDirection.RECEIVABLE.value,
            origin_type=DebtOriginType.SHARED_EXPENSE.value,
            origin_transaction_id=expense.id,
            original_amount=command.amount.amount,
            currency=expense.currency,
            due_date=command.due_date,
            status=DebtStatus.OPEN.value,
            note=note,
            client_operation_id=command.client_operation_id,
            version=1,
        )
        share = SharedExpenseShareModel(
            id=command.id,
            user_id=user_id,
            transaction_id=expense.id,
            person_id=person.id,
            amount=command.amount.amount,
            debt_id=debt.id,
            status=SharedExpenseShareStatus.ACTIVE.value,
            client_operation_id=command.client_operation_id,
            version=1,
        )
        self._debts.add_debt(debt)
        self._debts.add_share(share)
        await self._flush_share()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="shared_expense_share",
            entity_id=share.id,
            action="CREATE",
            after={
                "transaction_id": str(expense.id),
                "person_id": str(person.id),
                "debt_id": str(debt.id),
                "amount": command.amount.to_api(),
                "currency": command.amount.currency,
            },
            request_id=request_id,
            client_operation_id=command.client_operation_id,
        )
        await self._session.flush()
        return await self._debts.share_snapshot_for(share)

    async def list_shares(
        self, *, transaction_id: UUID, user_id: UUID
    ) -> list[SharedExpenseShareSnapshot]:
        await self._require_expense(
            transaction_id=transaction_id,
            user_id=user_id,
            for_update=False,
        )
        return [
            await self._debts.share_snapshot_for(value)
            for value in await self._debts.shares_for_transaction(
                transaction_id=transaction_id,
                user_id=user_id,
            )
        ]

    async def update_share_in_transaction(
        self,
        *,
        share_id: UUID,
        user_id: UUID,
        command: UpdateShareCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> SharedExpenseShareSnapshot:
        share = await self._debts.get_share_owned(
            share_id=share_id,
            user_id=user_id,
        )
        if share is None:
            raise DomainError("SHARE_NOT_FOUND", "Shared-expense share was not found.")
        expense = await self._require_expense(
            transaction_id=share.transaction_id,
            user_id=user_id,
            for_update=True,
        )
        share = await self._debts.get_share_owned(
            share_id=share_id,
            user_id=user_id,
            for_update=True,
        )
        if share is None:
            raise DomainError("SHARE_NOT_FOUND", "Shared-expense share was not found.")
        if share.version != command.version:
            raise DomainError(
                "VERSION_CONFLICT",
                "This share changed since it was loaded.",
                details={"current_version": share.version},
            )
        debt = await self._debts.get_owned(
            debt_id=share.debt_id,
            user_id=user_id,
            for_update=True,
        )
        if debt is None:
            raise RuntimeError("Shared-expense debt could not be found.")
        paid = await self._debts.paid_amount(debt_id=debt.id, user_id=user_id)
        before = {
            "amount": format(share.amount, ".4f"),
            "status": share.status,
            "version": share.version,
        }
        if command.cancel:
            if paid > 0:
                raise DomainError(
                    "SHARE_HAS_PAYMENTS",
                    "A share with repayments cannot be cancelled; adjust it to at least the "
                    "paid amount.",
                )
            reason = normalize_optional_text(command.reason, field="reason", maximum=1000)
            if reason is None:
                raise DomainError(
                    "CANCELLATION_REASON_REQUIRED", "Explain why the share is being cancelled."
                )
            share.status = SharedExpenseShareStatus.CANCELLED.value
            debt.status = DebtStatus.CANCELLED.value
            debt.cancelled_at = datetime.now(UTC)
            debt.cancellation_reason = reason
        else:
            if command.amount is None:
                raise DomainError("SHARE_AMOUNT_REQUIRED", "Supply a new share amount.")
            command.amount.require_positive()
            if command.amount.currency != expense.currency:
                raise DomainError("CURRENCY_MISMATCH", "Share currency must match the expense.")
            if command.amount.amount < paid:
                raise DomainError(
                    "SHARE_BELOW_PAID_AMOUNT",
                    "Share cannot be reduced below the amount already repaid.",
                    details={"paid_amount": format(paid, ".4f"), "currency": expense.currency},
                )
            refunds = await self._debts.refund_total(transaction_id=expense.id, user_id=user_id)
            other_shares = (
                await self._debts.active_share_total(transaction_id=expense.id, user_id=user_id)
                - share.amount
            )
            available = expense.amount - refunds - other_shares
            if command.amount.amount > available:
                raise DomainError(
                    "SHARED_EXPENSE_CAP_EXCEEDED",
                    "Share exceeds the amount still available on this expense.",
                    details={
                        "available_amount": format(available, ".4f"),
                        "currency": expense.currency,
                    },
                )
            share.amount = command.amount.amount
            debt.original_amount = command.amount.amount
            debt.status = (
                DebtStatus.SETTLED.value
                if paid == command.amount.amount
                else DebtStatus.PARTIALLY_PAID.value
                if paid > 0
                else DebtStatus.OPEN.value
            )
        share.version += 1
        debt.version += 1
        await self._session.flush()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="shared_expense_share",
            entity_id=share.id,
            action="CANCEL" if command.cancel else "ADJUST",
            before=before,
            after={
                "amount": format(share.amount, ".4f"),
                "status": share.status,
                "version": share.version,
            },
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        return await self._debts.share_snapshot_for(share)

    async def refund_in_transaction(
        self,
        *,
        transaction_id: UUID,
        user_id: UUID,
        command: CreateRefundCommand,
        request_id: str | None,
    ) -> RefundSnapshot:
        command.amount.require_positive()
        occurred_at = normalize_timestamp(command.occurred_at)
        require_not_future(occurred_at)
        expense = await self._require_expense(
            transaction_id=transaction_id,
            user_id=user_id,
            for_update=True,
        )
        if occurred_at < expense.occurred_at:
            raise DomainError(
                "REFUND_BEFORE_EXPENSE", "Refund cannot occur before the original expense."
            )
        if command.amount.currency != expense.currency:
            raise DomainError(
                "CURRENCY_MISMATCH", "Refund currency must match the original expense."
            )
        prior_refunds = await self._debts.refund_total(transaction_id=expense.id, user_id=user_id)
        refundable = expense.amount - prior_refunds
        if command.amount.amount > refundable:
            raise DomainError(
                "REFUND_EXCEEDS_REMAINING",
                "Refund exceeds the remaining refundable amount.",
                details={
                    "remaining_refundable": format(refundable, ".4f"),
                    "currency": expense.currency,
                },
            )
        active_shares = await self._debts.active_share_total(
            transaction_id=expense.id, user_id=user_id
        )
        remaining_gross = refundable - command.amount.amount
        if active_shares > remaining_gross:
            raise DomainError(
                "REFUND_CONFLICTS_WITH_SHARES",
                "Reduce reimbursement shares before recording this refund.",
                details={
                    "active_share_total": format(active_shares, ".4f"),
                    "maximum_refund": format(refundable - active_shares, ".4f"),
                    "currency": expense.currency,
                },
            )
        account = await self._accounts.get_owned(
            account_id=command.account_id,
            user_id=user_id,
            for_update=True,
        )
        if account is None:
            raise DomainError("ACCOUNT_NOT_FOUND", "Account was not found.")
        if account.currency != command.amount.currency:
            raise DomainError(
                "CURRENCY_MISMATCH", "Refund currency must match the destination account."
            )
        if AccountStatus(account.status) is not AccountStatus.ACTIVE:
            code = (
                "ACCOUNT_CLOSED"
                if account.status == AccountStatus.CLOSED.value
                else "ACCOUNT_READ_ONLY"
            )
            raise DomainError(code, "Only an active account accepts a refund.")
        if occurred_at < account.opened_at:
            raise DomainError(
                "TRANSACTION_BEFORE_ACCOUNT_OPENED",
                "Refund cannot be before the account opening time.",
            )
        refund = build_posted_movement(
            transaction_id=command.id,
            user_id=user_id,
            account=account,
            kind=TransactionKind.REFUND,
            effect=AccountEffect.INFLOW,
            amount=command.amount,
            occurred_at=occurred_at,
            counterparty=expense.counterparty,
            note=normalize_optional_text(command.note, field="note", maximum=2000),
            client_operation_id=command.client_operation_id,
        )
        refund.parent_transaction_id = expense.id
        refund.category_id = expense.category_id
        self._transactions.add(refund)
        tag_ids = set(await self._transactions.tag_ids(transaction_id=expense.id))
        await self._session.flush()
        await self._transactions.replace_tags(
            transaction_id=refund.id, user_id=user_id, tag_ids=tag_ids
        )
        account.version += 1
        await self._flush_refund()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="refund",
            entity_id=refund.id,
            action="CREATE",
            after={
                "original_transaction_id": str(expense.id),
                "account_id": str(account.id),
                "amount": command.amount.to_api(),
                "currency": command.amount.currency,
                "remaining_refundable": format(remaining_gross, ".4f"),
            },
            request_id=request_id,
            client_operation_id=command.client_operation_id,
        )
        snapshot = await self._transactions.snapshot_for(refund)
        return RefundSnapshot(
            original_transaction_id=expense.id,
            refundable_amount=Money(remaining_gross, expense.currency),
            refund_transaction=snapshot,
        )

    async def _require_expense(
        self, *, transaction_id: UUID, user_id: UUID, for_update: bool
    ) -> TransactionModel:
        expense = await self._transactions.get_owned(
            transaction_id=transaction_id,
            user_id=user_id,
            for_update=for_update,
        )
        if expense is None or expense.type != TransactionKind.EXPENSE.value:
            raise DomainError("EXPENSE_NOT_FOUND", "Posted expense was not found.")
        if expense.status != TransactionStatus.POSTED.value:
            raise DomainError(
                "EXPENSE_NOT_POSTED", "Only a posted, unreversed expense can be shared or refunded."
            )
        return expense

    async def _flush_share(self) -> None:
        try:
            await self._session.flush()
        except IntegrityError as exc:
            constraint = getattr(getattr(exc.orig, "__cause__", None), "constraint_name", None)
            if constraint == "uq_shared_expense_shares_transaction_person":
                raise DomainError(
                    "SHARE_ALREADY_EXISTS", "This person already has a share on the expense."
                ) from exc
            if constraint in {"pk_shared_expense_shares", "pk_debts"}:
                raise DomainError(
                    "SHARE_ID_CONFLICT", "A share operation identifier is unavailable."
                ) from exc
            if constraint in {
                "uq_shared_expense_shares_user_client_operation",
                "uq_debts_user_client_operation",
            }:
                raise DomainError(
                    "SHARE_OPERATION_CONFLICT",
                    "This client operation already belongs to another share.",
                ) from exc
            raise

    async def _flush_refund(self) -> None:
        try:
            await self._session.flush()
        except IntegrityError as exc:
            constraint = getattr(getattr(exc.orig, "__cause__", None), "constraint_name", None)
            if constraint == "pk_transactions":
                raise DomainError(
                    "REFUND_ID_CONFLICT", "This refund identifier is unavailable."
                ) from exc
            if constraint == "uq_transactions_user_client_operation":
                raise DomainError(
                    "REFUND_OPERATION_CONFLICT",
                    "This client operation already belongs to another transaction.",
                ) from exc
            raise
