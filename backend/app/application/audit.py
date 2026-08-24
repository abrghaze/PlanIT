from __future__ import annotations

from collections.abc import Mapping
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.application.json_contract import normalize_json_object
from app.db.models.control import AuditEventModel


def add_audit_event(
    session: AsyncSession,
    *,
    user_id: UUID,
    entity_type: str,
    entity_id: UUID,
    action: str,
    actor_user_id: UUID | None = None,
    before: Mapping[str, object] | None = None,
    after: Mapping[str, object] | None = None,
    request_id: str | None = None,
    client_operation_id: UUID | None = None,
) -> AuditEventModel:
    event = AuditEventModel(
        user_id=user_id,
        actor_user_id=actor_user_id,
        entity_type=entity_type,
        entity_id=entity_id,
        action=action,
        before_json=normalize_json_object(before) if before is not None else None,
        after_json=normalize_json_object(after) if after is not None else None,
        request_id=request_id,
        client_operation_id=client_operation_id,
    )
    session.add(event)
    return event
