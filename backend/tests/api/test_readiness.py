import httpx
from app.core.config import Settings
from app.main import create_app


async def test_readiness_uses_the_database_from_injected_settings() -> None:
    app = create_app(
        Settings(
            app_env="test",
            debug=False,
            database_url="postgresql+asyncpg://postgres@127.0.0.1:1/unreachable",
        )
    )
    transport = httpx.ASGITransport(app=app)
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get(
                "/api/v1/ready",
                headers={"X-Request-ID": "readiness-failure-test"},
            )
    finally:
        await app.state.db_engine.dispose()

    assert response.status_code == 503
    assert response.json() == {
        "error": {
            "code": "SERVICE_UNAVAILABLE",
            "message": "The service is temporarily unavailable.",
            "details": {},
            "request_id": "readiness-failure-test",
        }
    }
