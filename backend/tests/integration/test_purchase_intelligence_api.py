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
            "access_token_secret": "purchase-access-secret-with-at-least-32-characters",
            "refresh_token_pepper": "purchase-refresh-secret-with-at-least-32-characters",
        }
    )


def _headers(auth: dict[str, object], operation: UUID | None = None) -> dict[str, str]:
    result = {"Authorization": f"Bearer {auth['access_token']}"}
    if operation:
        result["Idempotency-Key"] = str(operation)
    return result


async def test_shop_variants_and_exact_itemized_expense(
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
                    "email": f"purchases-{uuid4()}@example.com",
                    "password": "correct horse battery staple",
                    "display_name": "Purchase Owner",
                    "base_currency": "MAD",
                    "timezone": "Africa/Casablanca",
                    "device_label": "pytest",
                },
            )
            assert registration.status_code == 201, registration.text
            auth = registration.json()
            user_id = UUID(auth["user"]["id"])
            categories = (await client.get("/api/v1/categories", headers=_headers(auth))).json()[
                "items"
            ]
            food = next(item for item in categories if item["name"] == "Food & dining")

            account_id = uuid4()
            operation = uuid4()
            account = await client.post(
                "/api/v1/accounts",
                headers=_headers(auth, operation),
                json={
                    "id": str(account_id),
                    "name": "Wallet",
                    "type": "CASH",
                    "opening_balance": {"amount": "100.0000", "currency": "MAD"},
                    "opened_at": (datetime.now(UTC) - timedelta(days=1)).isoformat(),
                    "include_in_total": True,
                    "allow_negative": False,
                    "sort_order": 0,
                },
            )
            assert account.status_code == 201, account.text

            merchant_id = uuid4()
            operation = uuid4()
            merchant = await client.post(
                "/api/v1/merchants",
                headers=_headers(auth, operation),
                json={
                    "id": str(merchant_id),
                    "name": "Market One",
                    "category_id": food["id"],
                    "notes": "Reusable brand",
                },
            )
            assert merchant.status_code == 201, merchant.text
            branch_id = uuid4()
            branch = await client.post(
                f"/api/v1/merchants/{merchant_id}/locations",
                headers=_headers(auth, uuid4()),
                json={"id": str(branch_id), "name": "City Centre", "location_text": "Casablanca"},
            )
            assert branch.status_code == 201, branch.text
            assert branch.json()["locations"][0]["id"] == str(branch_id)

            family_id = uuid4()
            litre_id = uuid4()
            two_litre_id = uuid4()
            for product_id, parent_id, variant, size in [
                (family_id, None, None, None),
                (litre_id, family_id, "1 L", "1"),
                (two_litre_id, family_id, "2 L", "2"),
            ]:
                payload = {
                    "id": str(product_id),
                    "parent_product_id": str(parent_id) if parent_id else None,
                    "name": "Milk",
                    "brand": "Atlas",
                    "variant_label": variant,
                    "size_value": size,
                    "size_unit": "L" if size else None,
                    "category_id": food["id"],
                    "default_merchant_id": str(merchant_id),
                }
                product = await client.post(
                    "/api/v1/products", headers=_headers(auth, uuid4()), json=payload
                )
                assert product.status_code == 201, product.text
            products = await client.get("/api/v1/products?search=milk", headers=_headers(auth))
            assert products.status_code == 200
            assert {item["variant_label"] for item in products.json()["items"]} == {
                None,
                "1 L",
                "2 L",
            }
            normalized = {
                item["variant_label"]: (
                    item["normalized_size_value"],
                    item["normalized_size_unit"],
                )
                for item in products.json()["items"]
            }
            assert normalized["1 L"] == ("1000.000000", "ML")
            assert normalized["2 L"] == ("2000.000000", "ML")

            tx_id = uuid4()
            tx_operation = uuid4()
            base = {
                "id": str(tx_id),
                "client_operation_id": str(tx_operation),
                "account_id": str(account_id),
                "type": "EXPENSE",
                "amount": {"amount": "25.0000", "currency": "MAD"},
                "occurred_at": datetime.now(UTC).isoformat(),
                "category_id": food["id"],
                "merchant_id": str(merchant_id),
                "merchant_location_id": str(branch_id),
                "tag_ids": [],
            }
            mismatch = await client.post(
                "/api/v1/transactions",
                headers=_headers(auth, tx_operation),
                json={
                    **base,
                    "items": [
                        {
                            "id": str(uuid4()),
                            "product_id": str(litre_id),
                            "description": "Milk 1 L",
                            "quantity": "2",
                            "unit_price": "10.0000",
                            "discount": "0.0000",
                        }
                    ],
                },
            )
            assert mismatch.status_code == 422
            assert mismatch.json()["error"]["code"] == "INVALID_LINE_TOTAL"

            tx_operation = uuid4()
            base["client_operation_id"] = str(tx_operation)
            exact = await client.post(
                "/api/v1/transactions",
                headers=_headers(auth, tx_operation),
                json={
                    **base,
                    "items": [
                        {
                            "id": str(uuid4()),
                            "product_id": str(litre_id),
                            "description": "Milk 1 L",
                            "quantity": "2",
                            "unit_price": "10.0000",
                            "discount": "0.0000",
                        },
                        {
                            "id": str(uuid4()),
                            "description": "Unspecified items",
                            "quantity": "1",
                            "unit_price": "5.0000",
                            "discount": "0.0000",
                        },
                    ],
                },
            )
            assert exact.status_code == 201, exact.text
            body = exact.json()
            assert body["merchant_id"] == str(merchant_id)
            assert len(body["items"]) == 2
            posted = await client.post(
                f"/api/v1/transactions/{tx_id}/post",
                headers=_headers(auth, uuid4()),
                json={"version": body["version"]},
            )
            assert posted.status_code == 200, posted.text
            assert sum(float(item["line_total"]) for item in posted.json()["items"]) == 25.0
    finally:
        if user_id:
            async with db_session_factory() as session, session.begin():
                await session.execute(delete(UserModel).where(UserModel.id == user_id))
