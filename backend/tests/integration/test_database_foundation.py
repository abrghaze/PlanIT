from datetime import UTC, datetime, timedelta, timezone
from decimal import Decimal
from uuid import UUID, uuid4

import httpx
import pytest
from app.core.config import Settings
from app.db.models.identity import UserModel
from app.db.models.ledger import AccountModel, TransactionModel
from app.main import create_app
from sqlalchemy import delete, func, select, text, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

pytestmark = pytest.mark.integration


async def _create_user_and_account(
    session_factory: async_sessionmaker[AsyncSession],
) -> tuple[UUID, UUID]:
    user_id = uuid4()
    account_id = uuid4()
    async with session_factory() as session, session.begin():
        session.add(
            UserModel(
                id=user_id,
                email=f"{user_id}@example.test",
                email_normalized=f"{user_id}@example.test",
                password_hash="$argon2id$integration-test-only",
                display_name="Constraint Test",
                base_currency="MAD",
                timezone="Africa/Casablanca",
                status="ACTIVE",
            )
        )
        session.add(
            AccountModel(
                id=account_id,
                user_id=user_id,
                name="Cash",
                type="CASH",
                currency="MAD",
                opening_balance=Decimal("10.0000"),
                opened_at=datetime.now(UTC),
                include_in_total=True,
                allow_negative=False,
                status="ACTIVE",
                sort_order=0,
                version=1,
            )
        )
    return user_id, account_id


async def _delete_user(session_factory: async_sessionmaker[AsyncSession], user_id: UUID) -> None:
    async with session_factory() as session, session.begin():
        await session.execute(delete(UserModel).where(UserModel.id == user_id))


def _expense(
    *,
    user_id: UUID,
    account_id: UUID,
    transaction_id: UUID | None = None,
    operation_id: UUID | None = None,
    effect: str = "OUTFLOW",
    amount: Decimal = Decimal("2.3400"),
    currency: str = "MAD",
    occurred_at: datetime | None = None,
) -> TransactionModel:
    return TransactionModel(
        id=transaction_id or uuid4(),
        user_id=user_id,
        account_id=account_id,
        type="EXPENSE",
        effect=effect,
        amount=amount,
        currency=currency,
        occurred_at=occurred_at or datetime.now(UTC),
        status="POSTED",
        client_operation_id=operation_id or uuid4(),
        version=1,
    )


