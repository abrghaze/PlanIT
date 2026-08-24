import logging
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.db.session import get_db_session

router = APIRouter()
logger = logging.getLogger("planit.readiness")


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    service: str
    version: str
    environment: str


class ReadinessResponse(BaseModel):
    status: Literal["ready"] = "ready"


@router.get("/health", response_model=HealthResponse, summary="Liveness information")
async def health(request: Request) -> HealthResponse:
    settings: Settings = request.app.state.settings
    return HealthResponse(
        service=settings.app_name,
        version=settings.app_version,
        environment=settings.app_env,
    )


@router.get("/ready", response_model=ReadinessResponse, summary="Database readiness")
async def readiness(
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> ReadinessResponse:
    try:
        await session.execute(text("SELECT 1"))
    except (OSError, SQLAlchemyError):
        logger.exception("database_readiness_check_failed")
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE) from None
    return ReadinessResponse()
