from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, timedelta
from decimal import ROUND_HALF_EVEN, Decimal, InvalidOperation
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.ledger import ExchangeRateModel, TransactionModel, TransactionTagModel
from app.db.models.purchases import ProductModel, TransactionItemModel
from app.domain.analytics.entities import (
    AccountFlowRow,
    AnalyticsDashboard,
    AnalyticsKpis,
    AnalyticsWarning,
    BreakdownRow,
    ExchangeRateSnapshot,
    ProductAnalyticsRow,
    TrendPoint,
)
from app.domain.analytics.enums import AnalyticsGranularity, AnalyticsPreset
from app.domain.analytics.policies import (
    AnalyticsPeriod,
    ExchangeRatePoint,
    bucket_start,
    convert_amount,
    normalized_package_quantity,
    resolve_period,
)
from app.domain.errors import DomainError
from app.domain.ledger.classification import (
    AnalyticsClassification,
    PortfolioFlowClass,
    classification_for,
    reversal_classification_for,
)
from app.domain.ledger.enums import AccountEffect, TransactionKind
from app.domain.money import Money
from app.infrastructure.repositories.analytics import AnalyticsFacts, AnalyticsRepository


@dataclass(frozen=True, slots=True)
class CreateExchangeRateCommand:
    id: UUID
    base_currency: str
    quote_currency: str
    rate: Decimal
    effective_at: datetime
    source: str


@dataclass(slots=True)
class _AmountAccumulator:
    amount: Decimal = Decimal("0.0000")
    source_ids: set[UUID] = field(default_factory=set)

    def add(self, amount: Decimal, source_id: UUID) -> None:
        self.amount += amount
        self.source_ids.add(source_id)


@dataclass(slots=True)
class _FlowAccumulator:
    inflow: Decimal = Decimal("0.0000")
    outflow: Decimal = Decimal("0.0000")
    source_ids: set[UUID] = field(default_factory=set)


@dataclass(slots=True)
class _TrendAccumulator:
    spending: Decimal = Decimal("0.0000")
    income: Decimal = Decimal("0.0000")
    cash_inflow: Decimal = Decimal("0.0000")
    cash_outflow: Decimal = Decimal("0.0000")


@dataclass(slots=True)
class _ProductAccumulator:
    spending: Decimal = Decimal("0.0000")
    purchase_total: Decimal = Decimal("0.0000")
    quantity: Decimal = Decimal("0")
    unit_prices: list[tuple[datetime, Decimal]] = field(default_factory=list)
    normalized_total: Decimal = Decimal("0")
    normalized_unit: str | None = None
    normalized_prices: list[tuple[datetime, Decimal]] = field(default_factory=list)
    source_ids: set[UUID] = field(default_factory=set)


class _CurrencyConverter:
    def __init__(self, *, target: str, facts: AnalyticsFacts) -> None:
        self.target = target
        self.missing: set[str] = set()
        self.rates = tuple(
            ExchangeRatePoint(
                base_currency=value.base_currency,
                quote_currency=value.quote_currency,
                rate=value.rate,
                effective_at=value.effective_at,
            )
            for value in facts.rates
        )

    def amount(
        self,
        value: Decimal,
        currency: str,
        at: datetime,
    ) -> Decimal | None:
        result = convert_amount(
            value,
            source_currency=currency,
            target_currency=self.target,
            at=at,
            rates=self.rates,
        )
        if result is None:
            self.missing.add(currency)
        return result


