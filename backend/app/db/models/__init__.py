"""Import models so SQLAlchemy and Alembic receive complete metadata."""

from app.db.models.control import AuditEventModel, IdempotencyKeyModel
from app.db.models.identity import AuthThrottleModel, RefreshSessionModel, UserModel
from app.db.models.ledger import (
    AccountModel,
    BalanceReconciliationModel,
    CategoryModel,
    DebtModel,
    DebtPaymentModel,
    ExchangeRateModel,
    PersonModel,
    ReallocationLineModel,
    ReallocationSessionModel,
    SharedExpenseShareModel,
    TagModel,
    TransactionModel,
    TransactionTagModel,
    TransferModel,
)
from app.db.models.purchases import (
    EntityMediaModel,
    MediaAssetModel,
    MerchantLocationModel,
    MerchantModel,
    ProductModel,
    TransactionItemModel,
)

__all__ = [
    "AccountModel",
    "AuditEventModel",
    "AuthThrottleModel",
    "BalanceReconciliationModel",
    "CategoryModel",
    "DebtModel",
    "DebtPaymentModel",
    "EntityMediaModel",
    "ExchangeRateModel",
    "IdempotencyKeyModel",
    "MediaAssetModel",
    "MerchantLocationModel",
    "MerchantModel",
    "PersonModel",
    "ProductModel",
    "ReallocationLineModel",
    "ReallocationSessionModel",
    "RefreshSessionModel",
    "SharedExpenseShareModel",
    "TagModel",
    "TransactionItemModel",
    "TransactionModel",
    "TransactionTagModel",
    "TransferModel",
    "UserModel",
]
