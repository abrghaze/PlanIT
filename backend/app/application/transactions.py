from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.audit import add_audit_event
from app.db.models.ledger import AccountModel, CategoryModel, TransactionModel
from app.db.models.purchases import TransactionItemModel
from app.domain.catalog.enums import CategoryKind
from app.domain.catalog.policies import category_accepts
from app.domain.errors import DomainError
from app.domain.ledger.entities import TransactionSnapshot
from app.domain.ledger.enums import (
    AccountEffect,
    AccountStatus,
    TransactionKind,
    TransactionStatus,
)
from app.domain.ledger.transactions import (
    effect_for,
    normalize_optional_text,
    normalize_timestamp,
    require_core_kind,
    require_draft,
    require_not_future,
    require_reversible,
)
from app.domain.money import Money
from app.domain.purchases.policies import calculate_line_total
from app.infrastructure.repositories.accounts import AccountRepository
from app.infrastructure.repositories.catalog import CatalogRepository
from app.infrastructure.repositories.purchases import PurchaseRepository
from app.infrastructure.repositories.transactions import TransactionRepository


@dataclass(frozen=True, slots=True)
class CreateTransactionCommand:
    id: UUID
    client_operation_id: UUID
    account_id: UUID
    kind: TransactionKind
    amount: Money
    occurred_at: datetime
    category_id: UUID | None
    merchant_id: UUID | None
    merchant_location_id: UUID | None
    counterparty: str | None
    note: str | None
    tag_ids: tuple[UUID, ...]
    items: tuple[TransactionItemCommand, ...]


@dataclass(frozen=True, slots=True)
class TransactionItemCommand:
    id: UUID
    product_id: UUID | None
    description: str
    quantity: Decimal
    unit_price: Decimal
    discount: Decimal


@dataclass(frozen=True, slots=True)
class UpdateTransactionCommand:
    version: int
    values: dict[str, object]


@dataclass(frozen=True, slots=True)
class PostTransactionCommand:
    version: int


@dataclass(frozen=True, slots=True)
class ReverseTransactionCommand:
    id: UUID
    client_operation_id: UUID
    version: int
    occurred_at: datetime
    note: str | None


@dataclass(frozen=True, slots=True)
class ReversalResult:
    original: TransactionSnapshot
    reversal: TransactionSnapshot


