from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.ledger import (
    BalanceReconciliationModel,
    ReallocationLineModel,
    ReallocationSessionModel,
    TransferModel,
)
from app.domain.ledger.entities import (
    BalanceReconciliationSnapshot,
    ReallocationLineSnapshot,
    ReallocationSnapshot,
    TransferSnapshot,
)
from app.domain.money import Money
from app.infrastructure.repositories.transactions import TransactionRepository


class TransferRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._transactions = TransactionRepository(session)

    def add(self, transfer: TransferModel) -> None:
        self._session.add(transfer)

    async def get_owned(
        self,
        *,
        transfer_id: UUID,
        user_id: UUID,
        for_update: bool = False,
    ) -> TransferModel | None:
        statement = select(TransferModel).where(
            TransferModel.id == transfer_id,
            TransferModel.user_id == user_id,
        )
        if for_update:
            statement = statement.with_for_update()
        return (await self._session.execute(statement)).scalar_one_or_none()

    async def for_reallocation(
        self,
        *,
        session_id: UUID,
        user_id: UUID,
    ) -> list[TransferModel]:
        statement = (
            select(TransferModel)
            .where(
                TransferModel.reallocation_session_id == session_id,
                TransferModel.user_id == user_id,
            )
            .order_by(TransferModel.id)
        )
        return list((await self._session.scalars(statement)).all())

    async def snapshot_for(self, model: TransferModel) -> TransferSnapshot:
        await self._session.refresh(model)
        source = await self._transactions.get_snapshot(
            transaction_id=model.source_transaction_id,
            user_id=model.user_id,
        )
        destination = await self._transactions.get_snapshot(
            transaction_id=model.destination_transaction_id,
            user_id=model.user_id,
        )
        fee = None
        if model.fee_transaction_id is not None:
            fee = await self._transactions.get_snapshot(
                transaction_id=model.fee_transaction_id,
                user_id=model.user_id,
            )
        if source is None or destination is None:
            raise RuntimeError("Transfer ledger rows could not be read back.")
        return TransferSnapshot(
            id=model.id,
            user_id=model.user_id,
            source_transaction=source,
            destination_transaction=destination,
            fee_transaction=fee,
            source_amount=Money(model.source_amount, source.amount.currency),
            destination_amount=Money(
                model.destination_amount,
                destination.amount.currency,
            ),
            fx_rate=model.fx_rate,
            reallocation_session_id=model.reallocation_session_id,
            source_fingerprint=model.source_fingerprint,
            client_operation_id=model.client_operation_id,
            version=model.version,
            created_at=model.created_at,
            updated_at=model.updated_at,
        )


class CorrectionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._transactions = TransactionRepository(session)
        self._transfers = TransferRepository(session)

    def add_reconciliation(self, value: BalanceReconciliationModel) -> None:
        self._session.add(value)

    def add_reallocation(self, value: ReallocationSessionModel) -> None:
        self._session.add(value)

    def add_reallocation_lines(self, values: list[ReallocationLineModel]) -> None:
        self._session.add_all(values)

    async def reconciliation_snapshot_for(
        self,
        model: BalanceReconciliationModel,
    ) -> BalanceReconciliationSnapshot:
        await self._session.refresh(model)
        adjustment = await self._transactions.get_snapshot(
            transaction_id=model.adjustment_transaction_id,
            user_id=model.user_id,
        )
        if adjustment is None:
            raise RuntimeError("Reconciliation adjustment could not be read back.")
        currency = adjustment.amount.currency
        return BalanceReconciliationSnapshot(
            id=model.id,
            user_id=model.user_id,
            account_id=model.account_id,
            calculated_balance=Money(model.calculated_balance, currency),
            actual_balance=Money(model.actual_balance, currency),
            delta=Money(model.delta, currency),
            effective_at=model.effective_at,
            reason=model.reason,
            adjustment_transaction=adjustment,
            source_fingerprint=model.source_fingerprint,
            client_operation_id=model.client_operation_id,
            version=model.version,
            created_at=model.created_at,
            updated_at=model.updated_at,
        )

    async def reallocation_snapshot_for(
        self,
        model: ReallocationSessionModel,
    ) -> ReallocationSnapshot:
        await self._session.refresh(model)
        line_statement = (
            select(ReallocationLineModel)
            .where(
                ReallocationLineModel.session_id == model.id,
                ReallocationLineModel.user_id == model.user_id,
            )
            .order_by(ReallocationLineModel.account_id)
        )
        line_models = list((await self._session.scalars(line_statement)).all())
        transfer_models = await self._transfers.for_reallocation(
            session_id=model.id,
            user_id=model.user_id,
        )
        return ReallocationSnapshot(
            id=model.id,
            user_id=model.user_id,
            fixed_total=Money(model.fixed_total, model.currency),
            balancing_account_id=model.balancing_account_id,
            source_fingerprint=model.source_fingerprint,
            client_operation_id=model.client_operation_id,
            lines=tuple(
                ReallocationLineSnapshot(
                    account_id=line.account_id,
                    before_balance=Money(line.before_balance, model.currency),
                    requested_balance=Money(line.requested_balance, model.currency),
                    delta=Money(line.delta, model.currency),
                )
                for line in line_models
            ),
            transfers=tuple(
                [await self._transfers.snapshot_for(transfer) for transfer in transfer_models]
            ),
            created_at=model.created_at,
            updated_at=model.updated_at,
        )
