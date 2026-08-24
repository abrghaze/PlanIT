from __future__ import annotations

import re
from dataclasses import dataclass
from decimal import ROUND_HALF_EVEN, Decimal, InvalidOperation
from typing import ClassVar, Self

from app.domain.errors import CurrencyMismatchError, DomainError

_CURRENCY_PATTERN = re.compile(r"^[A-Z]{3}$")


@dataclass(frozen=True, slots=True)
class Money:
    """Decimal-safe money at the database's authoritative four-decimal scale."""

    SCALE: ClassVar[Decimal] = Decimal("0.0001")
    MAX_ABS: ClassVar[Decimal] = Decimal("999999999999999.9999")

    amount: Decimal
    currency: str

    def __post_init__(self) -> None:
        amount = self._coerce_exact(self.amount)
        currency = self.currency.strip().upper()

        if not _CURRENCY_PATTERN.fullmatch(currency):
            raise DomainError(
                "INVALID_CURRENCY",
                "Currency must be a three-letter uppercase code.",
                details={"currency": self.currency},
            )
        if abs(amount) > self.MAX_ABS:
            raise DomainError(
                "AMOUNT_OUT_OF_RANGE",
                "Amount exceeds NUMERIC(19,4) storage range.",
            )

        object.__setattr__(self, "amount", amount.quantize(self.SCALE))
        object.__setattr__(self, "currency", currency)

    @classmethod
    def of(cls, amount: str | int | Decimal, currency: str) -> Self:
        if isinstance(amount, (bool, float)):
            raise TypeError("Money cannot be constructed from binary floating point.")
        try:
            decimal_amount = amount if isinstance(amount, Decimal) else Decimal(amount)
        except (InvalidOperation, ValueError) as exc:
            raise DomainError("INVALID_AMOUNT", "Amount must be a valid decimal string.") from exc
        return cls(decimal_amount, currency)

    @classmethod
    def zero(cls, currency: str) -> Self:
        return cls(Decimal("0"), currency)

    @classmethod
    def calculated(cls, amount: Decimal, currency: str) -> Self:
        """Create a value from derived arithmetic using the locked rounding policy."""
        if not amount.is_finite():
            raise DomainError("INVALID_AMOUNT", "Amount must be finite.")
        return cls(amount.quantize(cls.SCALE, rounding=ROUND_HALF_EVEN), currency)

    @classmethod
    def _coerce_exact(cls, value: Decimal) -> Decimal:
        if isinstance(value, float):
            raise TypeError("Money cannot be constructed from binary floating point.")
        if not isinstance(value, Decimal):
            raise TypeError("Money.amount must be a Decimal; use Money.of for input parsing.")
        if not value.is_finite():
            raise DomainError("INVALID_AMOUNT", "Amount must be finite.")
        exponent = value.as_tuple().exponent
        if not isinstance(exponent, int):
            raise DomainError("INVALID_AMOUNT", "Amount must be finite.")
        if exponent < -4:
            raise DomainError(
                "AMOUNT_PRECISION_EXCEEDED",
                "Amount may contain at most four fractional digits.",
                details={"scale": 4},
            )
        return value

    def _require_same_currency(self, other: Money) -> None:
        if self.currency != other.currency:
            raise CurrencyMismatchError(self.currency, other.currency)

    def __add__(self, other: Money) -> Self:
        if not isinstance(other, Money):
            return NotImplemented
        self._require_same_currency(other)
        return type(self).calculated(self.amount + other.amount, self.currency)

    def __sub__(self, other: Money) -> Self:
        if not isinstance(other, Money):
            return NotImplemented
        self._require_same_currency(other)
        return type(self).calculated(self.amount - other.amount, self.currency)

    def __neg__(self) -> Self:
        return type(self).calculated(-self.amount, self.currency)

    def multiply(self, factor: str | int | Decimal) -> Self:
        if isinstance(factor, (bool, float)):
            raise TypeError("Money arithmetic cannot use binary floating point.")
        try:
            decimal_factor = factor if isinstance(factor, Decimal) else Decimal(factor)
        except (InvalidOperation, ValueError) as exc:
            raise DomainError("INVALID_FACTOR", "Money factor must be a valid decimal.") from exc
        if not decimal_factor.is_finite():
            raise DomainError("INVALID_FACTOR", "Money factor must be finite.")
        return type(self).calculated(self.amount * decimal_factor, self.currency)

    def require_non_negative(self, *, code: str = "NEGATIVE_AMOUNT") -> Self:
        if self.amount < 0:
            raise DomainError(code, "Amount cannot be negative.")
        return self

    def require_positive(self, *, code: str = "NON_POSITIVE_AMOUNT") -> Self:
        if self.amount <= 0:
            raise DomainError(code, "Amount must be greater than zero.")
        return self

    def to_api(self) -> str:
        return format(self.amount, ".4f")
