from __future__ import annotations

import asyncio
from dataclasses import dataclass

import boto3  # type: ignore[import-not-found]
from botocore.client import Config  # type: ignore[import-not-found]

from app.core.config import Settings
from app.domain.errors import DomainError


@dataclass(frozen=True, slots=True)
class StoredObject:
    size_bytes: int
    content_type: str


class PrivateObjectStorage:
    def __init__(self, settings: Settings) -> None:
        if not settings.s3_access_key_id or not settings.s3_secret_access_key:
            raise DomainError(
                "MEDIA_STORAGE_UNAVAILABLE",
                "Private media storage is not configured.",
            )
        self._bucket = settings.s3_bucket
        self._client = boto3.client(
            "s3",
            endpoint_url=settings.s3_endpoint_url,
            region_name=settings.s3_region,
            aws_access_key_id=settings.s3_access_key_id.get_secret_value(),
            aws_secret_access_key=settings.s3_secret_access_key.get_secret_value(),
            config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
        )

    def signed_upload_url(self, *, key: str, content_type: str, expires: int = 300) -> str:
        return str(
            self._client.generate_presigned_url(
                "put_object",
                Params={"Bucket": self._bucket, "Key": key, "ContentType": content_type},
                ExpiresIn=expires,
            )
        )

    def signed_read_url(self, *, key: str, expires: int = 300) -> str:
        return str(
            self._client.generate_presigned_url(
                "get_object",
                Params={"Bucket": self._bucket, "Key": key},
                ExpiresIn=expires,
            )
        )

    async def inspect(self, *, key: str) -> StoredObject:
        try:
            response = await asyncio.to_thread(
                self._client.head_object,
                Bucket=self._bucket,
                Key=key,
            )
        except Exception as exc:
            raise DomainError(
                "MEDIA_UPLOAD_INCOMPLETE",
                "The uploaded file could not be verified. Retry the upload first.",
            ) from exc
        return StoredObject(
            size_bytes=int(response.get("ContentLength", 0)),
            content_type=str(response.get("ContentType", "")),
        )
