from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import httpx
import pytest
from app.core.config import Settings
from app.db.models.identity import UserModel
from app.main import create_app
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

pytestmark = pytest.mark.integration


def _settings() -> Settings:
    return Settings.model_validate(
        {
            "app_env": "test",
            "debug": False,
            "access_token_secret": "analytics-access-secret-with-at-least-32-characters",
            "refresh_token_pepper": "analytics-refresh-secret-with-at-least-32-characters",
        }
    )


def _headers(auth: dict[str, object], operation: UUID | None = None) -> dict[str, str]:
    result = {"Authorization": f"Bearer {auth['access_token']}"}
    if operation is not None:
        result["Idempotency-Key"] = str(operation)
    return result


async def _account(
    client: httpx.AsyncClient,
    auth: dict[str, object],
    *,
    name: str,
    currency: str,
    opening: str,
) -> UUID:
    account_id = uuid4()
    response = await client.post(
        "/api/v1/accounts",
        headers=_headers(auth, uuid4()),
        json={
            "id": str(account_id),
            "name": name,
            "type": "BANK",
            "opening_balance": {"amount": opening, "currency": currency},
            "opened_at": (datetime.now(UTC) - timedelta(days=2)).isoformat(),
            "include_in_total": True,
            "allow_negative": False,
            "sort_order": 0,
        },
    )
    assert response.status_code == 201, response.text
    return account_id


async def test_dashboard_classifies_spending_and_requires_historical_fx(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    app = create_app(_settings())
    user_id: UUID | None = None
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as client:
            registration = await client.post(
                "/api/v1/auth/register",
                json={
                    "email": f"analytics-{uuid4()}@example.com",
                    "password": "Correct horse battery staple 9!",
                    "display_name": "Analytics Owner",
                    "base_currency": "MAD",
                    "timezone": "Africa/Casablanca",
                    "device_label": "pytest",
                },
            )
            assert registration.status_code == 201, registration.text
            auth = registration.json()
            user_id = UUID(auth["user"]["id"])
            mad_account = await _account(
                client, auth, name="MAD wallet", currency="MAD", opening="100.0000"
            )
            await _account(client, auth, name="EUR wallet", currency="EUR", opening="10.0000")

            categories = await client.get("/api/v1/categories", headers=_headers(auth))
            food = next(
                item for item in categories.json()["items"] if item["name"] == "Food & dining"
            )
            transaction_id = uuid4()
            operation = uuid4()
            draft = await client.post(
                "/api/v1/transactions",
                headers=_headers(auth, operation),
                json={
                    "id": str(transaction_id),
                    "client_operation_id": str(operation),
                    "account_id": str(mad_account),
                    "type": "EXPENSE",
                    "amount": {"amount": "30.0000", "currency": "MAD"},
                    "occurred_at": datetime.now(UTC).isoformat(),
                    "category_id": food["id"],
                    "counterparty": "Analytics shop",
                    "tag_ids": [],
                },
            )
            assert draft.status_code == 201, draft.text
            posted = await client.post(
                f"/api/v1/transactions/{transaction_id}/post",
                headers=_headers(auth, uuid4()),
                json={"version": 1},
            )
            assert posted.status_code == 200, posted.text

            incomplete = await client.get(
                "/api/v1/analytics/dashboard",
                params={"preset": "THIS_MONTH"},
                headers=_headers(auth),
            )
            assert incomplete.status_code == 200, incomplete.text
            assert incomplete.json()["kpis"]["personal_spending"]["amount"] == "30.0000"
            assert incomplete.json()["kpis"]["complete"] is False
            assert incomplete.json()["warnings"][0]["currencies"] == ["EUR"]
            assert incomplete.json()["categories"][0]["source_transaction_ids"] == [
                str(transaction_id)
            ]

            rate_id = uuid4()
            rate = await client.post(
                "/api/v1/analytics/exchange-rates",
                headers=_headers(auth, rate_id),
                json={
                    "id": str(rate_id),
                    "base_currency": "EUR",
                    "quote_currency": "MAD",
                    "rate": "11.000000000000",
                    "effective_at": (datetime.now(UTC) - timedelta(days=3)).isoformat(),
                    "source": "manual",
                },
            )
            assert rate.status_code == 201, rate.text
            complete = await client.get(
                "/api/v1/analytics/dashboard",
                headers=_headers(auth),
            )
            assert complete.status_code == 200, complete.text
            assert complete.json()["kpis"]["complete"] is True
            assert complete.json()["kpis"]["money_in_accounts"]["amount"] == "180.0000"
            assert complete.json()["kpis"]["gross_spending"]["amount"] == "30.0000"
    finally:
        if user_id is not None:
            async with db_session_factory() as session, session.begin():
                await session.execute(delete(UserModel).where(UserModel.id == user_id))
