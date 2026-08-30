from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Protocol

from app.domain.errors import DomainError


@dataclass(frozen=True, slots=True)
class ReceiptLineSuggestion:
    description: str
    quantity: Decimal | None
    unit_price: Decimal | None
    confidence: Decimal


@dataclass(frozen=True, slots=True)
class ReceiptSuggestion:
    merchant_name: str | None
    total: Decimal | None
    currency: str | None
    lines: tuple[ReceiptLineSuggestion, ...]


class ReceiptOcrProvider(Protocol):
    async def suggest(self, *, content: bytes, mime_type: str) -> ReceiptSuggestion: ...


class DisabledReceiptOcrProvider:
    async def suggest(self, *, content: bytes, mime_type: str) -> ReceiptSuggestion:
        del content, mime_type
        raise DomainError(
            "AUTOMATION_PROVIDER_UNAVAILABLE",
            "Receipt scanning is not configured. Manual entry remains available.",
        )
