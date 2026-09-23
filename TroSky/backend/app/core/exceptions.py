"""Application exception hierarchy and standardized error responses.

Every client-facing error uses the shape::

    {
        "error": {
            "code": "SEAT_NOT_AVAILABLE",
            "message": "The selected seat is no longer available.",
            "details": {},
            "request_id": "..."
        }
    }

Route handlers and services should raise a subclass of :class:`AppError`
rather than returning ad-hoc error payloads or leaking internal exceptions.
Unhandled exceptions are converted to a generic ``INTERNAL_SERVER_ERROR``
response — the original exception is logged with full detail server-side but
never echoed to the client.
"""

from __future__ import annotations

from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.logging import get_logger

logger = get_logger(__name__)


class AppError(Exception):
    """Base class for all application-raised, client-facing errors."""

    code: str = "APP_ERROR"
    status_code: int = status.HTTP_400_BAD_REQUEST
    message: str = "An unexpected error occurred."

    def __init__(
        self,
        message: str | None = None,
        *,
        code: str | None = None,
        status_code: int | None = None,
        details: dict[str, Any] | None = None,
    ) -> None:
        self.message = message or self.message
        self.code = code or self.code
        self.status_code = status_code or self.status_code
        self.details = details or {}
        super().__init__(self.message)


class ValidationAppError(AppError):
    code = "VALIDATION_ERROR"
    status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
    message = "The submitted data is invalid."


class NotFoundError(AppError):
    code = "NOT_FOUND"
    status_code = status.HTTP_404_NOT_FOUND
    message = "The requested resource was not found."


class ConflictError(AppError):
    code = "CONFLICT"
    status_code = status.HTTP_409_CONFLICT
    message = "The request conflicts with the current state of the resource."


class UnauthorizedError(AppError):
    code = "UNAUTHORIZED"
    status_code = status.HTTP_401_UNAUTHORIZED
    message = "Authentication is required."


class ForbiddenError(AppError):
    code = "FORBIDDEN"
    status_code = status.HTTP_403_FORBIDDEN
    message = "You do not have permission to perform this action."


class RateLimitExceededError(AppError):
    code = "RATE_LIMIT_EXCEEDED"
    status_code = status.HTTP_429_TOO_MANY_REQUESTS
    message = "Too many requests. Please try again later."


class AccountLockedError(AppError):
    code = "ACCOUNT_LOCKED"
    status_code = status.HTTP_423_LOCKED
    message = "This account is temporarily locked due to repeated failed attempts."


class AccountSuspendedError(AppError):
    code = "ACCOUNT_SUSPENDED"
    status_code = status.HTTP_403_FORBIDDEN
    message = "This account has been suspended."


class IdempotencyConflictError(AppError):
    code = "IDEMPOTENCY_KEY_REUSED"
    status_code = status.HTTP_409_CONFLICT
    message = "This idempotency key was already used with a different request payload."


class InvalidCredentialsError(AppError):
    code = "INVALID_CREDENTIALS"
    status_code = status.HTTP_401_UNAUTHORIZED
    message = "The provided credentials are incorrect."


class OtpNotFoundError(AppError):
    code = "OTP_NOT_FOUND"
    status_code = status.HTTP_404_NOT_FOUND
    message = "No active OTP challenge was found for this target."


class OtpInvalidError(AppError):
    code = "OTP_INVALID"
    status_code = status.HTTP_400_BAD_REQUEST
    message = "The OTP code is incorrect."


class OtpExpiredError(AppError):
    code = "OTP_EXPIRED"
    status_code = status.HTTP_400_BAD_REQUEST
    message = "The OTP code has expired."


class OtpAttemptsExceededError(AppError):
    code = "OTP_ATTEMPTS_EXCEEDED"
    status_code = status.HTTP_429_TOO_MANY_REQUESTS
    message = "Too many incorrect OTP attempts. Request a new code."


class TokenReuseDetectedError(AppError):
    code = "REFRESH_TOKEN_REUSE_DETECTED"
    status_code = status.HTTP_401_UNAUTHORIZED
    message = "This refresh token has already been used. All sessions have been revoked."


class PasswordResetTokenInvalidError(AppError):
    code = "PASSWORD_RESET_TOKEN_INVALID"
    status_code = status.HTTP_400_BAD_REQUEST
    message = "This password reset link is invalid or has expired."


class FileValidationError(AppError):
    code = "FILE_VALIDATION_ERROR"
    status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
    message = "The uploaded file failed validation."


class InvalidStateTransitionError(AppError):
    code = "INVALID_STATE_TRANSITION"
    status_code = status.HTTP_409_CONFLICT
    message = "This action is not valid for the current status."


