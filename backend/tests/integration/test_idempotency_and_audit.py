import asyncio
from uuid import UUID, uuid4

import pytest
from app.application.audit import add_audit_event
from app.application.idempotency import OperationResponse, execute_idempotent
from app.db.models.control import AuditEventModel, IdempotencyKeyModel
from app.db.models.identity import UserModel
from app.domain.errors import DomainError
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

pytestmark = pytest.mark.integration


async def _create_user(session_factory: async_sessionmaker[AsyncSession]) -> UUID:
    user_id = uuid4()
    async with session_factory() as session, session.begin():
        session.add(
            UserModel(
                id=user_id,
                email=f"{user_id}@example.test",
                email_normalized=f"{user_id}@example.test",
                password_hash="$argon2id$integration-test-only",
                display_name="Integration Test",
                base_currency="MAD",
                timezone="Africa/Casablanca",
                status="ACTIVE",
            )
        )
    return user_id


async def _delete_user(session_factory: async_sessionmaker[AsyncSession], user_id: UUID) -> None:
    async with session_factory() as session, session.begin():
        await session.execute(delete(UserModel).where(UserModel.id == user_id))


async def test_concurrent_retry_has_one_business_effect_and_one_audit_event(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    user_id = await _create_user(db_session_factory)
    operation_id = uuid4()
    entity_id = uuid4()
    calls = 0

    async def operation(session: AsyncSession) -> OperationResponse:
        nonlocal calls
        calls += 1
        await asyncio.sleep(0.05)
        add_audit_event(
            session,
            user_id=user_id,
            actor_user_id=user_id,
            entity_type="foundation_probe",
            entity_id=entity_id,
            action="CREATE",
            after={"amount": "12.5000", "currency": "MAD"},
            request_id="integration-request",
            client_operation_id=operation_id,
        )
        return OperationResponse(
            status_code=201,
            body={"entity_id": str(entity_id), "amount": "12.5000"},
        )

    async def invoke(payload: dict[str, object]):
        async with db_session_factory() as session:
            return await execute_idempotent(
                session,
                user_id=user_id,
                scope="foundation.create",
                key=operation_id,
                request_payload=payload,
                operation=operation,
            )

    try:
        first, second = await asyncio.gather(
            invoke({"currency": "MAD", "amount": "12.5000"}),
            invoke({"amount": "12.5000", "currency": "MAD"}),
        )

        assert calls == 1
        assert {first.replayed, second.replayed} == {False, True}
        assert first.body == second.body

        async with db_session_factory() as session:
            idempotency_count = await session.scalar(
                select(func.count())
                .select_from(IdempotencyKeyModel)
                .where(
                    IdempotencyKeyModel.user_id == user_id,
                    IdempotencyKeyModel.scope == "foundation.create",
                    IdempotencyKeyModel.key == operation_id,
                )
            )
            audit_count = await session.scalar(
                select(func.count())
                .select_from(AuditEventModel)
                .where(AuditEventModel.client_operation_id == operation_id)
            )

        assert idempotency_count == 1
        assert audit_count == 1

        with pytest.raises(DomainError) as conflict:
            await invoke({"amount": "99.0000", "currency": "MAD"})
        assert conflict.value.code == "IDEMPOTENCY_CONFLICT"
        assert calls == 1
    finally:
        await _delete_user(db_session_factory, user_id)


async def test_failed_operation_rolls_back_audit_and_idempotency_state(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    user_id = await _create_user(db_session_factory)
    operation_id = uuid4()
    entity_id = uuid4()

    async def failing_operation(session: AsyncSession) -> OperationResponse:
        add_audit_event(
            session,
            user_id=user_id,
            entity_type="foundation_probe",
            entity_id=entity_id,
            action="CREATE",
            after={"amount": "1.0000"},
            client_operation_id=operation_id,
        )
        raise RuntimeError("simulated persistence failure")

    try:
        async with db_session_factory() as session:
            with pytest.raises(RuntimeError, match="simulated persistence failure"):
                await execute_idempotent(
                    session,
                    user_id=user_id,
                    scope="foundation.rollback",
                    key=operation_id,
                    request_payload={"amount": "1.0000"},
                    operation=failing_operation,
                )

        async with db_session_factory() as session:
            idempotency_count = await session.scalar(
                select(func.count())
                .select_from(IdempotencyKeyModel)
                .where(IdempotencyKeyModel.key == operation_id)
            )
            audit_count = await session.scalar(
                select(func.count())
                .select_from(AuditEventModel)
                .where(AuditEventModel.client_operation_id == operation_id)
            )

        assert idempotency_count == 0
        assert audit_count == 0
    finally:
        await _delete_user(db_session_factory, user_id)
