from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from uuid import UUID

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UuidPrimaryKeyMixin


class UserStatus(StrEnum):
    ACTIVE = "ACTIVE"
    DISABLED = "DISABLED"
    PENDING_DELETION = "PENDING_DELETION"


class UserModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint("base_currency ~ '^[A-Z]{3}$'", name="base_currency_format"),
        CheckConstraint(
            "status IN ('ACTIVE', 'DISABLED', 'PENDING_DELETION')", name="status_valid"
        ),
    )

    email: Mapped[str] = mapped_column(String(320), nullable=False)
    email_normalized: Mapped[str] = mapped_column(String(320), nullable=False, unique=True)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    display_name: Mapped[str] = mapped_column(String(120), nullable=False)
    base_currency: Mapped[str] = mapped_column(String(3), nullable=False)
    timezone: Mapped[str] = mapped_column(String(64), nullable=False, default="UTC")
    status: Mapped[str] = mapped_column(String(24), nullable=False, default=UserStatus.ACTIVE)


class RefreshSessionModel(UuidPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "refresh_sessions"
    __table_args__ = (
        CheckConstraint("expires_at > created_at", name="expiry_after_creation"),
        CheckConstraint(
            "replaced_by_id IS NULL OR revoked_at IS NOT NULL",
            name="replacement_requires_revocation",
        ),
        CheckConstraint(
            "NOT compromised OR revoked_at IS NOT NULL",
            name="compromise_requires_revocation",
        ),
        CheckConstraint(
            "replaced_by_id IS NULL OR replaced_by_id <> id",
            name="replacement_not_self",
        ),
        CheckConstraint("token_hash ~ '^[0-9a-f]{64}$'", name="token_hash_format"),
        Index("ix_refresh_sessions_user_active", "user_id", "revoked_at", "expires_at"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    device_label: Mapped[str | None] = mapped_column(String(160))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    replaced_by_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("refresh_sessions.id", ondelete="SET NULL")
    )
    compromised: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)


class AuthThrottleModel(TimestampMixin, Base):
    """Privacy-preserving, PostgreSQL-backed login throttling state."""

    __tablename__ = "auth_throttles"
    __table_args__ = (
        CheckConstraint("failure_count >= 0", name="failure_count_non_negative"),
        Index("ix_auth_throttles_blocked_until", "blocked_until"),
    )

    key_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    failure_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    window_started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    blocked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
