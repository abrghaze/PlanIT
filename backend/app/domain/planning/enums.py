from enum import StrEnum


class RecurringFrequency(StrEnum):
    WEEKLY = "WEEKLY"
    MONTHLY = "MONTHLY"
    QUARTERLY = "QUARTERLY"
    YEARLY = "YEARLY"


class RecurringMode(StrEnum):
    REMINDER = "REMINDER"
    AUTO_DRAFT = "AUTO_DRAFT"


class RecurringStatus(StrEnum):
    ACTIVE = "ACTIVE"
    PAUSED = "PAUSED"
    ARCHIVED = "ARCHIVED"


class OccurrenceStatus(StrEnum):
    DUE = "DUE"
    DRAFT_CREATED = "DRAFT_CREATED"
    RECORDED = "RECORDED"
    SKIPPED = "SKIPPED"


class GoalStatus(StrEnum):
    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    ARCHIVED = "ARCHIVED"
