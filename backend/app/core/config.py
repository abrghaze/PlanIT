from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_prefix="PLANIT_",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "PlanIT API"
    app_version: str = "0.1.0"
    app_env: Literal["local", "test", "staging", "production"] = "local"
    debug: bool = True
    api_prefix: str = "/api/v1"
    database_url: str = "postgresql+asyncpg://planit:planit_dev_only@localhost:5432/planit"
    allowed_origins: list[str] = Field(default_factory=list)
    access_token_secret: str = "local-only-replace-before-any-deployment"
    refresh_token_pepper: str = "local-only-different-refresh-token-secret"
    access_token_ttl_minutes: int = 15
    refresh_token_ttl_days: int = 30
    s3_endpoint_url: str | None = None
    s3_region: str = "auto"
    s3_bucket: str = "planit-private"
    s3_access_key_id: SecretStr | None = None
    s3_secret_access_key: SecretStr | None = None

    @model_validator(mode="after")
    def validate_deployment_safety(self) -> Settings:
        if self.app_env in {"staging", "production"}:
            if self.debug:
                raise ValueError("Debug mode is forbidden in staging and production.")
            secrets = (self.access_token_secret, self.refresh_token_pepper)
            if any(len(value) < 32 or "replace" in value.lower() for value in secrets):
                raise ValueError(
                    "Deployment secrets must be non-placeholder values of 32+ characters."
                )
            storage_credentials = (self.s3_access_key_id, self.s3_secret_access_key)
            if any(storage_credentials) and not all(storage_credentials):
                raise ValueError("Both S3 access-key fields must be configured together.")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
