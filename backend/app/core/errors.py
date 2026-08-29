from __future__ import annotations

import logging
from collections.abc import Mapping
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.domain.errors import DomainError

logger = logging.getLogger("planit.errors")

_CONFLICT_CODES = {
    "ACCOUNT_CLOSED",
    "ACCOUNT_HAS_ACTIVITY",
    "ACCOUNT_ID_CONFLICT",
    "ACCOUNT_READ_ONLY",
    "CATALOG_ID_CONFLICT",
    "CATALOG_NAME_CONFLICT",
    "CATEGORY_HAS_ACTIVE_CHILDREN",
    "CATEGORY_IN_USE",
    "CURRENCY_MISMATCH",
    "DEBT_ALREADY_SETTLED",
    "DEBT_ID_CONFLICT",
    "DEBT_NOT_OPEN",
    "DEBT_OPERATION_CONFLICT",
    "DEBT_OVERPAYMENT",
    "EMAIL_ALREADY_REGISTERED",
    "FINANCIAL_INTEGRITY_CONFLICT",
    "IDEMPOTENCY_CONFLICT",
    "NEGATIVE_BALANCE_NOT_ALLOWED",
    "STALE_BALANCE",
    "SPECIALIZED_REVERSAL_REQUIRED",
    "TRANSACTION_ALREADY_REVERSED",
    "TRANSACTION_ID_CONFLICT",
    "TRANSACTION_NOT_DRAFT",
    "TRANSACTION_NOT_POSTED",
    "TRANSACTION_OPERATION_CONFLICT",
    "TRANSFER_ID_CONFLICT",
    "TRANSFER_OPERATION_CONFLICT",
    "REALLOCATION_ID_CONFLICT",
    "REALLOCATION_OPERATION_CONFLICT",
    "RECONCILIATION_ID_CONFLICT",
    "RECONCILIATION_OPERATION_CONFLICT",
    "REFUND_CONFLICTS_WITH_SHARES",
    "REFUND_EXCEEDS_REMAINING",
    "REFUND_ID_CONFLICT",
    "REFUND_OPERATION_CONFLICT",
    "SHARE_ALREADY_EXISTS",
    "SHARE_BELOW_PAID_AMOUNT",
    "SHARE_HAS_PAYMENTS",
    "SHARE_ID_CONFLICT",
    "SHARE_OPERATION_CONFLICT",
    "SHARED_EXPENSE_CAP_EXCEEDED",
    "VERSION_CONFLICT",
}

_DOMAIN_STATUS_CODES = {
    "ACCOUNT_NOT_FOUND": 404,
    "CATEGORY_NOT_FOUND": 404,
    "DEBT_NOT_FOUND": 404,
    "EXPENSE_NOT_FOUND": 404,
    "PERSON_NOT_FOUND": 404,
    "SHARE_NOT_FOUND": 404,
    "TAG_NOT_FOUND": 404,
    "TRANSACTION_NOT_FOUND": 404,
    "TRANSFER_NOT_FOUND": 404,
    "AUTH_RATE_LIMITED": 429,
    "INVALID_CREDENTIALS": 401,
    "INVALID_REFRESH_TOKEN": 401,
    "TOKEN_REUSE_DETECTED": 401,
    **{code: 409 for code in _CONFLICT_CODES},
}

_HTTP_ERROR_CONTRACTS = {
    400: ("BAD_REQUEST", "The request could not be processed."),
    401: ("UNAUTHENTICATED", "Authentication is required."),
    403: ("FORBIDDEN", "You are not allowed to perform this action."),
    404: ("NOT_FOUND", "The requested resource was not found."),
    405: ("METHOD_NOT_ALLOWED", "The requested method is not allowed."),
    409: ("CONFLICT", "The request conflicts with current state."),
    429: ("RATE_LIMITED", "Too many requests were received."),
    503: ("SERVICE_UNAVAILABLE", "The service is temporarily unavailable."),
}


class ErrorBody(BaseModel):
    code: str
    message: str
    details: dict[str, Any] = Field(default_factory=dict)
    request_id: str


class ErrorEnvelope(BaseModel):
    error: ErrorBody


def _request_id(request: Request) -> str:
    return str(getattr(request.state, "request_id", "unknown"))


def _response(
    request: Request,
    *,
    status_code: int,
    code: str,
    message: str,
    details: dict[str, Any] | None = None,
    headers: Mapping[str, str] | None = None,
) -> JSONResponse:
    request_id = _request_id(request)
    body = ErrorEnvelope(
        error=ErrorBody(
            code=code,
            message=message,
            details=details or {},
            request_id=request_id,
        )
    )
    response_headers = dict(headers or {})
    response_headers["X-Request-ID"] = request_id
    return JSONResponse(
        status_code=status_code,
        content=body.model_dump(mode="json"),
        headers=response_headers,
    )


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(DomainError)
    async def handle_domain_error(request: Request, exc: DomainError) -> JSONResponse:
        return _response(
            request,
            status_code=_DOMAIN_STATUS_CODES.get(exc.code, 422),
            code=exc.code,
            message=exc.message,
            details=exc.details,
        )

    @app.exception_handler(RequestValidationError)
    async def handle_request_validation(
        request: Request,
        exc: RequestValidationError,
    ) -> JSONResponse:
        issues = [
            {
                "field": ".".join(str(part) for part in issue["loc"]),
                "type": issue["type"],
                "message": issue["msg"],
            }
            for issue in exc.errors()
        ]
        return _response(
            request,
            status_code=422,
            code="VALIDATION_ERROR",
            message="The request contains invalid values.",
            details={"issues": issues},
        )

    @app.exception_handler(StarletteHTTPException)
    async def handle_http_error(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        code, message = _HTTP_ERROR_CONTRACTS.get(
            exc.status_code,
            ("HTTP_ERROR", "The request could not be completed."),
        )
        return _response(
            request,
            status_code=exc.status_code,
            code=code,
            message=message,
            headers=exc.headers,
        )

    @app.exception_handler(Exception)
    async def handle_unexpected_error(request: Request, exc: Exception) -> JSONResponse:
        logger.exception(
            "unhandled_request_error",
            extra={
                "request_id": _request_id(request),
                "method": request.method,
                "path": request.url.path,
            },
            exc_info=exc,
        )
        return _response(
            request,
            status_code=500,
            code="INTERNAL_ERROR",
            message="An unexpected error occurred.",
        )
