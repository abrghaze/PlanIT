from __future__ import annotations

import re
from dataclasses import dataclass
from uuid import UUID, uuid5

from app.domain.catalog.enums import CategoryKind
from app.domain.errors import DomainError

_COLOR_PATTERN = re.compile(r"^#[0-9A-F]{6}$")


@dataclass(frozen=True, slots=True)
class DefaultCategory:
    id: UUID
    name: str
    kind: CategoryKind


_DEFAULT_CATEGORIES: tuple[tuple[str, CategoryKind], ...] = (
    ("Food & dining", CategoryKind.EXPENSE),
    ("Transport", CategoryKind.EXPENSE),
    ("Housing", CategoryKind.EXPENSE),
    ("Utilities", CategoryKind.EXPENSE),
    ("Health", CategoryKind.EXPENSE),
    ("Shopping", CategoryKind.EXPENSE),
    ("Entertainment", CategoryKind.EXPENSE),
    ("Other expense", CategoryKind.EXPENSE),
    ("Salary", CategoryKind.INCOME),
    ("Gifts", CategoryKind.INCOME),
    ("Sales", CategoryKind.INCOME),
    ("Other income", CategoryKind.INCOME),
)


def default_categories(user_id: UUID) -> tuple[DefaultCategory, ...]:
    return tuple(
        DefaultCategory(
            id=uuid5(user_id, f"planit-category:{kind.value}:{normalize_name(name)}"),
            name=name,
            kind=kind,
        )
        for name, kind in _DEFAULT_CATEGORIES
    )


def normalize_name(value: str) -> str:
    normalized = " ".join(value.strip().split())
    if not normalized:
        raise DomainError("INVALID_CATALOG_NAME", "Name cannot be blank.")
    if len(normalized) > 80:
        raise DomainError("INVALID_CATALOG_NAME", "Name cannot exceed 80 characters.")
    return normalized


def searchable_name(value: str) -> str:
    return normalize_name(value).casefold()


def normalize_color(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = value.strip().upper()
    if not _COLOR_PATTERN.fullmatch(normalized):
        raise DomainError("INVALID_TAG_COLOR", "Tag color must use #RRGGBB format.")
    return normalized


def category_accepts(*, category_kind: CategoryKind, transaction_kind: str) -> bool:
    return category_kind is CategoryKind.BOTH or category_kind.value == transaction_kind


def parent_accepts(*, parent_kind: CategoryKind, child_kind: CategoryKind) -> bool:
    return parent_kind is CategoryKind.BOTH or parent_kind is child_kind
