from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from uuid import UUID


@dataclass(frozen=True, slots=True)
class UserIdentity:
    id: UUID
    email: str
    display_name: str
    base_currency: str
    timezone: str
    status: str
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class AuthenticatedPrincipal:
    user: UserIdentity
    session_id: UUID
