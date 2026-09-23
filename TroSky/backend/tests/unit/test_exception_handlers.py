"""Unit tests for the registered exception handlers.

Uses a minimal app rather than the real one so these exercise the handlers
themselves without needing Postgres or Redis.
"""

from __future__ import annotations

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from pydantic import BaseModel, field_validator

from app.core.exceptions import register_exception_handlers

pytestmark = pytest.mark.asyncio


class _Body(BaseModel):
    phone_number: str

    @field_validator("phone_number")
    @classmethod
    def _check(cls, value: str) -> str:
        if not value.startswith("+"):
            # Mirrors app.schemas.auth._validate_phone: a field validator
            # raising ValueError puts the exception object into the error's
            # "ctx", which is not JSON serializable.
            raise ValueError(f"{value!r} is not a valid phone number")
        return value


def _app() -> FastAPI:
    application = FastAPI()
    register_exception_handlers(application)

    @application.post("/echo")
    async def echo(body: _Body) -> dict[str, str]:  # pragma: no cover - trivial
        return {"phone_number": body.phone_number}

    return application


async def _post(payload: dict[str, object]):
    transport = ASGITransport(app=_app())
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        return await client.post("/echo", json=payload)


class TestValidationErrorHandler:
    async def test_field_validator_value_error_returns_422_not_500(self) -> None:
        """Regression: the raw ValueError in Pydantic's "ctx" used to make
        the handler's own JSONResponse render fail, turning every invalid
        phone number into a 500."""
        response = await _post({"phone_number": "0241234567"})
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "VALIDATION_ERROR"

    async def test_error_detail_keeps_message_and_drops_ctx(self) -> None:
        response = await _post({"phone_number": "0241234567"})
        error = response.json()["error"]["details"]["errors"][0]
        assert "ctx" not in error
        assert error["loc"] == ["body", "phone_number"]
        assert "is not a valid phone number" in error["msg"]

    async def test_missing_field_still_reported(self) -> None:
        response = await _post({})
        assert response.status_code == 422
        assert response.json()["error"]["details"]["errors"][0]["type"] == "missing"
