"""Shared schema building blocks."""

from __future__ import annotations

from typing import Generic, TypeVar

from pydantic import BaseModel, ConfigDict

T = TypeVar("T")


class ApiModel(BaseModel):
    """Base for every response/request schema.

    ``from_attributes`` lets response schemas be built directly from ORM
    model instances (``Model.model_validate(orm_obj)``); ``extra="forbid"``
    on request schemas (set per-schema) guards against mass assignment.
    """

    model_config = ConfigDict(from_attributes=True)


class RequestModel(BaseModel):
    """Base for request schemas: rejects unknown fields outright, which is
    the project's mass-assignment guard (see ``CONTRIBUTING.md``)."""

    model_config = ConfigDict(extra="forbid")


class MessageResponse(ApiModel):
    message: str


class PaginatedResponse(BaseModel, Generic[T]):
    """Standard limit/offset pagination envelope for list endpoints that
    need a total count (admin review queues, reports)."""

    model_config = ConfigDict(from_attributes=True)

    items: list[T]
    total: int
    limit: int
    offset: int
