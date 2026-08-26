from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID, uuid5

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.audit import add_audit_event
from app.application.ledger_posting import build_posted_movement
from app.db.models.ledger import (
    AccountModel,
    BalanceReconciliationModel,
    ReallocationLineModel,
    ReallocationSessionModel,
    TransferModel,
)
from app.domain.errors import DomainError
from app.domain.ledger.entities import (
    BalanceReconciliationSnapshot,
    ReallocationSnapshot,
)
from app.domain.ledger.enums import (
    AccountEffect,
    AccountStatus,
    TransactionKind,
)
from app.domain.ledger.reallocation import (
    AccountPosition,
    ReallocationPreview,
    preview_reallocation,
)
from app.domain.ledger.reconciliation import (
    ReconciliationPreview,
    preview_reconciliation,
)
from app.domain.ledger.transactions import (
    normalize_optional_text,
    normalize_timestamp,
    require_not_future,
)
from app.domain.money import Money
from app.infrastructure.repositories.accounts import AccountRepository
from app.infrastructure.repositories.financial_operations import (
    CorrectionRepository,
    TransferRepository,
)
from app.infrastructure.repositories.transactions import TransactionRepository


@dataclass(frozen=True, slots=True)
class ReconciliationPreviewCommand:
    account_id: UUID
    actual_balance: Money
    effective_at: datetime


@dataclass(frozen=True, slots=True)
class CommitReconciliationCommand:
    id: UUID
    client_operation_id: UUID
    adjustment_transaction_id: UUID
    preview: ReconciliationPreviewCommand
    source_fingerprint: str
    reason: str | None


@dataclass(frozen=True, slots=True)
class ReallocationPreviewCommand:
    account_ids: tuple[UUID, ...]
    fixed_total: Money
    balancing_account_id: UUID
    requested_balances: dict[UUID, Money]
    occurred_at: datetime


@dataclass(frozen=True, slots=True)
class CommitReallocationCommand:
    id: UUID
    client_operation_id: UUID
    preview: ReallocationPreviewCommand
    source_fingerprint: str
    note: str | None


