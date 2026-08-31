from __future__ import annotations

import json
from datetime import UTC, datetime
from decimal import Decimal
from typing import ClassVar
from uuid import UUID, uuid4

import httpx
import pytest
from app.api.v1 import privacy as privacy_routes
from app.core.config import Settings
from app.db.models.identity import UserModel
from app.db.models.ledger import AccountModel, TransactionModel
from app.db.models.purchases import MediaAssetModel
from app.main import create_app
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

pytestmark = pytest.mark.integration


def _settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        "app_env": "test",
        "debug": False,
        "access_token_secret": "privacy-access-secret-with-at-least-32-characters",
        "refresh_token_pepper": "privacy-refresh-secret-with-at-least-32-characters",
    }
    values.update(overrides)
    return Settings.model_validate(values)


async def _register(client: httpx.AsyncClient, email: str) -> dict[str, object]:
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "Correct horse battery staple 9!",
            "display_name": "Privacy Owner",
            "base_currency": "MAD",
            "timezone": "Africa/Casablanca",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def _headers(auth: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {auth['access_token']}"}


async def _cleanup(factory: async_sessionmaker[AsyncSession], user_ids: list[UUID]) -> None:
    async with factory() as session, session.begin():
        await session.execute(delete(UserModel).where(UserModel.id.in_(user_ids)))


async def test_private_exports_are_owner_scoped_and_preserve_money(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    app = create_app(_settings())
    transport = httpx.ASGITransport(app=app)
    user_ids: list[UUID] = []
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            owner = await _register(client, f"export-{uuid4()}@example.com")
            stranger = await _register(client, f"private-{uuid4()}@example.com")
            owner_id = UUID(str(owner["user"]["id"]))  # type: ignore[index]
            stranger_id = UUID(str(stranger["user"]["id"]))  # type: ignore[index]
            user_ids.extend((owner_id, stranger_id))
            owner_account_id = uuid4()
            stranger_account_id = uuid4()
            now = datetime.now(UTC)

            async with db_session_factory() as session, session.begin():
                session.add_all(
                    [
                        AccountModel(
                            id=owner_account_id,
                            user_id=owner_id,
                            name="Owner wallet",
                            type="CASH",
                            currency="MAD",
                            opening_balance=Decimal("100.0000"),
                            opened_at=now,
                            include_in_total=True,
                            allow_negative=False,
                            status="ACTIVE",
                            sort_order=0,
                            version=1,
                        ),
                        AccountModel(
                            id=stranger_account_id,
                            user_id=stranger_id,
                            name="Stranger secret account",
                            type="CASH",
                            currency="MAD",
                            opening_balance=Decimal("999.0000"),
                            opened_at=now,
                            include_in_total=True,
                            allow_negative=False,
                            status="ACTIVE",
                            sort_order=0,
                            version=1,
                        ),
                    ]
                )
                session.add(
                    TransactionModel(
                        id=uuid4(),
                        user_id=owner_id,
                        account_id=owner_account_id,
                        type="EXPENSE",
                        effect="OUTFLOW",
                        amount=Decimal("12.3400"),
                        currency="MAD",
                        occurred_at=now,
                        status="POSTED",
                        note="owner-only note",
                        client_operation_id=uuid4(),
                        version=1,
                    )
                )

            transactions = await client.get(
                "/api/v1/privacy/export.csv?data_type=transactions",
                headers=_headers(owner),
            )
            assert transactions.status_code == 200
            assert transactions.headers["cache-control"] == "no-store"
            assert "attachment" in transactions.headers["content-disposition"]
            assert "12.3400" in transactions.text
            assert "owner-only note" in transactions.text
            assert "Stranger secret account" not in transactions.text

            accounts = await client.get(
                "/api/v1/privacy/export.csv?data_type=accounts",
                headers=_headers(owner),
            )
            assert accounts.status_code == 200
            assert "87.6600" in accounts.text
            assert "999.0000" not in accounts.text

            backup = await client.get(
                "/api/v1/privacy/backup.json",
                headers=_headers(owner),
            )
            assert backup.status_code == 200
            document = json.loads(backup.content)
            assert document["format"] == "planit-portable-backup"
            assert document["schema_version"] == 1
            assert document["data"]["accounts"][0]["name"] == "Owner wallet"
            serialized = backup.text.casefold()
            assert "password_hash" not in serialized
            assert "token_hash" not in serialized
            assert "storage_key" not in serialized
            assert "stranger secret account" not in serialized
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)


async def test_profile_deletion_requires_password_and_preserves_other_users(
    db_session_factory: async_sessionmaker[AsyncSession],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _FakeObjectStorage.deleted.clear()
    monkeypatch.setattr(privacy_routes, "PrivateObjectStorage", _FakeObjectStorage)
    app = create_app(
        _settings(
            s3_access_key_id="fake-access",
            s3_secret_access_key="fake-secret",
        )
    )
    transport = httpx.ASGITransport(app=app)
    user_ids: list[UUID] = []
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            owner = await _register(client, f"delete-{uuid4()}@example.com")
            stranger = await _register(client, f"keep-{uuid4()}@example.com")
            owner_id = UUID(str(owner["user"]["id"]))  # type: ignore[index]
            stranger_id = UUID(str(stranger["user"]["id"]))  # type: ignore[index]
            user_ids.extend((owner_id, stranger_id))
            media_id = uuid4()
            media_key = f"users/{owner_id}/transaction/private-receipt.jpg"
            account_id = uuid4()

            async with db_session_factory() as session, session.begin():
                session.add_all(
                    [
                        AccountModel(
                            id=account_id,
                            user_id=owner_id,
                            name="Delete me",
                            type="CASH",
                            currency="MAD",
                            opening_balance=Decimal("20.0000"),
                            opened_at=datetime.now(UTC),
                            include_in_total=True,
                            allow_negative=False,
                            status="ACTIVE",
                            sort_order=0,
                            version=1,
                        ),
                        MediaAssetModel(
                            id=media_id,
                            user_id=owner_id,
                            kind="RECEIPT",
                            status="PENDING",
                            storage_key=media_key,
                            mime_type="image/jpeg",
                            size_bytes=128,
                        ),
                    ]
                )
                await session.flush()
                session.add(
                    TransactionModel(
                        id=uuid4(),
                        user_id=owner_id,
                        account_id=account_id,
                        type="EXPENSE",
                        effect="OUTFLOW",
                        amount=Decimal("2.0000"),
                        currency="MAD",
                        occurred_at=datetime.now(UTC),
                        status="POSTED",
                        client_operation_id=uuid4(),
                        version=1,
                    )
                )

            wrong = await client.request(
                "DELETE",
                "/api/v1/privacy/profile",
                headers=_headers(owner),
                json={
                    "password": "wrong password",
                    "confirmation": "DELETE MY PLANIT DATA",
                },
            )
            assert wrong.status_code == 401
            assert wrong.json()["error"]["code"] == "INVALID_CREDENTIALS"

            deleted = await client.request(
                "DELETE",
                "/api/v1/privacy/profile",
                headers=_headers(owner),
                json={
                    "password": "Correct horse battery staple 9!",
                    "confirmation": "DELETE MY PLANIT DATA",
                },
            )
            assert deleted.status_code == 204, deleted.text
            assert _FakeObjectStorage.deleted == [media_key]

            rejected = await client.get("/api/v1/auth/me", headers=_headers(owner))
            assert rejected.status_code == 401

        async with db_session_factory() as session:
            assert await session.get(UserModel, owner_id) is None
            assert await session.get(UserModel, stranger_id) is not None
            owner_data = await session.scalar(
                select(AccountModel.id).where(AccountModel.user_id == owner_id).limit(1)
            )
            assert owner_data is None
        user_ids.remove(owner_id)
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)


class _FakeObjectStorage:
    deleted: ClassVar[list[str]] = []

    def __init__(self, settings: Settings) -> None:
        del settings

    async def delete_many(self, *, keys: list[str]) -> None:
        self.deleted.extend(keys)
