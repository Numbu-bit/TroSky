"""Pagination totals for BookingRepository.list_for_passenger / list_all.

Totals used to be computed by fetching every matching booking id and
calling ``len()`` in Python -- memory and transfer that grow with a
passenger's whole history, on every page. They are now a ``COUNT(*)`` in
the database. These tests check the numbers still come out right across
pages and filters, and that the count really is done by the database.
"""

from __future__ import annotations

import uuid
from decimal import Decimal

import pytest
from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.bookings import BookingStatus
from app.repositories.booking_repository import BookingRepository
from tests.integration.test_booking_service import _make_bookable_trip

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


async def _bookings(
    repo: BookingRepository, trip_id: uuid.UUID, passenger_id: uuid.UUID, count: int
) -> list:
    made = []
    for _ in range(count):
        made.append(
            await repo.create_booking(
                passenger_id=passenger_id,
                trip_id=trip_id,
                passenger_count=1,
                origin_stop_id=None,
                destination_stop_id=None,
                fare_amount=Decimal("20.00"),
                platform_fee=Decimal("0.50"),
                total_amount=Decimal("20.50"),
                expires_at=None,
                idempotency_key=None,
                idempotency_request_hash=None,
            )
        )
    return made


class TestPassengerTotals:
    async def test_total_counts_every_booking_while_the_page_is_limited(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, _, _ = await _make_bookable_trip(db_session, make_user=make_user)
        repo = BookingRepository(db_session)
        ama = (await make_user()).id
        await _bookings(repo, trip_id, ama, 5)
        await _bookings(repo, trip_id, (await make_user()).id, 3)  # someone else's

        first, total = await repo.list_for_passenger(ama, limit=2, offset=0)
        assert (len(first), total) == (2, 5)

        last, total = await repo.list_for_passenger(ama, limit=2, offset=4)
        assert (len(last), total) == (1, 5)

    async def test_a_passenger_with_no_bookings_has_a_total_of_zero(
        self, db_session: AsyncSession, make_user
    ) -> None:
        items, total = await BookingRepository(db_session).list_for_passenger(
            (await make_user()).id, limit=20, offset=0
        )
        assert (items, total) == ([], 0)


class TestAdminTotals:
    async def test_the_status_filter_applies_to_the_total(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, _, _ = await _make_bookable_trip(db_session, make_user=make_user)
        repo = BookingRepository(db_session)
        made = await _bookings(repo, trip_id, (await make_user()).id, 4)
        for booking in made[:3]:
            await repo.set_status(
                booking, new_status=BookingStatus.CONFIRMED, changed_by=None, reason="test"
            )

        _, confirmed = await repo.list_all(status=BookingStatus.CONFIRMED, limit=1, offset=0)
        _, everything = await repo.list_all(status=None, limit=1, offset=0)
        assert confirmed >= 3
        assert everything >= confirmed + 1


class TestQueryShape:
    async def test_the_total_is_a_count_in_the_database(
        self, db_session: AsyncSession, make_user
    ) -> None:
        """Guards against a quiet revert: the old code issued a bare
        ``SELECT bookings.id ... WHERE passenger_id = ...`` with no LIMIT and
        counted the rows in Python."""
        trip_id, _, _ = await _make_bookable_trip(db_session, make_user=make_user)
        repo = BookingRepository(db_session)
        ama = (await make_user()).id
        await _bookings(repo, trip_id, ama, 3)

        statements: list[str] = []

        def capture(conn, cursor, statement, parameters, context, executemany) -> None:  # type: ignore[no-untyped-def]
            statements.append(statement.lower())

        sync_connection = db_session.bind.sync_connection  # type: ignore[union-attr]
        event.listen(sync_connection, "before_cursor_execute", capture)
        try:
            await repo.list_for_passenger(ama, limit=1, offset=0)
        finally:
            event.remove(sync_connection, "before_cursor_execute", capture)

        assert any("count(" in s for s in statements), statements
        unbounded_id_scans = [
            s
            for s in statements
            if s.lstrip().startswith("select bookings.id") and "limit" not in s
        ]
        assert unbounded_id_scans == []
