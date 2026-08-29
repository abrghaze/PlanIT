from enum import StrEnum


class DebtDirection(StrEnum):
    RECEIVABLE = "RECEIVABLE"
    PAYABLE = "PAYABLE"


class DebtOriginType(StrEnum):
    EXISTING = "EXISTING"
    LEND_NOW = "LEND_NOW"
    BORROW_NOW = "BORROW_NOW"
    SHARED_EXPENSE = "SHARED_EXPENSE"


class DebtStatus(StrEnum):
    OPEN = "OPEN"
    PARTIALLY_PAID = "PARTIALLY_PAID"
    SETTLED = "SETTLED"
    CANCELLED = "CANCELLED"


class SharedExpenseShareStatus(StrEnum):
    ACTIVE = "ACTIVE"
    CANCELLED = "CANCELLED"
