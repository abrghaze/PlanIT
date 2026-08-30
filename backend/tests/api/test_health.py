import httpx
from app.core.config import Settings
from app.main import create_app


async def test_health_contract() -> None:
    app = create_app(Settings(app_env="test", debug=False))
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/api/v1/health",
            headers={"X-Request-ID": "test-request"},
        )

    assert response.status_code == 200
    assert response.headers["X-Request-ID"] == "test-request"
    assert response.headers["Server-Timing"].startswith("app;dur=")
    assert response.json() == {
        "status": "ok",
        "service": "PlanIT API",
        "version": "0.9.0",
        "environment": "test",
    }
