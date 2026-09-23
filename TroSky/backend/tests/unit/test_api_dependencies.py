"""Unit tests for shared API dependency helpers (no external services)."""

from __future__ import annotations

import uuid

from app.api.dependencies import PaginationParams, _extract_idempotency_key, _pagination_params


class TestPagination:
    def test_defaults(self) -> None:
        params = _pagination_params()
        assert params == PaginationParams(limit=20, offset=0)

    def test_custom_values_are_respected(self) -> None:
        params = _pagination_params(limit=50, offset=10)
        assert params.limit == 50
        assert params.offset == 10


class TestIdempotencyKeyExtraction:
    def test_returns_none_when_absent(self) -> None:
        assert _extract_idempotency_key(None) is None

    def test_returns_the_provided_uuid(self) -> None:
        key = uuid.uuid4()
        assert _extract_idempotency_key(key) == key
