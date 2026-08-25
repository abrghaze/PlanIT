from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import Select, case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.ledger import AccountModel, TransactionModel
from app.domain.accounts.entities import AccountSnapshot
from app.domain.ledger.enums import TransactionStatus
from app.domain.money import Money


class AccountRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def add(self, account: AccountModel) -> None:
        self._session.add(account)

    async def get_owned(
        self,
        *,
        account_id: UUID,
        user_id: UUID,
        for_update: bool = False,
    ) -> AccountModel | None:
        statement = select(AccountModel).where(
            AccountModel.id == account_id,
            AccountModel.user_id == user_id,
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    async def has_posted_activity(self, account_id: UUID) -> bool:
        statement = (
            select(TransactionModel.id)
            .where(
                TransactionModel.account_id == account_id,
                TransactionModel.status.in_(
                    [TransactionStatus.POSTED.value, TransactionStatus.REVERSED.value]
                ),
            )
            .limit(1)
        )
        return (await self._session.scalar(statement)) is not None

    async def list_snapshots(
        self,
        *,
        user_id: UUID,
        as_of: datetime,
        statuses: set[str] | None = None,
    ) -> list[AccountSnapshot]:
        statement = self._snapshot_statement(user_id=user_id, as_of=as_of)
        if statuses:
            statement = statement.where(AccountModel.status.in_(statuses))
        statement = statement.order_by(
            AccountModel.sort_order, AccountModel.created_at, AccountModel.id
        )
        rows = (await self._session.execute(statement)).all()
        return [self._to_snapshot(account, balance, as_of) for account, balance in rows]

    async def get_snapshot(
        self,
        *,
        account_id: UUID,
        user_id: UUID,
        as_of: datetime,
    ) -> AccountSnapshot | None:
        statement = self._snapshot_statement(user_id=user_id, as_of=as_of).where(
            AccountModel.id == account_id
        )
        row = (await self._session.execute(statement)).one_or_none()
        if row is None:
            return None
        account, balance = row
        return self._to_snapshot(account, balance, as_of)

    @staticmethod
    def _snapshot_statement(
        *, user_id: UUID, as_of: datetime
    ) -> Select[tuple[AccountModel, Decimal]]:
        signed_amount = case(
            (TransactionModel.effect == "INFLOW", TransactionModel.amount),
            else_=-TransactionModel.amount,
        )
        movement_totals = (
            select(
                TransactionModel.account_id.label("account_id"),
                func.sum(signed_amount).label("movement_total"),
            )
            .where(
                TransactionModel.user_id == user_id,
                TransactionModel.status.in_(
                    [TransactionStatus.POSTED.value, TransactionStatus.REVERSED.value]
                ),
                TransactionModel.occurred_at <= as_of,
            )
            .group_by(TransactionModel.account_id)
            .subquery()
        )
        balance = (
            AccountModel.opening_balance
            + func.coalesce(movement_totals.c.movement_total, Decimal("0.0000"))
        ).label("calculated_balance")
        return (
            select(AccountModel, balance)
            .outerjoin(movement_totals, movement_totals.c.account_id == AccountModel.id)
            .where(AccountModel.user_id == user_id)
        )

    @staticmethod
    def _to_snapshot(
        account: AccountModel,
        balance: Decimal,
        as_of: datetime,
    ) -> AccountSnapshot:
        return AccountSnapshot(
            id=account.id,
            user_id=account.user_id,
            name=account.name,
            type=account.type,
            currency=account.currency,
            opening_balance=Money(account.opening_balance, account.currency),
            calculated_balance=Money(balance, account.currency),
            opened_at=account.opened_at,
            include_in_total=account.include_in_total,
            allow_negative=account.allow_negative,
            status=account.status,
            sort_order=account.sort_order,
            archived_at=account.archived_at,
            closed_at=account.closed_at,
            version=account.version,
            created_at=account.created_at,
            updated_at=account.updated_at,
            balance_as_of=as_of,
        )
