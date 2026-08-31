from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import httpx
import pytest
from app.core.config import Settings
from app.db.models.control import AuditEventModel
from app.db.models.identity import UserModel
from app.db.models.ledger import TransactionModel
from app.main import create_app
from sqlalchemy import delete, func, select, update
from sqlalchemy.exc import IntegrityError
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
            "email": f"ledger-{uuid4()}@example.com",
            "password": "Correct horse battery staple 9!",
            "display_name": "Ledger Owner",
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
    opening: str = "100.0000",
) -> UUID:
    account_id = uuid4()
    operation_id = uuid4()
    response = await client.post(
        "/api/v1/accounts",
        headers=_headers(auth, operation_id),
        json={
            "id": str(account_id),
            "name": "Daily cash",
            "type": "CASH",
            "opening_balance": {"amount": opening, "currency": "MAD"},
            "opened_at": (datetime.now(UTC) - timedelta(days=1)).isoformat(),
            "include_in_total": True,
            "allow_negative": False,
            "sort_order": 0,
        },
    )
    assert response.status_code == 201, response.text
    return account_id


async def _cleanup(
    session_factory: async_sessionmaker[AsyncSession],
    user_ids: list[UUID],
) -> None:
    async with session_factory() as session, session.begin():
        await session.execute(delete(UserModel).where(UserModel.id.in_(user_ids)))


async def test_balance_and_transactions_survive_logout_and_login(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    app = create_app(_settings())
    user_ids: list[UUID] = []
    try:
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            original = await _register(client)
            user = original["user"]
            assert isinstance(user, dict)
            user_id = UUID(str(user["id"]))
            user_ids.append(user_id)
            account_id = await _create_account(client, original)

            categories = await client.get(
                "/api/v1/categories",
                headers=_headers(original),
            )
            assert categories.status_code == 200, categories.text
            food = next(
                item for item in categories.json()["items"] if item["name"] == "Food & dining"
            )

            transaction_id = uuid4()
            create_operation = uuid4()
            created = await client.post(
                "/api/v1/transactions",
                headers=_headers(original, create_operation),
                json={
                    "id": str(transaction_id),
                    "client_operation_id": str(create_operation),
                    "account_id": str(account_id),
                    "type": "EXPENSE",
                    "amount": {"amount": "25.0000", "currency": "MAD"},
                    "occurred_at": datetime.now(UTC).isoformat(),
                    "category_id": food["id"],
                    "counterparty": "Persistence test shop",
                },
            )
            assert created.status_code == 201, created.text
            posted = await client.post(
                f"/api/v1/transactions/{transaction_id}/post",
                headers=_headers(original, uuid4()),
                json={"version": 1},
            )
            assert posted.status_code == 200, posted.text

            before_logout = await client.get(
                f"/api/v1/accounts/{account_id}/balance",
                headers=_headers(original),
            )
            assert before_logout.status_code == 200, before_logout.text
            assert before_logout.json()["balance"] == {
                "amount": "75.0000",
                "currency": "MAD",
            }

            logout = await client.post(
                "/api/v1/auth/logout",
                json={"refresh_token": original["refresh_token"]},
            )
            assert logout.status_code == 204, logout.text

            login = await client.post(
                "/api/v1/auth/login",
                json={
                    "email": user["email"],
                    "password": "Correct horse battery staple 9!",
                    "device_label": "pytest-relogin",
                },
            )
            assert login.status_code == 200, login.text
            restored = login.json()
            assert restored["user"]["id"] == str(user_id)

            accounts = await client.get(
                "/api/v1/accounts",
                headers=_headers(restored),
            )
            transactions = await client.get(
                "/api/v1/transactions",
                headers=_headers(restored),
            )
            after_login = await client.get(
                f"/api/v1/accounts/{account_id}/balance",
                headers=_headers(restored),
            )

            assert accounts.status_code == 200, accounts.text
            assert transactions.status_code == 200, transactions.text
            assert after_login.status_code == 200, after_login.text
            assert str(account_id) in {item["id"] for item in accounts.json()["items"]}
            assert str(transaction_id) in {item["id"] for item in transactions.json()["items"]}
            assert after_login.json()["balance"] == before_logout.json()["balance"]
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)


