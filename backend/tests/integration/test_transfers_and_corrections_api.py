from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import httpx
import pytest
from app.core.config import Settings
from app.db.models.control import AuditEventModel
from app.db.models.identity import UserModel
from app.db.models.ledger import (
    BalanceReconciliationModel,
    ReallocationLineModel,
    ReallocationSessionModel,
    TransactionModel,
    TransferModel,
)
from app.main import create_app
from sqlalchemy import delete, func, select
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
            "email": f"milestone-three-{uuid4()}@example.com",
            "password": "correct horse battery staple",
            "display_name": "Milestone Three",
            "base_currency": "MAD",
            "timezone": "Africa/Casablanca",
            "device_label": "pytest",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def _headers(auth: dict[str, object], operation_id: UUID | None = None) -> dict[str, str]:
    headers = {"Authorization": f"Bearer {auth['access_token']}"}
    if operation_id is not None:
        headers["Idempotency-Key"] = str(operation_id)
    return headers


async def _create_account(
    client: httpx.AsyncClient,
    auth: dict[str, object],
    *,
    name: str,
    opening: str,
    currency: str = "MAD",
    allow_negative: bool = False,
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
            "allow_negative": allow_negative,
            "sort_order": 0,
        },
    )
    assert response.status_code == 201, response.text
    return account_id


async def _balance(
    client: httpx.AsyncClient,
    auth: dict[str, object],
    account_id: UUID,
) -> str:
    response = await client.get(
        f"/api/v1/accounts/{account_id}/balance",
        headers=_headers(auth),
    )
    assert response.status_code == 200, response.text
    return str(response.json()["balance"]["amount"])


async def _cleanup(
    session_factory: async_sessionmaker[AsyncSession],
    user_ids: list[UUID],
) -> None:
    async with session_factory() as session, session.begin():
        await session.execute(delete(UserModel).where(UserModel.id.in_(user_ids)))


