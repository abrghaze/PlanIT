from __future__ import annotations

from fastapi import FastAPI

from app.api.router import api_router
from app.core.config import Settings, get_settings
from app.core.errors import register_error_handlers
from app.core.middleware import register_middleware


def create_app(settings: Settings | None = None) -> FastAPI:
    resolved = settings or get_settings()
    app = FastAPI(
        title=resolved.app_name,
        version=resolved.app_version,
        debug=resolved.debug,
        docs_url="/docs" if resolved.app_env != "production" else None,
        redoc_url="/redoc" if resolved.app_env != "production" else None,
        openapi_url="/openapi.json" if resolved.app_env != "production" else None,
    )
    app.state.settings = resolved
    register_middleware(app, allowed_origins=resolved.allowed_origins)
    register_error_handlers(app)
    app.include_router(api_router, prefix=resolved.api_prefix)
    return app


app = create_app()
