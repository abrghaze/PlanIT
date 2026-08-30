from __future__ import annotations

import csv
import io
import json
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Protocol
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.base import Base
from app.db.models.identity import UserModel
from app.db.models.ledger import AccountModel, CategoryModel, TransactionModel
from app.db.models.purchases import MediaAssetModel, MerchantModel
from app.domain.errors import DomainError
from app.infrastructure.repositories.accounts import AccountRepository
from app.infrastructure.repositories.identity import IdentityRepository
from app.infrastructure.security.passwords import PasswordService

_PORTABLE_TABLES = (
    "accounts",
    "categories",
    "tags",
    "transactions",
    "transaction_tags",
    "people",
    "debts",
    "debt_payments",
    "shared_expense_shares",
    "transfers",
    "balance_reconciliations",
    "reallocation_sessions",
    "reallocation_lines",
    "exchange_rates",
    "merchants",
    "merchant_locations",
    "products",
    "transaction_items",
    "recurring_rules",
    "recurring_occurrences",
    "savings_goals",
    "goal_allocations",
)


class ObjectDeleter(Protocol):
    async def delete_many(self, *, keys: list[str]) -> None: ...


class PrivacyService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def transactions_csv(
        self,
        *,
        user_id: UUID,
        date_from: date | None,
        date_to: date | None,
    ) -> bytes:
        self._validate_range(date_from, date_to)
        statement = (
            select(
                TransactionModel,
                AccountModel.name,
                CategoryModel.name,
                MerchantModel.name,
            )
            .join(AccountModel, AccountModel.id == TransactionModel.account_id)
            .outerjoin(CategoryModel, CategoryModel.id == TransactionModel.category_id)
            .outerjoin(MerchantModel, MerchantModel.id == TransactionModel.merchant_id)
            .where(TransactionModel.user_id == user_id)
            .order_by(TransactionModel.occurred_at, TransactionModel.id)
        )
        if date_from is not None:
            statement = statement.where(TransactionModel.occurred_at >= self._day_start(date_from))
        if date_to is not None:
            statement = statement.where(TransactionModel.occurred_at < self._day_start(date_to, 1))
        rows = (await self._session.execute(statement)).all()
        output = io.StringIO(newline="")
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow(
            (
                "id",
                "occurred_at",
                "account",
                "type",
                "effect",
                "amount",
                "currency",
                "status",
                "category",
                "merchant",
                "counterparty",
                "note",
            )
        )
        for transaction, account, category, merchant in rows:
            writer.writerow(
                (
                    transaction.id,
                    transaction.occurred_at.isoformat(),
                    account,
                    transaction.type,
                    transaction.effect,
                    format(transaction.amount, "f"),
                    transaction.currency,
                    transaction.status,
                    category or "",
                    merchant or "",
                    transaction.counterparty or "",
                    transaction.note or "",
                )
            )
        return ("\ufeff" + output.getvalue()).encode("utf-8")

    async def accounts_csv(self, *, user_id: UUID, as_of: datetime | None) -> bytes:
        resolved_as_of = (as_of or datetime.now(UTC)).astimezone(UTC)
        accounts = await AccountRepository(self._session).list_snapshots(
            user_id=user_id,
            as_of=resolved_as_of,
        )
        output = io.StringIO(newline="")
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow(
            (
                "id",
                "name",
                "type",
                "currency",
                "opening_balance",
                "calculated_balance",
                "balance_as_of",
                "status",
                "include_in_total",
            )
        )
        for account in accounts:
            writer.writerow(
                (
                    account.id,
                    account.name,
                    account.type,
                    account.currency,
                    format(account.opening_balance.amount, "f"),
                    format(account.calculated_balance.amount, "f"),
                    account.balance_as_of.isoformat(),
                    account.status,
                    str(account.include_in_total).lower(),
                )
            )
        return ("\ufeff" + output.getvalue()).encode("utf-8")

    async def portable_backup(self, *, user_id: UUID) -> bytes:
        user = await IdentityRepository(self._session).get_user_by_id(user_id)
        if user is None:
            raise DomainError("INVALID_CREDENTIALS", "Authentication credentials are invalid.")
        data: dict[str, list[dict[str, object | None]]] = {}
        for name in _PORTABLE_TABLES:
            table = Base.metadata.tables[name]
            statement = select(table).where(table.c.user_id == user_id)
            if table.primary_key.columns:
                statement = statement.order_by(*table.primary_key.columns)
            rows = (await self._session.execute(statement)).mappings().all()
            data[name] = [
                {key: self._json_value(value) for key, value in row.items()} for row in rows
            ]

        media_rows = (
            await self._session.execute(
                select(MediaAssetModel)
                .where(MediaAssetModel.user_id == user_id)
                .order_by(MediaAssetModel.created_at, MediaAssetModel.id)
            )
        ).scalars()
        data["media_assets"] = [
            {
                "id": str(item.id),
                "kind": item.kind,
                "status": item.status,
                "mime_type": item.mime_type,
                "size_bytes": item.size_bytes,
                "created_at": item.created_at.isoformat(),
                "updated_at": item.updated_at.isoformat(),
            }
            for item in media_rows
        ]
        document = {
            "format": "planit-portable-backup",
            "schema_version": 1,
            "generated_at": datetime.now(UTC).isoformat(),
            "profile": {
                "id": str(user.id),
                "email": user.email,
                "display_name": user.display_name,
                "base_currency": user.base_currency,
                "timezone": user.timezone,
                "created_at": user.created_at.isoformat(),
                "updated_at": user.updated_at.isoformat(),
            },
            "data": data,
        }
        return json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")

    async def delete_profile(
        self,
        *,
        user_id: UUID,
        password: str,
        storage: ObjectDeleter | None,
    ) -> None:
        async with self._session.begin():
            user = (
                await self._session.execute(
                    select(UserModel).where(UserModel.id == user_id).with_for_update()
                )
            ).scalar_one_or_none()
            if user is None or not PasswordService().verify(user.password_hash, password):
                raise DomainError("INVALID_CREDENTIALS", "Password is incorrect.")
            keys = list(
                (
                    await self._session.scalars(
                        select(MediaAssetModel.storage_key).where(
                            MediaAssetModel.user_id == user_id
                        )
                    )
                ).all()
            )
            if keys:
                if storage is None:
                    raise DomainError(
                        "MEDIA_STORAGE_UNAVAILABLE",
                        "Private media storage is required before this profile can be deleted.",
                    )
                await storage.delete_many(keys=keys)
            await self._session.delete(user)
            await self._session.flush()

    @staticmethod
    def _validate_range(date_from: date | None, date_to: date | None) -> None:
        if date_from is not None and date_to is not None and date_from > date_to:
            raise DomainError(
                "EXPORT_DATE_RANGE_INVALID",
                "The export start date must be on or before the end date.",
            )

    @staticmethod
    def _day_start(value: date, offset_days: int = 0) -> datetime:
        from datetime import timedelta

        return datetime.combine(value + timedelta(days=offset_days), datetime.min.time(), UTC)

    @staticmethod
    def _json_value(value: object) -> object | None:
        if value is None or isinstance(value, (str, int, float, bool)):
            return value
        if isinstance(value, Decimal):
            return format(value, "f")
        if isinstance(value, (UUID, datetime, date)):
            return value.isoformat() if not isinstance(value, UUID) else str(value)
        raise TypeError(f"Unsupported portable backup value type: {type(value).__name__}")
