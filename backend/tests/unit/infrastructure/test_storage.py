from urllib.parse import parse_qs, urlsplit

import pytest
from app.core.config import Settings
from app.domain.errors import DomainError
from app.infrastructure.storage import PrivateObjectStorage


def test_private_storage_requires_credentials() -> None:
    with pytest.raises(DomainError) as raised:
        PrivateObjectStorage(Settings(app_env="test", debug=False))
    assert raised.value.code == "MEDIA_STORAGE_UNAVAILABLE"


def test_private_storage_generates_short_lived_signed_urls() -> None:
    storage = PrivateObjectStorage(
        Settings.model_validate(
            {
                "app_env": "test",
                "debug": False,
                "s3_endpoint_url": "http://localhost:3900",
                "s3_region": "garage",
                "s3_bucket": "planit-private",
                "s3_access_key_id": "integration-access-key",
                "s3_secret_access_key": "integration-secret-key",
            }
        )
    )
    upload = storage.signed_upload_url(
        key="users/owner/transaction/receipt.jpg",
        content_type="image/jpeg",
    )
    read = storage.signed_read_url(key="users/owner/transaction/receipt.jpg")
    for value in (upload, read):
        query = parse_qs(urlsplit(value).query)
        assert query["X-Amz-Expires"] == ["300"]
        assert "X-Amz-Signature" in query
    assert "X-Amz-SignedHeaders=content-type%3Bhost" in upload
    assert "X-Amz-SignedHeaders=host" in read