async def test_transfer_pair_fee_idempotency_and_specialized_reversal_guard(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    app = create_app(_settings())
    user_ids: list[UUID] = []
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            auth = await _register(client)
            user_id = UUID(str(auth["user"]["id"]))  # type: ignore[index]
            user_ids.append(user_id)
            source_id = await _create_account(
                client, auth, name="Transfer source", opening="200.0000"
            )
            destination_id = await _create_account(
                client, auth, name="Transfer destination", opening="50.0000"
            )
            occurred_at = datetime.now(UTC)
            preview_payload = {
                "source_account_id": str(source_id),
                "destination_account_id": str(destination_id),
                "source_amount": {"amount": "40.0000", "currency": "MAD"},
                "fee": {
                    "account_id": str(source_id),
                    "amount": {"amount": "5.0000", "currency": "MAD"},
                },
                "occurred_at": occurred_at.isoformat(),
            }
            preview = await client.post(
                "/api/v1/transfers/preview",
                headers=_headers(auth),
                json=preview_payload,
            )
            assert preview.status_code == 200, preview.text
            assert {
                item["account_id"]: item["after"]["amount"] for item in preview.json()["impacts"]
            } == {str(source_id): "155.0000", str(destination_id): "90.0000"}

            operation_id = uuid4()
            transfer_id = uuid4()
            commit_payload = {
                **preview_payload,
                "id": str(transfer_id),
                "client_operation_id": str(operation_id),
                "source_transaction_id": str(uuid4()),
                "destination_transaction_id": str(uuid4()),
                "fee_transaction_id": str(uuid4()),
                "source_fingerprint": preview.json()["source_fingerprint"],
                "note": "Move savings and record bank fee",
            }
            committed = await client.post(
                "/api/v1/transfers/commit",
                headers=_headers(auth, operation_id),
                json=commit_payload,
            )
            replay = await client.post(
                "/api/v1/transfers/commit",
                headers=_headers(auth, operation_id),
                json=commit_payload,
            )
            assert committed.status_code == replay.status_code == 201
            assert replay.headers["Idempotency-Replayed"] == "true"
            assert committed.json()["id"] == str(transfer_id)
            assert committed.json()["source_transaction"]["type"] == "TRANSFER_OUT"
            assert committed.json()["destination_transaction"]["type"] == "TRANSFER_IN"
            assert committed.json()["fee_transaction"]["type"] == "TRANSFER_FEE"
            assert await _balance(client, auth, source_id) == "155.0000"
            assert await _balance(client, auth, destination_id) == "90.0000"

            stale_operation = uuid4()
            stale_commit = await client.post(
                "/api/v1/transfers/commit",
                headers=_headers(auth, stale_operation),
                json={
                    **commit_payload,
                    "id": str(uuid4()),
                    "client_operation_id": str(stale_operation),
                    "source_transaction_id": str(uuid4()),
                    "destination_transaction_id": str(uuid4()),
                    "fee_transaction_id": str(uuid4()),
                },
            )
            assert stale_commit.status_code == 409
            assert stale_commit.json()["error"]["code"] == "STALE_BALANCE"

            fetched = await client.get(
                f"/api/v1/transfers/{transfer_id}",
                headers=_headers(auth),
            )
            assert fetched.status_code == 200
            assert fetched.json() == committed.json()

            source_transaction = committed.json()["source_transaction"]
            reverse_operation = uuid4()
            forbidden_reverse = await client.post(
                f"/api/v1/transactions/{source_transaction['id']}/reverse",
                headers=_headers(auth, reverse_operation),
                json={
                    "id": str(uuid4()),
                    "client_operation_id": str(reverse_operation),
                    "version": source_transaction["version"],
                    "occurred_at": datetime.now(UTC).isoformat(),
                },
            )
            assert forbidden_reverse.status_code == 409
            assert forbidden_reverse.json()["error"]["code"] == ("SPECIALIZED_REVERSAL_REQUIRED")

        async with db_session_factory() as session:
            transaction_types = list(
                (
                    await session.scalars(
                        select(TransactionModel.type)
                        .where(TransactionModel.user_id == user_id)
                        .order_by(TransactionModel.type)
                    )
                ).all()
            )
            transfer_count = await session.scalar(
                select(func.count())
                .select_from(TransferModel)
                .where(TransferModel.user_id == user_id)
            )
            audit_count = await session.scalar(
                select(func.count())
                .select_from(AuditEventModel)
                .where(
                    AuditEventModel.user_id == user_id,
                    AuditEventModel.entity_id == transfer_id,
                    AuditEventModel.action == "COMMIT",
                )
            )
        assert transaction_types == ["TRANSFER_FEE", "TRANSFER_IN", "TRANSFER_OUT"]
        assert transfer_count == 1
        assert audit_count == 1
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)


