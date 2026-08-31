from __future__ import annotations

import asyncio
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
            "access_token_secret": "integration-access-secret-with-at-least-32-characters",
            "refresh_token_pepper": "integration-refresh-pepper-with-at-least-32-characters",
        }
    )


async def _register(client: httpx.AsyncClient) -> dict[str, object]:
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": f"milestone-four-{uuid4()}@example.com",
            "password": "Correct horse battery staple 9!",
            "display_name": "Milestone Four",
            "base_currency": "MAD",
            "timezone": "Africa/Casablanca",
            "device_label": "pytest",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def _headers(auth: dict[str, object], operation_id: UUID | None = None) -> dict[str, str]:
    result = {"Authorization": f"Bearer {auth['access_token']}"}
    if operation_id is not None:
        result["Idempotency-Key"] = str(operation_id)
    return result


async def _create_account(
    client: httpx.AsyncClient, auth: dict[str, object], *, opening: str = "500.0000"
) -> UUID:
    account_id = uuid4()
    response = await client.post(
        "/api/v1/accounts",
        headers=_headers(auth, uuid4()),
        json={
            "id": str(account_id),
            "name": "Debt account",
            "type": "BANK",
            "opening_balance": {"amount": opening, "currency": "MAD"},
            "opened_at": (datetime.now(UTC) - timedelta(days=2)).isoformat(),
            "include_in_total": True,
            "allow_negative": False,
            "sort_order": 0,
        },
    )
    assert response.status_code == 201, response.text
    return account_id


async def _create_person(client: httpx.AsyncClient, auth: dict[str, object], name: str) -> UUID:
    person_id = uuid4()
    response = await client.post(
        "/api/v1/people",
        headers=_headers(auth, uuid4()),
        json={"id": str(person_id), "name": name},
    )
    assert response.status_code == 201, response.text
    return person_id


async def _create_posted_expense(
    client: httpx.AsyncClient,
    auth: dict[str, object],
    *,
    account_id: UUID,
    amount: str = "100.0000",
) -> UUID:
    categories = (await client.get("/api/v1/categories", headers=_headers(auth))).json()["items"]
    category = next(item for item in categories if item["kind"] == "EXPENSE")
    transaction_id = uuid4()
    operation_id = uuid4()
    created = await client.post(
        "/api/v1/transactions",
        headers=_headers(auth, operation_id),
        json={
            "id": str(transaction_id),
            "client_operation_id": str(operation_id),
            "account_id": str(account_id),
            "type": "EXPENSE",
            "amount": {"amount": amount, "currency": "MAD"},
            "occurred_at": datetime.now(UTC).isoformat(),
            "category_id": category["id"],
            "counterparty": "Shared dinner",
        },
    )
    assert created.status_code == 201, created.text
    posted = await client.post(
        f"/api/v1/transactions/{transaction_id}/post",
        headers=_headers(auth, uuid4()),
        json={"version": 1},
    )
    assert posted.status_code == 200, posted.text
    return transaction_id


async def _balance(client: httpx.AsyncClient, auth: dict[str, object], account_id: UUID) -> str:
    response = await client.get(f"/api/v1/accounts/{account_id}/balance", headers=_headers(auth))
    assert response.status_code == 200
    return str(response.json()["balance"]["amount"])


async def _cleanup(session_factory: async_sessionmaker[AsyncSession], user_ids: list[UUID]) -> None:
    async with session_factory() as session, session.begin():
        await session.execute(delete(UserModel).where(UserModel.id.in_(user_ids)))


async def test_debt_origins_repayment_idempotency_and_concurrent_overpayment(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    app = create_app(_settings())
    user_ids: list[UUID] = []
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as client:
            auth = await _register(client)
            user_ids.append(UUID(str(auth["user"]["id"])))  # type: ignore[index]
            account_id = await _create_account(client, auth)
            person_id = await _create_person(client, auth, "Amina")

            existing_operation = uuid4()
            existing_id = uuid4()
            existing_payload = {
                "id": str(existing_id),
                "client_operation_id": str(existing_operation),
                "person_id": str(person_id),
                "direction": "RECEIVABLE",
                "origin_type": "EXISTING",
                "amount": {"amount": "100.0000", "currency": "MAD"},
                "due_date": (datetime.now(UTC).date() + timedelta(days=7)).isoformat(),
            }
            existing = await client.post(
                "/api/v1/debts",
                headers=_headers(auth, existing_operation),
                json=existing_payload,
            )
            replay = await client.post(
                "/api/v1/debts",
                headers=_headers(auth, existing_operation),
                json=existing_payload,
            )
            assert existing.status_code == replay.status_code == 201
            assert replay.headers["Idempotency-Replayed"] == "true"
            assert existing.json()["origin_transaction"] is None
            assert await _balance(client, auth, account_id) == "500.0000"

            async def repay(amount: str) -> httpx.Response:
                operation_id = uuid4()
                return await client.post(
                    f"/api/v1/debts/{existing_id}/payments",
                    headers=_headers(auth, operation_id),
                    json={
                        "id": str(uuid4()),
                        "client_operation_id": str(operation_id),
                        "transaction_id": str(uuid4()),
                        "account_id": str(account_id),
                        "amount": {"amount": amount, "currency": "MAD"},
                        "paid_at": datetime.now(UTC).isoformat(),
                    },
                )

            concurrent = await asyncio.gather(repay("70.0000"), repay("50.0000"))
            assert sorted(response.status_code for response in concurrent) == [201, 409]
            rejected = next(response for response in concurrent if response.status_code == 409)
            assert rejected.json()["error"]["code"] == "DEBT_OVERPAYMENT"
            debt = (await client.get(f"/api/v1/debts/{existing_id}", headers=_headers(auth))).json()
            assert debt["paid_amount"]["amount"] in {"70.0000", "50.0000"}
            assert debt["status"] == "PARTIALLY_PAID"

            lend_operation = uuid4()
            lend = await client.post(
                "/api/v1/debts",
                headers=_headers(auth, lend_operation),
                json={
                    "id": str(uuid4()),
                    "client_operation_id": str(lend_operation),
                    "person_id": str(person_id),
                    "direction": "RECEIVABLE",
                    "origin_type": "LEND_NOW",
                    "amount": {"amount": "40.0000", "currency": "MAD"},
                    "account_id": str(account_id),
                    "transaction_id": str(uuid4()),
                    "occurred_at": datetime.now(UTC).isoformat(),
                },
            )
            assert lend.status_code == 201, lend.text
            assert lend.json()["origin_transaction"]["type"] == "LOAN_PRINCIPAL_OUT"
            expected = "530.0000" if debt["paid_amount"]["amount"] == "70.0000" else "510.0000"
            assert await _balance(client, auth, account_id) == expected
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)