class AnalyticsService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repository = AnalyticsRepository(session)

    async def dashboard(
        self,
        *,
        user_id: UUID,
        base_currency: str,
        timezone: str,
        preset: AnalyticsPreset,
        custom_from: date | None,
        custom_to: date | None,
        granularity: AnalyticsGranularity | None,
    ) -> AnalyticsDashboard:
        generated_at = datetime.now(UTC)
        period = resolve_period(
            preset=preset,
            timezone=timezone,
            custom_from=custom_from,
            custom_to=custom_to,
            granularity=granularity,
            now=generated_at,
        )
        facts = await self._repository.facts(user_id=user_id, through=period.utc_to)
        converter = _CurrencyConverter(target=base_currency, facts=facts)
        return self._build_dashboard(
            facts=facts,
            period=period,
            base_currency=base_currency,
            generated_at=generated_at,
            converter=converter,
        )

    async def create_exchange_rate(
        self,
        *,
        user_id: UUID,
        command: CreateExchangeRateCommand,
    ) -> ExchangeRateSnapshot:
        base = _currency(command.base_currency)
        quote = _currency(command.quote_currency)
        if base == quote:
            raise DomainError("CURRENCY_PAIR_REQUIRED", "Exchange-rate currencies must differ.")
        rate = _rate(command.rate)
        if command.effective_at.tzinfo is None:
            raise DomainError("INVALID_TIMESTAMP", "Exchange-rate timestamps need a timezone.")
        source = command.source.strip()
        if not source:
            raise DomainError("INVALID_EXCHANGE_RATE_SOURCE", "Exchange-rate source is required.")
        model = ExchangeRateModel(
            id=command.id,
            user_id=user_id,
            base_currency=base,
            quote_currency=quote,
            rate=rate,
            effective_at=command.effective_at.astimezone(UTC),
            source=source,
        )
        self._repository.add_rate(model)
        await self._session.flush()
        await self._session.refresh(model)
        return self._rate_snapshot(model)

    async def list_exchange_rates(self, *, user_id: UUID) -> tuple[ExchangeRateSnapshot, ...]:
        return tuple(
            self._rate_snapshot(value)
            for value in await self._repository.list_rates(user_id=user_id)
        )

    def _build_dashboard(
        self,
        *,
        facts: AnalyticsFacts,
        period: AnalyticsPeriod,
        base_currency: str,
        generated_at: datetime,
        converter: _CurrencyConverter,
    ) -> AnalyticsDashboard:
        transaction_map = {value.id: value for value in facts.transactions}
        categories = {value.id: value.name for value in facts.categories}
        tags = {value.id: value.name for value in facts.tags}
        merchants = {value.id: value.name for value in facts.merchants}
        locations = {value.id: value.name for value in facts.locations}
        products = {value.id: value for value in facts.products}
        items = _group_items(facts.items)
        tag_map = _group_tags(facts.transaction_tags)
        share_map = _share_totals(facts)

        money_in_accounts = self._money_in_accounts(facts, period, converter)
        net_receivables = self._net_receivables(facts, period, converter)

        gross_spending = Decimal("0.0000")
        personal_spending = Decimal("0.0000")
        income = Decimal("0.0000")
        cash_inflow = Decimal("0.0000")
        cash_outflow = Decimal("0.0000")
        reconciliation = Decimal("0.0000")
        trend: dict[date, _TrendAccumulator] = {
            value: _TrendAccumulator() for value in _bucket_dates(period)
        }
        category_rows: dict[UUID | None, _AmountAccumulator] = defaultdict(_AmountAccumulator)
        merchant_rows: dict[UUID | None, _AmountAccumulator] = defaultdict(_AmountAccumulator)
        branch_rows: dict[UUID | None, _AmountAccumulator] = defaultdict(_AmountAccumulator)
        tag_rows: dict[UUID | None, _AmountAccumulator] = defaultdict(_AmountAccumulator)
        account_rows: dict[UUID, _FlowAccumulator] = defaultdict(_FlowAccumulator)
        product_rows: dict[UUID, _ProductAccumulator] = defaultdict(_ProductAccumulator)

        period_transactions = [
            value
            for value in facts.transactions
            if period.utc_from <= value.occurred_at < period.utc_to
        ]
        for transaction in period_transactions:
            original, classification = _effective_transaction(transaction, transaction_map)
            converted = converter.amount(
                transaction.amount,
                transaction.currency,
                transaction.occurred_at,
            )
            if converted is None:
                continue
            bucket = trend[
                bucket_start(
                    transaction.occurred_at,
                    timezone=period.timezone,
                    granularity=period.granularity,
                )
            ]
            gross_contribution = converted * classification.spending_multiplier
            share = self._share_adjustment(
                transaction=transaction,
                original=original,
                classification=classification,
                share_map=share_map,
                converter=converter,
            )
            personal_contribution = gross_contribution - share
            income_contribution = converted * classification.income_multiplier
            gross_spending += gross_contribution
            personal_spending += personal_contribution
            income += income_contribution
            bucket.spending += personal_contribution
            bucket.income += income_contribution

            if classification.portfolio_flow is not PortfolioFlowClass.NON_CASH_ADJUSTMENT:
                flow = account_rows[transaction.account_id]
                flow.source_ids.add(transaction.id)
                if transaction.effect == AccountEffect.INFLOW:
                    cash_inflow += converted
                    bucket.cash_inflow += converted
                    flow.inflow += converted
                else:
                    cash_outflow += converted
                    bucket.cash_outflow += converted
                    flow.outflow += converted
            else:
                reconciliation += (
                    converted if transaction.effect == AccountEffect.INFLOW else -converted
                )

            if personal_contribution != 0:
                category_id = original.category_id
                category_rows[category_id].add(personal_contribution, transaction.id)
                merchant_id = original.merchant_id
                merchant_rows[merchant_id].add(personal_contribution, transaction.id)
                branch_id = original.merchant_location_id
                branch_rows[branch_id].add(personal_contribution, transaction.id)
                for tag_id in tag_map.get(original.id, ()):
                    tag_rows[tag_id].add(personal_contribution, transaction.id)
                self._add_products(
                    accumulator=product_rows,
                    transaction=transaction,
                    original=original,
                    contribution=personal_contribution,
                    original_items=items.get(original.id, ()),
                    products=products,
                    converter=converter,
                )

        warning_values: list[AnalyticsWarning] = []
        if converter.missing:
            currencies = tuple(sorted(converter.missing))
            warning_values.append(
                AnalyticsWarning(
                    code="FX_RATE_MISSING",
                    message=(
                        "Some values are excluded because no historical conversion rate "
                        f"to {base_currency} exists."
                    ),
                    currencies=currencies,
                )
            )

        account_names = {value.id: value.name for value in facts.accounts}
        net_position = money_in_accounts + net_receivables
        kpis = AnalyticsKpis(
            money_in_accounts=_money(money_in_accounts, base_currency),
            net_receivables=_money(net_receivables, base_currency),
            personal_net_position=_money(net_position, base_currency),
            gross_spending=_money(gross_spending, base_currency),
            personal_spending=_money(personal_spending, base_currency),
            income=_money(income, base_currency),
            net_income=_money(income - personal_spending, base_currency),
            cash_inflow=_money(cash_inflow, base_currency),
            cash_outflow=_money(cash_outflow, base_currency),
            reconciliation_adjustments=_money(reconciliation, base_currency),
            complete=not converter.missing,
        )
        return AnalyticsDashboard(
            generated_at=generated_at,
            base_currency=base_currency,
            period=period,
            kpis=kpis,
            warnings=tuple(warning_values),
            trend=tuple(
                TrendPoint(
                    period_start=key,
                    spending=_money(value.spending, base_currency),
                    income=_money(value.income, base_currency),
                    cash_inflow=_money(value.cash_inflow, base_currency),
                    cash_outflow=_money(value.cash_outflow, base_currency),
                )
                for key, value in sorted(trend.items())
            ),
            categories=_breakdown(
                category_rows,
                names=categories,
                fallback="Uncategorized",
                currency=base_currency,
            ),
            merchants=_breakdown(
                merchant_rows,
                names=merchants,
                fallback="No merchant",
                currency=base_currency,
            ),
            branches=_breakdown(
                branch_rows,
                names=locations,
                fallback="No branch",
                currency=base_currency,
            ),
            tags=_breakdown(
                tag_rows,
                names=tags,
                fallback="Untagged",
                currency=base_currency,
            ),
            products=_product_breakdown(product_rows, products, base_currency),
            accounts=tuple(
                AccountFlowRow(
                    account_id=key,
                    name=account_names.get(key, "Unknown account"),
                    inflow=_money(value.inflow, base_currency),
                    outflow=_money(value.outflow, base_currency),
                    source_transaction_ids=_source_ids(value.source_ids),
                    source_count=len(value.source_ids),
                )
                for key, value in sorted(
                    account_rows.items(),
                    key=lambda item: item[1].inflow + item[1].outflow,
                    reverse=True,
                )
            ),
        )

    @staticmethod
    def _money_in_accounts(
        facts: AnalyticsFacts,
        period: AnalyticsPeriod,
        converter: _CurrencyConverter,
    ) -> Decimal:
        transactions_by_account: dict[UUID, list[TransactionModel]] = defaultdict(list)
        for transaction in facts.transactions:
            transactions_by_account[transaction.account_id].append(transaction)
        total = Decimal("0.0000")
        valuation_at = period.utc_to - timedelta(microseconds=1)
        for account in facts.accounts:
            if not account.include_in_total or account.opened_at >= period.utc_to:
                continue
            native_balance = account.opening_balance
            for transaction in transactions_by_account.get(account.id, ()):
                native_balance += (
                    transaction.amount
                    if transaction.effect == AccountEffect.INFLOW
                    else -transaction.amount
                )
            converted = converter.amount(native_balance, account.currency, valuation_at)
            if converted is not None:
                total += converted
        return total

    @staticmethod
    def _net_receivables(
        facts: AnalyticsFacts,
        period: AnalyticsPeriod,
        converter: _CurrencyConverter,
    ) -> Decimal:
        paid: dict[UUID, Decimal] = defaultdict(lambda: Decimal("0.0000"))
        for payment in facts.debt_payments:
            paid[payment.debt_id] += payment.amount
        result = Decimal("0.0000")
        valuation_at = period.utc_to - timedelta(microseconds=1)
        for debt in facts.debts:
            remaining = max(Decimal("0.0000"), debt.original_amount - paid[debt.id])
            converted = converter.amount(remaining, debt.currency, valuation_at)
            if converted is None:
                continue
            result += converted if debt.direction == "RECEIVABLE" else -converted
        return result

    @staticmethod
    def _share_adjustment(
        *,
        transaction: TransactionModel,
        original: TransactionModel,
        classification: AnalyticsClassification,
        share_map: dict[UUID, Decimal],
        converter: _CurrencyConverter,
    ) -> Decimal:
        transaction_kind = TransactionKind(transaction.type)
        if original.type != TransactionKind.EXPENSE or transaction_kind not in {
            TransactionKind.EXPENSE,
            TransactionKind.REVERSAL,
        }:
            return Decimal("0.0000")
        shared = share_map.get(original.id, Decimal("0.0000"))
        if shared == 0:
            return shared
        converted = converter.amount(shared, original.currency, transaction.occurred_at)
        if converted is None:
            return Decimal("0.0000")
        return converted * classification.spending_multiplier

    @staticmethod
    def _add_products(
        *,
        accumulator: dict[UUID, _ProductAccumulator],
        transaction: TransactionModel,
        original: TransactionModel,
        contribution: Decimal,
        original_items: tuple[TransactionItemModel, ...],
        products: dict[UUID, ProductModel],
        converter: _CurrencyConverter,
    ) -> None:
        if original.type != TransactionKind.EXPENSE or original.amount == 0:
            return
        converted_original = converter.amount(
            original.amount,
            original.currency,
            transaction.occurred_at,
        )
        if converted_original is None or converted_original == 0:
            return
        ratio = contribution / converted_original
        is_purchase = transaction.id == original.id and contribution > 0
        for item in original_items:
            if item.product_id is None or item.product_id not in products:
                continue
            converted_line = converter.amount(
                item.line_total,
                original.currency,
                transaction.occurred_at,
            )
            if converted_line is None:
                continue
            value = accumulator[item.product_id]
            value.spending += converted_line * ratio
            value.source_ids.add(transaction.id)
            if not is_purchase:
                continue
            value.purchase_total += converted_line
            value.quantity += item.quantity
            if item.quantity > 0:
                value.unit_prices.append((transaction.occurred_at, converted_line / item.quantity))
            normalized = normalized_package_quantity(
                products[item.product_id].size_value,
                products[item.product_id].size_unit,
            )
            if normalized is None:
                continue
            package_quantity, unit = normalized
            normalized_quantity = package_quantity * item.quantity
            if normalized_quantity <= 0:
                continue
            if value.normalized_unit not in {None, unit}:
                value.normalized_unit = None
                value.normalized_total = Decimal("0")
                value.normalized_prices.clear()
                continue
            value.normalized_unit = unit
            value.normalized_total += normalized_quantity
            value.normalized_prices.append(
                (transaction.occurred_at, converted_line / normalized_quantity)
            )

    @staticmethod
    def _rate_snapshot(model: ExchangeRateModel) -> ExchangeRateSnapshot:
        return ExchangeRateSnapshot(
            id=model.id,
            base_currency=model.base_currency,
            quote_currency=model.quote_currency,
            rate=model.rate,
            effective_at=model.effective_at,
            source=model.source,
            created_at=model.created_at,
            updated_at=model.updated_at,
        )


