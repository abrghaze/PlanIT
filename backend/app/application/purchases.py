from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal
from typing import cast
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.audit import add_audit_event
from app.db.models.purchases import MerchantLocationModel, MerchantModel, ProductModel
from app.domain.errors import DomainError
from app.domain.ledger.transactions import normalize_optional_text
from app.domain.purchases.entities import MerchantSnapshot, ProductSnapshot
from app.infrastructure.repositories.catalog import CatalogRepository
from app.infrastructure.repositories.purchases import PurchaseRepository


@dataclass(frozen=True, slots=True)
class MerchantCommand:
    id: UUID
    name: str
    category_id: UUID | None
    notes: str | None


@dataclass(frozen=True, slots=True)
class LocationCommand:
    id: UUID
    name: str
    location_text: str | None
    latitude: Decimal | None
    longitude: Decimal | None


@dataclass(frozen=True, slots=True)
class ProductCommand:
    id: UUID
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


class PurchaseCatalogService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = PurchaseRepository(session)
        self._catalog = CatalogRepository(session)

    async def list_merchants(
        self, *, user_id: UUID, search: str | None, include_archived: bool
    ) -> list[MerchantSnapshot]:
        return await self._repo.list_merchants(
            user_id=user_id,
            search=self._searchable(search, 160) if search else None,
            include_archived=include_archived,
        )

    async def get_merchant(self, *, user_id: UUID, merchant_id: UUID) -> MerchantSnapshot:
        model = await self._repo.get_merchant(merchant_id=merchant_id, user_id=user_id)
        if model is None:
            raise DomainError("MERCHANT_NOT_FOUND", "Shop was not found.")
        return await self._repo.merchant_snapshot_for(model)

    async def create_merchant(
        self, *, user_id: UUID, command: MerchantCommand, request_id: str | None, operation_id: UUID
    ) -> MerchantSnapshot:
        await self._require_category(user_id, command.category_id)
        model = MerchantModel(
            id=command.id,
            user_id=user_id,
            name=self._name(command.name, 160),
            normalized_name=self._searchable(command.name, 160),
            category_id=command.category_id,
            notes=normalize_optional_text(command.notes, field="notes", maximum=2000),
            version=1,
        )
        self._repo.add(model)
        await self._flush("MERCHANT")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="merchant",
            entity_id=model.id,
            action="CREATE",
            after={"name": model.name, "version": 1},
            request_id=request_id,
            client_operation_id=operation_id,
        )
        return await self._repo.merchant_snapshot_for(model)

    async def update_merchant(
        self,
        *,
        merchant_id: UUID,
        user_id: UUID,
        version: int,
        values: dict[str, object],
        request_id: str | None,
        operation_id: UUID,
    ) -> MerchantSnapshot:
        model = await self._repo.get_merchant(
            merchant_id=merchant_id, user_id=user_id, for_update=True
        )
        if model is None:
            raise DomainError("MERCHANT_NOT_FOUND", "Shop was not found.")
        self._version(model.version, version)
        if "category_id" in values:
            category_id = values["category_id"] if isinstance(values["category_id"], UUID) else None
            await self._require_category(user_id, category_id)
            model.category_id = category_id
        if "name" in values:
            model.name = self._name(str(values["name"]), 160)
            model.normalized_name = self._searchable(model.name, 160)
        if "notes" in values:
            raw = values["notes"]
            model.notes = normalize_optional_text(
                str(raw) if raw is not None else None, field="notes", maximum=2000
            )
        if "archived" in values:
            model.archived_at = datetime.now(UTC) if values["archived"] is True else None
        model.version += 1
        await self._flush("MERCHANT")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="merchant",
            entity_id=model.id,
            action="UPDATE",
            after={"name": model.name, "version": model.version},
            request_id=request_id,
            client_operation_id=operation_id,
        )
        return await self._repo.merchant_snapshot_for(model)

    async def add_location(
        self,
        *,
        merchant_id: UUID,
        user_id: UUID,
        command: LocationCommand,
        request_id: str | None,
        operation_id: UUID,
    ) -> MerchantSnapshot:
        merchant = await self._repo.get_merchant(
            merchant_id=merchant_id, user_id=user_id, for_update=True
        )
        if merchant is None or merchant.archived_at is not None:
            raise DomainError("MERCHANT_NOT_FOUND", "Shop was not found.")
        if (command.latitude is None) != (command.longitude is None):
            raise DomainError(
                "INVALID_LOCATION", "Latitude and longitude must be supplied together."
            )
        model = MerchantLocationModel(
            id=command.id,
            user_id=user_id,
            merchant_id=merchant.id,
            name=self._name(command.name, 160),
            normalized_name=self._searchable(command.name, 160),
            location_text=normalize_optional_text(
                command.location_text, field="location_text", maximum=500
            ),
            latitude=command.latitude,
            longitude=command.longitude,
            version=1,
        )
        self._repo.add(model)
        merchant.version += 1
        await self._flush("MERCHANT_LOCATION")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="merchant_location",
            entity_id=model.id,
            action="CREATE",
            after={"merchant_id": str(merchant.id), "name": model.name},
            request_id=request_id,
            client_operation_id=operation_id,
        )
        return await self._repo.merchant_snapshot_for(merchant)

    async def update_location(
        self,
        *,
        merchant_id: UUID,
        location_id: UUID,
        user_id: UUID,
        version: int,
        values: dict[str, object],
        request_id: str | None,
        operation_id: UUID,
    ) -> MerchantSnapshot:
        merchant = await self._repo.get_merchant(
            merchant_id=merchant_id, user_id=user_id, for_update=True
        )
        location = await self._repo.get_location(
            location_id=location_id, user_id=user_id, for_update=True
        )
        if merchant is None or location is None or location.merchant_id != merchant.id:
            raise DomainError("MERCHANT_LOCATION_NOT_FOUND", "Shop branch was not found.")
        self._version(location.version, version)
        if "name" in values:
            location.name = self._name(str(values["name"]), 160)
            location.normalized_name = self._searchable(location.name, 160)
        if "location_text" in values:
            raw = values["location_text"]
            location.location_text = normalize_optional_text(
                str(raw) if raw is not None else None,
                field="location_text",
                maximum=500,
            )
        if "latitude" in values or "longitude" in values:
            latitude = cast(Decimal | None, values.get("latitude", location.latitude))
            longitude = cast(Decimal | None, values.get("longitude", location.longitude))
            if (latitude is None) != (longitude is None):
                raise DomainError(
                    "INVALID_LOCATION", "Latitude and longitude must be supplied together."
                )
            location.latitude = latitude
            location.longitude = longitude
        if values.get("archived") is True:
            location.archived_at = datetime.now(UTC)
        elif values.get("archived") is False:
            location.archived_at = None
        location.version += 1
        merchant.version += 1
        await self._flush("MERCHANT_LOCATION")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="merchant_location",
            entity_id=location.id,
            action="UPDATE",
            after={"merchant_id": str(merchant.id), "version": location.version},
            request_id=request_id,
            client_operation_id=operation_id,
        )
        return await self._repo.merchant_snapshot_for(merchant)

    async def list_products(
        self, *, user_id: UUID, search: str | None, merchant_id: UUID | None, include_archived: bool
    ) -> list[ProductSnapshot]:
        return await self._repo.list_products(
            user_id=user_id,
            search=self._searchable(search, 160) if search else None,
            merchant_id=merchant_id,
            include_archived=include_archived,
        )

    async def get_product(self, *, user_id: UUID, product_id: UUID) -> ProductSnapshot:
        model = await self._repo.get_product(product_id=product_id, user_id=user_id)
        if model is None:
            raise DomainError("PRODUCT_NOT_FOUND", "Product was not found.")
        return self._repo.product_snapshot(model)

    async def create_product(
        self, *, user_id: UUID, command: ProductCommand, request_id: str | None, operation_id: UUID
    ) -> ProductSnapshot:
        await self._validate_product_references(user_id, command)
        brand = normalize_optional_text(command.brand, field="brand", maximum=120)
        variant = normalize_optional_text(command.variant_label, field="variant_label", maximum=120)
        barcode = normalize_optional_text(command.barcode, field="barcode", maximum=80)
        model = ProductModel(
            id=command.id,
            user_id=user_id,
            parent_product_id=command.parent_product_id,
            name=self._name(command.name, 160),
            normalized_name=self._searchable(command.name, 160),
            brand=brand,
            normalized_brand=self._searchable(brand, 120) if brand else "",
            variant_label=variant,
            normalized_variant=self._searchable(variant, 120) if variant else "",
            size_value=command.size_value,
            size_unit=command.size_unit,
            barcode=barcode,
            category_id=command.category_id,
            default_merchant_id=command.default_merchant_id,
            notes=normalize_optional_text(command.notes, field="notes", maximum=2000),
            version=1,
        )
        self._repo.add(model)
        await self._flush("PRODUCT")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="product",
            entity_id=model.id,
            action="CREATE",
            after={"name": model.name, "variant": model.variant_label, "version": 1},
            request_id=request_id,
            client_operation_id=operation_id,
        )
        await self._session.refresh(model)
        return self._repo.product_snapshot(model)

    async def update_product(
        self,
        *,
        product_id: UUID,
        user_id: UUID,
        version: int,
        values: dict[str, object],
        request_id: str | None,
        operation_id: UUID,
    ) -> ProductSnapshot:
        model = await self._repo.get_product(
            product_id=product_id, user_id=user_id, for_update=True
        )
        if model is None:
            raise DomainError("PRODUCT_NOT_FOUND", "Product was not found.")
        self._version(model.version, version)
        data = ProductCommand(
            id=model.id,
            parent_product_id=cast(
                UUID | None,
                values.get("parent_product_id", model.parent_product_id),
            ),
            name=str(values.get("name", model.name)),
            brand=self._optional(values, "brand", model.brand),
            variant_label=self._optional(values, "variant_label", model.variant_label),
            size_value=cast(Decimal | None, values.get("size_value", model.size_value)),
            size_unit=self._optional(values, "size_unit", model.size_unit),
            barcode=self._optional(values, "barcode", model.barcode),
            category_id=cast(UUID | None, values.get("category_id", model.category_id)),
            default_merchant_id=cast(
                UUID | None,
                values.get("default_merchant_id", model.default_merchant_id),
            ),
            notes=self._optional(values, "notes", model.notes),
        )
        await self._validate_product_references(user_id, data)
        model.name = self._name(data.name, 160)
        model.normalized_name = self._searchable(model.name, 160)
        model.parent_product_id = data.parent_product_id
        model.brand = data.brand
        model.normalized_brand = self._searchable(data.brand, 120) if data.brand else ""
        model.variant_label = data.variant_label
        model.normalized_variant = (
            self._searchable(data.variant_label, 120) if data.variant_label else ""
        )
        model.size_value = data.size_value
        model.size_unit = data.size_unit
        model.barcode = data.barcode
        model.category_id = data.category_id
        model.default_merchant_id = data.default_merchant_id
        model.notes = data.notes
        if values.get("archived") is True:
            model.archived_at = datetime.now(UTC)
        elif values.get("archived") is False:
            model.archived_at = None
        model.version += 1
        await self._flush("PRODUCT")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="product",
            entity_id=model.id,
            action="UPDATE",
            after={"name": model.name, "variant": model.variant_label, "version": model.version},
            request_id=request_id,
            client_operation_id=operation_id,
        )
        await self._session.refresh(model)
        return self._repo.product_snapshot(model)

    async def _validate_product_references(self, user_id: UUID, command: ProductCommand) -> None:
        if (command.size_value is None) != (command.size_unit is None):
            raise DomainError(
                "INVALID_PRODUCT_SIZE", "Product size requires both a positive value and unit."
            )
        if command.size_value is not None and command.size_value <= 0:
            raise DomainError("INVALID_PRODUCT_SIZE", "Product size must be positive.")
        await self._require_category(user_id, command.category_id)
        if command.parent_product_id:
            parent = await self._repo.get_product(
                product_id=command.parent_product_id, user_id=user_id
            )
            if parent is None or parent.archived_at is not None:
                raise DomainError("PRODUCT_NOT_FOUND", "Parent product was not found.")
        if command.default_merchant_id:
            merchant = await self._repo.get_merchant(
                merchant_id=command.default_merchant_id, user_id=user_id
            )
            if merchant is None or merchant.archived_at is not None:
                raise DomainError("MERCHANT_NOT_FOUND", "Default shop was not found.")

    async def _require_category(self, user_id: UUID, category_id: UUID | None) -> None:
        if category_id is None:
            return
        category = await self._catalog.get_category(category_id=category_id, user_id=user_id)
        if category is None or category.archived_at is not None:
            raise DomainError("CATEGORY_NOT_FOUND", "Category was not found.")

    async def _flush(self, entity: str) -> None:
        try:
            await self._session.flush()
        except IntegrityError as exc:
            constraint = getattr(getattr(exc.orig, "__cause__", None), "constraint_name", "")
            if "normalized" in (constraint or "") or "barcode" in (constraint or ""):
                raise DomainError(
                    f"{entity}_CONFLICT",
                    "An active record with these identifying details already exists.",
                ) from exc
            if (constraint or "").startswith("pk_"):
                raise DomainError(
                    f"{entity}_ID_CONFLICT", "This identifier is unavailable."
                ) from exc
            raise

    @staticmethod
    def _name(value: str, maximum: int) -> str:
        name = value.strip()
        if not name or len(name) > maximum:
            raise DomainError("INVALID_NAME", f"Name must contain 1 to {maximum} characters.")
        return name

    @staticmethod
    def _searchable(value: str, maximum: int) -> str:
        normalized = " ".join(value.strip().split())
        if not normalized or len(normalized) > maximum:
            raise DomainError(
                "INVALID_NAME",
                f"Name must contain 1 to {maximum} characters.",
            )
        return normalized.casefold()

    @staticmethod
    def _version(current: int, requested: int) -> None:
        if current != requested:
            raise DomainError(
                "VERSION_CONFLICT",
                "This record changed since it was loaded.",
                details={"current_version": current},
            )

    @staticmethod
    def _optional(values: dict[str, object], key: str, current: str | None) -> str | None:
        if key not in values:
            return current
        raw = values[key]
        return str(raw).strip() or None if raw is not None else None
