from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID, uuid5

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.audit import add_audit_event
from app.application.ledger_posting import build_posted_movement
from app.db.models.ledger import AccountModel, TransferModel
from app.domain.errors import DomainError
from app.domain.ledger.entities import TransferSnapshot
from app.domain.ledger.enums import (
    AccountEffect,
    AccountStatus,
    TransactionKind,
)
from app.domain.ledger.reallocation import AccountPosition
from app.domain.ledger.transactions import (
    normalize_optional_text,
    normalize_timestamp,
    require_not_future,
)
from app.domain.ledger.transfers import TransferFee, TransferPreview, preview_transfer
from app.domain.money import Money
from app.infrastructure.repositories.accounts import AccountRepository
from app.infrastructure.repositories.financial_operations import TransferRepository
from app.infrastructure.repositories.transactions import TransactionRepository


@dataclass(frozen=True, slots=True)
class TransferPreviewCommand:
    source_account_id: UUID
    destination_account_id: UUID
    source_amount: Money
    destination_amount: Money | None
    fx_rate: Decimal | None
    fee_account_id: UUID | None
    fee_amount: Money | None
    occurred_at: datetime


@dataclass(frozen=True, slots=True)
class CommitTransferCommand:
    id: UUID
    client_operation_id: UUID
    source_transaction_id: UUID
    destination_transaction_id: UUID
    fee_transaction_id: UUID | None
    preview: TransferPreviewCommand
    source_fingerprint: str
    note: str | None


