from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.audit import add_audit_event
from app.db.models.ledger import CategoryModel, TagModel
from app.domain.catalog.entities import CategorySnapshot, TagSnapshot
from app.domain.catalog.enums import CategoryKind
from app.domain.catalog.policies import (
    default_categories,
    normalize_color,
    normalize_name,
    parent_accepts,
    searchable_name,
)
from app.domain.errors import DomainError
from app.infrastructure.repositories.catalog import CatalogRepository


@dataclass(frozen=True, slots=True)
class CreateCategoryCommand:
    id: UUID
    name: str
    kind: CategoryKind
    parent_id: UUID | None


@dataclass(frozen=True, slots=True)
class UpdateCategoryCommand:
    version: int
    values: dict[str, object]


@dataclass(frozen=True, slots=True)
class CreateTagCommand:
    id: UUID
    name: str
    color: str | None


@dataclass(frozen=True, slots=True)
class UpdateTagCommand:
    version: int
    values: dict[str, object]


def add_default_categories(session: AsyncSession, *, user_id: UUID) -> None:
    session.add_all(
        CategoryModel(
            id=item.id,
            user_id=user_id,
            name=item.name,
            normalized_name=searchable_name(item.name),
            kind=item.kind.value,
            parent_id=None,
            is_seeded=True,
            archived_at=None,
            version=1,
        )
        for item in default_categories(user_id)
    )


