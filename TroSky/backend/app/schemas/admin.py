"""Request/response schemas for admin user management."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import Field

from app.schemas.common import ApiModel, RequestModel


class AdminUserSummaryResponse(ApiModel):
    id: uuid.UUID
    phone_number: str
    email: str | None
    is_active: bool
    is_suspended: bool
    suspended_reason: str | None
    created_at: datetime


class SuspendUserRequest(RequestModel):
    reason: str = Field(..., min_length=1, max_length=500)
