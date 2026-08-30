from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from uuid import UUID


@dataclass(frozen=True, slots=True)
class MerchantLocationSnapshot:
    id: UUID
    merchant_id: UUID
    name: str
    location_text: str | None
    latitude: Decimal | None
    longitude: Decimal | None
    archived_at: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class MerchantSnapshot:
    id: UUID
    user_id: UUID
    name: str
    category_id: UUID | None
    notes: str | None
    locations: tuple[MerchantLocationSnapshot, ...]
    archived_at: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class ProductSnapshot:
    id: UUID
    user_id: UUID
    parent_product_id: UUID | None
    name: str
    brand: str | None
    variant_label: str | None
    size_value: Decimal | None
    size_unit: str | None
    barcode: str | None
    category_id: UUID | None
    default_merchant_id: UUID | None
    notes: str | None
    archived_at: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class TransactionItemSnapshot:
    id: UUID
    product_id: UUID | None
    description: str
    quantity: Decimal
    unit_price: Decimal
    discount: Decimal
    line_total: Decimal
    position: int


@dataclass(frozen=True, slots=True)
class MediaAssetSnapshot:
    id: UUID
    user_id: UUID
    kind: str
    status: str
    mime_type: str
    size_bytes: int
    created_at: datetime
    finalized_at: datetime | None
