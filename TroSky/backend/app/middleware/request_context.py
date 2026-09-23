"""Request-scoped middleware: correlation IDs, structured access logging,
and request body size enforcement."""

from __future__ import annotations

import time
import uuid

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.core.config import Settings
from app.core.logging import get_logger, request_id_ctx

logger = get_logger(__name__)

REQUEST_ID_HEADER = "X-Request-ID"


class CorrelationIdMiddleware(BaseHTTPMiddleware):
    """Assigns/propagates a request correlation ID (``X-Request-ID``).

    The ID is bound into the structlog context so every log line emitted
    while handling this request automatically includes it, and it is
    reflected back in the response header and in standardized error bodies.
    """

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        incoming_id = request.headers.get(REQUEST_ID_HEADER)
        request_id = incoming_id if incoming_id else str(uuid.uuid4())
        request.state.request_id = request_id
        token = request_id_ctx.set(request_id)
        try:
            response = await call_next(request)
        finally:
            request_id_ctx.reset(token)
        response.headers[REQUEST_ID_HEADER] = request_id
        return response


class AccessLogMiddleware(BaseHTTPMiddleware):
    """Emits one structured JSON access log line per request."""

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = round((time.perf_counter() - start) * 1000, 2)
        logger.info(
            "http_request",
            method=request.method,
            path=request.url.path,
            status_code=response.status_code,
            duration_ms=duration_ms,
            client_ip=request.client.host if request.client else None,
            request_id=getattr(request.state, "request_id", None),
        )
        return response


class RequestSizeLimitMiddleware(BaseHTTPMiddleware):
    """Rejects requests whose declared ``Content-Length`` exceeds the
    configured maximum, before the body is read into memory."""

    def __init__(self, app, settings: Settings) -> None:  # type: ignore[no-untyped-def]
        super().__init__(app)
        self._max_bytes = settings.MAX_REQUEST_BODY_BYTES

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        content_length = request.headers.get("content-length")
        if content_length is not None:
            try:
                declared_size = int(content_length)
            except ValueError:
                declared_size = None
            if declared_size is not None and declared_size > self._max_bytes:
                request_id = getattr(request.state, "request_id", "unknown")
                return JSONResponse(
                    status_code=413,
                    content={
                        "error": {
                            "code": "PAYLOAD_TOO_LARGE",
                            "message": "Request body exceeds the maximum allowed size.",
                            "details": {"max_bytes": self._max_bytes},
                            "request_id": request_id,
                        }
                    },
                )
        return await call_next(request)
