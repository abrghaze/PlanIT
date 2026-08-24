from __future__ import annotations

from typing import Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.domain.money import Money


class MoneyPayload(BaseModel):
    """JSON money contract: decimal string plus ISO-style currency code."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    amount: str = Field(strict=True, min_length=1)
    currency: str = Field(strict=True, min_length=3, max_length=3)

    @model_validator(mode="after")
    def validate_domain_value(self) -> Self:
        self.to_domain()
        return self

    def to_domain(self) -> Money:
        return Money.of(self.amount, self.currency)

    @classmethod
    def from_domain(cls, money: Money) -> Self:
        return cls(amount=money.to_api(), currency=money.currency)
