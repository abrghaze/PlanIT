from __future__ import annotations

from datetime import datetime
from typing import Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.application.catalog import (
    CreateCategoryCommand,
    CreateTagCommand,
    UpdateCategoryCommand,
    UpdateTagCommand,
)
from app.domain.catalog.entities import CategorySnapshot, TagSnapshot
from app.domain.catalog.enums import CategoryKind


class CategoryCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    name: str = Field(strict=True, min_length=1, max_length=80)
    kind: CategoryKind
    parent_id: UUID | None = None

    def to_command(self) -> CreateCategoryCommand:
        return CreateCategoryCommand(
            id=self.id,
            name=self.name,
            kind=self.kind,
            parent_id=self.parent_id,
        )


class CategoryUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    version: int = Field(ge=1)
    name: str | None = Field(default=None, strict=True, min_length=1, max_length=80)
    kind: CategoryKind | None = None
    parent_id: UUID | None = None
    archived: bool | None = None

    @model_validator(mode="after")
    def require_change(self) -> Self:
        changed = self.model_fields_set - {"version"}
        if not changed:
            raise ValueError("At least one category field must be supplied.")
        if any(getattr(self, field) is None for field in changed - {"parent_id"}):
            raise ValueError("Category update fields cannot be null.")
        return self

    def to_command(self) -> UpdateCategoryCommand:
        values: dict[str, object] = {}
        for field in self.model_fields_set - {"version"}:
            value = getattr(self, field)
            values[field] = value.value if isinstance(value, CategoryKind) else value
        return UpdateCategoryCommand(version=self.version, values=values)


class CategoryResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    name: str
    kind: CategoryKind
    parent_id: UUID | None
    is_seeded: bool
    archived_at: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: CategorySnapshot) -> Self:
        return cls(
            id=value.id,
            name=value.name,
            kind=CategoryKind(value.kind),
            parent_id=value.parent_id,
            is_seeded=value.is_seeded,
            archived_at=value.archived_at,
            version=value.version,
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class CategoryListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    items: list[CategoryResponse]


class TagCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    name: str = Field(strict=True, min_length=1, max_length=80)
    color: str | None = Field(default=None, strict=True, min_length=7, max_length=7)

    def to_command(self) -> CreateTagCommand:
        return CreateTagCommand(id=self.id, name=self.name, color=self.color)


class TagUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    version: int = Field(ge=1)
    name: str | None = Field(default=None, strict=True, min_length=1, max_length=80)
    color: str | None = Field(default=None, strict=True, min_length=7, max_length=7)
    archived: bool | None = None

    @model_validator(mode="after")
    def require_change(self) -> Self:
        changed = self.model_fields_set - {"version"}
        if not changed:
            raise ValueError("At least one tag field must be supplied.")
        if any(getattr(self, field) is None for field in changed - {"color"}):
            raise ValueError("Tag update fields cannot be null.")
        return self

    def to_command(self) -> UpdateTagCommand:
        return UpdateTagCommand(
            version=self.version,
            values={field: getattr(self, field) for field in self.model_fields_set - {"version"}},
        )


class TagResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: UUID
    name: str
    color: str | None
    archived_at: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: TagSnapshot) -> Self:
        return cls(
            id=value.id,
            name=value.name,
            color=value.color,
            archived_at=value.archived_at,
            version=value.version,
            created_at=value.created_at,
            updated_at=value.updated_at,
        )


class TagListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    items: list[TagResponse]
