from enum import StrEnum


class AnalyticsPreset(StrEnum):
    TODAY = "TODAY"
    YESTERDAY = "YESTERDAY"
    THIS_WEEK = "THIS_WEEK"
    LAST_7_DAYS = "LAST_7_DAYS"
    THIS_MONTH = "THIS_MONTH"
    LAST_MONTH = "LAST_MONTH"
    LAST_30_DAYS = "LAST_30_DAYS"
    THIS_YEAR = "THIS_YEAR"
    CUSTOM = "CUSTOM"


class AnalyticsGranularity(StrEnum):
    DAY = "DAY"
    WEEK = "WEEK"
    MONTH = "MONTH"