async def test_cross_currency_transfer_is_explicit_and_owner_scoped(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    app = create_app(_settings())
    user_ids: list[UUID] = []
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            owner = await _register(client)
            stranger = await _register(client)
            user_ids.extend(
                [
                    UUID(str(owner["user"]["id"])),  # type: ignore[index]
                    UUID(str(stranger["user"]["id"])),  # type: ignore[index]
                ]
            )
            euros = await _create_account(
                client,
                owner,
                name="Euro account",
                opening="100.0000",
                currency="EUR",
            )
            dirhams = await _create_account(
                client,
                owner,
                name="Dirham account",
                opening="500.0000",
            )
            payload = {
                "source_account_id": str(euros),
                "destination_account_id": str(dirhams),
                "source_amount": {"amount": "10.0000", "currency": "EUR"},
                "destination_amount": {"amount": "107.2500", "currency": "MAD"},
                "fx_rate": "10.725000000000",
                "occurred_at": datetime.now(UTC).isoformat(),
            }
            hidden = await client.post(
                "/api/v1/transfers/preview",
                headers=_headers(stranger),
                json=payload,
            )
            assert hidden.status_code == 404
            assert hidden.json()["error"]["code"] == "ACCOUNT_NOT_FOUND"

            mismatch = await client.post(
                "/api/v1/transfers/preview",
                headers=_headers(owner),
                json={
                    **payload,
                    "destination_amount": {"amount": "107.2400", "currency": "MAD"},
                },
            )
            assert mismatch.status_code == 422
            assert mismatch.json()["error"]["code"] == "FX_AMOUNT_MISMATCH"

            preview = await client.post(
                "/api/v1/transfers/preview",
                headers=_headers(owner),
                json=payload,
            )
            assert preview.status_code == 200, preview.text
            operation_id = uuid4()
            commit = await client.post(
                "/api/v1/transfers/commit",
                headers=_headers(owner, operation_id),
                json={
                    **payload,
                    "id": str(uuid4()),
                    "client_operation_id": str(operation_id),
                    "source_transaction_id": str(uuid4()),
                    "destination_transaction_id": str(uuid4()),
                    "source_fingerprint": preview.json()["source_fingerprint"],
                },
            )
            assert commit.status_code == 201, commit.text
            assert commit.json()["source_amount"] == {
                "amount": "10.0000",
                "currency": "EUR",
            }
            assert commit.json()["destination_amount"] == {
                "amount": "107.2500",
                "currency": "MAD",
            }
            assert commit.json()["fx_rate"] == "10.725000000000"
            assert await _balance(client, owner, euros) == "90.0000"
            assert await _balance(client, owner, dirhams) == "607.2500"

            tie_payload = {
                **payload,
                "source_amount": {"amount": "1.0000", "currency": "EUR"},
                "destination_amount": {"amount": "1.2344", "currency": "MAD"},
                "fx_rate": "1.234450000000",
            }
            tie_preview = await client.post(
                "/api/v1/transfers/preview",
                headers=_headers(owner),
                json=tie_payload,
            )
            assert tie_preview.status_code == 200, tie_preview.text
            tie_operation = uuid4()
            tie_commit = await client.post(
                "/api/v1/transfers/commit",
                headers=_headers(owner, tie_operation),
                json={
                    **tie_payload,
                    "id": str(uuid4()),
                    "client_operation_id": str(tie_operation),
                    "source_transaction_id": str(uuid4()),
                    "destination_transaction_id": str(uuid4()),
                    "source_fingerprint": tie_preview.json()["source_fingerprint"],
                },
            )
            assert tie_commit.status_code == 201, tie_commit.text
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)


async def test_historical_reconciliation_cannot_make_current_balance_negative(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    app = create_app(_settings())
    user_ids: list[UUID] = []
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            auth = await _register(client)
            user_ids.append(UUID(str(auth["user"]["id"])))  # type: ignore[index]
            account_id = await _create_account(
                client,
                auth,
                name="Historical statement account",
                opening="100.0000",
            )
            categories = (await client.get("/api/v1/categories", headers=_headers(auth))).json()[
                "items"
            ]
            expense_category = next(item for item in categories if item["kind"] == "EXPENSE")
            expense_id = uuid4()
            create_operation = uuid4()
            expense = await client.post(
                "/api/v1/transactions",
                headers=_headers(auth, create_operation),
                json={
                    "id": str(expense_id),
                    "client_operation_id": str(create_operation),
                    "account_id": str(account_id),
                    "type": "EXPENSE",
                    "amount": {"amount": "60.0000", "currency": "MAD"},
                    "occurred_at": (datetime.now(UTC) - timedelta(minutes=10)).isoformat(),
                    "category_id": expense_category["id"],
                },
            )
            assert expense.status_code == 201, expense.text
            posted = await client.post(
                f"/api/v1/transactions/{expense_id}/post",
                headers=_headers(auth, uuid4()),
                json={"version": 1},
            )
            assert posted.status_code == 200, posted.text
            assert await _balance(client, auth, account_id) == "40.0000"

            reconciliation = await client.post(
                f"/api/v1/accounts/{account_id}/reconciliations/preview",
                headers=_headers(auth),
                json={
                    "actual_balance": {"amount": "50.0000", "currency": "MAD"},
                    "effective_at": (datetime.now(UTC) - timedelta(hours=1)).isoformat(),
                    "reason": "Older statement",
                },
            )
            assert reconciliation.status_code == 409
            assert reconciliation.json()["error"]["code"] == "NEGATIVE_BALANCE_NOT_ALLOWED"
            assert reconciliation.json()["error"]["details"] == {
                "current_balance": "40.0000",
                "reconciliation_delta": "-50.0000",
                "projected_current_balance": "-10.0000",
            }
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)


