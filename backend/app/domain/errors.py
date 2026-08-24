from __future__ import annotations

from collections.abc import Mapping
from typing import Any


class DomainError(ValueError):
    """Expected business-rule failure safe to map to an API response."""

    def __init__(
        self,
        code: str,
        message: str,
        *,
        details: Mapping[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.details = dict(details or {})


class CurrencyMismatchError(DomainError):
    def __init__(self, left: str, right: str) -> None:
        super().__init__(
            "CURRENCY_MISMATCH",
            f"Money in {left} cannot be combined with money in {right}.",
            details={"left_currency": left, "right_currency": right},
        )
