"""Request-scoped middleware: correlation IDs, structured access logging,
and request body size enforcement."""

from __future__ import annotations

import time
import uuid

from starlette.exceptions import HTTPException
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response
from starlette.types import ASGIApp, Message, Receive, Scope, Send

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


_TOO_LARGE_MESSAGE = "Request body exceeds the maximum allowed size."


class PayloadTooLargeError(HTTPException):
    """Raised mid-stream once a request body passes the size limit.

    Deliberately a Starlette ``HTTPException``: FastAPI's body parser
    re-raises those unchanged, but converts any other exception into a
    generic 400 ("There was an error parsing the body"), which would hide
    the real cause from the client. ``details`` is picked up by the app's
    HTTP exception handler so this and the declared-length rejection
    produce the same error body.
    """

    def __init__(self, max_bytes: int) -> None:
        super().__init__(status_code=413, detail=_TOO_LARGE_MESSAGE)
        self.details = {"max_bytes": max_bytes}


def _declared_length(scope: Scope) -> int | None:
    for name, value in scope.get("headers", []):
        if name == b"content-length":
            try:
                return int(value)
            except ValueError:
                return None
    return None


class RequestSizeLimitMiddleware:
    """Caps request bodies at ``MAX_REQUEST_BODY_BYTES``.

    Two checks, because what a client *declares* and what it *sends* can
    differ:

    * a declared ``Content-Length`` over the limit is refused before a
      single byte is read;
    * every body chunk is counted as it arrives, so a chunked request with
      no ``Content-Length`` -- or one that sends more than it declared -- is
      stopped the moment it passes the limit instead of being buffered.

    Pure ASGI rather than ``BaseHTTPMiddleware``: counting has to wrap the
    ``receive`` channel itself, which that base class does not expose.
    """

    def __init__(self, app: ASGIApp, settings: Settings) -> None:
        self.app = app
        self._max_bytes = settings.MAX_REQUEST_BODY_BYTES

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        declared = _declared_length(scope)
        if declared is not None and declared > self._max_bytes:
            await self._refuse(scope, receive, send)
            return

        received = 0
        response_started = False

        async def counted_receive() -> Message:
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > self._max_bytes:
                    raise PayloadTooLargeError(self._max_bytes)
            return message

        async def tracked_send(message: Message) -> None:
            nonlocal response_started
            if message["type"] == "http.response.start":
                response_started = True
            await send(message)

        try:
            await self.app(scope, counted_receive, tracked_send)
        except PayloadTooLargeError:
            # Normally the app's HTTPException handler has already answered
            # 413 and this is never reached; it covers a body read outside
            # FastAPI's own handling. A response already under way cannot be
            # replaced, so the connection is left to fail instead.
            if response_started:
                raise
            await self._refuse(scope, receive, send)

    async def _refuse(self, scope: Scope, receive: Receive, send: Send) -> None:
        request_id = scope.get("state", {}).get("request_id", "unknown")
        response = JSONResponse(
            status_code=413,
            content={
                "error": {
                    "code": "PAYLOAD_TOO_LARGE",
                    "message": _TOO_LARGE_MESSAGE,
                    "details": {"max_bytes": self._max_bytes},
                    "request_id": request_id,
                }
            },
        )
        await response(scope, receive, send)
