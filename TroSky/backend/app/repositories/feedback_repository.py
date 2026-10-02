"""Database access for ratings and complaints."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.feedback import Complaint, ComplaintCategory, ComplaintStatus, Rating


class RatingAlreadyExistsError(Exception):
    """Raised when a booking already has a rating (unique constraint)."""


class RatingRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        booking_id: uuid.UUID,
        trip_id: uuid.UUID,
        passenger_id: uuid.UUID,
        driver_id: uuid.UUID | None,
        score: int,
        comment: str | None,
        categories: dict[str, int | None] | None = None,
    ) -> Rating:
        rating = Rating(
            booking_id=booking_id,
            trip_id=trip_id,
            passenger_id=passenger_id,
            driver_id=driver_id,
            score=score,
            comment=comment,
            **(categories or {}),
        )
        try:
            async with self._session.begin_nested():
                self._session.add(rating)
                await self._session.flush()
        except IntegrityError as exc:
            raise RatingAlreadyExistsError(str(booking_id)) from exc
        return rating

    async def get_by_booking_id(self, booking_id: uuid.UUID) -> Rating | None:
        result = await self._session.execute(select(Rating).where(Rating.booking_id == booking_id))
        return result.scalar_one_or_none()

    async def get_driver_category_averages(self, driver_id: uuid.UUID) -> dict[str, Decimal | None]:
        """Average of each optional rating category, over the ratings that
        gave one (None when none did)."""
        columns = (Rating.safety, Rating.cleanliness, Rating.professionalism, Rating.timeliness)
        result = await self._session.execute(
            select(*(func.avg(column) for column in columns)).where(Rating.driver_id == driver_id)
        )
        averages = result.one()
        return {
            column.key: (
                Decimal(str(average)).quantize(Decimal("0.01")) if average is not None else None
            )
            for column, average in zip(columns, averages, strict=True)
        }

    async def get_driver_average(self, driver_id: uuid.UUID) -> tuple[Decimal | None, int]:
        result = await self._session.execute(
            select(func.avg(Rating.score), func.count(Rating.id)).where(
                Rating.driver_id == driver_id
            )
        )
        average, count = result.one()
        rounded = Decimal(str(average)).quantize(Decimal("0.01")) if average is not None else None
        return rounded, int(count)


class ComplaintRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        filed_by: uuid.UUID,
        booking_id: uuid.UUID | None,
        trip_id: uuid.UUID | None,
        category: ComplaintCategory,
        subject: str,
        description: str,
    ) -> Complaint:
        complaint = Complaint(
            filed_by=filed_by,
            booking_id=booking_id,
            trip_id=trip_id,
            category=category,
            subject=subject,
            description=description,
        )
        self._session.add(complaint)
        await self._session.flush()
        return complaint

    async def get_by_id(self, complaint_id: uuid.UUID) -> Complaint | None:
        result = await self._session.execute(select(Complaint).where(Complaint.id == complaint_id))
        return result.scalar_one_or_none()

    async def get_for_update(self, complaint_id: uuid.UUID) -> Complaint | None:
        result = await self._session.execute(
            select(Complaint).where(Complaint.id == complaint_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def list_for_user(
        self, filed_by: uuid.UUID, *, limit: int, offset: int
    ) -> tuple[list[Complaint], int]:
        count_result = await self._session.execute(
            select(Complaint.id).where(Complaint.filed_by == filed_by)
        )
        total = len(count_result.scalars().all())
        result = await self._session.execute(
            select(Complaint)
            .where(Complaint.filed_by == filed_by)
            .order_by(Complaint.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        return list(result.scalars().all()), total

    async def list_all(
        self, *, status: ComplaintStatus | None, limit: int, offset: int
    ) -> tuple[list[Complaint], int]:
        stmt = select(Complaint)
        if status is not None:
            stmt = stmt.where(Complaint.status == status)
        count_result = await self._session.execute(
            select(func.count()).select_from(stmt.subquery())
        )
        total = count_result.scalar_one()
        result = await self._session.execute(
            stmt.order_by(Complaint.created_at.desc()).limit(limit).offset(offset)
        )
        return list(result.scalars().all()), total

    async def set_status(
        self,
        complaint: Complaint,
        *,
        new_status: ComplaintStatus,
        resolved_by: uuid.UUID | None,
        resolution_notes: str | None,
    ) -> None:
        complaint.status = new_status
        complaint.resolved_by = resolved_by
        complaint.resolved_at = datetime.now(UTC) if resolved_by is not None else None
        complaint.resolution_notes = resolution_notes
        await self._session.flush()
