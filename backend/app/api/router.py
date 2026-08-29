from fastapi import APIRouter

from app.api.v1.accounts import router as accounts_router
from app.api.v1.auth import router as auth_router
from app.api.v1.catalog import router as catalog_router
from app.api.v1.corrections import router as corrections_router
from app.api.v1.debts import debts_router, people_router
from app.api.v1.health import router as health_router
from app.api.v1.sharing import shares_router, transaction_sharing_router
from app.api.v1.transactions import router as transactions_router
from app.api.v1.transfers import router as transfers_router

api_router = APIRouter()
api_router.include_router(health_router, tags=["system"])
api_router.include_router(auth_router, tags=["authentication"])
api_router.include_router(accounts_router, tags=["accounts"])
api_router.include_router(catalog_router, tags=["catalog"])
api_router.include_router(transactions_router, tags=["transactions"])
api_router.include_router(transfers_router, tags=["transfers"])
api_router.include_router(corrections_router, tags=["corrections"])
api_router.include_router(people_router, tags=["people"])
api_router.include_router(debts_router, tags=["debts"])
api_router.include_router(transaction_sharing_router, tags=["sharing"])
api_router.include_router(shares_router, tags=["sharing"])
