import pytest
from app.domain.errors import DomainError
from app.domain.ledger.classification import (
    PortfolioFlowClass,
    classification_for,
    reversal_classification_for,
)
from app.domain.ledger.enums import TransactionKind


def test_every_non_reversal_kind_has_an_explicit_classification() -> None:
    classified = {kind for kind in TransactionKind if kind is not TransactionKind.REVERSAL}

    assert {kind for kind in classified if classification_for(kind)} == classified


@pytest.mark.parametrize(
    ("kind", "spending", "income", "flow"),
    [
        (TransactionKind.EXPENSE, 1, 0, PortfolioFlowClass.EXTERNAL),
        (TransactionKind.INCOME, 0, 1, PortfolioFlowClass.EXTERNAL),
        (TransactionKind.REFUND, -1, 0, PortfolioFlowClass.EXTERNAL),
        (TransactionKind.TRANSFER_OUT, 0, 0, PortfolioFlowClass.INTERNAL),
        (TransactionKind.TRANSFER_FEE, 1, 0, PortfolioFlowClass.EXTERNAL),
        (TransactionKind.LOAN_PRINCIPAL_OUT, 0, 0, PortfolioFlowClass.EXTERNAL),
        (TransactionKind.DEBT_REPAYMENT_OUT, 0, 0, PortfolioFlowClass.EXTERNAL),
        (
            TransactionKind.RECONCILIATION_ADJUSTMENT,
            0,
            0,
            PortfolioFlowClass.NON_CASH_ADJUSTMENT,
        ),
    ],
)
def test_kpi_matrix(
    kind: TransactionKind,
    spending: int,
    income: int,
    flow: PortfolioFlowClass,
) -> None:
    classification = classification_for(kind)

    assert classification.spending_multiplier == spending
    assert classification.income_multiplier == income
    assert classification.portfolio_flow is flow


def test_refund_reversal_restores_spending() -> None:
    classification = reversal_classification_for(TransactionKind.REFUND)

    assert classification.spending_multiplier == 1


def test_reversal_requires_the_original_kind() -> None:
    with pytest.raises(DomainError) as error:
        classification_for(TransactionKind.REVERSAL)

    assert error.value.code == "ORIGINAL_CLASSIFICATION_REQUIRED"
