from enum import StrEnum


class AccountType(StrEnum):
    BANK = "BANK"
    CASH = "CASH"
    SAVINGS = "SAVINGS"
    CARD = "CARD"
    PREPAID = "PREPAID"
    INVESTMENT = "INVESTMENT"
    OTHER = "OTHER"