async def test_expense_draft_post_reverse_is_idempotent_and_balance_correct(
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
            account_id = await _create_account(client, auth)

            categories = await client.get("/api/v1/categories", headers=_headers(auth))
            assert categories.status_code == 200
            assert len(categories.json()["items"]) == 12
            food = next(
                item for item in categories.json()["items"] if item["name"] == "Food & dining"
            )

            tag_id = uuid4()
            tag_operation = uuid4()
            tag_payload = {"id": str(tag_id), "name": "Vacation", "color": "#3366FF"}
            tag = await client.post(
                "/api/v1/tags",
                headers=_headers(auth, tag_operation),
                json=tag_payload,
            )
            tag_replay = await client.post(
                "/api/v1/tags",
                headers=_headers(auth, tag_operation),
                json=tag_payload,
            )
            assert tag.status_code == tag_replay.status_code == 201
            assert tag_replay.headers["Idempotency-Replayed"] == "true"

            transaction_id = uuid4()
            create_operation = uuid4()
            draft_payload = {
                "id": str(transaction_id),
                "client_operation_id": str(create_operation),
                "account_id": str(account_id),
                "type": "EXPENSE",
                "amount": {"amount": "25.0000", "currency": "MAD"},
                "occurred_at": datetime.now(UTC).isoformat(),
                "category_id": food["id"],
                "counterparty": "Corner shop",
                "note": "Quick entry",
                "tag_ids": [str(tag_id)],
            }
            draft = await client.post(
                "/api/v1/transactions",
                headers=_headers(auth, create_operation),
                json=draft_payload,
            )
            replay = await client.post(
                "/api/v1/transactions",
                headers=_headers(auth, create_operation),
                json=draft_payload,
            )
            assert draft.status_code == replay.status_code == 201
            assert draft.json()["status"] == "DRAFT"
            assert replay.headers["Idempotency-Replayed"] == "true"

            balance = await client.get(
                f"/api/v1/accounts/{account_id}/balance",
                headers=_headers(auth),
            )
            assert balance.json()["balance"]["amount"] == "100.0000"

            update_operation = uuid4()
            updated = await client.patch(
                f"/api/v1/transactions/{transaction_id}",
                headers=_headers(auth, update_operation),
                json={"version": 1, "amount": {"amount": "30.0000", "currency": "MAD"}},
            )
            assert updated.status_code == 200, updated.text
            assert updated.json()["version"] == 2

            post_operation = uuid4()
            post_payload = {"version": 2}
            posted = await client.post(
                f"/api/v1/transactions/{transaction_id}/post",
                headers=_headers(auth, post_operation),
                json=post_payload,
            )
            posted_replay = await client.post(
                f"/api/v1/transactions/{transaction_id}/post",
                headers=_headers(auth, post_operation),
                json=post_payload,
            )
            assert posted.status_code == posted_replay.status_code == 200
            assert posted.json()["status"] == "POSTED"
            assert posted.json()["version"] == 3
            assert posted_replay.headers["Idempotency-Replayed"] == "true"

            balance = await client.get(
                f"/api/v1/accounts/{account_id}/balance",
                headers=_headers(auth),
            )
            assert balance.json()["balance"]["amount"] == "70.0000"

            immutable = await client.patch(
                f"/api/v1/transactions/{transaction_id}",
                headers=_headers(auth, uuid4()),
                json={"version": 3, "amount": {"amount": "1.0000", "currency": "MAD"}},
            )
            assert immutable.status_code == 409
            assert immutable.json()["error"]["code"] == "TRANSACTION_NOT_DRAFT"

            reversal_id = uuid4()
            reverse_operation = uuid4()
            reversal_payload = {
                "id": str(reversal_id),
                "client_operation_id": str(reverse_operation),
                "version": 3,
                "occurred_at": datetime.now(UTC).isoformat(),
                "note": "Entered by mistake",
            }
            reversed_response = await client.post(
                f"/api/v1/transactions/{transaction_id}/reverse",
                headers=_headers(auth, reverse_operation),
                json=reversal_payload,
            )
            reversed_replay = await client.post(
                f"/api/v1/transactions/{transaction_id}/reverse",
                headers=_headers(auth, reverse_operation),
                json=reversal_payload,
            )
            assert reversed_response.status_code == reversed_replay.status_code == 201
            assert reversed_response.json()["original"]["status"] == "REVERSED"
            assert reversed_response.json()["reversal"]["effect"] == "INFLOW"
            assert reversed_response.json()["reversal"]["reversal_of_id"] == str(transaction_id)
            assert reversed_response.json()["reversal"]["tag_ids"] == [str(tag_id)]
            assert reversed_replay.headers["Idempotency-Replayed"] == "true"

            balance = await client.get(
                f"/api/v1/accounts/{account_id}/balance",
                headers=_headers(auth),
            )
            assert balance.json()["balance"]["amount"] == "100.0000"

            duplicate_reversal_operation = uuid4()
            duplicate_reversal = await client.post(
                f"/api/v1/transactions/{transaction_id}/reverse",
                headers=_headers(auth, duplicate_reversal_operation),
                json={
                    **reversal_payload,
                    "id": str(uuid4()),
                    "client_operation_id": str(duplicate_reversal_operation),
                    "version": 4,
                },
            )
            assert duplicate_reversal.status_code == 409
            assert duplicate_reversal.json()["error"]["code"] == "TRANSACTION_ALREADY_REVERSED"

            incompatible_category = await client.patch(
                f"/api/v1/categories/{food['id']}",
                headers=_headers(auth, uuid4()),
                json={"version": food["version"], "kind": "INCOME"},
            )
            assert incompatible_category.status_code == 409
            assert incompatible_category.json()["error"]["code"] == "CATEGORY_IN_USE"

        async with db_session_factory() as session:
            with pytest.raises(IntegrityError):
                async with session.begin():
                    await session.execute(
                        update(TransactionModel)
                        .where(TransactionModel.id == transaction_id)
                        .values(amount="999.0000")
                    )

        async with db_session_factory() as session:
            actions = set(
                (
                    await session.scalars(
                        select(AuditEventModel.action).where(
                            AuditEventModel.user_id == user_id,
                            AuditEventModel.entity_id == transaction_id,
                        )
                    )
                ).all()
            )
            transaction_count = await session.scalar(
                select(func.count())
                .select_from(TransactionModel)
                .where(TransactionModel.user_id == user_id)
            )
        assert {"CREATE_DRAFT", "UPDATE_DRAFT", "POST", "REVERSE"} <= actions
        assert transaction_count == 2
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)