class CorrectionService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._accounts = AccountRepository(session)
        self._transactions = TransactionRepository(session)
        self._transfers = TransferRepository(session)
        self._corrections = CorrectionRepository(session)

    async def preview_reconciliation(
        self,
        *,
        user_id: UUID,
        command: ReconciliationPreviewCommand,
    ) -> ReconciliationPreview:
        _, preview = await self._evaluate_reconciliation(
            user_id=user_id,
            command=command,
            for_update=False,
        )
        return preview

    async def commit_reconciliation_in_transaction(
        self,
        *,
        user_id: UUID,
        command: CommitReconciliationCommand,
        request_id: str | None,
    ) -> BalanceReconciliationSnapshot:
        account, preview = await self._evaluate_reconciliation(
            user_id=user_id,
            command=command.preview,
            for_update=True,
        )
        if preview.source_fingerprint != command.source_fingerprint:
            raise DomainError(
                "STALE_BALANCE",
                "Account balance changed after the reconciliation preview.",
                details={"current_source_fingerprint": preview.source_fingerprint},
            )
        if preview.delta.amount == 0:
            raise DomainError(
                "NO_RECONCILIATION_NEEDED",
                "The entered balance already matches the ledger balance.",
            )
        reason = normalize_optional_text(command.reason, field="note", maximum=2000)
        effect = AccountEffect.INFLOW if preview.delta.amount > 0 else AccountEffect.OUTFLOW
        adjustment_amount = Money.calculated(abs(preview.delta.amount), preview.delta.currency)
        adjustment = build_posted_movement(
            transaction_id=command.adjustment_transaction_id,
            user_id=user_id,
            account=account,
            kind=TransactionKind.RECONCILIATION_ADJUSTMENT,
            effect=effect,
            amount=adjustment_amount,
            occurred_at=preview.effective_at,
            counterparty="Balance reconciliation",
            note=reason,
            client_operation_id=uuid5(
                command.client_operation_id,
                "reconciliation-adjustment",
            ),
        )
        reconciliation = BalanceReconciliationModel(
            id=command.id,
            user_id=user_id,
            account_id=account.id,
            calculated_balance=preview.calculated_balance.amount,
            actual_balance=preview.actual_balance.amount,
            delta=preview.delta.amount,
            effective_at=preview.effective_at,
            reason=reason,
            adjustment_transaction_id=adjustment.id,
            source_fingerprint=preview.source_fingerprint,
            client_operation_id=command.client_operation_id,
            version=1,
        )
        self._transactions.add(adjustment)
        await self._flush("RECONCILIATION")
        self._corrections.add_reconciliation(reconciliation)
        account.version += 1
        await self._flush("RECONCILIATION")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="balance_reconciliation",
            entity_id=reconciliation.id,
            action="COMMIT",
            after={
                "account_id": str(account.id),
                "calculated_balance": preview.calculated_balance.to_api(),
                "actual_balance": preview.actual_balance.to_api(),
                "delta": preview.delta.to_api(),
                "currency": preview.delta.currency,
                "effective_at": preview.effective_at.isoformat(),
                "adjustment_transaction_id": str(adjustment.id),
            },
            request_id=request_id,
            client_operation_id=command.client_operation_id,
        )
        return await self._corrections.reconciliation_snapshot_for(reconciliation)

    async def preview_reallocation(
        self,
        *,
        user_id: UUID,
        command: ReallocationPreviewCommand,
    ) -> ReallocationPreview:
        _, preview = await self._evaluate_reallocation(
            user_id=user_id,
            command=command,
            for_update=False,
        )
        return preview

    async def commit_reallocation_in_transaction(
        self,
        *,
        user_id: UUID,
        command: CommitReallocationCommand,
        request_id: str | None,
    ) -> ReallocationSnapshot:
        accounts, preview = await self._evaluate_reallocation(
            user_id=user_id,
            command=command.preview,
            for_update=True,
        )
        if preview.source_fingerprint != command.source_fingerprint:
            raise DomainError(
                "STALE_BALANCE",
                "Account balances changed after the reallocation preview.",
                details={"current_source_fingerprint": preview.source_fingerprint},
            )
        changed_lines = [
            line
            for line in preview.lines
            if line.account_id != preview.balancing_account_id and line.delta.amount != 0
        ]
        if not changed_lines:
            raise DomainError(
                "NO_REALLOCATION_CHANGES",
                "At least one non-balancing account must change.",
            )
        note = normalize_optional_text(command.note, field="note", maximum=2000)
        occurred_at = normalize_timestamp(command.preview.occurred_at)
        session = ReallocationSessionModel(
            id=command.id,
            user_id=user_id,
            fixed_total=preview.fixed_total.amount,
            currency=preview.fixed_total.currency,
            balancing_account_id=preview.balancing_account_id,
            source_fingerprint=preview.source_fingerprint,
            client_operation_id=command.client_operation_id,
        )
        self._corrections.add_reallocation(session)
        await self._flush("REALLOCATION")
        self._corrections.add_reallocation_lines(
            [
                ReallocationLineModel(
                    session_id=session.id,
                    account_id=line.account_id,
                    user_id=user_id,
                    before_balance=line.before.amount,
                    requested_balance=line.target.amount,
                    delta=line.delta.amount,
                )
                for line in preview.lines
            ]
        )
        await self._flush("REALLOCATION")

        balancing = accounts[preview.balancing_account_id]
        involved_account_ids = {balancing.id}
        transfer_ids: list[UUID] = []
        transfer_models: list[TransferModel] = []
        for line in changed_lines:
            changed_account = accounts[line.account_id]
            if line.delta.amount > 0:
                source_account = balancing
                destination_account = changed_account
            else:
                source_account = changed_account
                destination_account = balancing
            amount = Money.calculated(abs(line.delta.amount), preview.fixed_total.currency)
            key = str(line.account_id)
            transfer_id = uuid5(command.id, f"reallocation-transfer:{key}")
            source_id = uuid5(command.id, f"reallocation-source:{key}")
            destination_id = uuid5(command.id, f"reallocation-destination:{key}")
            transfer_operation_id = uuid5(
                command.client_operation_id,
                f"reallocation-transfer:{key}",
            )
            source = build_posted_movement(
                transaction_id=source_id,
                user_id=user_id,
                account=source_account,
                kind=TransactionKind.TRANSFER_OUT,
                effect=AccountEffect.OUTFLOW,
                amount=amount,
                occurred_at=occurred_at,
                counterparty=destination_account.name,
                note=note,
                client_operation_id=uuid5(transfer_operation_id, "source"),
            )
            destination = build_posted_movement(
                transaction_id=destination_id,
                user_id=user_id,
                account=destination_account,
                kind=TransactionKind.TRANSFER_IN,
                effect=AccountEffect.INFLOW,
                amount=amount,
                occurred_at=occurred_at,
                counterparty=source_account.name,
                note=note,
                client_operation_id=uuid5(transfer_operation_id, "destination"),
            )
            self._transactions.add(source)
            self._transactions.add(destination)
            transfer_models.append(
                TransferModel(
                    id=transfer_id,
                    user_id=user_id,
                    source_transaction_id=source.id,
                    destination_transaction_id=destination.id,
                    fee_transaction_id=None,
                    source_amount=amount.amount,
                    destination_amount=amount.amount,
                    fx_rate=None,
                    reallocation_session_id=session.id,
                    source_fingerprint=preview.source_fingerprint,
                    client_operation_id=transfer_operation_id,
                    version=1,
                )
            )
            transfer_ids.append(transfer_id)
            involved_account_ids.add(changed_account.id)

        await self._flush("REALLOCATION")
        for transfer in transfer_models:
            self._transfers.add(transfer)
        for account_id in involved_account_ids:
            accounts[account_id].version += 1
        await self._flush("REALLOCATION")
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="reallocation",
            entity_id=session.id,
            action="COMMIT",
            after={
                "fixed_total": preview.fixed_total.to_api(),
                "currency": preview.fixed_total.currency,
                "balancing_account_id": str(preview.balancing_account_id),
                "transfer_ids": [str(value) for value in transfer_ids],
                "lines": [
                    {
                        "account_id": str(line.account_id),
                        "before": line.before.to_api(),
                        "target": line.target.to_api(),
                        "delta": line.delta.to_api(),
                    }
                    for line in preview.lines
                ],
            },
            request_id=request_id,
            client_operation_id=command.client_operation_id,
        )
        return await self._corrections.reallocation_snapshot_for(session)

    async def _evaluate_reconciliation(
        self,
        *,
        user_id: UUID,
        command: ReconciliationPreviewCommand,
        for_update: bool,
    ) -> tuple[AccountModel, ReconciliationPreview]:
        effective_at = normalize_timestamp(command.effective_at)
        require_not_future(effective_at)
        account = await self._accounts.get_owned(
            account_id=command.account_id,
            user_id=user_id,
            for_update=for_update,
        )
        if account is None:
            raise DomainError("ACCOUNT_NOT_FOUND", "Account was not found.")
        self._require_active(account, "reconciliation")
        if command.actual_balance.currency != account.currency:
            raise DomainError(
                "CURRENCY_MISMATCH",
                "Actual balance must use the account currency.",
            )
        if effective_at < account.opened_at:
            raise DomainError(
                "TRANSACTION_BEFORE_ACCOUNT_OPENED",
                "Reconciliation time cannot be before the account opening time.",
            )
        if command.actual_balance.amount < 0 and not account.allow_negative:
            raise DomainError(
                "NEGATIVE_BALANCE_NOT_ALLOWED",
                "This account does not allow a negative reconciled balance.",
            )
        snapshot = await self._accounts.get_snapshot(
            account_id=account.id,
            user_id=user_id,
            as_of=effective_at,
        )
        if snapshot is None:
            raise DomainError("ACCOUNT_NOT_FOUND", "Account was not found.")
        preview = preview_reconciliation(
            account_id=account.id,
            account_version=account.version,
            calculated_balance=snapshot.calculated_balance,
            actual_balance=command.actual_balance,
            effective_at=effective_at,
        )
        current_snapshot = await self._accounts.get_snapshot(
            account_id=account.id,
            user_id=user_id,
            as_of=max(datetime.now(UTC), effective_at),
        )
        if current_snapshot is None:
            raise DomainError("ACCOUNT_NOT_FOUND", "Account was not found.")
        projected_current_balance = current_snapshot.calculated_balance + preview.delta
        if projected_current_balance.amount < 0 and not account.allow_negative:
            raise DomainError(
                "NEGATIVE_BALANCE_NOT_ALLOWED",
                "This historical reconciliation would make the current balance negative.",
                details={
                    "current_balance": current_snapshot.calculated_balance.to_api(),
                    "reconciliation_delta": preview.delta.to_api(),
                    "projected_current_balance": projected_current_balance.to_api(),
                },
            )
        return account, preview

    async def _evaluate_reallocation(
        self,
        *,
        user_id: UUID,
        command: ReallocationPreviewCommand,
        for_update: bool,
    ) -> tuple[dict[UUID, AccountModel], ReallocationPreview]:
        occurred_at = normalize_timestamp(command.occurred_at)
        require_not_future(occurred_at)
        account_ids = set(command.account_ids)
        if len(account_ids) != len(command.account_ids):
            raise DomainError("DUPLICATE_ACCOUNT", "Each reallocation account must be unique.")
        models = await self._accounts.get_owned_many(
            account_ids=account_ids,
            user_id=user_id,
            for_update=for_update,
        )
        if len(models) != len(account_ids):
            raise DomainError("ACCOUNT_NOT_FOUND", "A reallocation account was not found.")
        accounts = {model.id: model for model in models}
        for account in models:
            self._require_active(account, "reallocation")
            if occurred_at < account.opened_at:
                raise DomainError(
                    "TRANSACTION_BEFORE_ACCOUNT_OPENED",
                    "Reallocation time cannot be before an account opening time.",
                )
        snapshots = await self._accounts.get_snapshots(
            account_ids=account_ids,
            user_id=user_id,
            as_of=max(datetime.now(UTC), occurred_at),
        )
        positions = tuple(
            AccountPosition(
                account_id=snapshot.id,
                balance=snapshot.calculated_balance,
                allow_negative=snapshot.allow_negative,
                version=snapshot.version,
            )
            for snapshot in snapshots
        )
        preview = preview_reallocation(
            positions=positions,
            fixed_total=command.fixed_total,
            balancing_account_id=command.balancing_account_id,
            requested_balances=command.requested_balances,
        )
        return accounts, preview

    @staticmethod
    def _require_active(account: AccountModel, operation: str) -> None:
        if AccountStatus(account.status) is AccountStatus.ACTIVE:
            return
        code = (
            "ACCOUNT_CLOSED"
            if account.status == AccountStatus.CLOSED.value
            else "ACCOUNT_READ_ONLY"
        )
        raise DomainError(code, f"Only active accounts can participate in {operation}.")

    async def _flush(self, operation: str) -> None:
        try:
            await self._session.flush()
        except IntegrityError as exc:
            driver_error = getattr(exc.orig, "__cause__", None)
            constraint_name = getattr(driver_error, "constraint_name", None)
            if constraint_name in {
                "pk_balance_reconciliations",
                "pk_reallocation_sessions",
                "pk_transactions",
                "pk_transfers",
            }:
                raise DomainError(
                    f"{operation}_ID_CONFLICT",
                    "A correction or generated movement identifier is unavailable.",
                ) from exc
            if constraint_name in {
                "uq_balance_reconciliations_user_client_operation",
                "uq_reallocation_sessions_user_client_operation",
                "uq_transactions_user_client_operation",
                "uq_transfers_user_client_operation",
            }:
                raise DomainError(
                    f"{operation}_OPERATION_CONFLICT",
                    "This client operation already belongs to another correction.",
                ) from exc
            raise
