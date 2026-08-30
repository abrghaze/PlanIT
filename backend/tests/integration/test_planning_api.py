from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import httpx
import pytest
from app.core.config import Settings
from app.db.models.identity import UserModel
from app.db.models.ledger import TransactionModel
from app.main import create_app
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

pytestmark = pytest.mark.integration


def _settings() -> Settings:
    return Settings.model_validate(
        {
            "app_env": "test",
            "debug": False,
            "access_token_secret": "planning-access-secret-with-at-least-32-characters",
            "refresh_token_pepper": "planning-refresh-secret-with-at-least-32-characters",
        }
    )


async def test_recurring_occurrences_are_unique_and_goals_never_create_spending(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    app = create_app(_settings())
    transport = httpx.ASGITransport(app=app)
    user_id: UUID | None = None
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            auth_response = await client.post(
                "/api/v1/auth/register",
                json={
                    "email": f"planning-{uuid4()}@example.com",
                    "password": "correct horse battery staple",
                    "display_name": "Planning User",
                    "base_currency": "MAD",
                    "timezone": "Africa/Casablanca",
                },
            )
            assert auth_response.status_code == 201, auth_response.text
            auth = auth_response.json()
            user_id = UUID(auth["user"]["id"])
            headers = {"Authorization": f"Bearer {auth['access_token']}"}
            account_id = uuid4()
            opened_at = datetime.now(UTC) - timedelta(days=10)
            account = await client.post(
                "/api/v1/accounts",
                headers={**headers, "Idempotency-Key": str(uuid4())},
                json={
                    "id": str(account_id),
                    "name": "Planning account",
                    "type": "BANK",
                    "opening_balance": {"amount": "10000.0000", "currency": "MAD"},
                    "opened_at": opened_at.isoformat(),
                    "include_in_total": True,
                    "allow_negative": False,
                    "sort_order": 0,
                },
            )
            assert account.status_code == 201, account.text

            due = datetime.now(UTC) - timedelta(days=1)
            reminder_id = uuid4()
            reminder = await client.post(
                "/api/v1/recurring/rules",
                headers={**headers, "Idempotency-Key": str(uuid4())},
                json={
                    "id": str(reminder_id),
                    "name": "Rent",
                    "kind": "EXPENSE",
                    "account_id": str(account_id),
                    "amount": {"amount": "3000.0000", "currency": "MAD"},
                    "frequency": "MONTHLY",
                    "timezone": "Africa/Casablanca",
                    "next_due_at": due.isoformat(),
                    "mode": "REMINDER",
                },
            )
            assert reminder.status_code == 201, reminder.text

            first_process = await client.post(
                "/api/v1/recurring/process-due",
                headers={**headers, "Idempotency-Key": str(uuid4())},
            )
            assert first_process.status_code == 200, first_process.text
            occurrence = first_process.json()["items"][0]
            assert occurrence["status"] == "DUE"
            assert occurrence["transaction_id"] is None

            second_process = await client.post(
                "/api/v1/recurring/process-due",
                headers={**headers, "Idempotency-Key": str(uuid4())},
            )
            assert second_process.status_code == 200
            assert second_process.json()["items"] == []

            record_key = uuid4()
            recorded = await client.post(
                f"/api/v1/recurring/occurrences/{occurrence['id']}/record",
                headers={**headers, "Idempotency-Key": str(record_key)},
            )
            replayed = await client.post(
                f"/api/v1/recurring/occurrences/{occurrence['id']}/record",
                headers={**headers, "Idempotency-Key": str(record_key)},
            )
            assert recorded.status_code == replayed.status_code == 200
            assert recorded.json()["status"] == "DRAFT_CREATED"
            assert recorded.json()["transaction_id"] == replayed.json()["transaction_id"]
            assert replayed.headers["Idempotency-Replayed"] == "true"

            auto_rule = await client.post(
                "/api/v1/recurring/rules",
                headers={**headers, "Idempotency-Key": str(uuid4())},
                json={
                    "id": str(uuid4()),
                    "name": "Salary",
                    "kind": "INCOME",
                    "account_id": str(account_id),
                    "amount": {"amount": "8000.0000", "currency": "MAD"},
                    "frequency": "MONTHLY",
                    "timezone": "Africa/Casablanca",
                    "next_due_at": due.isoformat(),
                    "mode": "AUTO_DRAFT",
                },
            )
            assert auto_rule.status_code == 201, auto_rule.text
            auto_process = await client.post(
                "/api/v1/recurring/process-due",
                headers={**headers, "Idempotency-Key": str(uuid4())},
            )
            assert auto_process.status_code == 200, auto_process.text
            assert auto_process.json()["items"][0]["status"] == "DRAFT_CREATED"
            assert auto_process.json()["items"][0]["transaction_id"] is not None

            goal_id = uuid4()
            goal = await client.post(
                "/api/v1/goals",
                headers={**headers, "Idempotency-Key": str(uuid4())},
                json={
                    "id": str(goal_id),
                    "name": "Laptop",
                    "target_amount": {"amount": "12000.0000", "currency": "MAD"},
                },
            )
            assert goal.status_code == 201, goal.text
            allocation_key = uuid4()
            allocated = await client.post(
                f"/api/v1/goals/{goal_id}/allocations",
                headers={**headers, "Idempotency-Key": str(allocation_key)},
                json={
                    "id": str(uuid4()),
                    "client_operation_id": str(allocation_key),
                    "amount": {"amount": "2500.0000", "currency": "MAD"},
                    "note": "Monthly saving",
                },
            )
            assert allocated.status_code == 200, allocated.text
            assert allocated.json()["progress"]["amount"] == "2500.0000"
            assert allocated.json()["remaining"]["amount"] == "9500.0000"
            adjusted = await client.patch(
                f"/api/v1/goals/{goal_id}",
                headers={**headers, "Idempotency-Key": str(uuid4())},
                json={
                    "version": allocated.json()["version"],
                    "target_amount": {"amount": "15000.0000", "currency": "MAD"},
                },
            )
            assert adjusted.status_code == 200, adjusted.text
            assert adjusted.json()["remaining"]["amount"] == "12500.0000"

        async with db_session_factory() as session:
            transaction_count = await session.scalar(
                select(func.count(TransactionModel.id)).where(TransactionModel.user_id == user_id)
            )
            assert transaction_count == 2
    finally:
        await app.state.db_engine.dispose()
        if user_id is not None:
            async with db_session_factory() as session, session.begin():
                await session.execute(delete(UserModel).where(UserModel.id == user_id))
