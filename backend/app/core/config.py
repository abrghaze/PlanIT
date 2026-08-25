from __future__ import annotations

from functools import lru_cache
from typing import Literal
from urllib.parse import urlsplit

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_LOCAL_DATABASE_URL = "postgresql+asyncpg://planit:planit_dev_only@localhost:5432/planit"
_PLACEHOLDER_MARKERS = (
    "change-before",
    "dev_only",
    "dev-only",
    "local-only",
    "replace",
)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_prefix="PLANIT_",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "PlanIT API"
    app_version: str = "0.3.0"
    app_env: Literal["local", "test", "staging", "production"] = "local"
    debug: bool = True
    api_prefix: str = "/api/v1"
    database_url: str = _LOCAL_DATABASE_URL
    allowed_origins: list[str] = Field(default_factory=list)
    access_token_secret: SecretStr = SecretStr("local-only-replace-before-any-deployment")
    refresh_token_pepper: SecretStr = SecretStr("local-only-different-refresh-token-secret")
    access_token_ttl_minutes: int = Field(default=15, gt=0)
    refresh_token_ttl_days: int = Field(default=30, gt=0)
    jwt_issuer: str = Field(default="planit-api", min_length=1, max_length=120)
    jwt_audience: str = Field(default="planit-mobile", min_length=1, max_length=120)
    login_max_attempts: int = Field(default=5, ge=2, le=20)
    login_window_minutes: int = Field(default=15, gt=0, le=1440)
    login_lockout_minutes: int = Field(default=15, gt=0, le=1440)
    s3_endpoint_url: str | None = None
    s3_region: str = "auto"
    s3_bucket: str = "planit-private"
    s3_access_key_id: SecretStr | None = None
    s3_secret_access_key: SecretStr | None = None

    @field_validator("api_prefix")
    @classmethod
    def validate_api_prefix(cls, value: str) -> str:
        if not value.startswith("/") or value == "/" or value.endswith("/") or "//" in value:
            raise ValueError(
                "API prefix must be an absolute, non-root path without a trailing slash."
            )
        return value

    @field_validator("database_url")
    @classmethod
    def validate_database_url(cls, value: str) -> str:
        if not value.startswith("postgresql+asyncpg://"):
            raise ValueError("Database URL must use PostgreSQL with the asyncpg driver.")
        return value

    @field_validator("allowed_origins")
    @classmethod
    def validate_allowed_origins(cls, values: list[str]) -> list[str]:
        for value in values:
            parsed = urlsplit(value)
            if (
                parsed.scheme not in {"http", "https"}
                or not parsed.netloc
                or parsed.username is not None
                or parsed.password is not None
                or bool(parsed.path)
                or parsed.query
                or parsed.fragment
            ):
                raise ValueError(
                    "CORS entries must be HTTP(S) origins without credentials or paths."
                )
        return values

    @model_validator(mode="after")
    def validate_deployment_safety(self) -> Settings:
        storage_credentials = (self.s3_access_key_id, self.s3_secret_access_key)
        if any(storage_credentials) and not all(storage_credentials):
            raise ValueError("Both S3 access-key fields must be configured together.")

        if self.app_env in {"staging", "production"}:
            if self.debug:
                raise ValueError("Debug mode is forbidden in staging and production.")
            secrets = (
                self.access_token_secret.get_secret_value(),
                self.refresh_token_pepper.get_secret_value(),
            )
            if any(
                len(value) < 32 or any(marker in value.lower() for marker in _PLACEHOLDER_MARKERS)
                for value in secrets
            ):
                raise ValueError(
                    "Deployment secrets must be non-placeholder values of 32+ characters."
                )
            if self.database_url == _LOCAL_DATABASE_URL or any(
                marker in self.database_url.lower() for marker in _PLACEHOLDER_MARKERS
            ):
                raise ValueError("The local development database URL cannot be deployed.")
            if any(not origin.startswith("https://") for origin in self.allowed_origins):
                raise ValueError("Deployed CORS origins must use HTTPS.")
            if all(storage_credentials):
                storage_values = tuple(
                    credential.get_secret_value()
                    for credential in storage_credentials
                    if credential is not None
                )
                if any(
                    any(marker in value.lower() for marker in _PLACEHOLDER_MARKERS)
                    for value in storage_values
                ):
                    raise ValueError("Deployment S3 credentials cannot be placeholder values.")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
