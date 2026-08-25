from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from uuid import UUID


@dataclass(frozen=True, slots=True)
class CategorySnapshot:
    id: UUID
    user_id: UUID
    name: str
    kind: str
    parent_id: UUID | None
    is_seeded: bool
    archived_at: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class TagSnapshot:
    id: UUID
    user_id: UUID
    name: str
    color: str | None
    archived_at: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime
