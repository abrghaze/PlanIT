import pytest
from app.core.config import Settings
from pydantic import ValidationError


def test_production_forbids_debug_mode() -> None:
    with pytest.raises(ValidationError, match="Debug mode is forbidden"):
        Settings(app_env="production", debug=True)


def test_deployed_storage_credentials_are_a_pair() -> None:
    with pytest.raises(ValidationError, match="configured together"):
        Settings(
            s3_access_key_id="access-only",
        )


def test_deployment_rejects_a_retained_local_secret() -> None:
    with pytest.raises(ValidationError, match="non-placeholder"):
        Settings(
            app_env="production",
            debug=False,
            database_url="postgresql+asyncpg://planit:real@database.example/planit",
            access_token_secret="a" * 32,
            refresh_token_pepper="local-only-different-refresh-token-secret",
        )


def test_deployment_rejects_local_database_and_insecure_cors() -> None:
    safe_secrets = {
        "access_token_secret": "a" * 32,
        "refresh_token_pepper": "b" * 32,
    }
    with pytest.raises(ValidationError, match="local development database"):
        Settings(
            app_env="staging",
            debug=False,
            database_url="postgresql+asyncpg://planit:planit_dev_only@localhost:5432/planit",
            **safe_secrets,
        )

    with pytest.raises(ValidationError, match="must use HTTPS"):
        Settings(
            app_env="staging",
            debug=False,
            database_url="postgresql+asyncpg://planit:real@database.example/planit",
            allowed_origins=["http://app.example"],
            **safe_secrets,
        )


def test_deployment_rejects_placeholder_storage_credentials() -> None:
    with pytest.raises(ValidationError, match="S3 credentials"):
        Settings(
            app_env="production",
            debug=False,
            database_url="postgresql+asyncpg://planit:real@database.example/planit",
            access_token_secret="a" * 32,
            refresh_token_pepper="b" * 32,
            s3_access_key_id="replace-after-bootstrap",
            s3_secret_access_key="replace-after-bootstrap",
        )


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("access_token_ttl_minutes", 0, "greater than 0"),
        ("refresh_token_ttl_days", -1, "greater than 0"),
        ("api_prefix", "api/v1", "API prefix"),
        ("database_url", "sqlite+aiosqlite:///planit.db", "PostgreSQL"),
        ("allowed_origins", ["https://user:pass@app.example/path"], "CORS entries"),
    ],
)
def test_invalid_foundation_configuration_is_rejected(
    field: str,
    value: object,
    message: str,
) -> None:
    with pytest.raises(ValidationError, match=message):
        Settings.model_validate({field: value})


def test_token_secrets_are_redacted_from_settings_representation() -> None:
    settings = Settings(access_token_secret="do-not-render-this-secret")

    assert "do-not-render-this-secret" not in repr(settings)
