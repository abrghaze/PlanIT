import httpx
from app.core.config import Settings
from app.domain.errors import DomainError
from app.main import create_app
from fastapi import Query


def _test_app():  # type: ignore[no-untyped-def]
    app = create_app(Settings(app_env="test", debug=False))

    @app.get("/test/domain-error")
    async def domain_error() -> None:
        raise DomainError(
            "STALE_BALANCE",
            "Balances changed.",
            details={"repair": "refresh"},
        )

    @app.get("/test/validated")
    async def validated(value: int = Query()) -> dict[str, int]:
        return {"value": value}

    @app.get("/test/unexpected")
    async def unexpected() -> None:
        raise RuntimeError("private implementation detail")

    return app


async def test_domain_error_uses_stable_envelope() -> None:
    transport = httpx.ASGITransport(app=_test_app())
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/test/domain-error",
            headers={"X-Request-ID": "domain-test"},
        )

    assert response.status_code == 409
    assert response.headers["X-Request-ID"] == "domain-test"
    assert response.json() == {
        "error": {
            "code": "STALE_BALANCE",
            "message": "Balances changed.",
            "details": {"repair": "refresh"},
            "request_id": "domain-test",
        }
    }


async def test_validation_errors_do_not_echo_input_values() -> None:
    transport = httpx.ASGITransport(app=_test_app())
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/test/validated?value=sensitive-invalid-value")

    body = response.json()
    assert response.status_code == 422
    assert body["error"]["code"] == "VALIDATION_ERROR"
    assert "sensitive-invalid-value" not in response.text


async def test_unexpected_errors_do_not_leak_exception_text() -> None:
    transport = httpx.ASGITransport(app=_test_app(), raise_app_exceptions=False)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/test/unexpected",
            headers={"X-Request-ID": "unexpected-test"},
        )

    assert response.status_code == 500
    assert response.json()["error"] == {
        "code": "INTERNAL_ERROR",
        "message": "An unexpected error occurred.",
        "details": {},
        "request_id": "unexpected-test",
    }
    assert "private implementation detail" not in response.text


async def test_untrusted_request_id_is_replaced() -> None:
    transport = httpx.ASGITransport(app=_test_app())
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get(
            "/api/v1/health",
            headers={"X-Request-ID": "contains spaces and is not trusted"},
        )

    assert response.status_code == 200
    assert response.headers["X-Request-ID"] != "contains spaces and is not trusted"
    assert len(response.headers["X-Request-ID"]) == 36
