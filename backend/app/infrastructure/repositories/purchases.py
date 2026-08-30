from __future__ import annotations

from uuid import UUID

from sqlalchemy import delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.purchases import (
    EntityMediaModel,
    MediaAssetModel,
    MerchantLocationModel,
    MerchantModel,
    ProductModel,
    TransactionItemModel,
)
from app.domain.purchases.entities import (
    MediaAssetSnapshot,
    MerchantLocationSnapshot,
    MerchantSnapshot,
    ProductSnapshot,
    TransactionItemSnapshot,
)


class PurchaseRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def add(self, model: object) -> None:
        self._session.add(model)

    async def get_merchant(
        self, *, merchant_id: UUID, user_id: UUID, for_update: bool = False
    ) -> MerchantModel | None:
        query = select(MerchantModel).where(
            MerchantModel.id == merchant_id, MerchantModel.user_id == user_id
        )
        if for_update:
            query = query.with_for_update()
        return (await self._session.execute(query)).scalar_one_or_none()

    async def get_location(
        self, *, location_id: UUID, user_id: UUID, for_update: bool = False
    ) -> MerchantLocationModel | None:
        query = select(MerchantLocationModel).where(
            MerchantLocationModel.id == location_id, MerchantLocationModel.user_id == user_id
        )
        if for_update:
            query = query.with_for_update()
        return (await self._session.execute(query)).scalar_one_or_none()

    async def get_product(
        self, *, product_id: UUID, user_id: UUID, for_update: bool = False
    ) -> ProductModel | None:
        query = select(ProductModel).where(
            ProductModel.id == product_id, ProductModel.user_id == user_id
        )
        if for_update:
            query = query.with_for_update()
        return (await self._session.execute(query)).scalar_one_or_none()

    async def list_merchants(
        self, *, user_id: UUID, search: str | None, include_archived: bool
    ) -> list[MerchantSnapshot]:
        query = select(MerchantModel).where(MerchantModel.user_id == user_id)
        if not include_archived:
            query = query.where(MerchantModel.archived_at.is_(None))
        if search:
            query = query.where(MerchantModel.normalized_name.contains(search))
        models = list(
            (
                await self._session.scalars(
                    query.order_by(MerchantModel.normalized_name, MerchantModel.id)
                )
            ).all()
        )
        locations = await self._locations_for(
            user_id=user_id, merchant_ids=[model.id for model in models]
        )
        return [self.merchant_snapshot(model, locations.get(model.id, ())) for model in models]

    async def merchant_snapshot_for(self, model: MerchantModel) -> MerchantSnapshot:
        locations = await self._locations_for(user_id=model.user_id, merchant_ids=[model.id])
        await self._session.refresh(model)
        return self.merchant_snapshot(model, locations.get(model.id, ()))

    async def list_products(
        self, *, user_id: UUID, search: str | None, merchant_id: UUID | None, include_archived: bool
    ) -> list[ProductSnapshot]:
        query = select(ProductModel).where(ProductModel.user_id == user_id)
        if not include_archived:
            query = query.where(ProductModel.archived_at.is_(None))
        if merchant_id:
            query = query.where(ProductModel.default_merchant_id == merchant_id)
        if search:
            query = query.where(
                or_(
                    ProductModel.normalized_name.contains(search),
                    ProductModel.normalized_brand.contains(search),
                    ProductModel.normalized_variant.contains(search),
                    ProductModel.barcode == search,
                )
            )
        models = list(
            (
                await self._session.scalars(
                    query.order_by(
                        ProductModel.normalized_name,
                        ProductModel.normalized_variant,
                        ProductModel.id,
                    )
                )
            ).all()
        )
        return [self.product_snapshot(model) for model in models]

    async def replace_items(
        self, *, transaction_id: UUID, user_id: UUID, items: list[TransactionItemModel]
    ) -> None:
        await self._session.execute(
            delete(TransactionItemModel).where(
                TransactionItemModel.transaction_id == transaction_id,
                TransactionItemModel.user_id == user_id,
            )
        )
        self._session.add_all(items)

    async def items_for(
        self, *, transaction_ids: list[UUID]
    ) -> dict[UUID, tuple[TransactionItemSnapshot, ...]]:
        if not transaction_ids:
            return {}
        query = (
            select(TransactionItemModel)
            .where(TransactionItemModel.transaction_id.in_(transaction_ids))
            .order_by(
                TransactionItemModel.transaction_id,
                TransactionItemModel.position,
                TransactionItemModel.id,
            )
        )
        result: dict[UUID, list[TransactionItemSnapshot]] = {}
        for model in (await self._session.scalars(query)).all():
            result.setdefault(model.transaction_id, []).append(self.item_snapshot(model))
        return {key: tuple(value) for key, value in result.items()}

    async def get_media(
        self, *, media_id: UUID, user_id: UUID, for_update: bool = False
    ) -> MediaAssetModel | None:
        query = select(MediaAssetModel).where(
            MediaAssetModel.id == media_id, MediaAssetModel.user_id == user_id
        )
        if for_update:
            query = query.with_for_update()
        return (await self._session.execute(query)).scalar_one_or_none()

    async def media_for_entity(
        self, *, user_id: UUID, entity_type: str, entity_id: UUID
    ) -> list[MediaAssetSnapshot]:
        query = (
            select(MediaAssetModel)
            .join(EntityMediaModel, EntityMediaModel.media_asset_id == MediaAssetModel.id)
            .where(
                EntityMediaModel.user_id == user_id,
                EntityMediaModel.entity_type == entity_type,
                EntityMediaModel.entity_id == entity_id,
            )
            .order_by(EntityMediaModel.sort_order, MediaAssetModel.created_at)
        )
        return [self.media_snapshot(model) for model in (await self._session.scalars(query)).all()]

    async def _locations_for(
        self, *, user_id: UUID, merchant_ids: list[UUID]
    ) -> dict[UUID, tuple[MerchantLocationSnapshot, ...]]:
        if not merchant_ids:
            return {}
        query = (
            select(MerchantLocationModel)
            .where(
                MerchantLocationModel.user_id == user_id,
                MerchantLocationModel.merchant_id.in_(merchant_ids),
            )
            .order_by(MerchantLocationModel.normalized_name, MerchantLocationModel.id)
        )
        result: dict[UUID, list[MerchantLocationSnapshot]] = {}
        for model in (await self._session.scalars(query)).all():
            result.setdefault(model.merchant_id, []).append(self.location_snapshot(model))
        return {key: tuple(value) for key, value in result.items()}

    @staticmethod
    def merchant_snapshot(
        model: MerchantModel, locations: tuple[MerchantLocationSnapshot, ...]
    ) -> MerchantSnapshot:
        return MerchantSnapshot(
            id=model.id,
            user_id=model.user_id,
            name=model.name,
            category_id=model.category_id,
            notes=model.notes,
            locations=locations,
            archived_at=model.archived_at,
            version=model.version,
            created_at=model.created_at,
            updated_at=model.updated_at,
        )

    @staticmethod
    def location_snapshot(model: MerchantLocationModel) -> MerchantLocationSnapshot:
        return MerchantLocationSnapshot(
            id=model.id,
            merchant_id=model.merchant_id,
            name=model.name,
            location_text=model.location_text,
            latitude=model.latitude,
            longitude=model.longitude,
            archived_at=model.archived_at,
            version=model.version,
            created_at=model.created_at,
            updated_at=model.updated_at,
        )

    @staticmethod
    def product_snapshot(model: ProductModel) -> ProductSnapshot:
        return ProductSnapshot(
            id=model.id,
            user_id=model.user_id,
            parent_product_id=model.parent_product_id,
            name=model.name,
            brand=model.brand,
            variant_label=model.variant_label,
            size_value=model.size_value,
            size_unit=model.size_unit,
            barcode=model.barcode,
            category_id=model.category_id,
            default_merchant_id=model.default_merchant_id,
            notes=model.notes,
            archived_at=model.archived_at,
            version=model.version,
            created_at=model.created_at,
            updated_at=model.updated_at,
        )

    @staticmethod
    def item_snapshot(model: TransactionItemModel) -> TransactionItemSnapshot:
        return TransactionItemSnapshot(
            id=model.id,
            product_id=model.product_id,
            description=model.description_snapshot,
            quantity=model.quantity,
            unit_price=model.unit_price,
            discount=model.discount,
            line_total=model.line_total,
            position=model.position,
        )

    @staticmethod
    def media_snapshot(model: MediaAssetModel) -> MediaAssetSnapshot:
        return MediaAssetSnapshot(
            id=model.id,
            user_id=model.user_id,
            kind=model.kind,
            status=model.status,
            mime_type=model.mime_type,
            size_bytes=model.size_bytes,
            created_at=model.created_at,
            finalized_at=model.finalized_at,
        )