class CatalogService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repository = CatalogRepository(session)

    async def create_category_in_transaction(
        self,
        *,
        user_id: UUID,
        command: CreateCategoryCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> CategorySnapshot:
        name = normalize_name(command.name)
        await self._validate_parent(
            user_id=user_id,
            parent_id=command.parent_id,
            child_kind=command.kind,
        )
        model = CategoryModel(
            id=command.id,
            user_id=user_id,
            name=name,
            normalized_name=searchable_name(name),
            kind=command.kind.value,
            parent_id=command.parent_id,
            is_seeded=False,
            archived_at=None,
            version=1,
        )
        self._repository.add_category(model)
        await self._flush_catalog(kind="category")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="category",
            entity_id=model.id,
            action="CREATE",
            after=self._category_audit(model),
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        return self._category_snapshot(model)

    async def list_categories(
        self,
        *,
        user_id: UUID,
        include_archived: bool,
    ) -> list[CategorySnapshot]:
        models = await self._repository.list_categories(
            user_id=user_id,
            include_archived=include_archived,
        )
        return [self._category_snapshot(model) for model in models]

    async def update_category_in_transaction(
        self,
        *,
        category_id: UUID,
        user_id: UUID,
        command: UpdateCategoryCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> CategorySnapshot:
        model = await self._repository.get_category(
            category_id=category_id,
            user_id=user_id,
            for_update=True,
        )
        if model is None:
            raise DomainError("CATEGORY_NOT_FOUND", "Category was not found.")
        self._require_version(model.version, command.version)
        before = self._category_audit(model)
        requested_kind = CategoryKind(str(command.values.get("kind", model.kind)))
        requested_parent = command.values.get("parent_id", model.parent_id)
        parent_id = requested_parent if isinstance(requested_parent, UUID) else None
        archiving = command.values.get("archived") is True
        changes_hierarchy = requested_kind.value != model.kind or archiving
        if changes_hierarchy and await self._repository.has_active_category_children(
            user_id=user_id,
            parent_id=model.id,
        ):
            raise DomainError(
                "CATEGORY_HAS_ACTIVE_CHILDREN",
                "Archive or move active child categories first.",
            )
        if (
            requested_kind.value != model.kind
            and await self._repository.has_incompatible_financial_history(
                user_id=user_id,
                category_id=model.id,
                requested_kind=requested_kind,
            )
        ):
            raise DomainError(
                "CATEGORY_IN_USE",
                "Category kind cannot conflict with posted financial history.",
            )
        await self._validate_parent(
            user_id=user_id,
            parent_id=parent_id,
            child_kind=requested_kind,
            child_id=model.id,
        )
        if "name" in command.values:
            model.name = normalize_name(str(command.values["name"]))
            model.normalized_name = searchable_name(model.name)
        if "kind" in command.values:
            model.kind = requested_kind.value
        if "parent_id" in command.values:
            model.parent_id = parent_id
        if "archived" in command.values:
            model.archived_at = datetime.now(UTC) if archiving else None
        model.version += 1
        await self._flush_catalog(kind="category")
        await self._session.refresh(model)
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="category",
            entity_id=model.id,
            action="ARCHIVE" if archiving else "UPDATE",
            before=before,
            after=self._category_audit(model),
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        return self._category_snapshot(model)

    async def create_tag_in_transaction(
        self,
        *,
        user_id: UUID,
        command: CreateTagCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> TagSnapshot:
        name = normalize_name(command.name)
        model = TagModel(
            id=command.id,
            user_id=user_id,
            name=name,
            normalized_name=searchable_name(name),
            color=normalize_color(command.color),
            archived_at=None,
            version=1,
        )
        self._repository.add_tag(model)
        await self._flush_catalog(kind="tag")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="tag",
            entity_id=model.id,
            action="CREATE",
            after=self._tag_audit(model),
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        return self._tag_snapshot(model)

    async def list_tags(
        self,
        *,
        user_id: UUID,
        include_archived: bool,
    ) -> list[TagSnapshot]:
        models = await self._repository.list_tags(
            user_id=user_id,
            include_archived=include_archived,
        )
        return [self._tag_snapshot(model) for model in models]

    async def update_tag_in_transaction(
        self,
        *,
        tag_id: UUID,
        user_id: UUID,
        command: UpdateTagCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> TagSnapshot:
        model = await self._repository.get_tag(
            tag_id=tag_id,
            user_id=user_id,
            for_update=True,
        )
        if model is None:
            raise DomainError("TAG_NOT_FOUND", "Tag was not found.")
        self._require_version(model.version, command.version)
        before = self._tag_audit(model)
        if "name" in command.values:
            model.name = normalize_name(str(command.values["name"]))
            model.normalized_name = searchable_name(model.name)
        if "color" in command.values:
            raw_color = command.values["color"]
            model.color = normalize_color(str(raw_color) if raw_color is not None else None)
        archiving = command.values.get("archived") is True
        if "archived" in command.values:
            model.archived_at = datetime.now(UTC) if archiving else None
        model.version += 1
        await self._flush_catalog(kind="tag")
        await self._session.refresh(model)
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="tag",
            entity_id=model.id,
            action="ARCHIVE" if archiving else "UPDATE",
            before=before,
            after=self._tag_audit(model),
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        return self._tag_snapshot(model)

    async def _validate_parent(
        self,
        *,
        user_id: UUID,
        parent_id: UUID | None,
        child_kind: CategoryKind,
        child_id: UUID | None = None,
    ) -> None:
        if parent_id is None:
            return
        if parent_id == child_id:
            raise DomainError("CATEGORY_PARENT_INVALID", "A category cannot parent itself.")
        parent = await self._repository.get_category(
            category_id=parent_id,
            user_id=user_id,
            for_update=True,
        )
        if parent is None or parent.archived_at is not None:
            raise DomainError("CATEGORY_NOT_FOUND", "Parent category was not found.")
        if not parent_accepts(
            parent_kind=CategoryKind(parent.kind),
            child_kind=child_kind,
        ):
            raise DomainError(
                "CATEGORY_KIND_MISMATCH",
                "Parent and child category kinds are incompatible.",
            )
        ancestor = parent
        visited: set[UUID] = set()
        while ancestor.parent_id is not None:
            if ancestor.id in visited:
                raise DomainError(
                    "CATEGORY_PARENT_INVALID",
                    "Category hierarchy cannot contain a cycle.",
                )
            visited.add(ancestor.id)
            if ancestor.parent_id == child_id:
                raise DomainError(
                    "CATEGORY_PARENT_INVALID",
                    "Category hierarchy cannot contain a cycle.",
                )
            next_ancestor = await self._repository.get_category(
                category_id=ancestor.parent_id,
                user_id=user_id,
                for_update=True,
            )
            if next_ancestor is None:
                raise DomainError("CATEGORY_NOT_FOUND", "Parent category was not found.")
            ancestor = next_ancestor

    async def _flush_catalog(self, *, kind: str) -> None:
        try:
            await self._session.flush()
        except IntegrityError as exc:
            driver_error = getattr(exc.orig, "__cause__", None)
            constraint_name = getattr(driver_error, "constraint_name", None)
            if constraint_name in {
                "uq_categories_user_active_normalized_name",
                "uq_tags_user_active_normalized_name",
            }:
                raise DomainError(
                    "CATALOG_NAME_CONFLICT",
                    f"An active {kind} already uses this name.",
                ) from exc
            if constraint_name in {"pk_categories", "pk_tags"}:
                raise DomainError(
                    "CATALOG_ID_CONFLICT",
                    f"This {kind} identifier is unavailable.",
                ) from exc
            raise

    @staticmethod
    def _require_version(current: int, requested: int) -> None:
        if current != requested:
            raise DomainError(
                "VERSION_CONFLICT",
                "This catalog entry changed since it was loaded.",
                details={"current_version": current},
            )

    @staticmethod
    def _category_snapshot(model: CategoryModel) -> CategorySnapshot:
        return CategorySnapshot(
            id=model.id,
            user_id=model.user_id,
            name=model.name,
            kind=model.kind,
            parent_id=model.parent_id,
            is_seeded=model.is_seeded,
            archived_at=model.archived_at,
            version=model.version,
            created_at=model.created_at,
            updated_at=model.updated_at,
        )

    @staticmethod
    def _tag_snapshot(model: TagModel) -> TagSnapshot:
        return TagSnapshot(
            id=model.id,
            user_id=model.user_id,
            name=model.name,
            color=model.color,
            archived_at=model.archived_at,
            version=model.version,
            created_at=model.created_at,
            updated_at=model.updated_at,
        )

    @staticmethod
    def _category_audit(model: CategoryModel) -> dict[str, object]:
        return {
            "name": model.name,
            "kind": model.kind,
            "parent_id": str(model.parent_id) if model.parent_id else None,
            "archived": model.archived_at is not None,
            "version": model.version,
        }

    @staticmethod
    def _tag_audit(model: TagModel) -> dict[str, object]:
        return {
            "name": model.name,
            "color": model.color,
            "archived": model.archived_at is not None,
            "version": model.version,
        }
