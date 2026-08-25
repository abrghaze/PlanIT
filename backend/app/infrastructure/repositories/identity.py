from __future__ import annotations

import hashlib
from datetime import datetime
from uuid import UUID

from sqlalchemy import delete, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.identity import (
    AuthThrottleModel,
    RefreshSessionModel,
    UserModel,
)


class IdentityRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_user_by_normalized_email(self, email: str) -> UserModel | None:
        return (
            await self._session.execute(
                select(UserModel).where(UserModel.email_normalized == email)
            )
        ).scalar_one_or_none()

    async def get_user_by_id(self, user_id: UUID) -> UserModel | None:
        return await self._session.get(UserModel, user_id)

    def add_user(self, user: UserModel) -> None:
        self._session.add(user)

    async def get_refresh_session_by_hash(
        self,
        token_hash: str,
        *,
        for_update: bool = False,
    ) -> RefreshSessionModel | None:
        statement = select(RefreshSessionModel).where(RefreshSessionModel.token_hash == token_hash)
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    async def get_refresh_session_by_id(
        self,
        session_id: UUID,
        *,
        for_update: bool = False,
    ) -> RefreshSessionModel | None:
        statement = select(RefreshSessionModel).where(RefreshSessionModel.id == session_id)
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    def add_refresh_session(self, refresh_session: RefreshSessionModel) -> None:
        self._session.add(refresh_session)

    async def revoke_replacement_chain(
        self,
        root: RefreshSessionModel,
        *,
        revoked_at: datetime,
        compromised: bool,
    ) -> None:
        current: RefreshSessionModel | None = root
        visited: set[UUID] = set()
        while current is not None and current.id not in visited:
            visited.add(current.id)
            current.revoked_at = current.revoked_at or revoked_at
            current.compromised = current.compromised or compromised
            replacement_id = current.replaced_by_id
            current = (
                await self.get_refresh_session_by_id(replacement_id, for_update=True)
                if replacement_id is not None
                else None
            )

    async def acquire_throttle_lock(self, key_hash: str) -> None:
        digest = hashlib.sha256(key_hash.encode("ascii")).digest()
        lock_id = int.from_bytes(digest[:8], byteorder="big", signed=True)
        await self._session.execute(
            text("SELECT pg_advisory_xact_lock(:lock_id)"),
            {"lock_id": lock_id},
        )

    async def get_throttle(self, key_hash: str) -> AuthThrottleModel | None:
        return await self._session.get(AuthThrottleModel, key_hash)

    def add_throttle(self, throttle: AuthThrottleModel) -> None:
        self._session.add(throttle)

    async def clear_throttle(self, key_hash: str) -> None:
        await self._session.execute(
            delete(AuthThrottleModel).where(AuthThrottleModel.key_hash == key_hash)
        )
