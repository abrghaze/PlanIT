from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.audit import add_audit_event
from app.application.catalog import add_default_categories
from app.core.config import Settings
from app.db.models.identity import AuthThrottleModel, RefreshSessionModel, UserModel
from app.domain.errors import DomainError
from app.domain.identity.entities import AuthenticatedPrincipal, UserIdentity
from app.domain.identity.policies import (
    normalize_currency,
    normalize_display_name,
    normalize_email,
    validate_password,
    validate_timezone,
)
from app.infrastructure.repositories.identity import IdentityRepository
from app.infrastructure.security.passwords import PasswordService
from app.infrastructure.security.tokens import AccessToken, RefreshToken, TokenService


@dataclass(frozen=True, slots=True)
class AuthResult:
    user: UserIdentity
    access_token: str
    refresh_token: str
    access_expires_at: datetime
    refresh_expires_at: datetime


class AuthService:
    def __init__(self, session: AsyncSession, settings: Settings) -> None:
        self._session = session
        self._settings = settings
        self._repository = IdentityRepository(session)
        self._passwords = PasswordService()
        self._tokens = TokenService(settings)

    async def register(
        self,
        *,
        email: str,
        password: str,
        display_name: str,
        base_currency: str,
        timezone: str,
        device_label: str | None,
        request_id: str | None,
    ) -> AuthResult:
        canonical_email, normalized_email = normalize_email(email)
        normalized_name = normalize_display_name(display_name)
        normalized_currency = normalize_currency(base_currency)
        normalized_timezone = validate_timezone(timezone)
        validate_password(password)
        password_hash = self._passwords.hash(password)
        normalized_device = self._normalize_device_label(device_label)

        result: AuthResult | None = None
        try:
            async with self._session.begin():
                existing = await self._repository.get_user_by_normalized_email(normalized_email)
                if existing is not None:
                    raise DomainError(
                        "EMAIL_ALREADY_REGISTERED",
                        "An account already exists for this email address.",
                    )

                user = UserModel(
                    id=uuid4(),
                    email=canonical_email,
                    email_normalized=normalized_email,
                    password_hash=password_hash,
                    display_name=normalized_name,
                    base_currency=normalized_currency,
                    timezone=normalized_timezone,
                    status="ACTIVE",
                )
                self._repository.add_user(user)
                await self._session.flush()
                add_default_categories(self._session, user_id=user.id)
                refresh_session, refresh_token = self._new_refresh_session(
                    user_id=user.id,
                    device_label=normalized_device,
                )
                self._repository.add_refresh_session(refresh_session)
                await self._session.flush()
                add_audit_event(
                    self._session,
                    user_id=user.id,
                    actor_user_id=user.id,
                    entity_type="user",
                    entity_id=user.id,
                    action="REGISTER",
                    after={
                        "base_currency": user.base_currency,
                        "timezone": user.timezone,
                        "status": user.status,
                    },
                    request_id=request_id,
                )
                result = self._build_result(user, refresh_session, refresh_token)
        except IntegrityError as exc:
            driver_error = getattr(exc.orig, "__cause__", None)
            constraint_name = getattr(driver_error, "constraint_name", None)
            if constraint_name == "uq_users_email_normalized":
                raise DomainError(
                    "EMAIL_ALREADY_REGISTERED",
                    "An account already exists for this email address.",
                ) from exc
            raise

        if result is None:
            raise RuntimeError("Registration completed without an authentication result.")
        return result

    async def login(
        self,
        *,
        email: str,
        password: str,
        device_label: str | None,
        client_address: str,
        request_id: str | None,
    ) -> AuthResult:
        try:
            _, normalized_email = normalize_email(email)
            email_is_valid = True
        except DomainError:
            normalized_email = email.strip().casefold()
            email_is_valid = False

        throttle_key = self._tokens.hash_private_identifier(
            f"login:{client_address}:{normalized_email}"
        )
        normalized_device = self._normalize_device_label(device_label)
        now = datetime.now(UTC)
        result: AuthResult | None = None
        failure: DomainError | None = None

        async with self._session.begin():
            await self._repository.acquire_throttle_lock(throttle_key)
            throttle = await self._repository.get_throttle(throttle_key)
            failure = self._active_rate_limit_error(throttle, now=now)
            if failure is None:
                user = (
                    await self._repository.get_user_by_normalized_email(normalized_email)
                    if email_is_valid
                    else None
                )
                password_matches = self._passwords.verify(
                    user.password_hash if user is not None and user.status == "ACTIVE" else None,
                    password,
                )
                if not password_matches or user is None or user.status != "ACTIVE":
                    self._record_login_failure(throttle_key, throttle, now=now)
                    failure = DomainError(
                        "INVALID_CREDENTIALS",
                        "Email or password is incorrect.",
                    )
                else:
                    await self._repository.clear_throttle(throttle_key)
                    if self._passwords.needs_rehash(user.password_hash):
                        user.password_hash = self._passwords.hash(password)
                    refresh_session, refresh_token = self._new_refresh_session(
                        user_id=user.id,
                        device_label=normalized_device,
                        now=now,
                    )
                    self._repository.add_refresh_session(refresh_session)
                    await self._session.flush()
                    add_audit_event(
                        self._session,
                        user_id=user.id,
                        actor_user_id=user.id,
                        entity_type="refresh_session",
                        entity_id=refresh_session.id,
                        action="LOGIN",
                        after={"device_label": normalized_device},
                        request_id=request_id,
                    )
                    result = self._build_result(user, refresh_session, refresh_token, now=now)

        if failure is not None:
            raise failure
        if result is None:
            raise RuntimeError("Login completed without an authentication result.")
        return result

    async def refresh(
        self,
        *,
        raw_refresh_token: str,
        request_id: str | None,
    ) -> AuthResult:
        token_hash = self._tokens.hash_refresh_token(raw_refresh_token)
        now = datetime.now(UTC)
        result: AuthResult | None = None
        failure: DomainError | None = None

        async with self._session.begin():
            current = await self._repository.get_refresh_session_by_hash(
                token_hash,
                for_update=True,
            )
            if current is None:
                failure = self._invalid_refresh_token()
            elif current.replaced_by_id is not None or current.compromised:
                await self._repository.revoke_replacement_chain(
                    current,
                    revoked_at=now,
                    compromised=True,
                )
                add_audit_event(
                    self._session,
                    user_id=current.user_id,
                    actor_user_id=current.user_id,
                    entity_type="refresh_session",
                    entity_id=current.id,
                    action="TOKEN_REUSE_DETECTED",
                    after={"replacement_chain_revoked": True},
                    request_id=request_id,
                )
                failure = DomainError(
                    "TOKEN_REUSE_DETECTED",
                    "This session can no longer be used. Sign in again.",
                )
            elif current.revoked_at is not None or current.expires_at <= now:
                current.revoked_at = current.revoked_at or now
                failure = self._invalid_refresh_token()
            else:
                user = await self._repository.get_user_by_id(current.user_id)
                if user is None or user.status != "ACTIVE":
                    current.revoked_at = now
                    failure = self._invalid_refresh_token()
                else:
                    replacement, refresh_token = self._new_refresh_session(
                        user_id=user.id,
                        device_label=current.device_label,
                        now=now,
                    )
                    self._repository.add_refresh_session(replacement)
                    await self._session.flush()
                    current.revoked_at = now
                    current.replaced_by_id = replacement.id
                    add_audit_event(
                        self._session,
                        user_id=user.id,
                        actor_user_id=user.id,
                        entity_type="refresh_session",
                        entity_id=current.id,
                        action="ROTATE",
                        after={"replacement_session_id": str(replacement.id)},
                        request_id=request_id,
                    )
                    result = self._build_result(user, replacement, refresh_token, now=now)

        if failure is not None:
            raise failure
        if result is None:
            raise RuntimeError("Refresh completed without an authentication result.")
        return result

    async def logout(self, *, raw_refresh_token: str, request_id: str | None) -> None:
        token_hash = self._tokens.hash_refresh_token(raw_refresh_token)
        now = datetime.now(UTC)
        async with self._session.begin():
            current = await self._repository.get_refresh_session_by_hash(
                token_hash,
                for_update=True,
            )
            if current is None:
                return
            await self._repository.revoke_replacement_chain(
                current,
                revoked_at=now,
                compromised=False,
            )
            add_audit_event(
                self._session,
                user_id=current.user_id,
                actor_user_id=current.user_id,
                entity_type="refresh_session",
                entity_id=current.id,
                action="LOGOUT",
                request_id=request_id,
            )

    async def authenticate_access_token(self, token: str) -> AuthenticatedPrincipal:
        claims = self._tokens.decode_access_token(token)
        now = datetime.now(UTC)
        principal: AuthenticatedPrincipal | None = None
        async with self._session.begin():
            refresh_session = await self._repository.get_refresh_session_by_id(claims.session_id)
            if (
                refresh_session is not None
                and refresh_session.user_id == claims.user_id
                and refresh_session.revoked_at is None
                and not refresh_session.compromised
                and refresh_session.expires_at > now
            ):
                user = await self._repository.get_user_by_id(claims.user_id)
                if user is not None and user.status == "ACTIVE":
                    principal = AuthenticatedPrincipal(
                        user=self._to_user_identity(user),
                        session_id=claims.session_id,
                    )
        if principal is None:
            raise DomainError(
                "INVALID_CREDENTIALS",
                "Authentication credentials are invalid or expired.",
            )
        return principal

    def _new_refresh_session(
        self,
        *,
        user_id: UUID,
        device_label: str | None,
        now: datetime | None = None,
    ) -> tuple[RefreshSessionModel, RefreshToken]:
        refresh_token = self._tokens.issue_refresh_token(now=now)
        return (
            RefreshSessionModel(
                id=uuid4(),
                user_id=user_id,
                token_hash=refresh_token.digest,
                device_label=device_label,
                expires_at=refresh_token.expires_at,
                revoked_at=None,
                replaced_by_id=None,
                compromised=False,
            ),
            refresh_token,
        )

    def _build_result(
        self,
        user: UserModel,
        refresh_session: RefreshSessionModel,
        refresh_token: RefreshToken,
        *,
        now: datetime | None = None,
    ) -> AuthResult:
        access: AccessToken = self._tokens.issue_access_token(
            user_id=user.id,
            session_id=refresh_session.id,
            now=now,
        )
        return AuthResult(
            user=self._to_user_identity(user),
            access_token=access.value,
            refresh_token=refresh_token.value,
            access_expires_at=access.expires_at,
            refresh_expires_at=refresh_token.expires_at,
        )

    def _active_rate_limit_error(
        self,
        throttle: AuthThrottleModel | None,
        *,
        now: datetime,
    ) -> DomainError | None:
        if throttle is None or throttle.blocked_until is None or throttle.blocked_until <= now:
            return None
        retry_after = max(1, int((throttle.blocked_until - now).total_seconds()))
        return DomainError(
            "AUTH_RATE_LIMITED",
            "Too many sign-in attempts. Try again later.",
            details={"retry_after_seconds": retry_after},
        )

    def _record_login_failure(
        self,
        key_hash: str,
        throttle: AuthThrottleModel | None,
        *,
        now: datetime,
    ) -> None:
        window = timedelta(minutes=self._settings.login_window_minutes)
        if throttle is None:
            throttle = AuthThrottleModel(
                key_hash=key_hash,
                failure_count=1,
                window_started_at=now,
                blocked_until=None,
            )
            self._repository.add_throttle(throttle)
        elif now - throttle.window_started_at >= window:
            throttle.failure_count = 1
            throttle.window_started_at = now
            throttle.blocked_until = None
        else:
            throttle.failure_count += 1

        if throttle.failure_count >= self._settings.login_max_attempts:
            throttle.blocked_until = now + timedelta(minutes=self._settings.login_lockout_minutes)

    @staticmethod
    def _normalize_device_label(value: str | None) -> str | None:
        if value is None:
            return None
        normalized = " ".join(value.strip().split())
        return normalized[:160] or None

    @staticmethod
    def _invalid_refresh_token() -> DomainError:
        return DomainError(
            "INVALID_REFRESH_TOKEN",
            "The refresh session is invalid or expired. Sign in again.",
        )

    @staticmethod
    def _to_user_identity(user: UserModel) -> UserIdentity:
        return UserIdentity(
            id=user.id,
            email=user.email,
            display_name=user.display_name,
            base_currency=user.base_currency,
            timezone=user.timezone,
            status=user.status,
            created_at=user.created_at,
            updated_at=user.updated_at,
        )