class TransferService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._accounts = AccountRepository(session)
        self._transactions = TransactionRepository(session)
        self._transfers = TransferRepository(session)

    async def preview(
        self,
        *,
        user_id: UUID,
        command: TransferPreviewCommand,
    ) -> TransferPreview:
        _, preview = await self._evaluate(
            user_id=user_id,
            command=command,
            for_update=False,
        )
        return preview

    async def commit_in_transaction(
        self,
        *,
        user_id: UUID,
        command: CommitTransferCommand,
        request_id: str | None,
        reallocation_session_id: UUID | None = None,
    ) -> TransferSnapshot:
        accounts, preview = await self._evaluate(
            user_id=user_id,
            command=command.preview,
            for_update=True,
        )
        if preview.source_fingerprint != command.source_fingerprint:
            raise DomainError(
                "STALE_BALANCE",
                "Account balances changed after the transfer preview.",
                details={"current_source_fingerprint": preview.source_fingerprint},
            )
        ids = {
            command.id,
            command.source_transaction_id,
            command.destination_transaction_id,
        }
        if command.fee_transaction_id is not None:
            ids.add(command.fee_transaction_id)
        expected_id_count = 4 if command.fee_transaction_id is not None else 3
        if len(ids) != expected_id_count:
            raise DomainError(
                "DUPLICATE_OPERATION_ID",
                "Transfer and ledger identifiers must be distinct.",
            )

        note = normalize_optional_text(command.note, field="note", maximum=2000)
        occurred_at = normalize_timestamp(command.preview.occurred_at)
        source_account = accounts[command.preview.source_account_id]
        destination_account = accounts[command.preview.destination_account_id]
        source = build_posted_movement(
            transaction_id=command.source_transaction_id,
            user_id=user_id,
            account=source_account,
            kind=TransactionKind.TRANSFER_OUT,
            effect=AccountEffect.OUTFLOW,
            amount=preview.source_amount,
            occurred_at=occurred_at,
            counterparty=destination_account.name,
            note=note,
            client_operation_id=uuid5(command.client_operation_id, "transfer-source"),
        )
        destination = build_posted_movement(
            transaction_id=command.destination_transaction_id,
            user_id=user_id,
            account=destination_account,
            kind=TransactionKind.TRANSFER_IN,
            effect=AccountEffect.INFLOW,
            amount=preview.destination_amount,
            occurred_at=occurred_at,
            counterparty=source_account.name,
            note=note,
            client_operation_id=uuid5(command.client_operation_id, "transfer-destination"),
        )
        movements = [source, destination]
        fee_model = None
        if preview.fee is not None:
            if command.fee_transaction_id is None:
                raise DomainError(
                    "FEE_TRANSACTION_ID_REQUIRED",
                    "A fee transaction identifier is required when a fee is present.",
                )
            fee_model = build_posted_movement(
                transaction_id=command.fee_transaction_id,
                user_id=user_id,
                account=accounts[preview.fee.account_id],
                kind=TransactionKind.TRANSFER_FEE,
                effect=AccountEffect.OUTFLOW,
                amount=preview.fee.amount,
                occurred_at=occurred_at,
                counterparty="Transfer fee",
                note=note,
                client_operation_id=uuid5(command.client_operation_id, "transfer-fee"),
            )
            movements.append(fee_model)
        elif command.fee_transaction_id is not None:
            raise DomainError(
                "UNEXPECTED_FEE_TRANSACTION_ID",
                "Fee transaction identifier must be omitted when no fee is present.",
            )

        for movement in movements:
            self._transactions.add(movement)
        await self._flush()
        transfer = TransferModel(
            id=command.id,
            user_id=user_id,
            source_transaction_id=source.id,
            destination_transaction_id=destination.id,
            fee_transaction_id=fee_model.id if fee_model else None,
            source_amount=preview.source_amount.amount,
            destination_amount=preview.destination_amount.amount,
            fx_rate=preview.fx_rate,
            reallocation_session_id=reallocation_session_id,
            source_fingerprint=preview.source_fingerprint,
            client_operation_id=command.client_operation_id,
            version=1,
        )
        self._transfers.add(transfer)
        affected_account_ids = {
            command.preview.source_account_id,
            command.preview.destination_account_id,
        }
        if command.preview.fee_account_id is not None:
            affected_account_ids.add(command.preview.fee_account_id)
        for account_id in affected_account_ids:
            accounts[account_id].version += 1
        await self._flush()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="transfer",
            entity_id=transfer.id,
            action="COMMIT",
            after={
                "source_transaction_id": str(source.id),
                "destination_transaction_id": str(destination.id),
                "fee_transaction_id": str(fee_model.id) if fee_model else None,
                "source_amount": preview.source_amount.to_api(),
                "source_currency": preview.source_amount.currency,
                "destination_amount": preview.destination_amount.to_api(),
                "destination_currency": preview.destination_amount.currency,
                "fx_rate": format(preview.fx_rate, ".12f") if preview.fx_rate else None,
                "reallocation_session_id": (
                    str(reallocation_session_id) if reallocation_session_id else None
                ),
            },
            request_id=request_id,
            client_operation_id=command.client_operation_id,
        )
        return await self._transfers.snapshot_for(transfer)

    async def get_transfer(self, *, transfer_id: UUID, user_id: UUID) -> TransferSnapshot:
        model = await self._transfers.get_owned(
            transfer_id=transfer_id,
            user_id=user_id,
        )
        if model is None:
            raise DomainError("TRANSFER_NOT_FOUND", "Transfer was not found.")
        return await self._transfers.snapshot_for(model)

    async def _evaluate(
        self,
        *,
        user_id: UUID,
        command: TransferPreviewCommand,
        for_update: bool,
    ) -> tuple[dict[UUID, AccountModel], TransferPreview]:
        occurred_at = normalize_timestamp(command.occurred_at)
        require_not_future(occurred_at)
        account_ids = {command.source_account_id, command.destination_account_id}
        if command.fee_account_id is not None:
            account_ids.add(command.fee_account_id)
        if (command.fee_account_id is None) != (command.fee_amount is None):
            raise DomainError(
                "INVALID_TRANSFER_FEE",
                "Fee account and fee amount must be supplied together.",
            )
        models = await self._accounts.get_owned_many(
            account_ids=account_ids,
            user_id=user_id,
            for_update=for_update,
        )
        if len(models) != len(account_ids):
            raise DomainError("ACCOUNT_NOT_FOUND", "A transfer account was not found.")
        accounts = {model.id: model for model in models}
        for account in models:
            if AccountStatus(account.status) is not AccountStatus.ACTIVE:
                code = (
                    "ACCOUNT_CLOSED"
                    if account.status == AccountStatus.CLOSED.value
                    else "ACCOUNT_READ_ONLY"
                )
                raise DomainError(code, "Only active accounts can participate in a transfer.")
            if occurred_at < account.opened_at:
                raise DomainError(
                    "TRANSACTION_BEFORE_ACCOUNT_OPENED",
                    "Transfer time cannot be before an account opening time.",
                )
        as_of = max(datetime.now(UTC), occurred_at)
        snapshots = await self._accounts.get_snapshots(
            account_ids=account_ids,
            user_id=user_id,
            as_of=as_of,
        )
        if len(snapshots) != len(account_ids):
            raise DomainError("ACCOUNT_NOT_FOUND", "A transfer account was not found.")
        positions = tuple(
            AccountPosition(
                account_id=snapshot.id,
                balance=snapshot.calculated_balance,
                allow_negative=snapshot.allow_negative,
                version=snapshot.version,
            )
            for snapshot in snapshots
        )
        fee = None
        if command.fee_account_id is not None and command.fee_amount is not None:
            fee = TransferFee(account_id=command.fee_account_id, amount=command.fee_amount)
        preview = preview_transfer(
            positions=positions,
            source_account_id=command.source_account_id,
            destination_account_id=command.destination_account_id,
            source_amount=command.source_amount,
            destination_amount=command.destination_amount,
            fx_rate=command.fx_rate,
            fee=fee,
        )
        return accounts, preview

    async def _flush(self) -> None:
        try:
            await self._session.flush()
        except IntegrityError as exc:
            driver_error = getattr(exc.orig, "__cause__", None)
            constraint_name = getattr(driver_error, "constraint_name", None)
            if constraint_name in {
                "pk_transfers",
                "pk_transactions",
                "uq_transfers_source_transaction_id",
                "uq_transfers_destination_transaction_id",
                "uq_transfers_fee_transaction_id",
            }:
                raise DomainError(
                    "TRANSFER_ID_CONFLICT",
                    "A transfer or movement identifier is unavailable.",
                ) from exc
            if constraint_name in {
                "uq_transfers_user_client_operation",
                "uq_transactions_user_client_operation",
            }:
                raise DomainError(
                    "TRANSFER_OPERATION_CONFLICT",
                    "This client operation already belongs to another transfer.",
                ) from exc
            raise
