from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.ledger import (
    AccountModel,
    CategoryModel,
    DebtModel,
    DebtPaymentModel,
    ExchangeRateModel,
    SharedExpenseShareModel,
    TagModel,
    TransactionModel,
    TransactionTagModel,
)
from app.db.models.purchases import (
    MerchantLocationModel,
    MerchantModel,
    ProductModel,
    TransactionItemModel,
)


@dataclass(frozen=True, slots=True)
class AnalyticsFacts:
    accounts: tuple[AccountModel, ...]
    transactions: tuple[TransactionModel, ...]
    categories: tuple[CategoryModel, ...]
    tags: tuple[TagModel, ...]
    transaction_tags: tuple[TransactionTagModel, ...]
    merchants: tuple[MerchantModel, ...]
    locations: tuple[MerchantLocationModel, ...]
    products: tuple[ProductModel, ...]
    items: tuple[TransactionItemModel, ...]
    shares: tuple[SharedExpenseShareModel, ...]
    debts: tuple[DebtModel, ...]
    debt_payments: tuple[DebtPaymentModel, ...]
    rates: tuple[ExchangeRateModel, ...]


class AnalyticsRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def facts(self, *, user_id: UUID, through: datetime) -> AnalyticsFacts:
        transactions = tuple(
            (
                await self._session.scalars(
                    select(TransactionModel)
                    .where(
                        TransactionModel.user_id == user_id,
                        TransactionModel.occurred_at < through,
                        TransactionModel.status.in_(["POSTED", "REVERSED"]),
                    )
                    .order_by(TransactionModel.occurred_at, TransactionModel.id)
                )
            ).all()
        )
        transaction_ids = [value.id for value in transactions]
        return AnalyticsFacts(
            accounts=tuple(
                (
                    await self._session.scalars(
                        select(AccountModel).where(AccountModel.user_id == user_id)
                    )
                ).all()
            ),
            transactions=transactions,
            categories=tuple(
                (
                    await self._session.scalars(
                        select(CategoryModel).where(CategoryModel.user_id == user_id)
                    )
                ).all()
            ),
            tags=tuple(
                (
                    await self._session.scalars(select(TagModel).where(TagModel.user_id == user_id))
                ).all()
            ),
            transaction_tags=(
                tuple(
                    (
                        await self._session.scalars(
                            select(TransactionTagModel).where(
                                TransactionTagModel.transaction_id.in_(transaction_ids)
                            )
                        )
                    ).all()
                )
                if transaction_ids
                else ()
            ),
            merchants=tuple(
                (
                    await self._session.scalars(
                        select(MerchantModel).where(MerchantModel.user_id == user_id)
                    )
                ).all()
            ),
            locations=tuple(
                (
                    await self._session.scalars(
                        select(MerchantLocationModel).where(
                            MerchantLocationModel.user_id == user_id
                        )
                    )
                ).all()
            ),
            products=tuple(
                (
                    await self._session.scalars(
                        select(ProductModel).where(ProductModel.user_id == user_id)
                    )
                ).all()
            ),
            items=(
                tuple(
                    (
                        await self._session.scalars(
                            select(TransactionItemModel).where(
                                TransactionItemModel.transaction_id.in_(transaction_ids)
                            )
                        )
                    ).all()
                )
                if transaction_ids
                else ()
            ),
            shares=tuple(
                (
                    await self._session.scalars(
                        select(SharedExpenseShareModel).where(
                            SharedExpenseShareModel.user_id == user_id,
                            SharedExpenseShareModel.created_at < through,
                            SharedExpenseShareModel.status == "ACTIVE",
                        )
                    )
                ).all()
            ),
            debts=tuple(
                (
                    await self._session.scalars(
                        select(DebtModel).where(
                            DebtModel.user_id == user_id,
                            DebtModel.created_at < through,
                            DebtModel.status != "CANCELLED",
                        )
                    )
                ).all()
            ),
            debt_payments=tuple(
                (
                    await self._session.scalars(
                        select(DebtPaymentModel).where(
                            DebtPaymentModel.user_id == user_id,
                            DebtPaymentModel.paid_at < through,
                        )
                    )
                ).all()
            ),
            rates=tuple(
                (
                    await self._session.scalars(
                        select(ExchangeRateModel)
                        .where(
                            ExchangeRateModel.user_id == user_id,
                            ExchangeRateModel.effective_at < through,
                        )
                        .order_by(ExchangeRateModel.effective_at, ExchangeRateModel.id)
                    )
                ).all()
            ),
        )

    def add_rate(self, rate: ExchangeRateModel) -> None:
        self._session.add(rate)

    async def list_rates(self, *, user_id: UUID) -> tuple[ExchangeRateModel, ...]:
        return tuple(
            (
                await self._session.scalars(
                    select(ExchangeRateModel)
                    .where(ExchangeRateModel.user_id == user_id)
                    .order_by(ExchangeRateModel.effective_at.desc(), ExchangeRateModel.id)
                )
            ).all()
        )
