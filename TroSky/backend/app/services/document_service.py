"""Shared document upload/validation logic used by both driver and vehicle
document upload flows.

Pipeline: validate (size/MIME/extension) → malware scan → store in the
private object-storage bucket → caller persists the resulting metadata row
and, separately, logs an audit event for the access/upload (audit logging
for document access is a spec requirement — see callers in
``app.api.v1.drivers`` / ``app.api.v1.fleets``).
"""

from __future__ import annotations

import uuid

from app.core.config import Settings
from app.core.exceptions import FileValidationError
from app.core.logging import get_logger
from app.providers.storage.base import ObjectStorageProvider, UploadedObject
from app.providers.storage.malware_scan import MalwareScanner
from app.utilities.file_validation import validate_upload

logger = get_logger(__name__)


async def store_uploaded_document(
    *,
    storage: ObjectStorageProvider,
    scanner: MalwareScanner,
    settings: Settings,
    key_prefix: str,
    filename: str,
    content_type: str,
    data: bytes,
) -> UploadedObject:
    """Validate, scan, and persist an uploaded document. Raises
    :class:`FileValidationError` if validation or scanning rejects it."""
    validate_upload(
        filename=filename, content_type=content_type, size_bytes=len(data), settings=settings
    )

    scan_result = await scanner.scan(data)
    if not scan_result.is_clean:
        logger.warning("document_upload_rejected_by_scanner", filename=filename)
        raise FileValidationError(
            "The uploaded file failed a malware scan and was not stored.",
            details={"scan_details": scan_result.details},
        )

    key = f"{key_prefix}/{uuid.uuid4()}-{filename}"
    uploaded = await storage.put_object(key, data, content_type)
    logger.info("document_uploaded", storage_key=key, size_bytes=uploaded.size_bytes)
    return uploaded
