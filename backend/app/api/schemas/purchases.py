from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.application.purchases import LocationCommand, MerchantCommand, ProductCommand
from app.domain.purchases.entities import (
    MerchantLocationSnapshot,
    MerchantSnapshot,
    ProductSnapshot,
)


class MerchantCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    name: str = Field(min_length=1, max_length=160)
    category_id: UUID | None = None
    notes: str | None = Field(default=None, max_length=2000)

    def to_command(self) -> MerchantCommand:
        return MerchantCommand(self.id, self.name, self.category_id, self.notes)


class MerchantUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    version: int = Field(ge=1)
    name: str | None = Field(default=None, min_length=1, max_length=160)
    category_id: UUID | None = None
    notes: str | None = Field(default=None, max_length=2000)
    archived: bool | None = None

    @model_validator(mode="after")
    def patch_present(self) -> Self:
        changed = self.model_fields_set - {"version"}
        if not changed:
            raise ValueError("At least one shop field must be supplied.")
        if "name" in changed and self.name is None:
            raise ValueError("Shop name cannot be null.")
        return self

    def values(self) -> dict[str, object]:
        return {field: getattr(self, field) for field in self.model_fields_set - {"version"}}


class MerchantLocationCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    name: str = Field(min_length=1, max_length=160)
    location_text: str | None = Field(default=None, max_length=500)
    latitude: Decimal | None = Field(default=None, ge=-90, le=90, max_digits=9, decimal_places=6)
    longitude: Decimal | None = Field(default=None, ge=-180, le=180, max_digits=9, decimal_places=6)

    @model_validator(mode="after")
    def coordinates_coherent(self) -> Self:
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("Latitude and longitude must be supplied together.")
        return self

    def to_command(self) -> LocationCommand:
        return LocationCommand(
            self.id, self.name, self.location_text, self.latitude, self.longitude
        )


class MerchantLocationUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    version: int = Field(ge=1)
    name: str | None = Field(default=None, min_length=1, max_length=160)
    location_text: str | None = Field(default=None, max_length=500)
    latitude: Decimal | None = Field(default=None, ge=-90, le=90, max_digits=9, decimal_places=6)
    longitude: Decimal | None = Field(default=None, ge=-180, le=180, max_digits=9, decimal_places=6)
    archived: bool | None = None

    @model_validator(mode="after")
    def patch_present(self) -> Self:
        changed = self.model_fields_set - {"version"}
        if not changed:
            raise ValueError("At least one branch field must be supplied.")
        if "name" in changed and self.name is None:
            raise ValueError("Branch name cannot be null.")
        if ("latitude" in changed) != ("longitude" in changed):
            raise ValueError("Update latitude and longitude together.")
        return self

    def values(self) -> dict[str, object]:
        return {field: getattr(self, field) for field in self.model_fields_set - {"version"}}


class MerchantLocationResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    merchant_id: UUID
    name: str
    location_text: str | None
    latitude: Decimal | None
    longitude: Decimal | None
    archived: bool
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: MerchantLocationSnapshot) -> Self:
        return cls(
            id=value.id,
            merchant_id=value.merchant_id,
            name=value.name,
            location_text=value.location_text,
            latitude=value.latitude,
            longitude=value.longitude,
            archived=value.archived_at is not None,
            version=value.version,
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class MerchantResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    name: str
    category_id: UUID | None
    notes: str | None
    locations: list[MerchantLocationResponse]
    archived: bool
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: MerchantSnapshot) -> Self:
        return cls(
            id=value.id,
            name=value.name,
            category_id=value.category_id,
            notes=value.notes,
            locations=[MerchantLocationResponse.from_domain(x) for x in value.locations],
            archived=value.archived_at is not None,
            version=value.version,
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class MerchantListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    items: list[MerchantResponse]


class ProductCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    parent_product_id: UUID | None = None
    name: str = Field(min_length=1, max_length=160)
    brand: str | None = Field(default=None, max_length=120)
    variant_label: str | None = Field(default=None, max_length=120)
    size_value: Decimal | None = Field(default=None, gt=0, max_digits=19, decimal_places=6)
    size_unit: str | None = Field(default=None, pattern="^(COUNT|G|KG|ML|L)$")
    barcode: str | None = Field(default=None, max_length=80)
    category_id: UUID | None = None
    default_merchant_id: UUID | None = None
    notes: str | None = Field(default=None, max_length=2000)

    @model_validator(mode="after")
    def size_coherent(self) -> Self:
        if (self.size_value is None) != (self.size_unit is None):
            raise ValueError("Size value and unit must be supplied together.")
        return self

    def to_command(self) -> ProductCommand:
        return ProductCommand(
            self.id,
            self.parent_product_id,
            self.name,
            self.brand,
            self.variant_label,
            self.size_value,
            self.size_unit,
            self.barcode,
            self.category_id,
            self.default_merchant_id,
            self.notes,
        )


class ProductUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    version: int = Field(ge=1)
    parent_product_id: UUID | None = None
    name: str | None = Field(default=None, min_length=1, max_length=160)
    brand: str | None = Field(default=None, max_length=120)
    variant_label: str | None = Field(default=None, max_length=120)
    size_value: Decimal | None = Field(default=None, gt=0, max_digits=19, decimal_places=6)
    size_unit: str | None = Field(default=None, pattern="^(COUNT|G|KG|ML|L)$")
    barcode: str | None = Field(default=None, max_length=80)
    category_id: UUID | None = None
    default_merchant_id: UUID | None = None
    notes: str | None = Field(default=None, max_length=2000)
    archived: bool | None = None

    @model_validator(mode="after")
    def patch_present(self) -> Self:
        changed = self.model_fields_set - {"version"}
        if not changed:
            raise ValueError("At least one product field must be supplied.")
        if "name" in changed and self.name is None:
            raise ValueError("Product name cannot be null.")
        if ("size_value" in changed) != ("size_unit" in changed):
            raise ValueError("Update size value and unit together.")
        return self

    def values(self) -> dict[str, object]:
        return {field: getattr(self, field) for field in self.model_fields_set - {"version"}}


class ProductResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    parent_product_id: UUID | None
    name: str
    brand: str | None
    variant_label: str | None
    size_value: Decimal | None
    size_unit: str | None
    normalized_size_value: Decimal | None
    normalized_size_unit: str | None
    barcode: str | None
    category_id: UUID | None
    default_merchant_id: UUID | None
    notes: str | None
    archived: bool
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: ProductSnapshot) -> Self:
        normalized_value = value.size_value
        normalized_unit = value.size_unit
        if value.size_value is not None and value.size_unit == "KG":
            normalized_value = value.size_value * Decimal("1000")
            normalized_unit = "G"
        elif value.size_value is not None and value.size_unit == "L":
            normalized_value = value.size_value * Decimal("1000")
            normalized_unit = "ML"
        return cls(
            id=value.id,
            parent_product_id=value.parent_product_id,
            name=value.name,
            brand=value.brand,
            variant_label=value.variant_label,
            size_value=value.size_value,
            size_unit=value.size_unit,
            normalized_size_value=normalized_value,
            normalized_size_unit=normalized_unit,
            barcode=value.barcode,
            category_id=value.category_id,
            default_merchant_id=value.default_merchant_id,
            notes=value.notes,
            archived=value.archived_at is not None,
            version=value.version,
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class ProductListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    items: list[ProductResponse]