async def test_category_hierarchy_rejects_cycles_and_lists_archived_entries(
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
            parent_id = uuid4()
            child_id = uuid4()
            parent = await client.post(
                "/api/v1/categories",
                headers=_headers(auth, uuid4()),
                json={
                    "id": str(parent_id),
                    "name": "Parent",
                    "kind": "EXPENSE",
                },
            )
            child = await client.post(
                "/api/v1/categories",
                headers=_headers(auth, uuid4()),
                json={
                    "id": str(child_id),
                    "name": "Child",
                    "kind": "EXPENSE",
                    "parent_id": str(parent_id),
                },
            )
            assert parent.status_code == child.status_code == 201

            cycle = await client.patch(
                f"/api/v1/categories/{parent_id}",
                headers=_headers(auth, uuid4()),
                json={"version": 1, "parent_id": str(child_id)},
            )
            assert cycle.status_code == 422
            assert cycle.json()["error"]["code"] == "CATEGORY_PARENT_INVALID"

            active_children = await client.patch(
                f"/api/v1/categories/{parent_id}",
                headers=_headers(auth, uuid4()),
                json={"version": 1, "archived": True},
            )
            assert active_children.status_code == 409
            assert active_children.json()["error"]["code"] == "CATEGORY_HAS_ACTIVE_CHILDREN"

            archived = await client.patch(
                f"/api/v1/categories/{child_id}",
                headers=_headers(auth, uuid4()),
                json={"version": 1, "archived": True},
            )
            assert archived.status_code == 200
            active_list = await client.get("/api/v1/categories", headers=_headers(auth))
            complete_list = await client.get(
                "/api/v1/categories?include_archived=true",
                headers=_headers(auth),
            )
            assert str(child_id) not in {item["id"] for item in active_list.json()["items"]}
            assert str(child_id) in {item["id"] for item in complete_list.json()["items"]}
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)


