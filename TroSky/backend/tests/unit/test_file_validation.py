"""Unit tests for upload validation (size/MIME/extension allowlists)."""

from __future__ import annotations

import pytest

from app.core.config import Settings
from app.core.exceptions import FileValidationError
from app.utilities.file_validation import validate_upload


def _settings(**overrides: object) -> Settings:
    base = {
        "SECRET_KEY": "a" * 40,
        "PAYMENTS_WEBHOOK_SIGNING_SECRET": "b" * 40,
        "TICKET_QR_SIGNING_SECRET": "c" * 40,
        "DATABASE_URL": "postgresql+asyncpg://u:p@localhost:5432/db",
        "DATABASE_URL_SYNC": "postgresql+psycopg://u:p@localhost:5432/db",
    }
    base.update(overrides)
    return Settings(**base)  # type: ignore[arg-type]


class TestValidateUpload:
    def test_accepts_a_valid_jpeg(self) -> None:
        validate_upload(
            filename="license.jpg",
            content_type="image/jpeg",
            size_bytes=1024,
            settings=_settings(),
        )

    def test_accepts_a_valid_pdf(self) -> None:
        validate_upload(
            filename="insurance.pdf",
            content_type="application/pdf",
            size_bytes=2048,
            settings=_settings(),
        )

    def test_rejects_empty_file(self) -> None:
        with pytest.raises(FileValidationError, match="empty"):
            validate_upload(
                filename="license.jpg",
                content_type="image/jpeg",
                size_bytes=0,
                settings=_settings(),
            )

    def test_rejects_oversized_file(self) -> None:
        settings = _settings(MAX_UPLOAD_SIZE_BYTES=1000)
        with pytest.raises(FileValidationError, match="exceeds the maximum"):
            validate_upload(
                filename="license.jpg",
                content_type="image/jpeg",
                size_bytes=1001,
                settings=settings,
            )

    def test_rejects_disallowed_mime_type(self) -> None:
        with pytest.raises(FileValidationError, match="not allowed"):
            validate_upload(
                filename="script.exe",
                content_type="application/x-msdownload",
                size_bytes=1024,
                settings=_settings(),
            )

    def test_rejects_extension_mismatched_with_declared_type(self) -> None:
        # A .png filename but declaring image/jpeg — extension/type must agree.
        with pytest.raises(FileValidationError, match="does not match"):
            validate_upload(
                filename="license.png",
                content_type="image/jpeg",
                size_bytes=1024,
                settings=_settings(),
            )

    def test_rejects_missing_extension(self) -> None:
        with pytest.raises(FileValidationError, match="does not match"):
            validate_upload(
                filename="license",
                content_type="image/jpeg",
                size_bytes=1024,
                settings=_settings(),
            )
