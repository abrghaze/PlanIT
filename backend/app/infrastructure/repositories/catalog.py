from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.ledger import CategoryModel, TagModel, TransactionModel
from app.domain.catalog.enums import CategoryKind
from app.domain.ledger.enums import TransactionStatus


class CatalogRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def add_category(self, category: CategoryModel) -> None:
        self._session.add(category)

    def add_tag(self, tag: TagModel) -> None:
        self._session.add(tag)

    async def get_category(
        self,
        *,
        category_id: UUID,
        user_id: UUID,
        for_update: bool = False,
    ) -> CategoryModel | None:
        statement = select(CategoryModel).where(
            CategoryModel.id == category_id,
            CategoryModel.user_id == user_id,
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    async def get_tag(
        self,
        *,
        tag_id: UUID,
        user_id: UUID,
        for_update: bool = False,
    ) -> TagModel | None:
        statement = select(TagModel).where(
            TagModel.id == tag_id,
            TagModel.user_id == user_id,
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    async def list_categories(
        self,
        *,
        user_id: UUID,
        include_archived: bool,
    ) -> list[CategoryModel]:
        statement = select(CategoryModel).where(CategoryModel.user_id == user_id)
        if not include_archived:
            statement = statement.where(CategoryModel.archived_at.is_(None))
        statement = statement.order_by(
            CategoryModel.kind,
            CategoryModel.normalized_name,
            CategoryModel.id,
        )
        return list((await self._session.scalars(statement)).all())

    async def list_tags(
        self,
        *,
        user_id: UUID,
        include_archived: bool,
    ) -> list[TagModel]:
        statement = select(TagModel).where(TagModel.user_id == user_id)
        if not include_archived:
            statement = statement.where(TagModel.archived_at.is_(None))
        statement = statement.order_by(TagModel.normalized_name, TagModel.id)
        return list((await self._session.scalars(statement)).all())

    async def get_active_tags(self, *, user_id: UUID, tag_ids: set[UUID]) -> list[TagModel]:
        if not tag_ids:
            return []
        statement = select(TagModel).where(
            TagModel.user_id == user_id,
            TagModel.id.in_(tag_ids),
            TagModel.archived_at.is_(None),
        )
        return list((await self._session.scalars(statement)).all())

    async def has_active_category_children(self, *, user_id: UUID, parent_id: UUID) -> bool:
        statement = (
            select(CategoryModel.id)
            .where(
                CategoryModel.user_id == user_id,
                CategoryModel.parent_id == parent_id,
                CategoryModel.archived_at.is_(None),
            )
            .limit(1)
        )
        return (await self._session.scalar(statement)) is not None

    async def has_incompatible_financial_history(
        self,
        *,
        user_id: UUID,
        category_id: UUID,
        requested_kind: CategoryKind,
    ) -> bool:
        if requested_kind is CategoryKind.BOTH:
            return False
        statement = (
            select(TransactionModel.id)
            .where(
                TransactionModel.user_id == user_id,
                TransactionModel.category_id == category_id,
                TransactionModel.status.in_(
                    [
                        TransactionStatus.POSTED.value,
                        TransactionStatus.REVERSED.value,
                    ]
                ),
                TransactionModel.type.in_(["EXPENSE", "INCOME"]),
                TransactionModel.type != requested_kind.value,
            )
            .limit(1)
        )
        return (await self._session.scalar(statement)) is not None
