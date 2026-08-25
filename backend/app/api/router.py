from fastapi import APIRouter

from app.api.v1.accounts import router as accounts_router
from app.api.v1.auth import router as auth_router
from app.api.v1.catalog import router as catalog_router
from app.api.v1.health import router as health_router
from app.api.v1.transactions import router as transactions_router

api_router = APIRouter()
api_router.include_router(health_router, tags=["system"])
api_router.include_router(auth_router, tags=["authentication"])
api_router.include_router(accounts_router, tags=["accounts"])
api_router.include_router(catalog_router, tags=["catalog"])
api_router.include_router(transactions_router, tags=["transactions"])
