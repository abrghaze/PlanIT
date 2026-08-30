from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import PurePosixPath
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.application.audit import add_audit_event
from app.db.models.purchases import EntityMediaModel, MediaAssetModel
from app.domain.errors import DomainError
from app.domain.purchases.entities import MediaAssetSnapshot
from app.domain.purchases.policies import validate_image
from app.infrastructure.repositories.purchases import PurchaseRepository
from app.infrastructure.repositories.transactions import TransactionRepository
from app.infrastructure.storage import PrivateObjectStorage


@dataclass(frozen=True, slots=True)
class PendingUpload:
    asset: MediaAssetSnapshot
    upload_url: str
    expires_in_seconds: int
    required_headers: dict[str, str]


class MediaService:
    def __init__(self, session: AsyncSession, storage: PrivateObjectStorage) -> None:
        self._session = session
        self._storage = storage
        self._repo = PurchaseRepository(session)

    async def create_pending(
        self,
        *,
        media_id: UUID,
        user_id: UUID,
        entity_type: str,
        entity_id: UUID,
        mime_type: str,
        size_bytes: int,
        request_id: str | None,
        operation_id: UUID,
    ) -> PendingUpload:
        validate_image(mime_type=mime_type, size_bytes=size_bytes)
        kind, role = self._kind_role(entity_type)
        await self._require_target(user_id, entity_type, entity_id)
        extension = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}[mime_type]
        key = str(
            PurePosixPath(
                "users",
                str(user_id),
                entity_type.lower(),
                str(entity_id),
                f"{media_id}.{extension}",
            )
        )
        model = MediaAssetModel(
            id=media_id,
            user_id=user_id,
            kind=kind,
            status="PENDING",
            storage_key=key,
            mime_type=mime_type,
            size_bytes=size_bytes,
        )
        self._repo.add(model)
        await self._session.flush()
        self._repo.add(
            EntityMediaModel(
                media_asset_id=model.id,
                user_id=user_id,
                entity_type=entity_type,
                entity_id=entity_id,
                role=role,
                sort_order=0,
            )
        )
        await self._session.flush()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="media_asset",
            entity_id=model.id,
            action="CREATE_PENDING",
            after={
                "target_type": entity_type,
                "target_id": str(entity_id),
                "mime_type": mime_type,
                "size_bytes": size_bytes,
            },
            request_id=request_id,
            client_operation_id=operation_id,
        )
        await self._session.refresh(model)
        return PendingUpload(
            asset=self._repo.media_snapshot(model),
            upload_url=self._storage.signed_upload_url(key=key, content_type=mime_type),
            expires_in_seconds=300,
            required_headers={"Content-Type": mime_type},
        )

    async def finalize(
        self, *, media_id: UUID, user_id: UUID, request_id: str | None, operation_id: UUID
    ) -> MediaAssetSnapshot:
        model = await self._repo.get_media(media_id=media_id, user_id=user_id, for_update=True)
        if model is None:
            raise DomainError("MEDIA_NOT_FOUND", "Media upload was not found.")
        if model.status == "FINALIZED":
            return self._repo.media_snapshot(model)
        stored = await self._storage.inspect(key=model.storage_key)
        if (
            stored.size_bytes != model.size_bytes
            or stored.content_type.split(";")[0].strip().lower() != model.mime_type
        ):
            raise DomainError(
                "MEDIA_UPLOAD_MISMATCH",
                "Uploaded file metadata does not match the reserved upload.",
                details={"expected_size": model.size_bytes, "actual_size": stored.size_bytes},
            )
        model.status = "FINALIZED"
        model.finalized_at = datetime.now(UTC)
        await self._session.flush()
        add_audit_event(
            self._session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="media_asset",
            entity_id=model.id,
            action="FINALIZE",
            after={"status": "FINALIZED"},
            request_id=request_id,
            client_operation_id=operation_id,
        )
        await self._session.refresh(model)
        return self._repo.media_snapshot(model)

    async def read_url(
        self, *, media_id: UUID, user_id: UUID
    ) -> tuple[MediaAssetSnapshot, str, int]:
        model = await self._repo.get_media(media_id=media_id, user_id=user_id)
        if model is None or model.status != "FINALIZED":
            raise DomainError("MEDIA_NOT_FOUND", "Media file was not found.")
        return (
            self._repo.media_snapshot(model),
            self._storage.signed_read_url(key=model.storage_key),
            300,
        )

    async def list_entity(
        self, *, user_id: UUID, entity_type: str, entity_id: UUID
    ) -> list[MediaAssetSnapshot]:
        await self._require_target(user_id, entity_type, entity_id)
        return await self._repo.media_for_entity(
            user_id=user_id, entity_type=entity_type, entity_id=entity_id
        )

    async def _require_target(self, user_id: UUID, entity_type: str, entity_id: UUID) -> None:
        found: object | None = None
        if entity_type == "MERCHANT":
            found = await self._repo.get_merchant(merchant_id=entity_id, user_id=user_id)
        elif entity_type == "PRODUCT":
            found = await self._repo.get_product(product_id=entity_id, user_id=user_id)
        elif entity_type == "TRANSACTION":
            found = await TransactionRepository(self._session).get_owned(
                transaction_id=entity_id, user_id=user_id
            )
        else:
            raise DomainError("INVALID_MEDIA_TARGET", "Media target type is invalid.")
        if found is None:
            raise DomainError("UNAUTHORIZED_ENTITY", "Media target is unavailable.")

    @staticmethod
    def _kind_role(entity_type: str) -> tuple[str, str]:
        values = {
            "MERCHANT": ("MERCHANT_IMAGE", "IMAGE"),
            "PRODUCT": ("PRODUCT_IMAGE", "IMAGE"),
            "TRANSACTION": ("RECEIPT", "RECEIPT"),
        }
        try:
            return values[entity_type]
        except KeyError as exc:
            raise DomainError("INVALID_MEDIA_TARGET", "Media target type is invalid.") from exc