def _effective_transaction(
    transaction: TransactionModel,
    transaction_map: dict[UUID, TransactionModel],
) -> tuple[TransactionModel, AnalyticsClassification]:
    kind = TransactionKind(transaction.type)
    if kind is TransactionKind.REFUND:
        if (
            transaction.parent_transaction_id is None
            or transaction.parent_transaction_id not in transaction_map
        ):
            raise RuntimeError("A refund is missing its owned original transaction.")
        return transaction_map[transaction.parent_transaction_id], classification_for(kind)
    if kind is not TransactionKind.REVERSAL:
        return transaction, classification_for(kind)
    if transaction.reversal_of_id is None or transaction.reversal_of_id not in transaction_map:
        raise RuntimeError("A reversal is missing its owned original transaction.")
    original = transaction_map[transaction.reversal_of_id]
    return original, reversal_classification_for(TransactionKind(original.type))


def _group_items(
    values: tuple[TransactionItemModel, ...],
) -> dict[UUID, tuple[TransactionItemModel, ...]]:
    result: dict[UUID, list[TransactionItemModel]] = defaultdict(list)
    for value in values:
        result[value.transaction_id].append(value)
    return {
        key: tuple(sorted(items, key=lambda item: (item.position, item.id)))
        for key, items in result.items()
    }


