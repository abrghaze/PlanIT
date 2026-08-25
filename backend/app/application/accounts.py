from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.audit import add_audit_event
from app.db.models.ledger import AccountModel
from app.domain.accounts.entities import AccountSnapshot
from app.domain.accounts.enums import AccountType
from app.domain.accounts.policies import (
    normalize_account_name,
    require_financial_fields_mutable,
    validate_account_edit,
    validate_negative_policy,
)
from app.domain.errors import DomainError
from app.domain.ledger.enums import AccountStatus
from app.domain.money import Money
from app.infrastructure.repositories.accounts import AccountRepository


@dataclass(frozen=True, slots=True)
class CreateAccountCommand:
    id: UUID
    name: str
    type: AccountType
    opening_balance: Money
    opened_at: datetime
    include_in_total: bool
    allow_negative: bool
    sort_order: int


@dataclass(frozen=True, slots=True)
class UpdateAccountCommand:
    version: int
    values: dict[str, object]


class AccountService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repository = AccountRepository(session)

    async def create_in_transaction(
        self,
        *,
        user_id: UUID,
        command: CreateAccountCommand,
        request_id: str | None,
        client_operation_id: UUID | None = None,
    ) -> AccountSnapshot:
        name = normalize_account_name(command.name)
        validate_negative_policy(
            command.opening_balance,
            allow_negative=command.allow_negative,
        )
        opened_at = self._normalize_timestamp(command.opened_at)
        if opened_at > datetime.now(UTC) + timedelta(minutes=5):
            raise DomainError(
                "INVALID_OPENED_AT",
                "Account opening time cannot be in the future.",
            )
        if command.sort_order < 0:
            raise DomainError("INVALID_SORT_ORDER", "Sort order cannot be negative.")

        account = AccountModel(
            id=command.id,
            user_id=user_id,
            name=name,
            type=command.type.value,
            currency=command.opening_balance.currency,
            opening_balance=command.opening_balance.amount,
            opened_at=opened_at,
            include_in_total=command.include_in_total,
            allow_negative=command.allow_negative,
            status=AccountStatus.ACTIVE.value,
            sort_order=command.sort_order,
            archived_at=None,
            closed_at=None,
            version=1,
        )
        self._repository.add(account)
        try:
            await self._session.flush()
        except IntegrityError as exc:
            driver_error = getattr(exc.orig, "__cause__", None)
            constraint_name = getattr(driver_error, "constraint_name", None)
            if constraint_name == "pk_accounts":
                raise DomainError(
                    "ACCOUNT_ID_CONFLICT",
                    "This account identifier is unavailable.",
                ) from exc
            raise
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="account",
            entity_id=account.id,
            action="CREATE",
            after=self._audit_snapshot(account),
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        snapshot = await self._repository.get_snapshot(
            account_id=account.id,
            user_id=user_id,
            as_of=datetime.now(UTC),
        )
        if snapshot is None:
            raise RuntimeError("Created account could not be read back.")
        return snapshot

    async def list_accounts(
        self,
        *,
        user_id: UUID,
        statuses: set[AccountStatus] | None,
        as_of: datetime | None = None,
    ) -> list[AccountSnapshot]:
        normalized_as_of = self._normalize_timestamp(as_of or datetime.now(UTC))
        return await self._repository.list_snapshots(
            user_id=user_id,
            as_of=normalized_as_of,
            statuses={status.value for status in statuses} if statuses else None,
        )

    async def get_account(
        self,
        *,
        account_id: UUID,
        user_id: UUID,
        as_of: datetime | None = None,
    ) -> AccountSnapshot:
        snapshot = await self._repository.get_snapshot(
            account_id=account_id,
            user_id=user_id,
            as_of=self._normalize_timestamp(as_of or datetime.now(UTC)),
        )
        if snapshot is None:
            raise self._not_found()
        return snapshot

    async def update(
        self,
        *,
        account_id: UUID,
        user_id: UUID,
        command: UpdateAccountCommand,
        request_id: str | None,
    ) -> AccountSnapshot:
        result: AccountSnapshot | None = None
        async with self._session.begin():
            account = await self._repository.get_owned(
                account_id=account_id,
                user_id=user_id,
                for_update=True,
            )
            if account is None:
                raise self._not_found()
            if account.version != command.version:
                raise DomainError(
                    "VERSION_CONFLICT",
                    "The account changed since it was loaded.",
                    details={"current_version": account.version},
                )

            before = self._audit_snapshot(account)
            changed_fields = await self._apply_changes(account, command.values)
            if changed_fields:
                account.version += 1
                await self._session.flush()
                add_audit_event(
                    self._session,
                    user_id=user_id,
                    actor_user_id=user_id,
                    entity_type="account",
                    entity_id=account.id,
                    action=self._audit_action(before["status"], account.status),
                    before=before,
                    after=self._audit_snapshot(account),
                    request_id=request_id,
                )

            result = await self._repository.get_snapshot(
                account_id=account.id,
                user_id=user_id,
                as_of=datetime.now(UTC),
            )

        if result is None:
            raise RuntimeError("Updated account could not be read back.")
        return result

    async def _apply_changes(
        self,
        account: AccountModel,
        requested: dict[str, object],
    ) -> set[str]:
        values = dict(requested)
        if "name" in values:
            values["name"] = normalize_account_name(str(values["name"]))
        if "type" in values:
            values["type"] = AccountType(str(values["type"])).value
        if "status" in values:
            values["status"] = AccountStatus(str(values["status"])).value
        if "opened_at" in values:
            timestamp = values["opened_at"]
            if not isinstance(timestamp, datetime):
                raise TypeError("opened_at must be a datetime.")
            values["opened_at"] = self._normalize_timestamp(timestamp)
        if "sort_order" in values:
            sort_order = values["sort_order"]
            if isinstance(sort_order, bool) or not isinstance(sort_order, int):
                raise TypeError("sort_order must be an integer.")
            if sort_order < 0:
                raise DomainError("INVALID_SORT_ORDER", "Sort order cannot be negative.")

        opening_balance = values.pop("opening_balance", None)
        if opening_balance is not None:
            if not isinstance(opening_balance, Money):
                raise TypeError("opening_balance must be Money.")
            values["opening_balance"] = opening_balance.amount
            values["currency"] = opening_balance.currency

        changed = {field for field, value in values.items() if getattr(account, field) != value}
        if not changed:
            return set()

        current_status = AccountStatus(account.status)
        requested_status = AccountStatus(str(values.get("status", account.status)))
        validate_account_edit(
            current_status=current_status,
            requested_status=requested_status,
            changed_fields=changed,
        )

        financial_fields = {"opening_balance", "currency", "opened_at"}
        if changed & financial_fields:
            require_financial_fields_mutable(
                has_posted_activity=await self._repository.has_posted_activity(account.id)
            )

        raw_opening = values.get("opening_balance", account.opening_balance)
        if not isinstance(raw_opening, Decimal):
            raise TypeError("opening_balance must resolve to Decimal.")
        resulting_opening = Money(raw_opening, str(values.get("currency", account.currency)))
        resulting_allow_negative = bool(values.get("allow_negative", account.allow_negative))
        validate_negative_policy(
            resulting_opening,
            allow_negative=resulting_allow_negative,
        )
        if not resulting_allow_negative:
            current = await self._repository.get_snapshot(
                account_id=account.id,
                user_id=account.user_id,
                as_of=datetime.now(UTC),
            )
            resulting_balance = resulting_opening.amount
            if current is not None and resulting_opening.currency == account.currency:
                resulting_balance = (
                    current.calculated_balance.amount
                    - account.opening_balance
                    + resulting_opening.amount
                )
            if resulting_balance < 0:
                raise DomainError(
                    "NEGATIVE_BALANCE_NOT_ALLOWED",
                    "Negative balances cannot be disabled while the account is below zero.",
                )

        for field, value in values.items():
            setattr(account, field, value)
        if "status" in changed:
            self._apply_lifecycle_timestamps(account, requested_status)
        return changed

    @staticmethod
    def _apply_lifecycle_timestamps(
        account: AccountModel,
        status: AccountStatus,
    ) -> None:
        now = datetime.now(UTC)
        if status is AccountStatus.ACTIVE:
            account.archived_at = None
            account.closed_at = None
        elif status is AccountStatus.ARCHIVED:
            account.archived_at = now
            account.closed_at = None
        else:
            account.archived_at = None
            account.closed_at = now

    @staticmethod
    def _audit_action(previous_status: object, status: str) -> str:
        if previous_status == status:
            return "UPDATE"
        if status == AccountStatus.ARCHIVED.value:
            return "ARCHIVE"
        if status == AccountStatus.CLOSED.value:
            return "CLOSE"
        return "RESTORE"

    @staticmethod
    def _audit_snapshot(account: AccountModel) -> dict[str, object]:
        return {
            "name": account.name,
            "type": account.type,
            "currency": account.currency,
            "opening_balance": format(account.opening_balance, ".4f"),
            "opened_at": account.opened_at.isoformat(),
            "include_in_total": account.include_in_total,
            "allow_negative": account.allow_negative,
            "status": account.status,
            "sort_order": account.sort_order,
            "version": account.version,
        }

    @staticmethod
    def _normalize_timestamp(value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise DomainError("INVALID_TIMESTAMP", "Timestamps must include a timezone.")
        return value.astimezone(UTC)

    @staticmethod
    def _not_found() -> DomainError:
        return DomainError(
            "ACCOUNT_NOT_FOUND",
            "The requested account was not found.",
        )