class SeatNotAvailableError(AppError):
    code = "SEAT_NOT_AVAILABLE"
    status_code = status.HTTP_409_CONFLICT
    message = "The selected seat is no longer available."


class PaymentError(AppError):
    code = "PAYMENT_ERROR"
    status_code = status.HTTP_402_PAYMENT_REQUIRED
    message = "The payment could not be processed."


class ProviderError(AppError):
    """Raised when an upstream provider (payments, SMS, email, maps) fails."""

    code = "PROVIDER_ERROR"
    status_code = status.HTTP_502_BAD_GATEWAY
    message = "An upstream provider is currently unavailable."


class ExternalServiceUnavailableError(AppError):
    code = "SERVICE_UNAVAILABLE"
    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    message = "A required service is temporarily unavailable."


class InsufficientWalletBalanceError(AppError):
    code = "INSUFFICIENT_WALLET_BALANCE"
    status_code = status.HTTP_402_PAYMENT_REQUIRED
    message = "The wallet balance is insufficient for this transaction."


class InvalidWebhookSignatureError(AppError):
    code = "INVALID_WEBHOOK_SIGNATURE"
    status_code = status.HTTP_401_UNAUTHORIZED
    message = "The webhook signature could not be verified."


class RefundNotAllowedError(AppError):
    code = "REFUND_NOT_ALLOWED"
    status_code = status.HTTP_409_CONFLICT
    message = "This payment is not eligible for a refund."


class TicketValidationError(AppError):
    code = "TICKET_VALIDATION_FAILED"
    status_code = status.HTTP_400_BAD_REQUEST
    message = "This ticket could not be validated."


def _request_id(request: Request) -> str:
    return getattr(request.state, "request_id", "unknown")


def _error_body(
    *, code: str, message: str, details: dict[str, Any], request_id: str
) -> dict[str, Any]:
    return {
        "error": {
            "code": code,
            "message": message,
            "details": details,
            "request_id": request_id,
        }
    }


def register_exception_handlers(app: FastAPI) -> None:
    """Attach standardized exception handlers to the FastAPI application."""

    @app.exception_handler(AppError)
    async def handle_app_error(request: Request, exc: AppError) -> JSONResponse:
        request_id = _request_id(request)
        logger.info(
            "app_error",
            code=exc.code,
            status_code=exc.status_code,
            path=request.url.path,
            request_id=request_id,
        )
        return JSONResponse(
            status_code=exc.status_code,
            content=_error_body(
                code=exc.code, message=exc.message, details=exc.details, request_id=request_id
            ),
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        request_id = _request_id(request)
        # Pydantic puts the originating exception object in each error's
        # "ctx" (e.g. ctx={"error": ValueError(...)} for a field validator
        # that raised). That object is not JSON serializable, and rendering
        # it would fail *inside this handler*, downgrading a clean 422 into
        # a 500. "msg" already carries the same text, so drop "ctx" and run
        # the rest through jsonable_encoder to catch any other exotic input.
        details = {
            "errors": jsonable_encoder(
                [{k: v for k, v in error.items() if k != "ctx"} for error in exc.errors()]
            )
        }
        logger.info(
            "validation_error", path=request.url.path, request_id=request_id, errors=details
        )
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content=_error_body(
                code="VALIDATION_ERROR",
                message="The submitted data is invalid.",
                details=details,
                request_id=request_id,
            ),
        )

    @app.exception_handler(StarletteHTTPException)
    async def handle_http_exception(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        request_id = _request_id(request)
        code = {
            status.HTTP_404_NOT_FOUND: "NOT_FOUND",
            status.HTTP_401_UNAUTHORIZED: "UNAUTHORIZED",
            status.HTTP_403_FORBIDDEN: "FORBIDDEN",
            status.HTTP_405_METHOD_NOT_ALLOWED: "METHOD_NOT_ALLOWED",
            status.HTTP_413_REQUEST_ENTITY_TOO_LARGE: "PAYLOAD_TOO_LARGE",
            status.HTTP_429_TOO_MANY_REQUESTS: "RATE_LIMIT_EXCEEDED",
        }.get(exc.status_code, "HTTP_ERROR")
        return JSONResponse(
            status_code=exc.status_code,
            content=_error_body(
                code=code,
                message=str(exc.detail),
                details={},
                request_id=request_id,
            ),
        )

    @app.exception_handler(Exception)
    async def handle_unexpected_exception(request: Request, exc: Exception) -> JSONResponse:
        request_id = _request_id(request)
        logger.error(
            "unhandled_exception",
            path=request.url.path,
            request_id=request_id,
            exc_info=exc,
            exception_type=type(exc).__name__,
        )
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=_error_body(
                code="INTERNAL_SERVER_ERROR",
                message="An unexpected error occurred. Please try again later.",
                details={},
                request_id=request_id,
            ),
        )
