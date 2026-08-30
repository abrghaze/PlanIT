from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from app.domain.analytics.policies import AnalyticsPeriod
from app.domain.money import Money


@dataclass(frozen=True, slots=True)
class AnalyticsWarning:
    code: str
    message: str
    currencies: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class AnalyticsKpis:
    money_in_accounts: Money
    net_receivables: Money
    personal_net_position: Money
    gross_spending: Money
    personal_spending: Money
    income: Money
    net_income: Money
    cash_inflow: Money
    cash_outflow: Money
    reconciliation_adjustments: Money
    complete: bool


@dataclass(frozen=True, slots=True)
class TrendPoint:
    period_start: date
    spending: Money
    income: Money
    cash_inflow: Money
    cash_outflow: Money


@dataclass(frozen=True, slots=True)
class BreakdownRow:
    entity_id: UUID | None
    name: str
    amount: Money
    source_transaction_ids: tuple[UUID, ...]
    source_count: int


@dataclass(frozen=True, slots=True)
class AccountFlowRow:
    account_id: UUID
    name: str
    inflow: Money
    outflow: Money
    source_transaction_ids: tuple[UUID, ...]
    source_count: int


@dataclass(frozen=True, slots=True)
class ProductAnalyticsRow:
    product_id: UUID
    name: str
    variant_label: str | None
    total_quantity: Decimal
    spending: Money
    average_unit_price: Money | None
    minimum_unit_price: Money | None
    maximum_unit_price: Money | None
    last_unit_price: Money | None
    normalized_unit: str | None
    normalized_average_price: Money | None
    source_transaction_ids: tuple[UUID, ...]
    source_count: int


@dataclass(frozen=True, slots=True)
class AnalyticsDashboard:
    generated_at: datetime
    base_currency: str
    period: AnalyticsPeriod
    kpis: AnalyticsKpis
    warnings: tuple[AnalyticsWarning, ...]
    trend: tuple[TrendPoint, ...]
    categories: tuple[BreakdownRow, ...]
    merchants: tuple[BreakdownRow, ...]
    branches: tuple[BreakdownRow, ...]
    tags: tuple[BreakdownRow, ...]
    products: tuple[ProductAnalyticsRow, ...]
    accounts: tuple[AccountFlowRow, ...]


@dataclass(frozen=True, slots=True)
class ExchangeRateSnapshot:
    id: UUID
    base_currency: str
    quote_currency: str
    rate: Decimal
    effective_at: datetime
    source: str
    created_at: datetime
    updated_at: datetime
