"""Admin settings and feature flags change what the platform does.

Overrides are written straight into the rolled-back test transaction, and
the services are built the way the API builds them: with
``effective_settings``.
"""

from __future__ import annotations

import dataclasses
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.exceptions import ConflictError, FeatureDisabledError
from app.core.redis import get_redis_client
from app.models.admin import FeatureFlag, SystemSetting
from app.models.payments import Wallet, WalletReferenceType, WalletTransaction
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.services import system_settings_service
from app.services.booking_service import BookingService
from app.services.system_settings_service import (
    CACHE_SECONDS,
    SystemSettingsService,
    admin_settings,
    effective_settings,
    is_enabled,
)
from app.services.trip_search_service import TripSearchService
from app.services.trip_service import TripService
from app.services.trip_share_service import TripShareService
from tests.integration.scenarios import TripScenario, book, build_trip_scenario

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

LEGON, CIRCLE = 1, 2


async def _scenario(session: AsyncSession, make_user, *, minutes: int = 60) -> TripScenario:
    return await build_trip_scenario(
        session, make_user, departure=datetime.now(UTC) + timedelta(minutes=minutes)
    )


async def _override(session: AsyncSession, **values: object) -> None:
    for key, value in values.items():
        await session.merge(SystemSetting(key=key, value=value))
    await session.flush()


async def _flag(session: AsyncSession, key: str, *, enabled: bool, rollout: int = 100) -> None:
    # Other tests may have committed the flag's row already.
    await session.merge(
        FeatureFlag(key=key, description=key, enabled=enabled, rollout_percent=rollout)
    )
    await session.flush()


