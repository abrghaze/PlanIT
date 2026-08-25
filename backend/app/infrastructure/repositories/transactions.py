from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.ledger import TransactionModel, TransactionTagModel
from app.domain.ledger.entities import TransactionSnapshot
from app.domain.money import Money


class TransactionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def add(self, transaction: TransactionModel) -> None:
        self._session.add(transaction)

    async def get_owned(
        self,
        *,
        transaction_id: UUID,
        user_id: UUID,
        for_update: bool = False,
    ) -> TransactionModel | None:
        statement = select(TransactionModel).where(
            TransactionModel.id == transaction_id,
            TransactionModel.user_id == user_id,
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    async def list_snapshots(
        self,
        *,
        user_id: UUID,
        statuses: set[str] | None,
        kinds: set[str] | None,
        account_id: UUID | None,
        category_id: UUID | None,
        tag_id: UUID | None,
        occurred_from: datetime | None,
        occurred_to: datetime | None,
        limit: int,
        offset: int,
    ) -> list[TransactionSnapshot]:
        statement = select(TransactionModel).where(TransactionModel.user_id == user_id)
        if statuses:
            statement = statement.where(TransactionModel.status.in_(statuses))
        if kinds:
            statement = statement.where(TransactionModel.type.in_(kinds))
        if account_id is not None:
            statement = statement.where(TransactionModel.account_id == account_id)
        if category_id is not None:
            statement = statement.where(TransactionModel.category_id == category_id)
        if tag_id is not None:
            tagged_ids = select(TransactionTagModel.transaction_id).where(
                TransactionTagModel.user_id == user_id,
                TransactionTagModel.tag_id == tag_id,
            )
            statement = statement.where(TransactionModel.id.in_(tagged_ids))
        if occurred_from is not None:
            statement = statement.where(TransactionModel.occurred_at >= occurred_from)
        if occurred_to is not None:
            statement = statement.where(TransactionModel.occurred_at <= occurred_to)
        statement = (
            statement.order_by(
                TransactionModel.occurred_at.desc(),
                TransactionModel.id.desc(),
            )
            .offset(offset)
            .limit(limit)
        )
        models = list((await self._session.scalars(statement)).all())
        tags = await self._tag_map([model.id for model in models])
        return [self._to_snapshot(model, tags.get(model.id, ())) for model in models]

    async def get_snapshot(
        self,
        *,
        transaction_id: UUID,
        user_id: UUID,
    ) -> TransactionSnapshot | None:
        model = await self.get_owned(transaction_id=transaction_id, user_id=user_id)
        if model is None:
            return None
        tags = await self.tag_ids(transaction_id=model.id)
        return self._to_snapshot(model, tags)

    async def snapshot_for(self, model: TransactionModel) -> TransactionSnapshot:
        await self._session.refresh(model)
        return self._to_snapshot(model, await self.tag_ids(transaction_id=model.id))

    async def tag_ids(self, *, transaction_id: UUID) -> tuple[UUID, ...]:
        statement = (
            select(TransactionTagModel.tag_id)
            .where(TransactionTagModel.transaction_id == transaction_id)
            .order_by(TransactionTagModel.tag_id)
        )
        return tuple((await self._session.scalars(statement)).all())

    async def replace_tags(
        self,
        *,
        transaction_id: UUID,
        user_id: UUID,
        tag_ids: set[UUID],
    ) -> None:
        await self._session.execute(
            delete(TransactionTagModel).where(
                TransactionTagModel.transaction_id == transaction_id,
                TransactionTagModel.user_id == user_id,
            )
        )
        self._session.add_all(
            TransactionTagModel(
                transaction_id=transaction_id,
                tag_id=tag_id,
                user_id=user_id,
            )
            for tag_id in sorted(tag_ids, key=str)
        )

    async def delete_draft(self, transaction: TransactionModel) -> None:
        await self._session.delete(transaction)

    async def _tag_map(self, transaction_ids: list[UUID]) -> dict[UUID, tuple[UUID, ...]]:
        if not transaction_ids:
            return {}
        statement = (
            select(TransactionTagModel.transaction_id, TransactionTagModel.tag_id)
            .where(TransactionTagModel.transaction_id.in_(transaction_ids))
            .order_by(TransactionTagModel.transaction_id, TransactionTagModel.tag_id)
        )
        result: dict[UUID, list[UUID]] = {}
        for transaction_id, tag_id in (await self._session.execute(statement)).all():
            result.setdefault(transaction_id, []).append(tag_id)
        return {key: tuple(value) for key, value in result.items()}

    @staticmethod
    def _to_snapshot(
        model: TransactionModel,
        tag_ids: tuple[UUID, ...],
    ) -> TransactionSnapshot:
        return TransactionSnapshot(
            id=model.id,
            user_id=model.user_id,
            account_id=model.account_id,
            kind=model.type,
            effect=model.effect,
            amount=Money(model.amount, model.currency),
            occurred_at=model.occurred_at,
            status=model.status,
            category_id=model.category_id,
            counterparty=model.counterparty,
            note=model.note,
            tag_ids=tag_ids,
            parent_transaction_id=model.parent_transaction_id,
            reversal_of_id=model.reversal_of_id,
            client_operation_id=model.client_operation_id,
            version=model.version,
            created_at=model.created_at,
            updated_at=model.updated_at,
        )
