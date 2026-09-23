"""Structured JSON logging configuration using structlog.

All application logs are emitted as structured JSON (in production /
staging) with a correlation ``request_id`` bound from request-scoped
context, and sensitive fields are redacted before ever reaching a log sink.
"""

from __future__ import annotations

import logging
import sys
from contextvars import ContextVar
from typing import Any, cast

import structlog
from structlog.types import EventDict, Processor

request_id_ctx: ContextVar[str | None] = ContextVar("request_id", default=None)
user_id_ctx: ContextVar[str | None] = ContextVar("user_id", default=None)

_SENSITIVE_KEYS = {
    "password",
    "password_hash",
    "hashed_password",
    "otp",
    "otp_code",
    "token",
    "access_token",
    "refresh_token",
    "authorization",
    "secret",
    "secret_key",
    "api_key",
    "pin",
    "cvv",
    "card_number",
    "card_cvv",
    "momo_pin",
    "private_key",
}


def _redact_processor(
    _logger: logging.Logger, _method_name: str, event_dict: EventDict
) -> EventDict:
    def redact(value: Any) -> Any:
        if isinstance(value, dict):
            return {
                k: ("***REDACTED***" if k.lower() in _SENSITIVE_KEYS else redact(v))
                for k, v in value.items()
            }
        if isinstance(value, list):
            return [redact(item) for item in value]
        return value

    for key in list(event_dict.keys()):
        if key.lower() in _SENSITIVE_KEYS:
            event_dict[key] = "***REDACTED***"
        else:
            event_dict[key] = redact(event_dict[key])
    return event_dict


def _bind_context_processor(
    _logger: logging.Logger, _method_name: str, event_dict: EventDict
) -> EventDict:
    request_id = request_id_ctx.get()
    if request_id:
        event_dict.setdefault("request_id", request_id)
    user_id = user_id_ctx.get()
    if user_id:
        event_dict.setdefault("user_id", user_id)
    return event_dict


def configure_logging(*, log_level: str = "INFO", json_logs: bool = True) -> None:
    """Configure stdlib logging + structlog. Call once at process startup."""
    timestamper = structlog.processors.TimeStamper(fmt="iso", utc=True)

    shared_processors: list[Processor] = [
        structlog.contextvars.merge_contextvars,
        _bind_context_processor,
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        timestamper,
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        _redact_processor,
    ]

    structlog.configure(
        processors=[
            *shared_processors,
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )

    renderer: Processor = (
        structlog.processors.JSONRenderer()
        if json_logs
        else structlog.dev.ConsoleRenderer(colors=True)
    )

    formatter = structlog.stdlib.ProcessorFormatter(
        processor=renderer,
        foreign_pre_chain=shared_processors,
    )

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    root_logger.handlers = [handler]
    root_logger.setLevel(log_level.upper())

    for noisy_logger in ("uvicorn.access", "uvicorn.error", "sqlalchemy.engine"):
        logging.getLogger(noisy_logger).setLevel(logging.WARNING)


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    return cast(structlog.stdlib.BoundLogger, structlog.get_logger(name))
