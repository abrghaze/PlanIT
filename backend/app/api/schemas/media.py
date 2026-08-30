from __future__ import annotations

from datetime import datetime
from typing import Literal, Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.application.media import PendingUpload
from app.domain.purchases.entities import MediaAssetSnapshot


class MediaUploadRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    entity_type: Literal["MERCHANT", "PRODUCT", "TRANSACTION"]
    entity_id: UUID
    mime_type: Literal["image/jpeg", "image/png", "image/webp"]
    size_bytes: int = Field(gt=0, le=10 * 1024 * 1024)


class MediaAssetResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID
    kind: str
    status: str
    mime_type: str
    size_bytes: int
    created_at: datetime
    finalized_at: datetime | None

    @classmethod
    def from_domain(cls, value: MediaAssetSnapshot) -> Self:
        return cls(
            id=value.id,
            kind=value.kind,
            status=value.status,
            mime_type=value.mime_type,
            size_bytes=value.size_bytes,
            created_at=value.created_at,
            finalized_at=value.finalized_at,
        )


class MediaUploadResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    asset: MediaAssetResponse
    upload_url: str
    expires_in_seconds: int
    required_headers: dict[str, str]

    @classmethod
    def from_domain(cls, value: PendingUpload) -> Self:
        return cls(
            asset=MediaAssetResponse.from_domain(value.asset),
            upload_url=value.upload_url,
            expires_in_seconds=value.expires_in_seconds,
            required_headers=value.required_headers,
        )


class MediaFinalizeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    id: UUID


class MediaReadResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    asset: MediaAssetResponse
    read_url: str
    expires_in_seconds: int


class MediaListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)
    items: list[MediaAssetResponse]
