from __future__ import annotations

from datetime import datetime
from uuid import UUID

from app.db.models.ledger import AccountModel, TransactionModel
from app.domain.ledger.enums import AccountEffect, TransactionKind, TransactionStatus
from app.domain.money import Money


def build_posted_movement(
    *,
    transaction_id: UUID,
    user_id: UUID,
    account: AccountModel,
    kind: TransactionKind,
    effect: AccountEffect,
    amount: Money,
    occurred_at: datetime,
    counterparty: str | None,
    note: str | None,
    client_operation_id: UUID,
) -> TransactionModel:
    return TransactionModel(
        id=transaction_id,
        user_id=user_id,
        account_id=account.id,
        type=kind.value,
        effect=effect.value,
        amount=amount.amount,
        currency=amount.currency,
        occurred_at=occurred_at,
        status=TransactionStatus.POSTED.value,
        category_id=None,
        counterparty=counterparty,
        note=note,
        parent_transaction_id=None,
        reversal_of_id=None,
        client_operation_id=client_operation_id,
        version=1,
    )
