"""Upload validation: file size, MIME type, and extension allowlists.

Applied before any bytes are written to object storage. This is
content-declared validation (trusts the client's declared content-type and
the filename extension) — it is a first line of defense, not a substitute
for the malware-scanning step that also runs before persistence (see
``app.services.document_service``).
"""

from __future__ import annotations

from app.core.config import Settings
from app.core.exceptions import FileValidationError

_MIME_TO_EXTENSIONS: dict[str, set[str]] = {
    "image/jpeg": {"jpg", "jpeg"},
    "image/png": {"png"},
    "application/pdf": {"pdf"},
}


def validate_upload(
    *, filename: str, content_type: str, size_bytes: int, settings: Settings
) -> None:
    if size_bytes <= 0:
        raise FileValidationError("The uploaded file is empty.")

    if size_bytes > settings.MAX_UPLOAD_SIZE_BYTES:
        raise FileValidationError(
            f"The uploaded file exceeds the maximum allowed size of "
            f"{settings.MAX_UPLOAD_SIZE_BYTES} bytes.",
            details={"max_bytes": settings.MAX_UPLOAD_SIZE_BYTES, "actual_bytes": size_bytes},
        )

    allowed_mime_types = set(settings.allowed_upload_mime_types)
    if content_type not in allowed_mime_types:
        raise FileValidationError(
            f"File type '{content_type}' is not allowed.",
            details={"allowed_types": sorted(allowed_mime_types)},
        )

    extension = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    allowed_extensions = _MIME_TO_EXTENSIONS.get(content_type, set())
    if not extension or extension not in allowed_extensions:
        raise FileValidationError(
            f"File extension for '{filename}' does not match its declared type.",
            details={"expected_extensions": sorted(allowed_extensions)},
        )
