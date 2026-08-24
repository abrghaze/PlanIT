from enum import StrEnum


class AccountEffect(StrEnum):
    INFLOW = "INFLOW"
    OUTFLOW = "OUTFLOW"


class TransactionStatus(StrEnum):
    DRAFT = "DRAFT"
    POSTED = "POSTED"
    REVERSED = "REVERSED"
    VOIDED = "VOIDED"

    @property
    def affects_balance(self) -> bool:
        # A REVERSED original remains part of history and is offset by a posted
        # reversal movement. Excluding it would apply the correction twice.
        return self in {TransactionStatus.POSTED, TransactionStatus.REVERSED}


class TransactionKind(StrEnum):
    EXPENSE = "EXPENSE"
    INCOME = "INCOME"
    TRANSFER_OUT = "TRANSFER_OUT"
    TRANSFER_IN = "TRANSFER_IN"
    TRANSFER_FEE = "TRANSFER_FEE"
    REFUND = "REFUND"
    LOAN_PRINCIPAL_OUT = "LOAN_PRINCIPAL_OUT"
    LOAN_PRINCIPAL_IN = "LOAN_PRINCIPAL_IN"
    DEBT_REPAYMENT_IN = "DEBT_REPAYMENT_IN"
    DEBT_REPAYMENT_OUT = "DEBT_REPAYMENT_OUT"
    RECONCILIATION_ADJUSTMENT = "RECONCILIATION_ADJUSTMENT"
    REVERSAL = "REVERSAL"


class AccountStatus(StrEnum):
    ACTIVE = "ACTIVE"
    ARCHIVED = "ARCHIVED"
    CLOSED = "CLOSED"