async def test_shared_expense_and_refund_caps_are_atomic(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    app = create_app(_settings())
    user_ids: list[UUID] = []
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        ) as client:
            auth = await _register(client)
            user_ids.append(UUID(str(auth["user"]["id"])))  # type: ignore[index]
            account_id = await _create_account(client, auth)
            people = [
                await _create_person(client, auth, "Friend one"),
                await _create_person(client, auth, "Friend two"),
            ]
            expense_id = await _create_posted_expense(client, auth, account_id=account_id)

            async def share(person_id: UUID) -> httpx.Response:
                operation_id = uuid4()
                return await client.post(
                    f"/api/v1/transactions/{expense_id}/shares",
                    headers=_headers(auth, operation_id),
                    json={
                        "id": str(uuid4()),
                        "debt_id": str(uuid4()),
                        "client_operation_id": str(operation_id),
                        "person_id": str(person_id),
                        "amount": {"amount": "60.0000", "currency": "MAD"},
                    },
                )

            shares = await asyncio.gather(*(share(person_id) for person_id in people))
            assert sorted(response.status_code for response in shares) == [201, 409]
            failed_share = next(response for response in shares if response.status_code == 409)
            assert failed_share.json()["error"]["code"] == "SHARED_EXPENSE_CAP_EXCEEDED"
            created_share = next(response for response in shares if response.status_code == 201)
            assert created_share.json()["debt"]["origin_type"] == "SHARED_EXPENSE"

            refund_operation = uuid4()
            blocked_refund = await client.post(
                f"/api/v1/transactions/{expense_id}/refund",
                headers=_headers(auth, refund_operation),
                json={
                    "id": str(uuid4()),
                    "client_operation_id": str(refund_operation),
                    "account_id": str(account_id),
                    "amount": {"amount": "50.0000", "currency": "MAD"},
                    "occurred_at": datetime.now(UTC).isoformat(),
                },
            )
            assert blocked_refund.status_code == 409
            assert blocked_refund.json()["error"]["code"] == "REFUND_CONFLICTS_WITH_SHARES"

            allowed_operation = uuid4()
            allowed_payload = {
                "id": str(uuid4()),
                "client_operation_id": str(allowed_operation),
                "account_id": str(account_id),
                "amount": {"amount": "40.0000", "currency": "MAD"},
                "occurred_at": datetime.now(UTC).isoformat(),
            }
            allowed = await client.post(
                f"/api/v1/transactions/{expense_id}/refund",
                headers=_headers(auth, allowed_operation),
                json=allowed_payload,
            )
            replay = await client.post(
                f"/api/v1/transactions/{expense_id}/refund",
                headers=_headers(auth, allowed_operation),
                json=allowed_payload,
            )
            assert allowed.status_code == replay.status_code == 201, allowed.text
            assert allowed.json()["refund_transaction"]["type"] == "REFUND"
            assert allowed.json()["refund_transaction"]["parent_transaction_id"] == str(expense_id)
            assert allowed.json()["refundable_amount"]["amount"] == "60.0000"
            assert replay.headers["Idempotency-Replayed"] == "true"
            assert await _balance(client, auth, account_id) == "440.0000"

            over_operation = uuid4()
            over = await client.post(
                f"/api/v1/transactions/{expense_id}/refund",
                headers=_headers(auth, over_operation),
                json={
                    "id": str(uuid4()),
                    "client_operation_id": str(over_operation),
                    "account_id": str(account_id),
                    "amount": {"amount": "0.0001", "currency": "MAD"},
                    "occurred_at": datetime.now(UTC).isoformat(),
                },
            )
            assert over.status_code == 409
            assert over.json()["error"]["code"] == "REFUND_CONFLICTS_WITH_SHARES"
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)
