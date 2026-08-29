from __future__ import annotations

from datetime import date
from decimal import Decimal
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.ledger import (
    DebtModel,
    DebtPaymentModel,
    PersonModel,
    SharedExpenseShareModel,
    TransactionModel,
)
from app.domain.debts.entities import (
    DebtPaymentSnapshot,
    DebtSnapshot,
    PersonSnapshot,
    SharedExpenseShareSnapshot,
)
from app.domain.debts.enums import DebtStatus
from app.domain.money import Money
from app.infrastructure.repositories.transactions import TransactionRepository


class PeopleRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def add(self, person: PersonModel) -> None:
        self._session.add(person)

    async def get_owned(
        self, *, person_id: UUID, user_id: UUID, for_update: bool = False
    ) -> PersonModel | None:
        statement = select(PersonModel).where(
            PersonModel.id == person_id, PersonModel.user_id == user_id
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    async def list_owned(self, *, user_id: UUID, include_archived: bool) -> list[PersonModel]:
        statement = select(PersonModel).where(PersonModel.user_id == user_id)
        if not include_archived:
            statement = statement.where(PersonModel.archived_at.is_(None))
        return list(
            (
                await self._session.scalars(
                    statement.order_by(PersonModel.normalized_name, PersonModel.id)
                )
            ).all()
        )

    @staticmethod
    def snapshot(model: PersonModel) -> PersonSnapshot:
        return PersonSnapshot(
            id=model.id,
            user_id=model.user_id,
            name=model.name,
            contact=model.contact,
            notes=model.notes,
            archived_at=model.archived_at,
            version=model.version,
            created_at=model.created_at,
            updated_at=model.updated_at,
        )


class DebtRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._transactions = TransactionRepository(session)

    def add_debt(self, debt: DebtModel) -> None:
        self._session.add(debt)

    def add_payment(self, payment: DebtPaymentModel) -> None:
        self._session.add(payment)

    def add_share(self, share: SharedExpenseShareModel) -> None:
        self._session.add(share)

    async def get_owned(
        self, *, debt_id: UUID, user_id: UUID, for_update: bool = False
    ) -> DebtModel | None:
        statement = select(DebtModel).where(DebtModel.id == debt_id, DebtModel.user_id == user_id)
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    async def list_owned(
        self,
        *,
        user_id: UUID,
        person_id: UUID | None,
        statuses: set[str] | None,
        directions: set[str] | None,
    ) -> list[DebtModel]:
        statement = select(DebtModel).where(DebtModel.user_id == user_id)
        if person_id is not None:
            statement = statement.where(DebtModel.person_id == person_id)
        if statuses:
            statement = statement.where(DebtModel.status.in_(statuses))
        if directions:
            statement = statement.where(DebtModel.direction.in_(directions))
        return list(
            (
                await self._session.scalars(
                    statement.order_by(
                        DebtModel.due_date.asc().nulls_last(),
                        DebtModel.created_at.desc(),
                        DebtModel.id,
                    )
                )
            ).all()
        )

    async def payments_for(self, *, debt_id: UUID, user_id: UUID) -> list[DebtPaymentModel]:
        statement = (
            select(DebtPaymentModel)
            .where(DebtPaymentModel.debt_id == debt_id, DebtPaymentModel.user_id == user_id)
            .order_by(DebtPaymentModel.paid_at, DebtPaymentModel.id)
        )
        return list((await self._session.scalars(statement)).all())

    async def paid_amount(self, *, debt_id: UUID, user_id: UUID) -> Decimal:
        value = await self._session.scalar(
            select(func.coalesce(func.sum(DebtPaymentModel.amount), Decimal("0.0000"))).where(
                DebtPaymentModel.debt_id == debt_id, DebtPaymentModel.user_id == user_id
            )
        )
        return Decimal(value or 0)

    async def get_share_owned(
        self, *, share_id: UUID, user_id: UUID, for_update: bool = False
    ) -> SharedExpenseShareModel | None:
        statement = select(SharedExpenseShareModel).where(
            SharedExpenseShareModel.id == share_id, SharedExpenseShareModel.user_id == user_id
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    async def shares_for_transaction(
        self, *, transaction_id: UUID, user_id: UUID
    ) -> list[SharedExpenseShareModel]:
        statement = (
            select(SharedExpenseShareModel)
            .where(
                SharedExpenseShareModel.transaction_id == transaction_id,
                SharedExpenseShareModel.user_id == user_id,
            )
            .order_by(SharedExpenseShareModel.created_at, SharedExpenseShareModel.id)
        )
        return list((await self._session.scalars(statement)).all())

    async def active_share_total(self, *, transaction_id: UUID, user_id: UUID) -> Decimal:
        value = await self._session.scalar(
            select(
                func.coalesce(func.sum(SharedExpenseShareModel.amount), Decimal("0.0000"))
            ).where(
                SharedExpenseShareModel.transaction_id == transaction_id,
                SharedExpenseShareModel.user_id == user_id,
                SharedExpenseShareModel.status == "ACTIVE",
            )
        )
        return Decimal(value or 0)

    async def refund_total(self, *, transaction_id: UUID, user_id: UUID) -> Decimal:
        value = await self._session.scalar(
            select(func.coalesce(func.sum(TransactionModel.amount), Decimal("0.0000"))).where(
                TransactionModel.parent_transaction_id == transaction_id,
                TransactionModel.user_id == user_id,
                TransactionModel.type == "REFUND",
                TransactionModel.status.in_(["POSTED", "REVERSED"]),
            )
        )
        return Decimal(value or 0)

    async def snapshot_for(self, debt: DebtModel) -> DebtSnapshot:
        await self._session.refresh(debt)
        payments = await self.payments_for(debt_id=debt.id, user_id=debt.user_id)
        paid = sum((payment.amount for payment in payments), Decimal("0.0000"))
        origin = None
        if debt.origin_transaction_id is not None:
            origin = await self._transactions.get_snapshot(
                transaction_id=debt.origin_transaction_id, user_id=debt.user_id
            )
        payment_snapshots: list[DebtPaymentSnapshot] = []
        for payment in payments:
            transaction = await self._transactions.get_snapshot(
                transaction_id=payment.transaction_id, user_id=debt.user_id
            )
            if transaction is None:
                raise RuntimeError("Debt payment movement could not be read back.")
            payment_snapshots.append(
                DebtPaymentSnapshot(
                    id=payment.id,
                    amount=Money(payment.amount, debt.currency),
                    paid_at=payment.paid_at,
                    transaction=transaction,
                    client_operation_id=payment.client_operation_id,
                    created_at=payment.created_at,
                )
            )
        remaining = debt.original_amount - paid
        return DebtSnapshot(
            id=debt.id,
            user_id=debt.user_id,
            person_id=debt.person_id,
            direction=debt.direction,
            origin_type=debt.origin_type,
            origin_transaction=origin,
            original_amount=Money(debt.original_amount, debt.currency),
            paid_amount=Money(paid, debt.currency),
            remaining_amount=Money(remaining, debt.currency),
            due_date=debt.due_date,
            status=debt.status,
            overdue=debt.status in {DebtStatus.OPEN.value, DebtStatus.PARTIALLY_PAID.value}
            and debt.due_date is not None
            and debt.due_date < date.today(),
            note=debt.note,
            cancellation_reason=debt.cancellation_reason,
            client_operation_id=debt.client_operation_id,
            version=debt.version,
            payments=tuple(payment_snapshots),
            created_at=debt.created_at,
            updated_at=debt.updated_at,
        )

    async def share_snapshot_for(
        self, share: SharedExpenseShareModel
    ) -> SharedExpenseShareSnapshot:
        await self._session.refresh(share)
        debt = await self.get_owned(debt_id=share.debt_id, user_id=share.user_id)
        if debt is None:
            raise RuntimeError("Shared-expense debt could not be read back.")
        debt_snapshot = await self.snapshot_for(debt)
        return SharedExpenseShareSnapshot(
            id=share.id,
            transaction_id=share.transaction_id,
            person_id=share.person_id,
            amount=Money(share.amount, debt.currency),
            debt=debt_snapshot,
            status=share.status,
            client_operation_id=share.client_operation_id,
            version=share.version,
            created_at=share.created_at,
            updated_at=share.updated_at,
        )
