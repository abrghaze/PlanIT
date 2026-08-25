from uuid import uuid4

import pytest
from app.domain.catalog.enums import CategoryKind
from app.domain.catalog.policies import (
    category_accepts,
    default_categories,
    normalize_color,
    normalize_name,
    parent_accepts,
)
from app.domain.errors import DomainError


def test_default_categories_are_deterministic_and_cover_both_flows() -> None:
    user_id = uuid4()
    first = default_categories(user_id)
    second = default_categories(user_id)

    assert first == second
    assert len({item.id for item in first}) == 12
    assert {item.kind for item in first} == {CategoryKind.EXPENSE, CategoryKind.INCOME}


def test_catalog_normalization_and_compatibility() -> None:
    assert normalize_name("  Food   and dining ") == "Food and dining"
    assert normalize_color("#aabbcc") == "#AABBCC"
    assert category_accepts(category_kind=CategoryKind.BOTH, transaction_kind="EXPENSE")
    assert not category_accepts(category_kind=CategoryKind.INCOME, transaction_kind="EXPENSE")
    assert parent_accepts(parent_kind=CategoryKind.BOTH, child_kind=CategoryKind.INCOME)
    assert not parent_accepts(parent_kind=CategoryKind.EXPENSE, child_kind=CategoryKind.INCOME)

    with pytest.raises(DomainError, match="#RRGGBB"):
        normalize_color("blue")