def _group_tags(
    values: tuple[TransactionTagModel, ...],
) -> dict[UUID, tuple[UUID, ...]]:
    result: dict[UUID, list[UUID]] = defaultdict(list)
    for value in values:
        result[value.transaction_id].append(value.tag_id)
    return {key: tuple(tags) for key, tags in result.items()}


def _share_totals(facts: AnalyticsFacts) -> dict[UUID, Decimal]:
    result: dict[UUID, Decimal] = defaultdict(lambda: Decimal("0.0000"))
    for share in facts.shares:
        result[share.transaction_id] += share.amount
    return result


def _bucket_dates(period: AnalyticsPeriod) -> tuple[date, ...]:
    values: list[date] = []
    current = bucket_start(
        period.utc_from,
        timezone=period.timezone,
        granularity=period.granularity,
    )
    while current <= period.local_to:
        values.append(current)
        if period.granularity is AnalyticsGranularity.MONTH:
            current = (current.replace(day=28) + timedelta(days=4)).replace(day=1)
        elif period.granularity is AnalyticsGranularity.WEEK:
            current += timedelta(days=7)
        else:
            current += timedelta(days=1)
    return tuple(values)


def _breakdown(
    values: dict[UUID | None, _AmountAccumulator],
    *,
    names: dict[UUID, str],
    fallback: str,
    currency: str,
) -> tuple[BreakdownRow, ...]:
    return tuple(
        BreakdownRow(
            entity_id=key,
            name=names.get(key, fallback) if key is not None else fallback,
            amount=_money(value.amount, currency),
            source_transaction_ids=_source_ids(value.source_ids),
            source_count=len(value.source_ids),
        )
        for key, value in sorted(values.items(), key=lambda item: item[1].amount, reverse=True)
        if value.amount != 0
    )


