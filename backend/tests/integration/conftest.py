from collections.abc import AsyncIterator

import pytest_asyncio
from app.core.config import Settings
from app.db.session import create_db_engine, create_session_factory
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker


@pytest_asyncio.fixture
async def db_session_factory() -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    engine = create_db_engine(Settings())
    session_factory = create_session_factory(engine)
    async with engine.connect() as connection:
        await connection.execute(text("SELECT 1"))
    try:
        yield session_factory
    finally:
        await engine.dispose()