class TestSettingsTakeEffect:
    async def test_the_platform_fee(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        await _override(db_session, platform_fee_flat_per_seat="1.25")

        settings = await effective_settings(db_session)
        quote, _, _ = await TripSearchService(db_session, get_redis_client(), settings).fare_quote(
            scenario.trip_id,
            origin_stop_id=scenario.stop_ids[LEGON],
            destination_stop_id=scenario.stop_ids[CIRCLE],
            seats=2,
        )

        assert Decimal("1.25") == settings.PLATFORM_FEE_FLAT_PER_SEAT
        assert quote.platform_fee == Decimal("2.50")

    async def test_the_payment_hold(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user)
        await _override(db_session, reservation_hold_seconds=120)

        booking = await BookingService(
            db_session, settings=await effective_settings(db_session)
        ).create_booking(
            (await make_user()).id,
            BookingCreateRequest(
                trip_id=scenario.trip_id,
                passengers=[PassengerInput(seat_id=scenario.seat_ids[0], full_name="Akos")],
            ),
            idempotency_key=None,
        )

        assert booking.expires_at is not None
        held_for = booking.expires_at - datetime.now(UTC)
        assert timedelta(seconds=100) < held_for <= timedelta(seconds=120)

    async def test_the_drivers_share(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user, minutes=-5)
        booking = await book(db_session, (await make_user()).id, scenario, seat=0)
        await _override(db_session, driver_earnings_share_percent="50.00")
        trips = TripService(db_session, await effective_settings(db_session))

        await trips.start_trip(scenario.trip_id, scenario.driver_user_id)
        await trips.end_trip(scenario.trip_id, scenario.driver_user_id)

        earned = await db_session.scalar(
            select(WalletTransaction.amount_minor_units)
            .join(Wallet, Wallet.id == WalletTransaction.wallet_id)
            .where(
                Wallet.user_id == scenario.driver_user_id,
                WalletTransaction.reference_type == WalletReferenceType.TRIP_EARNING,
            )
        )
        assert Decimal(earned) / 100 == booking.fare_amount / 2

    async def test_no_overrides_means_the_environment(self, db_session: AsyncSession) -> None:
        assert await effective_settings(db_session) is get_settings()

    async def test_a_flag_set_as_the_environment_has_it_changes_nothing(
        self, db_session: AsyncSession
    ) -> None:
        await _flag(db_session, "fare_sharing", enabled=get_settings().FARE_SHARING_ENABLED)

        assert await effective_settings(db_session) is get_settings()


class TestFlagsTakeEffect:
    async def test_fare_sharing_off_charges_everyone_the_solo_price(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        await book(db_session, (await make_user()).id, scenario, seat=0)
        await _flag(db_session, "fare_sharing", enabled=False)

        second = await BookingService(
            db_session, settings=await effective_settings(db_session)
        ).create_booking(
            (await make_user()).id,
            BookingCreateRequest(
                trip_id=scenario.trip_id,
                passengers=[PassengerInput(seat_id=scenario.seat_ids[1], full_name="Kwame")],
            ),
            idempotency_key=None,
        )

        assert second.fare_amount == Decimal("8.00")  # alone or not, the whole fare

    async def test_moving_trips_off(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, minutes=-5)
        await TripService(db_session).start_trip(scenario.trip_id, scenario.driver_user_id)
        await _flag(db_session, "book_moving_trips", enabled=False)
        settings = await effective_settings(db_session)

        offers, _ = await TripSearchService(db_session, get_redis_client(), settings).search(
            origin_stop_id=scenario.stop_ids[LEGON],
            destination_stop_id=scenario.stop_ids[CIRCLE],
            travel_date=datetime.now(UTC).date(),
            departure_after=None,
            departure_before=None,
            pickup_latitude=None,
            pickup_longitude=None,
            vehicle_type=None,
            sort="departure",
            seats=1,
            limit=20,
            offset=0,
        )
        with pytest.raises(ConflictError) as refused:
            await BookingService(db_session, settings=settings).create_booking(
                (await make_user()).id,
                BookingCreateRequest(
                    trip_id=scenario.trip_id,
                    passengers=[PassengerInput(seat_id=scenario.seat_ids[0], full_name="Esi")],
                    origin_stop_id=scenario.stop_ids[LEGON],
                ),
                idempotency_key=None,
            )

        assert scenario.trip_id not in {offer.summary.trip_id for offer in offers}
        assert refused.value.code == "TRIP_NOT_BOOKABLE"

    async def test_share_links_off(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user)
        passenger = await make_user()
        booking = await book(db_session, passenger.id, scenario, seat=0)
        await _flag(db_session, "trip_share_links", enabled=False)

        with pytest.raises(FeatureDisabledError):
            await TripShareService(db_session, get_redis_client()).create_link(
                passenger.id, booking.id
            )

    async def test_a_flag_with_no_row_uses_its_default(self, db_session: AsyncSession) -> None:
        # Other tests commit the flags' rows; this removal is rolled back.
        await db_session.execute(delete(FeatureFlag).where(FeatureFlag.key == "trip_share_links"))

        assert await is_enabled(db_session, "trip_share_links", uuid.uuid4()) is True

    async def test_a_partial_rollout_reaches_some_users(self, db_session: AsyncSession) -> None:
        await _flag(db_session, "trip_share_links", enabled=True, rollout=30)

        reached = [
            await is_enabled(db_session, "trip_share_links", uuid.uuid4()) for _ in range(200)
        ]

        assert 0 < sum(reached) < 200


class TestChangesApplyAtOnce:
    """On the worker that made the change, without waiting out the cache."""

    async def test_a_changed_setting(self, db_session: AsyncSession, make_user) -> None:
        admin = await make_user()
        await effective_settings(db_session)  # cached

        await SystemSettingsService(db_session).update_settings(
            {"platform_fee_flat_per_seat": "1.25"}, by=admin.id
        )

        assert Decimal("1.25") == (await effective_settings(db_session)).PLATFORM_FEE_FLAT_PER_SEAT

    async def test_a_switched_flag(self, db_session: AsyncSession, make_user) -> None:
        admin = await make_user()
        assert await is_enabled(db_session, "trip_share_links", admin.id)  # cached

        await SystemSettingsService(db_session).update_flag(
            "trip_share_links", enabled=False, rollout_percent=None, by=admin.id
        )

        assert not await is_enabled(db_session, "trip_share_links", admin.id)

    async def test_other_workers_see_it_when_their_cache_expires(
        self, db_session: AsyncSession
    ) -> None:
        await effective_settings(db_session)  # cached
        await _override(db_session, platform_fee_flat_per_seat="1.25")  # by another worker
        cached = (await effective_settings(db_session)).PLATFORM_FEE_FLAT_PER_SEAT
        snapshot = system_settings_service._cache
        assert snapshot is not None
        system_settings_service._cache = dataclasses.replace(
            snapshot, taken_at=snapshot.taken_at - CACHE_SECONDS - 1
        )

        fresh = (await effective_settings(db_session)).PLATFORM_FEE_FLAT_PER_SEAT

        assert (cached, fresh) == (get_settings().PLATFORM_FEE_FLAT_PER_SEAT, Decimal("1.25"))


class TestTheCacheHoldsUp:
    async def test_after_the_request_that_filled_it_failed(self, db_session: AsyncSession) -> None:
        """That request's session rolled back and closed; the next request
        still reads the cached flags."""
        factory = get_session_factory()
        async with factory() as setup:
            await SystemSettingsService(setup).ensure_flags()
            await setup.commit()
        async with factory() as failed:
            await is_enabled(failed, "trip_share_links", uuid.uuid4())
            await failed.rollback()

        assert await is_enabled(db_session, "trip_share_links", uuid.uuid4()) is True

    async def test_with_a_stored_value_no_longer_valid(self, db_session: AsyncSession) -> None:
        await _override(db_session, reservation_hold_seconds=5, platform_fee_flat_per_seat="1.25")

        settings = await effective_settings(db_session)

        default_hold = get_settings().SEAT_RESERVATION_HOLD_SECONDS
        assert default_hold == settings.SEAT_RESERVATION_HOLD_SECONDS
        assert Decimal("1.25") == settings.PLATFORM_FEE_FLAT_PER_SEAT  # the valid one applies

    async def test_a_bad_stored_value_blocks_no_other_change(
        self, db_session: AsyncSession, make_user
    ) -> None:
        await _override(db_session, complaint_sla_hours={"low": 72})  # no other priorities

        sla = (await admin_settings(db_session)).complaint_sla_hours
        await SystemSettingsService(db_session).update_settings(
            {"approval_target_hours": 24}, by=(await make_user()).id
        )

        assert sla == {"low": 72, "medium": 48, "high": 24, "urgent": 4}  # the defaults
        assert (await admin_settings(db_session)).approval_target_hours == 24