def _product_breakdown(
    values: dict[UUID, _ProductAccumulator],
    products: dict[UUID, ProductModel],
    currency: str,
) -> tuple[ProductAnalyticsRow, ...]:
    result: list[ProductAnalyticsRow] = []
    for product_id, value in sorted(
        values.items(), key=lambda item: item[1].spending, reverse=True
    ):
        product = products[product_id]
        prices = [price for _, price in value.unit_prices]
        result.append(
            ProductAnalyticsRow(
                product_id=product_id,
                name=product.name,
                variant_label=product.variant_label,
                total_quantity=value.quantity.quantize(Decimal("0.000001")),
                spending=_money(value.spending, currency),
                average_unit_price=(
                    _money(value.purchase_total / value.quantity, currency)
                    if value.quantity > 0
                    else None
                ),
                minimum_unit_price=_money(min(prices), currency) if prices else None,
                maximum_unit_price=_money(max(prices), currency) if prices else None,
                last_unit_price=(
                    _money(max(value.unit_prices, key=lambda item: item[0])[1], currency)
                    if prices
                    else None
                ),
                normalized_unit=value.normalized_unit,
                normalized_average_price=(
                    _money(value.purchase_total / value.normalized_total, currency)
                    if value.normalized_unit is not None and value.normalized_total > 0
                    else None
                ),
                source_transaction_ids=_source_ids(value.source_ids),
                source_count=len(value.source_ids),
            )
        )
    return tuple(result)


def _source_ids(values: set[UUID]) -> tuple[UUID, ...]:
    return tuple(sorted(values, key=str)[:50])


def _money(value: Decimal, currency: str) -> Money:
    return Money.calculated(value, currency)


def _currency(value: str) -> str:
    normalized = value.strip().upper()
    if len(normalized) != 3 or not normalized.isalpha():
        raise DomainError("INVALID_CURRENCY", "Currency must be a three-letter code.")
    return normalized


def _rate(value: Decimal) -> Decimal:
    if not value.is_finite() or value <= 0:
        raise DomainError("INVALID_EXCHANGE_RATE", "Exchange rate must be positive.")
    try:
        normalized = value.quantize(Decimal("0.000000000001"), rounding=ROUND_HALF_EVEN)
    except InvalidOperation as exc:
        raise DomainError("INVALID_EXCHANGE_RATE", "Exchange rate is outside range.") from exc
    if normalized >= Decimal("1000000000000000000"):
        raise DomainError("INVALID_EXCHANGE_RATE", "Exchange rate is outside range.")
    return normalized