async def test_clock_skew_postings_still_enforce_future_projected_balance(
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
            account_id = await _create_account(client, auth)
            categories = (
                await client.get(
                    "/api/v1/categories",
                    headers=_headers(auth),
                )
            ).json()["items"]
            expense_category = next(item for item in categories if item["kind"] == "EXPENSE")
            occurred_at = datetime.now(UTC) + timedelta(minutes=2)

            async def create_and_post(amount: str) -> tuple[UUID, httpx.Response]:
                transaction_id = uuid4()
                create_operation = uuid4()
                created = await client.post(
                    "/api/v1/transactions",
                    headers=_headers(auth, create_operation),
                    json={
                        "id": str(transaction_id),
                        "client_operation_id": str(create_operation),
                        "account_id": str(account_id),
                        "type": "EXPENSE",
                        "amount": {"amount": amount, "currency": "MAD"},
                        "occurred_at": occurred_at.isoformat(),
                        "category_id": expense_category["id"],
                    },
                )
                assert created.status_code == 201, created.text
                posted = await client.post(
                    f"/api/v1/transactions/{transaction_id}/post",
                    headers=_headers(auth, uuid4()),
                    json={"version": 1},
                )
                return transaction_id, posted

            _, first = await create_and_post("60.0000")
            second_id, second = await create_and_post("60.0000")
            assert first.status_code == 200
            assert second.status_code == 409
            assert second.json()["error"]["code"] == "NEGATIVE_BALANCE_NOT_ALLOWED"

            future_balance = await client.get(
                f"/api/v1/accounts/{account_id}/balance",
                headers=_headers(auth),
                params={"as_of": (occurred_at + timedelta(minutes=1)).isoformat()},
            )
            assert future_balance.json()["balance"]["amount"] == "40.0000"
            remaining_draft = await client.get(
                f"/api/v1/transactions/{second_id}",
                headers=_headers(auth),
            )
            assert remaining_draft.json()["status"] == "DRAFT"

            patch_operation = uuid4()
            clear_note = await client.patch(
                f"/api/v1/transactions/{second_id}",
                headers=_headers(auth, patch_operation),
                json={"version": 1, "note": None},
            )
            mismatched_reuse = await client.patch(
                f"/api/v1/transactions/{second_id}",
                headers=_headers(auth, patch_operation),
                json={"version": 1, "category_id": None},
            )
            assert clear_note.status_code == 200
            assert mismatched_reuse.status_code == 409
            assert mismatched_reuse.json()["error"]["code"] == "IDEMPOTENCY_CONFLICT"
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)


async def test_posting_enforces_negative_policy_category_and_ownership(
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
            account_id = await _create_account(client, owner, opening="10.0000")
            categories = (await client.get("/api/v1/categories", headers=_headers(owner))).json()[
                "items"
            ]
            expense_category = next(item for item in categories if item["kind"] == "EXPENSE")

            foreign_account_operation = uuid4()
            foreign_account = await client.post(
                "/api/v1/transactions",
                headers=_headers(stranger, foreign_account_operation),
                json={
                    "id": str(uuid4()),
                    "client_operation_id": str(foreign_account_operation),
                    "account_id": str(account_id),
                    "type": "EXPENSE",
                    "amount": {"amount": "1.0000", "currency": "MAD"},
                    "occurred_at": datetime.now(UTC).isoformat(),
                },
            )
            assert foreign_account.status_code == 404
            assert foreign_account.json()["error"]["code"] == "ACCOUNT_NOT_FOUND"

            transaction_id = uuid4()
            create_operation = uuid4()
            draft = await client.post(
                "/api/v1/transactions",
                headers=_headers(owner, create_operation),
                json={
                    "id": str(transaction_id),
                    "client_operation_id": str(create_operation),
                    "account_id": str(account_id),
                    "type": "EXPENSE",
                    "amount": {"amount": "11.0000", "currency": "MAD"},
                    "occurred_at": datetime.now(UTC).isoformat(),
                    "category_id": expense_category["id"],
                },
            )
            assert draft.status_code == 201
            rejected = await client.post(
                f"/api/v1/transactions/{transaction_id}/post",
                headers=_headers(owner, uuid4()),
                json={"version": 1},
            )
            assert rejected.status_code == 409
            assert rejected.json()["error"]["code"] == "NEGATIVE_BALANCE_NOT_ALLOWED"

            balance = await client.get(
                f"/api/v1/accounts/{account_id}/balance",
                headers=_headers(owner),
            )
            assert balance.json()["balance"]["amount"] == "10.0000"
            current = await client.get(
                f"/api/v1/transactions/{transaction_id}",
                headers=_headers(owner),
            )
            assert current.json()["status"] == "DRAFT"
    finally:
        await app.state.db_engine.dispose()
        await _cleanup(db_session_factory, user_ids)