async def test_migration_head_readiness_decimal_and_timezone_round_trip(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    user_id, account_id = await _create_user_and_account(db_session_factory)
    transaction_id = uuid4()
    source_time = datetime(2026, 8, 24, 19, 30, tzinfo=timezone(timedelta(hours=1)))
    try:
        async with db_session_factory() as session, session.begin():
            current_revision = await session.scalar(text("SELECT version_num FROM alembic_version"))
            session.add(
                _expense(
                    user_id=user_id,
                    account_id=account_id,
                    transaction_id=transaction_id,
                    amount=Decimal("0.1000"),
                    occurred_at=source_time,
                )
            )

        async with db_session_factory() as session:
            stored = await session.get(TransactionModel, transaction_id)

        assert current_revision == "20260830_0008"
        assert stored is not None
        assert stored.amount == Decimal("0.1000")
        assert isinstance(stored.amount, Decimal)
        assert stored.occurred_at == source_time.astimezone(UTC)
        assert stored.occurred_at.utcoffset() == timedelta(0)

        settings = Settings()
        app = create_app(settings)
        transport = httpx.ASGITransport(app=app)
        try:
            async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.get("/api/v1/ready")
        finally:
            await app.state.db_engine.dispose()
        assert response.status_code == 200
        assert response.json() == {"status": "ready"}
    finally:
        await _delete_user(db_session_factory, user_id)


async def test_critical_constraints_and_transaction_atomicity(
    db_session_factory: async_sessionmaker[AsyncSession],
) -> None:
    user_id, account_id = await _create_user_and_account(db_session_factory)
    other_user_id, other_account_id = await _create_user_and_account(db_session_factory)
    wrong_effect_id = uuid4()
    wrong_owner_id = uuid4()
    wrong_currency_id = uuid4()
    first_id = uuid4()
    second_id = uuid4()
    duplicate_operation_id = uuid4()
    original_id = uuid4()
    try:
        async with db_session_factory() as session:
            with pytest.raises(IntegrityError):
                async with session.begin():
                    session.add(
                        _expense(
                            user_id=user_id,
                            account_id=account_id,
                            transaction_id=wrong_effect_id,
                            effect="INFLOW",
                        )
                    )

        async with db_session_factory() as session:
            with pytest.raises(IntegrityError):
                async with session.begin():
                    session.add(
                        _expense(
                            user_id=user_id,
                            account_id=other_account_id,
                            transaction_id=wrong_owner_id,
                        )
                    )

        async with db_session_factory() as session:
            with pytest.raises(IntegrityError):
                async with session.begin():
                    session.add(
                        _expense(
                            user_id=user_id,
                            account_id=account_id,
                            transaction_id=wrong_currency_id,
                            currency="EUR",
                        )
                    )

        async with db_session_factory() as session:
            with pytest.raises(IntegrityError):
                async with session.begin():
                    session.add(
                        _expense(
                            user_id=user_id,
                            account_id=account_id,
                            amount=Decimal("0.0000"),
                        )
                    )

        async with db_session_factory() as session:
            with pytest.raises(IntegrityError):
                async with session.begin():
                    session.add_all(
                        [
                            _expense(
                                user_id=user_id,
                                account_id=account_id,
                                transaction_id=first_id,
                                operation_id=duplicate_operation_id,
                            ),
                            _expense(
                                user_id=user_id,
                                account_id=account_id,
                                transaction_id=second_id,
                                operation_id=duplicate_operation_id,
                            ),
                        ]
                    )

        async with db_session_factory() as session, session.begin():
            session.add(
                _expense(
                    user_id=user_id,
                    account_id=account_id,
                    transaction_id=original_id,
                )
            )
            session.add(
                TransactionModel(
                    user_id=user_id,
                    account_id=account_id,
                    type="REVERSAL",
                    effect="INFLOW",
                    amount=Decimal("2.3400"),
                    currency="MAD",
                    occurred_at=datetime.now(UTC),
                    status="POSTED",
                    reversal_of_id=original_id,
                    client_operation_id=uuid4(),
                    version=1,
                )
            )

        async with db_session_factory() as session:
            with pytest.raises(IntegrityError):
                async with session.begin():
                    session.add(
                        TransactionModel(
                            user_id=user_id,
                            account_id=account_id,
                            type="REVERSAL",
                            effect="INFLOW",
                            amount=Decimal("2.3400"),
                            currency="MAD",
                            occurred_at=datetime.now(UTC),
                            status="POSTED",
                            reversal_of_id=original_id,
                            client_operation_id=uuid4(),
                            version=1,
                        )
                    )

        async with db_session_factory() as session:
            with pytest.raises(IntegrityError, match="immutable after posting"):
                async with session.begin():
                    await session.execute(
                        update(AccountModel)
                        .where(AccountModel.id == account_id)
                        .values(opening_balance=Decimal("99.0000"))
                    )

        async with db_session_factory() as session:
            surviving_rows = await session.scalar(
                select(func.count())
                .select_from(TransactionModel)
                .where(
                    TransactionModel.id.in_(
                        [
                            first_id,
                            second_id,
                            wrong_effect_id,
                            wrong_owner_id,
                            wrong_currency_id,
                        ]
                    )
                )
            )
        assert surviving_rows == 0
    finally:
        await _delete_user(db_session_factory, user_id)
        await _delete_user(db_session_factory, other_user_id)
