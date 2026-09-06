from __future__ import annotations

import asyncio
import csv
import io
import json
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Protocol
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import delete, func, insert, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.audit import add_audit_event
from app.db.base import Base
from app.db.models.identity import UserModel
from app.db.models.ledger import AccountModel, CategoryModel, TransactionModel
from app.db.models.purchases import MediaAssetModel, MerchantModel
from app.domain.errors import DomainError
from app.domain.identity.policies import (
    normalize_currency,
    normalize_display_name,
    validate_timezone,
)
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
                    self._spreadsheet_text(account),
                    transaction.type,
                    transaction.effect,
                    format(transaction.amount, "f"),
                    transaction.currency,
                    transaction.status,
                    self._spreadsheet_text(category),
                    self._spreadsheet_text(merchant),
                    self._spreadsheet_text(transaction.counterparty),
                    self._spreadsheet_text(transaction.note),
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
                    self._spreadsheet_text(account.name),
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

    @staticmethod
    def _spreadsheet_text(value: str | None) -> str:
        """Keep user-entered CSV text from being interpreted as a formula."""
        if not value:
            return ""
        if value[0] in {"=", "+", "-", "@", "\t", "\r"}:
            return "'" + value
        return value

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
            "schema_version": 2,
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

    async def restore_portable_backup_in_transaction(
        self,
        *,
        user_id: UUID,
        password: str,
        document: dict[str, object],
        request_id: str | None,
        operation_id: UUID,
    ) -> tuple[int, int]:
        prepared, profile, ignored_receipts, schema_version = self._validate_portable_backup(
            document
        )
        user = (
            await self._session.execute(
                select(UserModel).where(UserModel.id == user_id).with_for_update()
            )
        ).scalar_one_or_none()
        if user is None or not await asyncio.to_thread(
            PasswordService().verify, user.password_hash if user is not None else None, password
        ):
            raise DomainError("INVALID_CREDENTIALS", "Password is incorrect.")
        source_user_id = UUID(str(profile["id"]))
        if source_user_id != user_id:
            source_is_active = await self._session.scalar(
                select(UserModel.id).where(UserModel.id == source_user_id)
            )
            if source_is_active is not None:
                raise DomainError(
                    "BACKUP_SOURCE_STILL_ACTIVE",
                    "The original profile still exists. Sign in to it instead of restoring a copy.",
                )
        await self._require_fresh_restore_target(user_id)
        await self._session.execute(delete(CategoryModel).where(CategoryModel.user_id == user_id))
        restored = 0
        for name in _PORTABLE_TABLES:
            rows = [dict(row, user_id=user_id) for row in prepared[name]]
            if rows:
                await self._session.execute(insert(Base.metadata.tables[name]), rows)
                restored += len(rows)
        user.display_name = normalize_display_name(str(profile["display_name"]))
        user.base_currency = normalize_currency(str(profile["base_currency"]))
        user.timezone = validate_timezone(str(profile["timezone"]))
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="user",
            entity_id=user_id,
            action="PORTABLE_RESTORE",
            after={
                "schema_version": schema_version,
                "restored_rows": restored,
                "ignored_receipt_files": ignored_receipts,
            },
            request_id=request_id,
            client_operation_id=operation_id,
        )
        await self._session.flush()
        return restored, ignored_receipts

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
            if user is None or not await asyncio.to_thread(
                PasswordService().verify,
                user.password_hash if user is not None else None,
                password,
            ):
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

    async def _require_fresh_restore_target(self, user_id: UUID) -> None:
        for name in _PORTABLE_TABLES:
            table = Base.metadata.tables[name]
            statement = select(func.count()).select_from(table).where(table.c.user_id == user_id)
            if name == "categories":
                statement = statement.where(table.c.is_seeded.is_(False))
            if int(await self._session.scalar(statement) or 0) > 0:
                raise DomainError(
                    "BACKUP_RESTORE_TARGET_NOT_EMPTY",
                    "Restore is available only for a fresh profile with no financial records.",
                )
        media_count = int(
            await self._session.scalar(
                select(func.count())
                .select_from(MediaAssetModel)
                .where(MediaAssetModel.user_id == user_id)
            )
            or 0
        )
        if media_count:
            raise DomainError(
                "BACKUP_RESTORE_TARGET_NOT_EMPTY",
                "Restore is available only for a fresh profile with no private media.",
            )

    @classmethod
    def _validate_portable_backup(
        cls, document: dict[str, object]
    ) -> tuple[dict[str, list[dict[str, object | None]]], dict[str, object], int, int]:
        schema_version = document.get("schema_version")
        if (
            document.get("format") != "planit-portable-backup"
            or not isinstance(schema_version, int)
            or isinstance(schema_version, bool)
            or schema_version not in {1, 2}
        ):
            raise DomainError(
                "BACKUP_FORMAT_UNSUPPORTED",
                "Choose an unmodified PlanIT portable-data file with schema version 1 or 2.",
            )
        profile_value = document.get("profile")
        data_value = document.get("data")
        if not isinstance(profile_value, dict) or not isinstance(data_value, dict):
            raise DomainError("BACKUP_INVALID", "The PlanIT data file is incomplete.")
        profile = {str(key): value for key, value in profile_value.items()}
        required_profile = {"id", "display_name", "base_currency", "timezone"}
        if not required_profile.issubset(profile):
            raise DomainError("BACKUP_INVALID", "The PlanIT profile data is incomplete.")
        try:
            source_user_id = UUID(str(profile["id"]))
        except (TypeError, ValueError) as exc:
            raise DomainError(
                "BACKUP_INVALID", "The PlanIT profile identifier is invalid."
            ) from exc
        allowed_sections = {*_PORTABLE_TABLES, "media_assets"}
        if set(data_value) != allowed_sections:
            raise DomainError(
                "BACKUP_FORMAT_UNSUPPORTED",
                "The PlanIT data file has unexpected or missing sections.",
            )
        prepared: dict[str, list[dict[str, object | None]]] = {}
        total_rows = 0
        for name in _PORTABLE_TABLES:
            table = Base.metadata.tables[name]
            raw_rows = data_value[name]
            if not isinstance(raw_rows, list):
                raise DomainError("BACKUP_INVALID", f"The {name} backup section is invalid.")
            total_rows += len(raw_rows)
            if total_rows > 100_000:
                raise DomainError("BACKUP_TOO_LARGE", "The backup contains too many records.")
            expected_columns = set(table.c.keys())
            rows: list[dict[str, object | None]] = []
            for raw in raw_rows:
                if not isinstance(raw, dict):
                    raise DomainError(
                        "BACKUP_FORMAT_UNSUPPORTED",
                        f"The {name} backup structure does not match schema version "
                        f"{schema_version}.",
                    )
                normalized = dict(raw)
                if schema_version == 1:
                    normalized = cls._upgrade_v1_row(name, normalized, expected_columns)
                if set(normalized) != expected_columns:
                    raise DomainError(
                        "BACKUP_FORMAT_UNSUPPORTED",
                        f"The {name} backup structure does not match schema version "
                        f"{schema_version}.",
                    )
                if str(normalized.get("user_id")) != str(source_user_id):
                    raise DomainError(
                        "BACKUP_INVALID", "The backup mixes data from different owners."
                    )
                row = {
                    str(key): cls._restore_value(table.c[str(key)].type.python_type, value)
                    for key, value in normalized.items()
                }
                rows.append(row)
            prepared[name] = rows
        media_value = data_value["media_assets"]
        if not isinstance(media_value, list):
            raise DomainError("BACKUP_INVALID", "The media backup section is invalid.")
        if total_rows + len(media_value) > 100_000:
            raise DomainError("BACKUP_TOO_LARGE", "The backup contains too many records.")
        return prepared, profile, len(media_value), schema_version

    @classmethod
    def _upgrade_v1_row(
        cls,
        table_name: str,
        row: dict[str, object],
        expected_columns: set[str],
    ) -> dict[str, object]:
        """Fill columns introduced after the original portable-backup format."""
        if set(row) == expected_columns:
            return row
        if table_name == "recurring_rules" and set(row) == expected_columns - {"anchor_day"}:
            row["anchor_day"] = cls._legacy_anchor_day(row)
        elif table_name == "transaction_items" and set(row) == expected_columns - {
            "package_size_value_snapshot",
            "package_size_unit_snapshot",
        }:
            row["package_size_value_snapshot"] = None
            row["package_size_unit_snapshot"] = None
        return row

    @staticmethod
    def _legacy_anchor_day(row: dict[str, object]) -> int:
        try:
            due_at = datetime.fromisoformat(str(row["next_due_at"]).replace("Z", "+00:00"))
            if due_at.tzinfo is None:
                raise ValueError("Timestamp has no timezone.")
            return due_at.astimezone(ZoneInfo(str(row["timezone"]))).day
        except (KeyError, TypeError, ValueError, ZoneInfoNotFoundError) as exc:
            raise DomainError("BACKUP_INVALID", "A legacy recurring-rule date is invalid.") from exc

    @staticmethod
    def _restore_value(value_type: type[object], value: object) -> object | None:
        if value is None:
            return None
        try:
            if value_type is UUID:
                return UUID(str(value))
            if value_type is datetime:
                restored = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
                if restored.tzinfo is None:
                    raise ValueError("Timestamp has no timezone.")
                return restored
            if value_type is date:
                return date.fromisoformat(str(value))
            if value_type is Decimal:
                return Decimal(str(value))
            if value_type is bool:
                if not isinstance(value, bool):
                    raise ValueError("Boolean value is invalid.")
                return value
            if value_type is int:
                if not isinstance(value, int) or isinstance(value, bool):
                    raise ValueError("Integer value is invalid.")
                return value
            if value_type is str:
                if not isinstance(value, str):
                    raise ValueError("Text value is invalid.")
                return value
        except (ValueError, TypeError, ArithmeticError) as exc:
            raise DomainError("BACKUP_INVALID", "The backup contains an invalid value.") from exc
        return value

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
