from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Protocol

from app.domain.errors import DomainError


@dataclass(frozen=True, slots=True)
class ImportedBankTransaction:
    provider_id: str
    occurred_at: datetime
    amount: Decimal
    currency: str
    description: str


class BankTransactionProvider(Protocol):
    async def fetch(
        self,
        *,
        connection_reference: str,
        since: datetime | None,
    ) -> tuple[ImportedBankTransaction, ...]: ...


class DisabledBankTransactionProvider:
    async def fetch(
        self,
        *,
        connection_reference: str,
        since: datetime | None,
    ) -> tuple[ImportedBankTransaction, ...]:
        del connection_reference, since
        raise DomainError(
            "AUTOMATION_PROVIDER_UNAVAILABLE",
            "Bank import is not configured. Manual entry remains available.",
        )