def test_financial_commit_openapi_contracts_are_typed() -> None:
    schema = create_app(_settings()).openapi()
    expected = {
        "/api/v1/transfers/commit": "TransferResponse",
        "/api/v1/accounts/{account_id}/reconciliations/commit": "ReconciliationResponse",
        "/api/v1/reallocations/commit": "ReallocationResponse",
    }

    for path, model_name in expected.items():
        response_schema = schema["paths"][path]["post"]["responses"]["201"]["content"][
            "application/json"
        ]["schema"]
        assert response_schema["$ref"].endswith(f"/{model_name}")


async def test_reconciliation_and_keep_total_fixed_are_atomic_and_neutral(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    app = create_app(_settings())
    user_ids: list[UUID] = []
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            auth = await _register(client)
            user_id = UUID(str(auth["user"]["id"]))  # type: ignore[index]
            user_ids.append(user_id)
            reconciliation_account = await _create_account(
                client, auth, name="Statement account", opening="1020.0000"
            )
            effective_at = datetime.now(UTC)
            reconciliation_payload = {
                "actual_balance": {"amount": "1000.0000", "currency": "MAD"},
                "effective_at": effective_at.isoformat(),
            }
            reconciliation_preview = await client.post(
                f"/api/v1/accounts/{reconciliation_account}/reconciliations/preview",
                headers=_headers(auth),
                json=reconciliation_payload,
            )
            assert reconciliation_preview.status_code == 200
            assert reconciliation_preview.json()["delta"]["amount"] == "-20.0000"
            reconciliation_operation = uuid4()
            reconciliation = await client.post(
                f"/api/v1/accounts/{reconciliation_account}/reconciliations/commit",
                headers=_headers(auth, reconciliation_operation),
                json={
                    **reconciliation_payload,
                    "id": str(uuid4()),
                    "client_operation_id": str(reconciliation_operation),
                    "adjustment_transaction_id": str(uuid4()),
                    "source_fingerprint": reconciliation_preview.json()["source_fingerprint"],
                    "reason": "Bank statement correction",
                },
            )
            reconciliation_replay = await client.post(
                f"/api/v1/accounts/{reconciliation_account}/reconciliations/commit",
                headers=_headers(auth, reconciliation_operation),
                json={
                    **reconciliation_payload,
                    "id": reconciliation.json()["id"],
                    "client_operation_id": str(reconciliation_operation),
                    "adjustment_transaction_id": reconciliation.json()["adjustment_transaction"][
                        "id"
                    ],
                    "source_fingerprint": reconciliation_preview.json()["source_fingerprint"],
                    "reason": "Bank statement correction",
                },
            )
            assert reconciliation.status_code == 201, reconciliation.text
            assert reconciliation_replay.status_code == 201
            assert reconciliation_replay.headers["Idempotency-Replayed"] == "true"
            assert reconciliation_replay.json() == reconciliation.json()
            assert reconciliation.json()["adjustment_transaction"]["type"] == (
                "RECONCILIATION_ADJUSTMENT"
            )
            assert reconciliation.json()["adjustment_transaction"]["effect"] == "OUTFLOW"
            assert await _balance(client, auth, reconciliation_account) == "1000.0000"

            first = await _create_account(client, auth, name="Envelope one", opening="100")
            second = await _create_account(client, auth, name="Envelope two", opening="100")
            balancing = await _create_account(
                client, auth, name="Balancing envelope", opening="100"
            )
            occurred_at = datetime.now(UTC)
            reallocation_payload = {
                "account_ids": [str(first), str(second), str(balancing)],
                "fixed_total": {"amount": "300.0000", "currency": "MAD"},
                "balancing_account_id": str(balancing),
                "requested_balances": [
                    {
                        "account_id": str(first),
                        "balance": {"amount": "130.0000", "currency": "MAD"},
                    },
                    {
                        "account_id": str(second),
                        "balance": {"amount": "90.0000", "currency": "MAD"},
                    },
                ],
                "occurred_at": occurred_at.isoformat(),
            }
            preview = await client.post(
                "/api/v1/reallocations/preview",
                headers=_headers(auth),
                json=reallocation_payload,
            )
            assert preview.status_code == 200, preview.text
            assert {
                item["account_id"]: item["requested_balance"]["amount"]
                for item in preview.json()["lines"]
            } == {
                str(first): "130.0000",
                str(second): "90.0000",
                str(balancing): "80.0000",
            }

            forbidden = await client.post(
                "/api/v1/reallocations/preview",
                headers=_headers(auth),
                json={
                    **reallocation_payload,
                    "requested_balances": [
                        {
                            "account_id": str(first),
                            "balance": {"amount": "310.0000", "currency": "MAD"},
                        }
                    ],
                },
            )
            assert forbidden.status_code == 409
            assert forbidden.json()["error"]["code"] == "NEGATIVE_BALANCE_NOT_ALLOWED"

            reallocation_operation = uuid4()
            committed = await client.post(
                "/api/v1/reallocations/commit",
                headers=_headers(auth, reallocation_operation),
                json={
                    **reallocation_payload,
                    "id": str(uuid4()),
                    "client_operation_id": str(reallocation_operation),
                    "source_fingerprint": preview.json()["source_fingerprint"],
                    "note": "Keep total fixed",
                },
            )
            assert committed.status_code == 201, committed.text
            assert len(committed.json()["transfers"]) == 2
            assert all(
                transfer["reallocation_session_id"] == committed.json()["id"]
                for transfer in committed.json()["transfers"]
            )
            balances = [
                await _balance(client, auth, account_id)
                for account_id in (first, second, balancing)
            ]
            assert balances == ["130.0000", "90.0000", "80.0000"]

            stale_reallocation_operation = uuid4()
            stale_reallocation = await client.post(
                "/api/v1/reallocations/commit",
                headers=_headers(auth, stale_reallocation_operation),
                json={
                    **reallocation_payload,
                    "id": str(uuid4()),
                    "client_operation_id": str(stale_reallocation_operation),
                    "source_fingerprint": preview.json()["source_fingerprint"],
                },
            )
            assert stale_reallocation.status_code == 409
            assert stale_reallocation.json()["error"]["code"] == "STALE_BALANCE"

        async with db_session_factory() as session:
            reconciliation_count = await session.scalar(
                select(func.count())
                .select_from(BalanceReconciliationModel)
                .where(BalanceReconciliationModel.user_id == user_id)
            )
            reallocation_count = await session.scalar(
                select(func.count())
                .select_from(ReallocationSessionModel)
                .where(ReallocationSessionModel.user_id == user_id)
            )
            line_count = await session.scalar(
                select(func.count())
                .select_from(ReallocationLineModel)
                .where(ReallocationLineModel.user_id == user_id)
            )
            neutral_movements = await session.scalar(
                select(func.count())
                .select_from(TransactionModel)
                .where(
                    TransactionModel.user_id == user_id,
                    TransactionModel.type.in_(
                        ["TRANSFER_OUT", "TRANSFER_IN", "RECONCILIATION_ADJUSTMENT"]
                    ),
                )
            )
        assert reconciliation_count == 1
        assert reallocation_count == 1
        assert line_count == 3
        assert neutral_movements == 5
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)
