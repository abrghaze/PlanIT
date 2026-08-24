from __future__ import annotations

import hashlib
from collections.abc import Awaitable, Callable, Mapping
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.json_contract import canonical_json, normalize_json_object
from app.db.models.control import IdempotencyKeyModel
from app.domain.errors import DomainError


@dataclass(frozen=True, slots=True)
class OperationResponse:
    status_code: int
    body: dict[str, object]


@dataclass(frozen=True, slots=True)
class IdempotencyResult:
    status_code: int
    body: dict[str, object]
    replayed: bool


IdempotentOperation = Callable[[AsyncSession], Awaitable[OperationResponse]]


def hash_request(payload: Mapping[str, object]) -> str:
    return hashlib.sha256(canonical_json(payload).encode("utf-8")).hexdigest()


def _advisory_lock_id(user_id: UUID, scope: str, key: UUID) -> int:
    digest = hashlib.sha256(f"{user_id}:{scope}:{key}".encode()).digest()
    return int.from_bytes(digest[:8], byteorder="big", signed=True)


async def execute_idempotent(
    session: AsyncSession,
    *,
    user_id: UUID,
    scope: str,
    key: UUID,
    request_payload: Mapping[str, object],
    operation: IdempotentOperation,
    ttl: timedelta = timedelta(hours=24),
) -> IdempotencyResult:
    """Execute one write and its idempotency record in the same DB transaction.

    PostgreSQL's transaction-scoped advisory lock serializes concurrent retries.
    The callback must use the supplied session and must not commit independently.
    """

    if not scope or len(scope) > 80:
        raise ValueError("Idempotency scope must contain 1 to 80 characters.")
    if ttl <= timedelta(0):
        raise ValueError("Idempotency TTL must be positive.")
    if session.in_transaction():
        raise RuntimeError("Idempotency coordinator must own the session transaction.")

    request_hash = hash_request(request_payload)

    async with session.begin():
        await session.execute(
            text("SELECT pg_advisory_xact_lock(:lock_id)"),
            {"lock_id": _advisory_lock_id(user_id, scope, key)},
        )
        now = datetime.now(UTC)
        existing = (
            await session.execute(
                select(IdempotencyKeyModel).where(
                    IdempotencyKeyModel.user_id == user_id,
                    IdempotencyKeyModel.scope == scope,
                    IdempotencyKeyModel.key == key,
                )
            )
        ).scalar_one_or_none()

        if existing is not None and existing.expires_at <= now:
            await session.delete(existing)
            await session.flush()
            existing = None

        if existing is not None:
            if existing.request_hash != request_hash:
                raise DomainError(
                    "IDEMPOTENCY_CONFLICT",
                    "The idempotency key was already used with a different request.",
                )
            if existing.response_status is None or existing.response_json is None:
                raise RuntimeError("Committed idempotency record is incomplete.")
            return IdempotencyResult(
                status_code=existing.response_status,
                body=normalize_json_object(existing.response_json),
                replayed=True,
            )

        response = await operation(session)
        if not 200 <= response.status_code <= 599:
            raise ValueError("Stored response status must be between 200 and 599.")
        response_body = normalize_json_object(response.body)
        session.add(
            IdempotencyKeyModel(
                user_id=user_id,
                scope=scope,
                key=key,
                request_hash=request_hash,
                response_status=response.status_code,
                response_json=response_body,
                expires_at=now + ttl,
            )
        )

    return IdempotencyResult(
        status_code=response.status_code,
        body=response_body,
        replayed=False,
    )