class TransactionService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._transactions = TransactionRepository(session)
        self._accounts = AccountRepository(session)
        self._catalog = CatalogRepository(session)
        self._purchases = PurchaseRepository(session)

    async def create_draft_in_transaction(
        self,
        *,
        user_id: UUID,
        command: CreateTransactionCommand,
        request_id: str | None,
    ) -> TransactionSnapshot:
        require_core_kind(command.kind)
        command.amount.require_positive()
        occurred_at = normalize_timestamp(command.occurred_at)
        account = await self._require_account(
            user_id=user_id,
            account_id=command.account_id,
            money=command.amount,
        )
        self._require_occurs_after_opening(occurred_at, account)
        await self._require_category(
            user_id=user_id,
            category_id=command.category_id,
            kind=command.kind,
            required=False,
        )
        tag_ids = set(command.tag_ids)
        await self._require_tags(user_id=user_id, tag_ids=tag_ids)
        await self._require_purchase_details(
            user_id=user_id,
            kind=command.kind,
            amount=command.amount.amount,
            merchant_id=command.merchant_id,
            merchant_location_id=command.merchant_location_id,
            items=command.items,
        )
        model = TransactionModel(
            id=command.id,
            user_id=user_id,
            account_id=account.id,
            type=command.kind.value,
            effect=effect_for(command.kind).value,
            amount=command.amount.amount,
            currency=account.currency,
            occurred_at=occurred_at,
            status=TransactionStatus.DRAFT.value,
            category_id=command.category_id,
            merchant_id=command.merchant_id,
            merchant_location_id=command.merchant_location_id,
            counterparty=normalize_optional_text(
                command.counterparty,
                field="counterparty",
                maximum=160,
            ),
            note=normalize_optional_text(command.note, field="note", maximum=2000),
            parent_transaction_id=None,
            reversal_of_id=None,
            client_operation_id=command.client_operation_id,
            version=1,
        )
        self._transactions.add(model)
        await self._flush_transaction()
        await self._transactions.replace_tags(
            transaction_id=model.id,
            user_id=user_id,
            tag_ids=tag_ids,
        )
        await self._replace_items(model.id, user_id, command.items)
        await self._session.flush()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="transaction",
            entity_id=model.id,
            action="CREATE_DRAFT",
            after=self._audit_snapshot(model, tag_ids),
            request_id=request_id,
            client_operation_id=command.client_operation_id,
        )
        return await self._transactions.snapshot_for(model)

    async def list_transactions(
        self,
        *,
        user_id: UUID,
        statuses: set[TransactionStatus] | None,
        kinds: set[TransactionKind] | None,
        account_id: UUID | None,
        category_id: UUID | None,
        tag_id: UUID | None,
        occurred_from: datetime | None,
        occurred_to: datetime | None,
        limit: int,
        offset: int,
    ) -> list[TransactionSnapshot]:
        normalized_from = normalize_timestamp(occurred_from) if occurred_from else None
        normalized_to = normalize_timestamp(occurred_to) if occurred_to else None
        if normalized_from and normalized_to and normalized_from > normalized_to:
            raise DomainError(
                "INVALID_DATE_RANGE",
                "The start of the date range must not be after its end.",
            )
        return await self._transactions.list_snapshots(
            user_id=user_id,
            statuses={item.value for item in statuses} if statuses else None,
            kinds={item.value for item in kinds} if kinds else None,
            account_id=account_id,
            category_id=category_id,
            tag_id=tag_id,
            occurred_from=normalized_from,
            occurred_to=normalized_to,
            limit=limit,
            offset=offset,
        )

    async def get_transaction(
        self,
        *,
        transaction_id: UUID,
        user_id: UUID,
    ) -> TransactionSnapshot:
        snapshot = await self._transactions.get_snapshot(
            transaction_id=transaction_id,
            user_id=user_id,
        )
        if snapshot is None:
            raise self._not_found()
        return snapshot

    async def update_draft_in_transaction(
        self,
        *,
        transaction_id: UUID,
        user_id: UUID,
        command: UpdateTransactionCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> TransactionSnapshot:
        model = await self._transactions.get_owned(
            transaction_id=transaction_id,
            user_id=user_id,
            for_update=True,
        )
        if model is None:
            raise self._not_found()
        require_draft(TransactionStatus(model.status))
        self._require_version(model.version, command.version)
        before_tags = set(await self._transactions.tag_ids(transaction_id=model.id))
        before = self._audit_snapshot(model, before_tags)

        kind = TransactionKind(str(command.values.get("kind", model.type)))
        require_core_kind(kind)
        raw_amount = command.values.get("amount")
        money = raw_amount if isinstance(raw_amount, Money) else Money(model.amount, model.currency)
        money.require_positive()
        account_id = command.values.get("account_id", model.account_id)
        if not isinstance(account_id, UUID):
            raise TypeError("account_id must be a UUID")
        account = await self._require_account(
            user_id=user_id,
            account_id=account_id,
            money=money,
        )
        raw_occurred = command.values.get("occurred_at", model.occurred_at)
        if not isinstance(raw_occurred, datetime):
            raise TypeError("occurred_at must be a datetime")
        occurred_at = normalize_timestamp(raw_occurred)
        self._require_occurs_after_opening(occurred_at, account)
        category_value = command.values.get("category_id", model.category_id)
        category_id = category_value if isinstance(category_value, UUID) else None
        await self._require_category(
            user_id=user_id,
            category_id=category_id,
            kind=kind,
            required=False,
        )
        raw_tag_ids = command.values.get("tag_ids", tuple(before_tags))
        if not isinstance(raw_tag_ids, tuple):
            raise TypeError("tag_ids must be a tuple")
        tag_ids = set(raw_tag_ids)
        await self._require_tags(user_id=user_id, tag_ids=tag_ids)
        raw_items = command.values.get("items")
        if raw_items is None:
            current = await self._purchases.items_for(transaction_ids=[model.id])
            item_commands = tuple(
                TransactionItemCommand(
                    item.id,
                    item.product_id,
                    item.description,
                    item.quantity,
                    item.unit_price,
                    item.discount,
                )
                for item in current.get(model.id, ())
            )
        elif isinstance(raw_items, tuple):
            item_commands = raw_items
        else:
            raise TypeError("items must be a tuple")
        merchant_value = command.values.get("merchant_id", model.merchant_id)
        merchant_id = merchant_value if isinstance(merchant_value, UUID) else None
        location_value = command.values.get("merchant_location_id", model.merchant_location_id)
        merchant_location_id = location_value if isinstance(location_value, UUID) else None
        await self._require_purchase_details(
            user_id=user_id,
            kind=kind,
            amount=money.amount,
            merchant_id=merchant_id,
            merchant_location_id=merchant_location_id,
            items=item_commands,
        )

        model.account_id = account.id
        model.type = kind.value
        model.effect = effect_for(kind).value
        model.amount = money.amount
        model.currency = account.currency
        model.occurred_at = occurred_at
        model.category_id = category_id
        model.merchant_id = merchant_id
        model.merchant_location_id = merchant_location_id
        if "counterparty" in command.values:
            raw = command.values["counterparty"]
            model.counterparty = normalize_optional_text(
                str(raw) if raw is not None else None,
                field="counterparty",
                maximum=160,
            )
        if "note" in command.values:
            raw = command.values["note"]
            model.note = normalize_optional_text(
                str(raw) if raw is not None else None,
                field="note",
                maximum=2000,
            )
        model.version += 1
        await self._transactions.replace_tags(
            transaction_id=model.id,
            user_id=user_id,
            tag_ids=tag_ids,
        )
        if raw_items is not None:
            await self._replace_items(model.id, user_id, item_commands)
        await self._flush_transaction()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="transaction",
            entity_id=model.id,
            action="UPDATE_DRAFT",
            before=before,
            after=self._audit_snapshot(model, tag_ids),
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        return await self._transactions.snapshot_for(model)

    async def post_in_transaction(
        self,
        *,
        transaction_id: UUID,
        user_id: UUID,
        command: PostTransactionCommand,
        request_id: str | None,
        client_operation_id: UUID,
    ) -> TransactionSnapshot:
        model = await self._transactions.get_owned(
            transaction_id=transaction_id,
            user_id=user_id,
            for_update=True,
        )
        if model is None:
            raise self._not_found()
        require_draft(TransactionStatus(model.status))
        self._require_version(model.version, command.version)
        kind = TransactionKind(model.type)
        require_core_kind(kind)
        require_not_future(model.occurred_at)
        account = await self._require_account(
            user_id=user_id,
            account_id=model.account_id,
            money=Money(model.amount, model.currency),
            for_update=True,
            posting=True,
        )
        self._require_occurs_after_opening(model.occurred_at, account)
        await self._require_category(
            user_id=user_id,
            category_id=model.category_id,
            kind=kind,
            required=True,
        )
        tag_ids = set(await self._transactions.tag_ids(transaction_id=model.id))
        await self._require_tags(user_id=user_id, tag_ids=tag_ids)
        item_map = await self._purchases.items_for(transaction_ids=[model.id])
        await self._require_purchase_details(
            user_id=user_id,
            kind=kind,
            amount=model.amount,
            merchant_id=model.merchant_id,
            merchant_location_id=model.merchant_location_id,
            items=tuple(
                TransactionItemCommand(
                    item.id,
                    item.product_id,
                    item.description,
                    item.quantity,
                    item.unit_price,
                    item.discount,
                )
                for item in item_map.get(model.id, ())
            ),
        )
        await self._require_projected_balance(
            account=account,
            user_id=user_id,
            amount=Money(model.amount, model.currency),
            effect=AccountEffect(model.effect),
            effective_at=model.occurred_at,
        )
        before = self._audit_snapshot(model, tag_ids)
        model.status = TransactionStatus.POSTED.value
        model.version += 1
        account.version += 1
        await self._flush_transaction()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="transaction",
            entity_id=model.id,
            action="POST",
            before=before,
            after=self._audit_snapshot(model, tag_ids),
            request_id=request_id,
            client_operation_id=client_operation_id,
        )
        return await self._transactions.snapshot_for(model)

    async def reverse_in_transaction(
        self,
        *,
        transaction_id: UUID,
        user_id: UUID,
        command: ReverseTransactionCommand,
        request_id: str | None,
    ) -> ReversalResult:
        original = await self._transactions.get_owned(
            transaction_id=transaction_id,
            user_id=user_id,
            for_update=True,
        )
        if original is None:
            raise self._not_found()
        self._require_version(original.version, command.version)
        original_kind = TransactionKind(original.type)
        require_reversible(TransactionStatus(original.status), original_kind)
        occurred_at = normalize_timestamp(command.occurred_at)
        require_not_future(occurred_at)
        if occurred_at < original.occurred_at:
            raise DomainError(
                "REVERSAL_BEFORE_ORIGINAL",
                "A reversal cannot occur before its original transaction.",
            )
        money = Money(original.amount, original.currency)
        account = await self._require_account(
            user_id=user_id,
            account_id=original.account_id,
            money=money,
            for_update=True,
            posting=True,
        )
        reversal_effect = (
            AccountEffect.OUTFLOW
            if AccountEffect(original.effect) is AccountEffect.INFLOW
            else AccountEffect.INFLOW
        )
        await self._require_projected_balance(
            account=account,
            user_id=user_id,
            amount=money,
            effect=reversal_effect,
            effective_at=occurred_at,
        )
        original_tag_ids = set(await self._transactions.tag_ids(transaction_id=original.id))
        before = self._audit_snapshot(original, original_tag_ids)
        reversal = TransactionModel(
            id=command.id,
            user_id=user_id,
            account_id=original.account_id,
            type=TransactionKind.REVERSAL.value,
            effect=reversal_effect.value,
            amount=original.amount,
            currency=original.currency,
            occurred_at=occurred_at,
            status=TransactionStatus.DRAFT.value,
            category_id=original.category_id,
            merchant_id=None,
            merchant_location_id=None,
            counterparty=original.counterparty,
            note=normalize_optional_text(command.note, field="note", maximum=2000),
            parent_transaction_id=original.id,
            reversal_of_id=original.id,
            client_operation_id=command.client_operation_id,
            version=1,
        )
        self._transactions.add(reversal)
        await self._flush_transaction()
        await self._transactions.replace_tags(
            transaction_id=reversal.id,
            user_id=user_id,
            tag_ids=original_tag_ids,
        )
        await self._session.flush()
        original.status = TransactionStatus.REVERSED.value
        original.version += 1
        reversal.status = TransactionStatus.POSTED.value
        account.version += 1
        await self._flush_transaction()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="transaction",
            entity_id=original.id,
            action="REVERSE",
            before=before,
            after={
                **self._audit_snapshot(original, original_tag_ids),
                "reversal_id": str(reversal.id),
            },
            request_id=request_id,
            client_operation_id=command.client_operation_id,
        )
        return ReversalResult(
            original=await self._transactions.snapshot_for(original),
            reversal=await self._transactions.snapshot_for(reversal),
        )

    async def _require_account(
        self,
        *,
        user_id: UUID,
        account_id: UUID,
        money: Money,
        for_update: bool = False,
        posting: bool = False,
    ) -> AccountModel:
        account = await self._accounts.get_owned(
            account_id=account_id,
            user_id=user_id,
            for_update=for_update,
        )
        if account is None:
            raise DomainError("ACCOUNT_NOT_FOUND", "Account was not found.")
        if account.currency != money.currency:
            raise DomainError(
                "CURRENCY_MISMATCH",
                "Transaction currency must match the selected account.",
                details={
                    "account_currency": account.currency,
                    "transaction_currency": money.currency,
                },
            )
        if posting and AccountStatus(account.status) is not AccountStatus.ACTIVE:
            code = (
                "ACCOUNT_CLOSED" if account.status == AccountStatus.CLOSED else "ACCOUNT_READ_ONLY"
            )
            raise DomainError(code, "Only an active account accepts new financial postings.")
        return account

    async def _require_category(
        self,
        *,
        user_id: UUID,
        category_id: UUID | None,
        kind: TransactionKind,
        required: bool,
    ) -> CategoryModel | None:
        if category_id is None:
            if required:
                raise DomainError(
                    "CATEGORY_REQUIRED",
                    "Choose a category before posting this transaction.",
                )
            return None
        category = await self._catalog.get_category(
            category_id=category_id,
            user_id=user_id,
        )
        if category is None or category.archived_at is not None:
            raise DomainError("CATEGORY_NOT_FOUND", "Category was not found.")
        if not category_accepts(
            category_kind=CategoryKind(category.kind),
            transaction_kind=kind.value,
        ):
            raise DomainError(
                "CATEGORY_KIND_MISMATCH",
                "This category cannot classify the selected transaction type.",
            )
        return category

    async def _require_tags(self, *, user_id: UUID, tag_ids: set[UUID]) -> None:
        if len(tag_ids) > 20:
            raise DomainError("TOO_MANY_TAGS", "A transaction can use at most 20 tags.")
        active = await self._catalog.get_active_tags(user_id=user_id, tag_ids=tag_ids)
        if len(active) != len(tag_ids):
            raise DomainError("TAG_NOT_FOUND", "One or more tags were not found.")

    async def _require_purchase_details(
        self,
        *,
        user_id: UUID,
        kind: TransactionKind,
        amount: Decimal,
        merchant_id: UUID | None,
        merchant_location_id: UUID | None,
        items: tuple[TransactionItemCommand, ...],
    ) -> None:
        if (merchant_id is not None or merchant_location_id is not None or items) and (
            kind is not TransactionKind.EXPENSE
        ):
            raise DomainError(
                "PURCHASE_DETAILS_EXPENSE_ONLY",
                "Shop and item details are available only for expenses.",
            )
        merchant = None
        if merchant_id is not None:
            merchant = await self._purchases.get_merchant(
                merchant_id=merchant_id,
                user_id=user_id,
            )
            if merchant is None or merchant.archived_at is not None:
                raise DomainError("MERCHANT_NOT_FOUND", "Shop was not found.")
        if merchant_location_id is not None:
            if merchant is None:
                raise DomainError(
                    "MERCHANT_REQUIRED",
                    "Select the shop before selecting a branch.",
                )
            location = await self._purchases.get_location(
                location_id=merchant_location_id,
                user_id=user_id,
            )
            if (
                location is None
                or location.archived_at is not None
                or location.merchant_id != merchant.id
            ):
                raise DomainError(
                    "MERCHANT_LOCATION_NOT_FOUND",
                    "Shop branch was not found.",
                )
        if len(items) > 200:
            raise DomainError("TOO_MANY_ITEMS", "A purchase can contain at most 200 lines.")
        total = Decimal("0")
        seen_ids: set[UUID] = set()
        for item in items:
            if item.id in seen_ids:
                raise DomainError(
                    "DUPLICATE_ITEM_ID",
                    "Item identifiers must be unique.",
                )
            seen_ids.add(item.id)
            description = item.description.strip()
            if not description or len(description) > 240:
                raise DomainError(
                    "INVALID_ITEM_DESCRIPTION",
                    "Item description must contain 1 to 240 characters.",
                )
            if item.product_id is not None:
                product = await self._purchases.get_product(
                    product_id=item.product_id,
                    user_id=user_id,
                )
                if product is None or product.archived_at is not None:
                    raise DomainError("PRODUCT_NOT_FOUND", "Product was not found.")
            total += calculate_line_total(item.quantity, item.unit_price, item.discount)
        if items and total != amount:
            raise DomainError(
                "INVALID_LINE_TOTAL",
                "Item lines must total exactly to the expense amount.",
                details={
                    "item_total": format(total, ".4f"),
                    "transaction_total": format(amount, ".4f"),
                    "difference": format(amount - total, ".4f"),
                },
            )

    async def _replace_items(
        self,
        transaction_id: UUID,
        user_id: UUID,
        items: tuple[TransactionItemCommand, ...],
    ) -> None:
        await self._purchases.replace_items(
            transaction_id=transaction_id,
            user_id=user_id,
            items=[
                TransactionItemModel(
                    id=item.id,
                    user_id=user_id,
                    transaction_id=transaction_id,
                    product_id=item.product_id,
                    description_snapshot=item.description.strip(),
                    quantity=item.quantity,
                    unit_price=item.unit_price,
                    discount=item.discount,
                    line_total=calculate_line_total(
                        item.quantity,
                        item.unit_price,
                        item.discount,
                    ),
                    position=index,
                )
                for index, item in enumerate(items)
            ],
        )

    async def _require_projected_balance(
        self,
        *,
        account: AccountModel,
        user_id: UUID,
        amount: Money,
        effect: AccountEffect,
        effective_at: datetime,
    ) -> None:
        if account.allow_negative or effect is AccountEffect.INFLOW:
            return
        snapshot = await self._accounts.get_snapshot(
            account_id=account.id,
            user_id=user_id,
            as_of=max(datetime.now(UTC), effective_at),
        )
        if snapshot is None:
            raise DomainError("ACCOUNT_NOT_FOUND", "Account was not found.")
        projected = snapshot.calculated_balance - amount
        if projected.amount < 0:
            raise DomainError(
                "NEGATIVE_BALANCE_NOT_ALLOWED",
                "This posting would make the account balance negative.",
                details={
                    "current_balance": snapshot.calculated_balance.to_api(),
                    "projected_balance": projected.to_api(),
                    "currency": account.currency,
                },
            )

    async def _flush_transaction(self) -> None:
        try:
            await self._session.flush()
        except IntegrityError as exc:
            driver_error = getattr(exc.orig, "__cause__", None)
            constraint_name = getattr(driver_error, "constraint_name", None)
            if constraint_name == "pk_transactions":
                raise DomainError(
                    "TRANSACTION_ID_CONFLICT",
                    "This transaction identifier is unavailable.",
                ) from exc
            if constraint_name == "uq_transactions_user_client_operation":
                raise DomainError(
                    "TRANSACTION_OPERATION_CONFLICT",
                    "This client operation already belongs to another transaction.",
                ) from exc
            if constraint_name == "uq_transactions_reversal_of_id":
                raise DomainError(
                    "TRANSACTION_ALREADY_REVERSED",
                    "This transaction has already been reversed.",
                ) from exc
            raise

    @staticmethod
    def _require_occurs_after_opening(occurred_at: datetime, account: AccountModel) -> None:
        if occurred_at < account.opened_at:
            raise DomainError(
                "TRANSACTION_BEFORE_ACCOUNT_OPENED",
                "Transaction time cannot be before the account opening time.",
            )

    @staticmethod
    def _require_version(current: int, requested: int) -> None:
        if current != requested:
            raise DomainError(
                "VERSION_CONFLICT",
                "This transaction changed since it was loaded.",
                details={"current_version": current},
            )

    @staticmethod
    def _not_found() -> DomainError:
        return DomainError("TRANSACTION_NOT_FOUND", "Transaction was not found.")

    @staticmethod
    def _audit_snapshot(
        model: TransactionModel,
        tag_ids: set[UUID],
    ) -> dict[str, object]:
        return {
            "account_id": str(model.account_id),
            "type": model.type,
            "effect": model.effect,
            "amount": format(model.amount, ".4f"),
            "currency": model.currency,
            "occurred_at": model.occurred_at.isoformat(),
            "status": model.status,
            "category_id": str(model.category_id) if model.category_id else None,
            "merchant_id": str(model.merchant_id) if model.merchant_id else None,
            "merchant_location_id": (
                str(model.merchant_location_id) if model.merchant_location_id else None
            ),
            "tag_ids": sorted(str(tag_id) for tag_id in tag_ids),
            "version": model.version,
        }
