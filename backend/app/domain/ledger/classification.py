from __future__ import annotations

from dataclasses import dataclass, replace
from enum import StrEnum

from app.domain.errors import DomainError
from app.domain.ledger.enums import TransactionKind


class PortfolioFlowClass(StrEnum):
    """How a movement contributes to whole-portfolio cash-flow reporting."""

    EXTERNAL = "EXTERNAL"
    INTERNAL = "INTERNAL"
    NON_CASH_ADJUSTMENT = "NON_CASH_ADJUSTMENT"


@dataclass(frozen=True, slots=True)
class AnalyticsClassification:
    """Central KPI rules for a posted ledger movement.

    Multipliers are deliberately integers. The caller applies them to Decimal
    amounts, preserving the application's no-binary-float rule.
    """

    spending_multiplier: int
    income_multiplier: int
    portfolio_flow: PortfolioFlowClass

    def __post_init__(self) -> None:
        if self.spending_multiplier not in {-1, 0, 1}:
            raise ValueError("Spending multiplier must be -1, 0, or 1.")
        if self.income_multiplier not in {-1, 0, 1}:
            raise ValueError("Income multiplier must be -1, 0, or 1.")

    def reversed(self) -> AnalyticsClassification:
        """Invert KPI effects while retaining the original movement class."""
        return replace(
            self,
            spending_multiplier=-self.spending_multiplier,
            income_multiplier=-self.income_multiplier,
        )


_CLASSIFICATIONS: dict[TransactionKind, AnalyticsClassification] = {
    TransactionKind.EXPENSE: AnalyticsClassification(
        spending_multiplier=1,
        income_multiplier=0,
        portfolio_flow=PortfolioFlowClass.EXTERNAL,
    ),
    TransactionKind.INCOME: AnalyticsClassification(
        spending_multiplier=0,
        income_multiplier=1,
        portfolio_flow=PortfolioFlowClass.EXTERNAL,
    ),
    TransactionKind.TRANSFER_OUT: AnalyticsClassification(
        spending_multiplier=0,
        income_multiplier=0,
        portfolio_flow=PortfolioFlowClass.INTERNAL,
    ),
    TransactionKind.TRANSFER_IN: AnalyticsClassification(
        spending_multiplier=0,
        income_multiplier=0,
        portfolio_flow=PortfolioFlowClass.INTERNAL,
    ),
    TransactionKind.TRANSFER_FEE: AnalyticsClassification(
        spending_multiplier=1,
        income_multiplier=0,
        portfolio_flow=PortfolioFlowClass.EXTERNAL,
    ),
    TransactionKind.REFUND: AnalyticsClassification(
        spending_multiplier=-1,
        income_multiplier=0,
        portfolio_flow=PortfolioFlowClass.EXTERNAL,
    ),
    TransactionKind.LOAN_PRINCIPAL_OUT: AnalyticsClassification(
        spending_multiplier=0,
        income_multiplier=0,
        portfolio_flow=PortfolioFlowClass.EXTERNAL,
    ),
    TransactionKind.LOAN_PRINCIPAL_IN: AnalyticsClassification(
        spending_multiplier=0,
        income_multiplier=0,
        portfolio_flow=PortfolioFlowClass.EXTERNAL,
    ),
    TransactionKind.DEBT_REPAYMENT_IN: AnalyticsClassification(
        spending_multiplier=0,
        income_multiplier=0,
        portfolio_flow=PortfolioFlowClass.EXTERNAL,
    ),
    TransactionKind.DEBT_REPAYMENT_OUT: AnalyticsClassification(
        spending_multiplier=0,
        income_multiplier=0,
        portfolio_flow=PortfolioFlowClass.EXTERNAL,
    ),
    TransactionKind.RECONCILIATION_ADJUSTMENT: AnalyticsClassification(
        spending_multiplier=0,
        income_multiplier=0,
        portfolio_flow=PortfolioFlowClass.NON_CASH_ADJUSTMENT,
    ),
}


def classification_for(kind: TransactionKind) -> AnalyticsClassification:
    """Return static KPI treatment; reversals require their original movement."""
    if kind is TransactionKind.REVERSAL:
        raise DomainError(
            "ORIGINAL_CLASSIFICATION_REQUIRED",
            "A reversal inherits and negates the classification of its original transaction.",
        )
    return _CLASSIFICATIONS[kind]


def reversal_classification_for(
    original_kind: TransactionKind,
) -> AnalyticsClassification:
    if original_kind is TransactionKind.REVERSAL:
        raise DomainError(
            "REVERSAL_OF_REVERSAL_NOT_ALLOWED",
            "A reversal cannot target another reversal transaction.",
        )
    return classification_for(original_kind).reversed()
