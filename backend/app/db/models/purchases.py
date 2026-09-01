from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    Uuid,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UuidPrimaryKeyMixin

MONEY = Numeric(19, 4, asdecimal=True)
QUANTITY = Numeric(19, 6, asdecimal=True)


class MerchantModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "merchants"
    __table_args__ = (
        CheckConstraint("length(btrim(name)) BETWEEN 1 AND 160", name="name_not_blank"),
        CheckConstraint("version > 0", name="version_positive"),
        ForeignKeyConstraint(
            ("category_id", "user_id"),
            ("categories.id", "categories.user_id"),
            name="fk_merchants_category_owner",
            ondelete="RESTRICT",
        ),
        UniqueConstraint("id", "user_id", name="uq_merchants_id_user"),
        Index(
            "uq_merchants_user_active_normalized_name",
            "user_id",
            "normalized_name",
            unique=True,
            postgresql_where=text("archived_at IS NULL"),
        ),
        Index("ix_merchants_user_name", "user_id", "normalized_name", "id"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    normalized_name: Mapped[str] = mapped_column(String(160), nullable=False)
    category_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True))
    notes: Mapped[str | None] = mapped_column(Text)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class MerchantLocationModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "merchant_locations"
    __table_args__ = (
        CheckConstraint("length(btrim(name)) BETWEEN 1 AND 160", name="name_not_blank"),
        CheckConstraint("latitude IS NULL OR latitude BETWEEN -90 AND 90", name="latitude_valid"),
        CheckConstraint(
            "longitude IS NULL OR longitude BETWEEN -180 AND 180", name="longitude_valid"
        ),
        CheckConstraint("version > 0", name="version_positive"),
        ForeignKeyConstraint(
            ("merchant_id", "user_id"),
            ("merchants.id", "merchants.user_id"),
            name="fk_merchant_locations_merchant_owner",
            ondelete="CASCADE",
        ),
        UniqueConstraint("id", "user_id", name="uq_merchant_locations_id_user"),
        UniqueConstraint(
            "id", "user_id", "merchant_id", name="uq_merchant_locations_id_user_merchant"
        ),
        Index(
            "uq_merchant_locations_merchant_active_name",
            "merchant_id",
            "normalized_name",
            unique=True,
            postgresql_where=text("archived_at IS NULL"),
        ),
        Index("ix_merchant_locations_user_merchant", "user_id", "merchant_id", "id"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    merchant_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    normalized_name: Mapped[str] = mapped_column(String(160), nullable=False)
    location_text: Mapped[str | None] = mapped_column(String(500))
    latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6, asdecimal=True))
    longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6, asdecimal=True))
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class ProductModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "products"
    __table_args__ = (
        CheckConstraint("length(btrim(name)) BETWEEN 1 AND 160", name="name_not_blank"),
        CheckConstraint(
            "parent_product_id IS NULL OR parent_product_id <> id", name="parent_not_self"
        ),
        CheckConstraint("size_value IS NULL OR size_value > 0", name="size_positive"),
        CheckConstraint(
            "(size_value IS NULL) = (size_unit IS NULL)", name="size_value_unit_coherent"
        ),
        CheckConstraint(
            "size_unit IS NULL OR size_unit IN ('COUNT','G','KG','ML','L')", name="size_unit_valid"
        ),
        CheckConstraint("version > 0", name="version_positive"),
        ForeignKeyConstraint(
            ("parent_product_id", "user_id"),
            ("products.id", "products.user_id"),
            name="fk_products_parent_owner",
            ondelete="RESTRICT",
        ),
        ForeignKeyConstraint(
            ("category_id", "user_id"),
            ("categories.id", "categories.user_id"),
            name="fk_products_category_owner",
            ondelete="RESTRICT",
        ),
        ForeignKeyConstraint(
            ("default_merchant_id", "user_id"),
            ("merchants.id", "merchants.user_id"),
            name="fk_products_default_merchant_owner",
            ondelete="RESTRICT",
        ),
        UniqueConstraint("id", "user_id", name="uq_products_id_user"),
        Index(
            "uq_products_user_active_identity",
            "user_id",
            "normalized_name",
            "normalized_brand",
            "normalized_variant",
            unique=True,
            postgresql_where=text("archived_at IS NULL"),
        ),
        Index(
            "uq_products_user_barcode",
            "user_id",
            "barcode",
            unique=True,
            postgresql_where=text("barcode IS NOT NULL AND archived_at IS NULL"),
        ),
        Index("ix_products_user_name", "user_id", "normalized_name", "id"),
        Index("ix_products_parent", "parent_product_id", "id"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    parent_product_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True))
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    normalized_name: Mapped[str] = mapped_column(String(160), nullable=False)
    brand: Mapped[str | None] = mapped_column(String(120))
    normalized_brand: Mapped[str] = mapped_column(String(120), nullable=False, default="")
    variant_label: Mapped[str | None] = mapped_column(String(120))
    normalized_variant: Mapped[str] = mapped_column(String(120), nullable=False, default="")
    size_value: Mapped[Decimal | None] = mapped_column(QUANTITY)
    size_unit: Mapped[str | None] = mapped_column(String(12))
    barcode: Mapped[str | None] = mapped_column(String(80))
    category_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True))
    default_merchant_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True))
    notes: Mapped[str | None] = mapped_column(Text)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class TransactionItemModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "transaction_items"
    __table_args__ = (
        CheckConstraint(
            "length(btrim(description_snapshot)) BETWEEN 1 AND 240", name="description_not_blank"
        ),
        CheckConstraint("quantity > 0", name="quantity_positive"),
        CheckConstraint("unit_price >= 0", name="unit_price_non_negative"),
        CheckConstraint("discount >= 0", name="discount_non_negative"),
        CheckConstraint("line_total >= 0", name="line_total_non_negative"),
        CheckConstraint(
            "line_total = planit_round_half_even(quantity * unit_price - discount, 4)",
            name="line_total_exact",
        ),
        CheckConstraint("position >= 0", name="position_non_negative"),
        ForeignKeyConstraint(
            ("transaction_id", "user_id"),
            ("transactions.id", "transactions.user_id"),
            name="fk_transaction_items_transaction_owner",
            ondelete="CASCADE",
        ),
        ForeignKeyConstraint(
            ("product_id", "user_id"),
            ("products.id", "products.user_id"),
            name="fk_transaction_items_product_owner",
            ondelete="RESTRICT",
        ),
        UniqueConstraint("transaction_id", "position", name="uq_transaction_items_position"),
        Index("ix_transaction_items_transaction_position", "transaction_id", "position", "id"),
        Index("ix_transaction_items_user_product", "user_id", "product_id", "transaction_id"),
    )

    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    transaction_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    product_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True))
    description_snapshot: Mapped[str] = mapped_column(String(240), nullable=False)
    quantity: Mapped[Decimal] = mapped_column(QUANTITY, nullable=False)
    unit_price: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    discount: Mapped[Decimal] = mapped_column(MONEY, nullable=False, default=Decimal("0"))
    line_total: Mapped[Decimal] = mapped_column(MONEY, nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)


class MediaAssetModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "media_assets"
    __table_args__ = (
        CheckConstraint(
            "kind IN ('MERCHANT_IMAGE','PRODUCT_IMAGE','RECEIPT','PURCHASE_IMAGE')",
            name="kind_valid",
        ),
        CheckConstraint("status IN ('PENDING','FINALIZED')", name="status_valid"),
        CheckConstraint("size_bytes BETWEEN 1 AND 10485760", name="size_valid"),
        CheckConstraint(
            "mime_type IN ('image/jpeg','image/png','image/webp')", name="mime_type_valid"
        ),
        CheckConstraint(
            "(status = 'FINALIZED') = (finalized_at IS NOT NULL)", name="finalization_coherent"
        ),
        UniqueConstraint("storage_key", name="uq_media_assets_storage_key"),
        UniqueConstraint("id", "user_id", name="uq_media_assets_id_user"),
        Index("ix_media_assets_user_status_created", "user_id", "status", "created_at"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    kind: Mapped[str] = mapped_column(String(24), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="PENDING")
    storage_key: Mapped[str] = mapped_column(String(500), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(80), nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    finalized_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class EntityMediaModel(Base):
    __tablename__ = "entity_media"
    __table_args__ = (
        CheckConstraint(
            "entity_type IN ('MERCHANT','PRODUCT','TRANSACTION')", name="entity_type_valid"
        ),
        CheckConstraint("role IN ('IMAGE','RECEIPT')", name="role_valid"),
        CheckConstraint("sort_order >= 0", name="sort_order_non_negative"),
        ForeignKeyConstraint(
            ("media_asset_id", "user_id"),
            ("media_assets.id", "media_assets.user_id"),
            name="fk_entity_media_asset_owner",
            ondelete="CASCADE",
        ),
        Index("ix_entity_media_entity", "user_id", "entity_type", "entity_id", "sort_order"),
    )

    media_asset_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    entity_type: Mapped[str] = mapped_column(String(16), nullable=False)
    entity_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    role: Mapped[str] = mapped_column(String(16), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
