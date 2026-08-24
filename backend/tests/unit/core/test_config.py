import pytest
from app.core.config import Settings
from pydantic import ValidationError


def test_production_forbids_debug_mode() -> None:
    with pytest.raises(ValidationError, match="Debug mode is forbidden"):
        Settings(app_env="production", debug=True)


def test_deployed_storage_credentials_are_a_pair() -> None:
    with pytest.raises(ValidationError, match="configured together"):
        Settings(
            app_env="staging",
            debug=False,
            access_token_secret="a" * 32,
            refresh_token_pepper="b" * 32,
            s3_access_key_id="access-only",
        )
