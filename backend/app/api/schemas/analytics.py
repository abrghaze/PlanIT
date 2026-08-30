from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.api.schemas.money import MoneyPayload
from app.application.analytics import CreateExchangeRateCommand
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
from app.domain.analytics.policies import AnalyticsPeriod


class AnalyticsPeriodResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    preset: AnalyticsPreset
    local_from: date
    local_to: date
    utc_from: datetime
    utc_to: datetime
    timezone: str
    granularity: AnalyticsGranularity

    @classmethod
    def from_domain(cls, value: AnalyticsPeriod) -> Self:
        return cls(**{field: getattr(value, field) for field in cls.model_fields})


class AnalyticsWarningResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    code: str
    message: str
    currencies: list[str]

    @classmethod
    def from_domain(cls, value: AnalyticsWarning) -> Self:
        return cls(code=value.code, message=value.message, currencies=list(value.currencies))


class AnalyticsKpisResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    money_in_accounts: MoneyPayload
    net_receivables: MoneyPayload
    personal_net_position: MoneyPayload
    gross_spending: MoneyPayload
    personal_spending: MoneyPayload
    income: MoneyPayload
    net_income: MoneyPayload
    cash_inflow: MoneyPayload
    cash_outflow: MoneyPayload
    reconciliation_adjustments: MoneyPayload
    complete: bool

    @classmethod
    def from_domain(cls, value: AnalyticsKpis) -> Self:
        return cls(
            **{
                field: MoneyPayload.from_domain(getattr(value, field))
                for field in cls.model_fields
                if field != "complete"
            },
            complete=value.complete,
        )


class TrendPointResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    period_start: date
    spending: MoneyPayload
    income: MoneyPayload
    cash_inflow: MoneyPayload
    cash_outflow: MoneyPayload

    @classmethod
    def from_domain(cls, value: TrendPoint) -> Self:
        return cls(
            period_start=value.period_start,
            spending=MoneyPayload.from_domain(value.spending),
            income=MoneyPayload.from_domain(value.income),
            cash_inflow=MoneyPayload.from_domain(value.cash_inflow),
            cash_outflow=MoneyPayload.from_domain(value.cash_outflow),
        )


class BreakdownRowResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    entity_id: UUID | None
    name: str
    amount: MoneyPayload
    source_transaction_ids: list[UUID]
    source_count: int

    @classmethod
    def from_domain(cls, value: BreakdownRow) -> Self:
        return cls(
            entity_id=value.entity_id,
            name=value.name,
            amount=MoneyPayload.from_domain(value.amount),
            source_transaction_ids=list(value.source_transaction_ids),
            source_count=value.source_count,
        )


class AccountFlowRowResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    account_id: UUID
    name: str
    inflow: MoneyPayload
    outflow: MoneyPayload
    source_transaction_ids: list[UUID]
    source_count: int

    @classmethod
    def from_domain(cls, value: AccountFlowRow) -> Self:
        return cls(
            account_id=value.account_id,
            name=value.name,
            inflow=MoneyPayload.from_domain(value.inflow),
            outflow=MoneyPayload.from_domain(value.outflow),
            source_transaction_ids=list(value.source_transaction_ids),
            source_count=value.source_count,
        )


class ProductAnalyticsRowResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    product_id: UUID
    name: str
    variant_label: str | None
    total_quantity: Decimal
    spending: MoneyPayload
    average_unit_price: MoneyPayload | None
    minimum_unit_price: MoneyPayload | None
    maximum_unit_price: MoneyPayload | None
    last_unit_price: MoneyPayload | None
    normalized_unit: str | None
    normalized_average_price: MoneyPayload | None
    source_transaction_ids: list[UUID]
    source_count: int

    @classmethod
    def from_domain(cls, value: ProductAnalyticsRow) -> Self:
        def money(item: object) -> MoneyPayload | None:
            return None if item is None else MoneyPayload.from_domain(item)  # type: ignore[arg-type]

        return cls(
            product_id=value.product_id,
            name=value.name,
            variant_label=value.variant_label,
            total_quantity=value.total_quantity,
            spending=MoneyPayload.from_domain(value.spending),
            average_unit_price=money(value.average_unit_price),
            minimum_unit_price=money(value.minimum_unit_price),
            maximum_unit_price=money(value.maximum_unit_price),
            last_unit_price=money(value.last_unit_price),
            normalized_unit=value.normalized_unit,
            normalized_average_price=money(value.normalized_average_price),
            source_transaction_ids=list(value.source_transaction_ids),
            source_count=value.source_count,
        )


class AnalyticsDashboardResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    generated_at: datetime
    base_currency: str
    period: AnalyticsPeriodResponse
    kpis: AnalyticsKpisResponse
    warnings: list[AnalyticsWarningResponse]
    trend: list[TrendPointResponse]
    categories: list[BreakdownRowResponse]
    merchants: list[BreakdownRowResponse]
    branches: list[BreakdownRowResponse]
    tags: list[BreakdownRowResponse]
    products: list[ProductAnalyticsRowResponse]
    accounts: list[AccountFlowRowResponse]

    @classmethod
    def from_domain(cls, value: AnalyticsDashboard) -> Self:
        return cls(
            generated_at=value.generated_at,
            base_currency=value.base_currency,
            period=AnalyticsPeriodResponse.from_domain(value.period),
            kpis=AnalyticsKpisResponse.from_domain(value.kpis),
            warnings=[AnalyticsWarningResponse.from_domain(item) for item in value.warnings],
            trend=[TrendPointResponse.from_domain(item) for item in value.trend],
            categories=[BreakdownRowResponse.from_domain(item) for item in value.categories],
            merchants=[BreakdownRowResponse.from_domain(item) for item in value.merchants],
            branches=[BreakdownRowResponse.from_domain(item) for item in value.branches],
            tags=[BreakdownRowResponse.from_domain(item) for item in value.tags],
            products=[ProductAnalyticsRowResponse.from_domain(item) for item in value.products],
            accounts=[AccountFlowRowResponse.from_domain(item) for item in value.accounts],
        )


class ExchangeRateCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    base_currency: str = Field(min_length=3, max_length=3)
    quote_currency: str = Field(min_length=3, max_length=3)
    rate: Decimal = Field(gt=0, max_digits=30, decimal_places=12)
    effective_at: datetime
    source: str = Field(default="manual", min_length=1, max_length=120)

    @field_validator("base_currency", "quote_currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        return value.strip().upper()

    @model_validator(mode="after")
    def currencies_differ(self) -> Self:
        if self.base_currency == self.quote_currency:
            raise ValueError("Exchange-rate currencies must differ.")
        return self

    def to_command(self) -> CreateExchangeRateCommand:
        return CreateExchangeRateCommand(
            id=self.id,
            base_currency=self.base_currency,
            quote_currency=self.quote_currency,
            rate=self.rate,
            effective_at=self.effective_at,
            source=self.source,
        )


class ExchangeRateResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    base_currency: str
    quote_currency: str
    rate: Decimal
    effective_at: datetime
    source: str
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, value: ExchangeRateSnapshot) -> Self:
        return cls(**{field: getattr(value, field) for field in cls.model_fields})


class ExchangeRateListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    items: list[ExchangeRateResponse]
