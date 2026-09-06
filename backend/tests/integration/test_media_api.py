from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal
from typing import ClassVar
from uuid import UUID, uuid4

import httpx
import pytest
from app.api.v1 import media as media_routes
from app.core.config import Settings
from app.db.models.identity import UserModel
from app.db.models.ledger import AccountModel, TransactionModel
from app.db.models.purchases import EntityMediaModel, MediaAssetModel
from app.main import create_app
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

pytestmark = pytest.mark.integration


def _settings() -> Settings:
    return Settings.model_validate(
        {
            "app_env": "test",
            "debug": False,
            "access_token_secret": "media-access-secret-with-at-least-32-characters",
            "refresh_token_pepper": "media-refresh-secret-with-at-least-32-characters",
            "s3_access_key_id": "fake-access",
            "s3_secret_access_key": "fake-secret",
        }
    )


async def _register(client: httpx.AsyncClient) -> dict[str, object]:
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": f"media-{uuid4()}@example.com",
            "password": "Correct horse battery staple 9!",
            "display_name": "Media Owner",
            "base_currency": "MAD",
            "timezone": "Africa/Casablanca",
            "device_label": "pytest",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


async def test_receipt_can_be_listed_opened_and_idempotently_deleted(
    db_session_factory: async_sessionmaker[AsyncSession],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _FakeStorage.deleted.clear()
    monkeypatch.setattr(media_routes, "PrivateObjectStorage", _FakeStorage)
    app = create_app(_settings())
    transport = httpx.ASGITransport(app=app)
    owner_id: UUID | None = None
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            auth = await _register(client)
            owner_id = UUID(str(auth["user"]["id"]))  # type: ignore[index]
            account_id = uuid4()
            transaction_id = uuid4()
            media_id = uuid4()
            storage_key = f"users/{owner_id}/transaction/{transaction_id}/{media_id}.jpg"
            now = datetime.now(UTC)
            async with db_session_factory() as session, session.begin():
                session.add(
                    AccountModel(
                        id=account_id,
                        user_id=owner_id,
                        name="Wallet",
                        type="CASH",
                        currency="MAD",
                        opening_balance=Decimal("20.0000"),
                        opened_at=now,
                        include_in_total=True,
                        allow_negative=False,
                        status="ACTIVE",
                        sort_order=0,
                        version=1,
                    )
                )
                session.add(
                    TransactionModel(
                        id=transaction_id,
                        user_id=owner_id,
                        account_id=account_id,
                        type="EXPENSE",
                        effect="OUTFLOW",
                        amount=Decimal("2.0000"),
                        currency="MAD",
                        occurred_at=now,
                        status="POSTED",
                        client_operation_id=uuid4(),
                        version=1,
                    )
                )
                session.add(
                    MediaAssetModel(
                        id=media_id,
                        user_id=owner_id,
                        kind="RECEIPT",
                        status="FINALIZED",
                        storage_key=storage_key,
                        mime_type="image/jpeg",
                        size_bytes=128,
                        finalized_at=now,
                    )
                )
                await session.flush()
                session.add(
                    EntityMediaModel(
                        media_asset_id=media_id,
                        user_id=owner_id,
                        entity_type="TRANSACTION",
                        entity_id=transaction_id,
                        role="RECEIPT",
                        sort_order=0,
                    )
                )

            headers = {"Authorization": f"Bearer {auth['access_token']}"}
            listed = await client.get(
                "/api/v1/media",
                headers=headers,
                params={"entity_type": "TRANSACTION", "entity_id": str(transaction_id)},
            )
            assert listed.status_code == 200, listed.text
            assert [item["id"] for item in listed.json()["items"]] == [str(media_id)]

            opened = await client.get(f"/api/v1/media/{media_id}/read-url", headers=headers)
            assert opened.status_code == 200, opened.text
            assert opened.json()["read_url"] == f"https://private.example/{storage_key}"

            operation_id = str(uuid4())
            delete_headers = {**headers, "Idempotency-Key": operation_id}
            removed = await client.delete(f"/api/v1/media/{media_id}", headers=delete_headers)
            replayed = await client.delete(f"/api/v1/media/{media_id}", headers=delete_headers)
            assert removed.status_code == replayed.status_code == 200
            assert replayed.headers["Idempotency-Replayed"] == "true"
            assert _FakeStorage.deleted == [storage_key]

        async with db_session_factory() as session:
            assert await session.get(MediaAssetModel, media_id) is None
    finally:
        await app.state.db_engine.dispose()
        if owner_id is not None:
            async with db_session_factory() as session, session.begin():
                await session.execute(delete(UserModel).where(UserModel.id == owner_id))


class _FakeStorage:
    deleted: ClassVar[list[str]] = []

    def __init__(self, settings: Settings) -> None:
        del settings

    def signed_read_url(self, *, key: str, expires: int = 300) -> str:
        del expires
        return f"https://private.example/{key}"

    async def delete_many(self, *, keys: list[str]) -> None:
        self.deleted.extend(keys)
