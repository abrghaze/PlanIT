from __future__ import annotations

import asyncio
from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID, uuid4

import httpx
import pytest
from app.core.config import Settings
from app.db.models.control import AuditEventModel
from app.db.models.identity import RefreshSessionModel, UserModel
from app.db.models.ledger import TransactionModel
from app.main import create_app
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

pytestmark = pytest.mark.integration


def _settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        "app_env": "test",
        "debug": False,
        "access_token_secret": "integration-access-secret-with-at-least-32-characters",
        "refresh_token_pepper": "integration-refresh-pepper-with-at-least-32-characters",
    }
    values.update(overrides)
    return Settings.model_validate(values)


async def _register(
    client: httpx.AsyncClient,
    *,
    email: str,
    password: str = "Correct horse battery staple 9!",
) -> dict[str, object]:
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "display_name": "Integration User",
            "base_currency": "MAD",
            "timezone": "Africa/Casablanca",
            "device_label": "pytest",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


async def _delete_users(
    session_factory: async_sessionmaker[AsyncSession],
    user_ids: list[UUID],
) -> None:
    if not user_ids:
        return
    async with session_factory() as session, session.begin():
        await session.execute(delete(UserModel).where(UserModel.id.in_(user_ids)))


def _authorization(auth: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {auth['access_token']}"}


def _account_payload(account_id: UUID, *, name: str = "Daily cash") -> dict[str, object]:
    return {
        "id": str(account_id),
        "name": name,
        "type": "CASH",
        "opening_balance": {"amount": "100.0000", "currency": "MAD"},
        "opened_at": datetime.now(UTC).isoformat(),
        "include_in_total": True,
        "allow_negative": False,
        "sort_order": 0,
    }


async def test_registration_login_logout_and_generic_failures(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    email = f"identity-{uuid4()}@example.com"
    app = create_app(_settings(login_max_attempts=2))
    transport = httpx.ASGITransport(app=app)
    user_ids: list[UUID] = []
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            weak_password = await client.post(
                "/api/v1/auth/register",
                json={
                    "email": f"weak-{uuid4()}@example.com",
                    "password": "all lowercase password",
                    "display_name": "Weak Password",
                    "base_currency": "MAD",
                    "timezone": "Africa/Casablanca",
                },
            )
            assert weak_password.status_code == 422
            assert weak_password.json()["error"]["code"] == "WEAK_PASSWORD"

            auth = await _register(client, email=email)
            user_ids.append(UUID(str(auth["user"]["id"])))  # type: ignore[index]

            duplicate = await client.post(
                "/api/v1/auth/register",
                json={
                    "email": email.upper(),
                    "password": "Another secure password 9!",
                    "display_name": "Duplicate",
                    "base_currency": "MAD",
                    "timezone": "UTC",
                },
            )
            assert duplicate.status_code == 409
            assert duplicate.json()["error"]["code"] == "EMAIL_ALREADY_REGISTERED"

            profile = await client.get("/api/v1/auth/me", headers=_authorization(auth))
            assert profile.status_code == 200
            assert profile.json()["email"].casefold() == email.casefold()

            unknown = await client.post(
                "/api/v1/auth/login",
                json={"email": f"missing-{uuid4()}@example.com", "password": "wrong password"},
            )
            wrong = await client.post(
                "/api/v1/auth/login",
                json={"email": email, "password": "wrong password"},
            )
            assert unknown.status_code == wrong.status_code == 401
            assert unknown.json()["error"]["code"] == "INVALID_CREDENTIALS"
            assert wrong.json()["error"]["code"] == "INVALID_CREDENTIALS"

            second_wrong = await client.post(
                "/api/v1/auth/login",
                json={"email": email, "password": "still wrong"},
            )
            limited = await client.post(
                "/api/v1/auth/login",
                json={"email": email, "password": "Correct horse battery staple 9!"},
            )
            assert second_wrong.status_code == 401
            assert limited.status_code == 429
            assert limited.json()["error"]["code"] == "AUTH_RATE_LIMITED"

            logout = await client.post(
                "/api/v1/auth/logout",
                json={"refresh_token": auth["refresh_token"]},
            )
            assert logout.status_code == 204
            rejected = await client.get("/api/v1/auth/me", headers=_authorization(auth))
            assert rejected.status_code == 401
    finally:
        await app.state.db_engine.dispose()
        await _delete_users(db_session_factory, user_ids)


async def test_refresh_rotation_detects_reuse_and_revokes_successors(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    email = f"rotation-{uuid4()}@example.com"
    app = create_app(_settings())
    transport = httpx.ASGITransport(app=app)
    user_ids: list[UUID] = []
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            original = await _register(client, email=email)
            user_id = UUID(str(original["user"]["id"]))  # type: ignore[index]
            user_ids.append(user_id)

            rotated_response = await client.post(
                "/api/v1/auth/refresh",
                json={"refresh_token": original["refresh_token"]},
            )
            assert rotated_response.status_code == 200
            rotated = rotated_response.json()
            assert rotated["refresh_token"] != original["refresh_token"]

            reused = await client.post(
                "/api/v1/auth/refresh",
                json={"refresh_token": original["refresh_token"]},
            )
            assert reused.status_code == 401
            assert reused.json()["error"]["code"] == "TOKEN_REUSE_DETECTED"

            successor_access = await client.get(
                "/api/v1/auth/me",
                headers=_authorization(rotated),
            )
            assert successor_access.status_code == 401

        async with db_session_factory() as session:
            sessions = (
                (
                    await session.execute(
                        select(RefreshSessionModel).where(RefreshSessionModel.user_id == user_id)
                    )
                )
                .scalars()
                .all()
            )
            reuse_audits = await session.scalar(
                select(func.count())
                .select_from(AuditEventModel)
                .where(
                    AuditEventModel.user_id == user_id,
                    AuditEventModel.action == "TOKEN_REUSE_DETECTED",
                )
            )
        assert len(sessions) == 2
        assert all(item.revoked_at is not None and item.compromised for item in sessions)
        assert reuse_audits == 1
    finally:
        await app.state.db_engine.dispose()
        await _delete_users(db_session_factory, user_ids)


async def test_account_ownership_idempotency_and_balance_read_model(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    app = create_app(_settings())
    transport = httpx.ASGITransport(app=app)
    user_ids: list[UUID] = []
    account_id = uuid4()
    operation_id = uuid4()
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            owner = await _register(client, email=f"owner-{uuid4()}@example.com")
            stranger = await _register(client, email=f"stranger-{uuid4()}@example.com")
            owner_id = UUID(str(owner["user"]["id"]))  # type: ignore[index]
            user_ids.extend([owner_id, UUID(str(stranger["user"]["id"]))])  # type: ignore[index]
            account_payload = _account_payload(account_id)

            created = await client.post(
                "/api/v1/accounts",
                json=account_payload,
                headers={**_authorization(owner), "Idempotency-Key": str(operation_id)},
            )
            assert created.status_code == 201, created.text
            assert created.headers["Idempotency-Replayed"] == "false"
            assert created.json()["calculated_balance"] == {
                "amount": "100.0000",
                "currency": "MAD",
            }

            replay = await client.post(
                "/api/v1/accounts",
                json=account_payload,
                headers={**_authorization(owner), "Idempotency-Key": str(operation_id)},
            )
            assert replay.status_code == 201
            assert replay.headers["Idempotency-Replayed"] == "true"
            assert replay.json() == created.json()

            conflict = await client.post(
                "/api/v1/accounts",
                json=_account_payload(account_id, name="Different account"),
                headers={**_authorization(owner), "Idempotency-Key": str(operation_id)},
            )
            assert conflict.status_code == 409
            assert conflict.json()["error"]["code"] == "IDEMPOTENCY_CONFLICT"

            hidden = await client.get(
                f"/api/v1/accounts/{account_id}",
                headers=_authorization(stranger),
            )
            missing = await client.get(
                f"/api/v1/accounts/{uuid4()}",
                headers=_authorization(stranger),
            )
            assert hidden.status_code == missing.status_code == 404
            assert hidden.json()["error"]["code"] == "ACCOUNT_NOT_FOUND"

            colliding = await client.post(
                "/api/v1/accounts",
                json=_account_payload(account_id, name="Colliding account"),
                headers={
                    **_authorization(stranger),
                    "Idempotency-Key": str(uuid4()),
                },
            )
            assert colliding.status_code == 409
            assert colliding.json()["error"]["code"] == "ACCOUNT_ID_CONFLICT"

        async with db_session_factory() as session, session.begin():
            session.add(
                TransactionModel(
                    user_id=owner_id,
                    account_id=account_id,
                    type="EXPENSE",
                    effect="OUTFLOW",
                    amount=Decimal("12.3400"),
                    currency="MAD",
                    occurred_at=datetime.now(UTC),
                    status="POSTED",
                    client_operation_id=uuid4(),
                    version=1,
                )
            )

        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            balance = await client.get(
                f"/api/v1/accounts/{account_id}/balance",
                headers=_authorization(owner),
            )
            assert balance.status_code == 200
            assert balance.json()["balance"] == {"amount": "87.6600", "currency": "MAD"}

            immutable = await client.patch(
                f"/api/v1/accounts/{account_id}",
                json={
                    "version": 1,
                    "opening_balance": {"amount": "120.0000", "currency": "MAD"},
                },
                headers=_authorization(owner),
            )
            assert immutable.status_code == 409
            assert immutable.json()["error"]["code"] == "ACCOUNT_HAS_ACTIVITY"
    finally:
        await app.state.db_engine.dispose()
        await _delete_users(db_session_factory, user_ids)


async def test_account_version_concurrency_and_audited_lifecycle(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    app = create_app(_settings())
    transport = httpx.ASGITransport(app=app)
    user_ids: list[UUID] = []
    account_id = uuid4()
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            auth = await _register(client, email=f"concurrency-{uuid4()}@example.com")
            user_id = UUID(str(auth["user"]["id"]))  # type: ignore[index]
            user_ids.append(user_id)
            headers = {**_authorization(auth), "Idempotency-Key": str(uuid4())}
            created = await client.post(
                "/api/v1/accounts",
                json=_account_payload(account_id),
                headers=headers,
            )
            assert created.status_code == 201

            first, second = await asyncio.gather(
                client.patch(
                    f"/api/v1/accounts/{account_id}",
                    json={"version": 1, "name": "Primary cash"},
                    headers=_authorization(auth),
                ),
                client.patch(
                    f"/api/v1/accounts/{account_id}",
                    json={"version": 1, "name": "Backup cash"},
                    headers=_authorization(auth),
                ),
            )
            assert {first.status_code, second.status_code} == {200, 409}
            winner = first if first.status_code == 200 else second
            version = winner.json()["version"]

            archived = await client.patch(
                f"/api/v1/accounts/{account_id}",
                json={"version": version, "status": "ARCHIVED"},
                headers=_authorization(auth),
            )
            assert archived.status_code == 200
            assert archived.json()["archived_at"] is not None

            read_only = await client.patch(
                f"/api/v1/accounts/{account_id}",
                json={"version": archived.json()["version"], "name": "Not allowed"},
                headers=_authorization(auth),
            )
            assert read_only.status_code == 409
            assert read_only.json()["error"]["code"] == "ACCOUNT_READ_ONLY"

            restored = await client.patch(
                f"/api/v1/accounts/{account_id}",
                json={"version": archived.json()["version"], "status": "ACTIVE"},
                headers=_authorization(auth),
            )
            closed = await client.patch(
                f"/api/v1/accounts/{account_id}",
                json={"version": restored.json()["version"], "status": "CLOSED"},
                headers=_authorization(auth),
            )
            reopened = await client.patch(
                f"/api/v1/accounts/{account_id}",
                json={"version": closed.json()["version"], "status": "ACTIVE"},
                headers=_authorization(auth),
            )
            assert restored.status_code == closed.status_code == reopened.status_code == 200
            assert reopened.json()["closed_at"] is None

        async with db_session_factory() as session:
            actions = (
                (
                    await session.execute(
                        select(AuditEventModel.action)
                        .where(
                            AuditEventModel.user_id == user_id,
                            AuditEventModel.entity_id == account_id,
                        )
                        .order_by(AuditEventModel.created_at)
                    )
                )
                .scalars()
                .all()
            )
        assert "CREATE" in actions
        assert "ARCHIVE" in actions
        assert "CLOSE" in actions
        assert actions.count("RESTORE") == 2
    finally:
        await app.state.db_engine.dispose()
        await _delete_users(db_session_factory, user_ids)
