"""Second round of frontend requests, at the service level: SOS without a
trip (G19), share links (G24), the monthly summary (G25), favourites'
next trip (G26), notification counts (G27), saved payment methods (G28),
the driver's own views (G29-G31), incidents (G32) and the manifest's
drop-off stop (G33).

Uses the Madina -> Legon -> Circle scenario: 20 km, GHS 8.00, 4 seats.
"""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import (
    ConflictError,
    FileValidationError,
    ForbiddenError,
    NotFoundError,
    ShareLinkGoneError,
    ValidationAppError,
)
from app.core.redis import get_redis_client
from app.models.bookings import Booking, BookingStatus
from app.models.notifications import NotificationCategory
from app.models.payments import (
    Payment,
    PaymentPurpose,
    PaymentStatus,
    WalletReferenceType,
)
from app.models.safety import IncidentSeverity, IncidentType
from app.providers.payments.base import PaymentChannel
from app.providers.sms.sandbox import SandboxSmsProvider
from app.providers.storage.malware_scan import NoOpMalwareScanner
from app.providers.storage.sandbox import SandboxStorageProvider
from app.repositories.profile_repository import EmergencyContactRepository
from app.schemas.booking import BookingCreateRequest, PassengerInput
from app.services.booking_service import BookingService
from app.services.notification_service import NotificationService
from app.services.payment_method_service import PaymentMethodService
from app.services.payment_service import PaymentService
from app.services.safety_service import SafetyService
from app.services.trip_search_service import TripSearchService
from app.services.trip_service import TripService
from app.services.trip_share_service import TripShareService
from app.services.wallet_service import WalletService
from app.utilities.share_link import encode_share_token
from tests.integration.scenarios import book, build_trip_scenario, driver_service, fleet_service

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

MADINA, LEGON, CIRCLE = 0, 1, 2
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


@pytest.fixture(autouse=True)
def _clear_sandboxes():
    SandboxSmsProvider.clear()
    SandboxStorageProvider.clear()
    yield
    SandboxSmsProvider.clear()
    SandboxStorageProvider.clear()


async def _scenario(session: AsyncSession, make_user, *, hours: float = 2):
    departure = datetime.now(UTC) + timedelta(hours=hours)
    return await build_trip_scenario(session, make_user, departure=departure)


async def _paid_with_wallet(session: AsyncSession, passenger_id: uuid.UUID, booking: Booking):
    await WalletService(session).credit(
        passenger_id,
        amount=Decimal("50.00"),
        reference_type=WalletReferenceType.WALLET_TOPUP,
        reference_id=None,
        description="Test top-up",
    )
    await PaymentService(session).pay_for_booking(
        passenger_id,
        booking.id,
        channel=PaymentChannel.WALLET,
        payer_phone=None,
        idempotency_key=None,
    )


class TestSosWithoutATrip:  # G19
    async def test_raised_from_home_and_contacts_are_texted(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        await EmergencyContactRepository(db_session).create(
            user_id=user.id,
            name="Mama",
            phone_number="+233241112223",
            relationship_label="Mother",
            is_primary=True,
        )

        alert = await SafetyService(db_session).trigger_sos_without_trip(
            triggered_by=user.id, latitude=5.6037, longitude=-0.187
        )

        assert alert.trip_id is None
        message = SandboxSmsProvider.get_last_message("+233241112223")
        assert message is not None
        assert "during a trip" not in message
        assert "5.6037, -0.187" in message


class TestShareLinks:  # G24
    async def test_a_paid_booking_can_be_shared_and_opened(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        passenger = await make_user()
        booking = await book(
            db_session, passenger.id, scenario, seat=0, origin=scenario.stop_ids[LEGON]
        )
        shares = TripShareService(db_session, get_redis_client())

        token, expires_at = await shares.create_link(passenger.id, booking.id)
        shared = await shares.open_link(token)

        assert expires_at > datetime.now(UTC) + timedelta(hours=11)
        assert shared.summary.trip_id == scenario.trip_id
        assert shared.boarding_stop_name == scenario.stop_names[LEGON]
        assert shared.alighting_stop_name == scenario.stop_names[CIRCLE]
        assert shared.location is None  # not under way yet

    async def test_only_the_passenger_can_share_and_only_once_paid(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        passenger = await make_user()
        held = await book(db_session, passenger.id, scenario, seat=0, confirm=False)
        shares = TripShareService(db_session, get_redis_client())

        with pytest.raises(NotFoundError):
            await shares.create_link((await make_user()).id, held.id)
        with pytest.raises(ConflictError) as unpaid:
            await shares.create_link(passenger.id, held.id)
        assert unpaid.value.code == "BOOKING_NOT_SHAREABLE"

    async def test_expired_and_cancelled_links_are_gone(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        passenger = await make_user()
        booking = await book(db_session, passenger.id, scenario, seat=0)
        shares = TripShareService(db_session, get_redis_client())
        secret = shares._secret()

        expired = encode_share_token(booking.id, datetime.now(UTC) - timedelta(seconds=1), secret)
        with pytest.raises(ShareLinkGoneError):
            await shares.open_link(expired)

        token, _ = await shares.create_link(passenger.id, booking.id)
        await db_session.execute(
            update(Booking).where(Booking.id == booking.id).values(status=BookingStatus.CANCELLED)
        )
        db_session.expire_all()
        with pytest.raises(ShareLinkGoneError):
            await shares.open_link(token)

        with pytest.raises(NotFoundError):
            await shares.open_link("not-a-real-token-at-all-not-a-real-token")


class TestMonthlySummary:  # G25
    async def test_counts_paid_trips_in_the_month_and_what_sharing_saved(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, hours=1)
        rider = await make_user()
        passenger = await make_user()
        await book(db_session, rider.id, scenario, seat=0)  # whole route, shares the cost
        await book(
            db_session, passenger.id, scenario, seat=1, origin=scenario.stop_ids[LEGON]
        )  # 4.00 solo, 2.67 shared
        await book(db_session, passenger.id, scenario, seat=2, confirm=False)  # unpaid: ignored

        month = datetime.now(UTC).date().replace(day=1) + timedelta(hours=1)
        summary = await BookingService(db_session).monthly_summary(passenger.id, month)

        assert summary.trips_count == 1
        assert summary.total_spent == Decimal("3.17")  # 2.67 + 0.50 fee
        assert summary.average_fare == Decimal("3.17")
        assert summary.total_saved == Decimal("1.33")
        assert summary.currency == "GHS"

    async def test_another_month_is_empty(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        passenger = await make_user()

        summary = await BookingService(db_session).monthly_summary(passenger.id, date(2020, 2, 1))

        assert (summary.trips_count, summary.total_spent, summary.average_fare) == (
            0,
            Decimal("0.00"),
            Decimal("0.00"),
        )


class TestFavouritesNextTrip:  # G26
    async def test_the_soonest_trip_with_a_free_seat(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user, hours=1)
        trips = TripService(db_session)
        later = await trips.create_trip(
            route_id=scenario.route_id,
            route_schedule_id=None,
            scheduled_departure_at=datetime.now(UTC) + timedelta(hours=3),
            scheduled_arrival_at=None,
            fare_amount=Decimal("8.00"),
            created_by=None,
        )
        await trips.assign_vehicle(later.id, scenario.vehicle_id, assigned_by=None)
        for seat in range(4):  # the first trip is full
            await book(db_session, (await make_user()).id, scenario, seat=seat)
        journey = (scenario.stop_ids[LEGON], scenario.stop_ids[CIRCLE])

        found = await TripSearchService(db_session, get_redis_client()).next_departures([journey])

        departure = found[journey]
        assert departure is not None
        assert departure.trip_id == later.id
        assert departure.available_seats == 4
        assert departure.fare.current == Decimal("4.00")

    async def test_none_when_nothing_runs(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        journey = (uuid.uuid4(), uuid.uuid4())

        found = await TripSearchService(db_session, get_redis_client()).next_departures([journey])

        assert found == {journey: None}


class TestNotificationCounts:  # G27
    async def test_unread_count_and_read_all(self, db_session: AsyncSession, make_user) -> None:
        user = await make_user()
        notifications = NotificationService(db_session)
        for title in ("Booked", "Paid", "Boarding soon"):
            await notifications.notify(
                user.id, category=NotificationCategory.TRANSACTIONAL, title=title, body=title
            )
        assert await notifications.count_unread(user.id) == 3

        assert await notifications.mark_all_read(user.id) == 3
        assert await notifications.count_unread(user.id) == 0
        assert await notifications.mark_all_read(user.id) == 0


class TestPaymentMethods:  # G28
    async def test_first_is_default_and_making_another_default_moves_it(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        methods = PaymentMethodService(db_session)

        first = await methods.add_method(
            user.id,
            channel=PaymentChannel.MTN_MOMO,
            phone_number="0241234567",
            label="Mine",
            make_default=False,
        )
        second = await methods.add_method(
            user.id,
            channel=PaymentChannel.TELECEL_CASH,
            phone_number="0201234567",
            label=None,
            make_default=True,
        )

        listed = await methods.list_methods(user.id)
        assert first.phone_number == "+233241234567"
        assert [m.id for m in listed] == [second.id, first.id]
        assert [m.is_default for m in listed] == [True, False]

    async def test_deleting_the_default_promotes_the_newest(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        methods = PaymentMethodService(db_session)
        added = [
            await methods.add_method(
                user.id,
                channel=PaymentChannel.MTN_MOMO,
                phone_number=number,
                label=None,
                make_default=False,
            )
            for number in ("0241000001", "0241000002", "0241000003")
        ]
        # One transaction stamps every row with the same now(); in the app
        # each is saved by its own request.
        for minutes_ago, method in zip((30, 20, 10), added, strict=True):
            method.created_at = datetime.now(UTC) - timedelta(minutes=minutes_ago)
        await db_session.flush()

        await methods.delete_method(user.id, added[0].id)

        listed = await methods.list_methods(user.id)
        assert listed[0].id == added[2].id
        assert listed[0].is_default is True
        assert sum(m.is_default for m in listed) == 1

    async def test_rejects_cards_duplicates_and_bad_numbers(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        methods = PaymentMethodService(db_session)
        await methods.add_method(
            user.id,
            channel=PaymentChannel.MTN_MOMO,
            phone_number="0241234567",
            label=None,
            make_default=False,
        )

        with pytest.raises(ValidationAppError):
            await methods.add_method(
                user.id,
                channel=PaymentChannel.CARD,
                phone_number="0241234567",
                label=None,
                make_default=False,
            )
        with pytest.raises(ConflictError) as duplicate:
            await methods.add_method(
                user.id,
                channel=PaymentChannel.MTN_MOMO,
                phone_number="+233 24 123 4567",
                label=None,
                make_default=False,
            )
        assert duplicate.value.code == "PAYMENT_METHOD_EXISTS"
        with pytest.raises(ValidationAppError):
            await methods.add_method(
                user.id,
                channel=PaymentChannel.MTN_MOMO,
                phone_number="12",
                label=None,
                make_default=False,
            )

    async def test_someone_elses_method_is_not_found(
        self, db_session: AsyncSession, make_user
    ) -> None:
        owner = await make_user()
        methods = PaymentMethodService(db_session)
        method = await methods.add_method(
            owner.id,
            channel=PaymentChannel.MTN_MOMO,
            phone_number="0241234567",
            label=None,
            make_default=False,
        )

        with pytest.raises(NotFoundError):
            await methods.get_method((await make_user()).id, method.id)
        with pytest.raises(NotFoundError):
            await methods.delete_method((await make_user()).id, method.id)


class TestDriverViews:  # G30, G31
    async def test_assignments_carry_the_vehicle(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user)
        await fleet_service(db_session).assign_driver(
            scenario.owner_user_id, scenario.vehicle_id, scenario.driver_id
        )

        assignments = await driver_service(db_session).list_own_assignments(scenario.driver_user_id)

        [(assignment, vehicle)] = assignments
        assert assignment.vehicle_id == scenario.vehicle_id
        assert vehicle is not None
        assert vehicle.registration_number == scenario.registration_number

    async def test_receipts_split_each_booking_by_seat_and_channel(
        self, db_session: AsyncSession, make_user, require_redis: None
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        passenger = await make_user()
        bookings = BookingService(db_session)

        pair = await bookings.create_booking(
            passenger.id,
            BookingCreateRequest(
                trip_id=scenario.trip_id,
                passengers=[
                    PassengerInput(seat_id=scenario.seat_ids[0], full_name="Ama Owusu"),
                    PassengerInput(seat_id=scenario.seat_ids[1], full_name="Kofi Owusu"),
                ],
            ),
            idempotency_key=None,
        )
        # Mobile money failed first; the wallet then paid. Only the payment
        # that went through may count.
        db_session.add(
            Payment(
                user_id=passenger.id,
                booking_id=pair.id,
                purpose=PaymentPurpose.BOOKING_PAYMENT,
                channel=PaymentChannel.MTN_MOMO,
                status=PaymentStatus.FAILED,
                amount=pair.total_amount,
                currency="GHS",
                internal_reference=f"TEST-{uuid.uuid4().hex[:20]}",
            )
        )
        await _paid_with_wallet(db_session, passenger.id, pair)
        await book(db_session, (await make_user()).id, scenario, seat=2, confirm=False)  # unpaid

        receipts = await TripService(db_session).get_receipts(
            scenario.trip_id, scenario.driver_user_id
        )

        assert [r.seat_label for r in receipts.receipts] == ["A1", "A2"]
        assert sum(r.amount for r in receipts.receipts) == pair.fare_amount
        assert receipts.total_collected == pair.fare_amount
        assert receipts.fare_per_seat == Decimal("8.00")
        [wallet] = receipts.by_channel
        assert (wallet.channel, wallet.passengers, wallet.amount) == (
            PaymentChannel.WALLET,
            2,
            pair.fare_amount,
        )

    async def test_receipts_are_for_the_assigned_driver_only(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)

        with pytest.raises(ForbiddenError):
            await TripService(db_session).get_receipts(scenario.trip_id, (await make_user()).id)


class TestIncidents:  # G32
    async def test_new_types_and_severity_follows_the_type(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        safety = SafetyService(db_session)

        hazard = await safety.report_incident(
            scenario.trip_id,
            reported_by=scenario.driver_user_id,
            incident_type=IncidentType.ROAD_HAZARD,
            severity=None,
            description="Pothole at Legon junction",
            latitude=None,
            longitude=None,
        )
        unruly = await safety.report_incident(
            scenario.trip_id,
            reported_by=scenario.driver_user_id,
            incident_type=IncidentType.PASSENGER_ISSUE,
            severity=IncidentSeverity.HIGH,
            description="Refused to pay",
            latitude=None,
            longitude=None,
        )

        assert hazard.severity == IncidentSeverity.MEDIUM
        assert unruly.severity == IncidentSeverity.HIGH

    async def test_one_photo_replaced_on_reupload_by_the_reporter_only(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        safety = SafetyService(db_session)
        incident = await safety.report_incident(
            scenario.trip_id,
            reported_by=scenario.driver_user_id,
            incident_type=IncidentType.ACCIDENT,
            severity=None,
            description="Minor knock",
            latitude=None,
            longitude=None,
        )
        storage = SandboxStorageProvider()
        upload = {
            "filename": "scene.png",
            "content_type": "image/png",
            "data": PNG,
            "storage": storage,
            "scanner": NoOpMalwareScanner(),
        }

        first = (
            await safety.attach_incident_photo(
                incident.id, reported_by=scenario.driver_user_id, **upload
            )
        ).photo_storage_key
        second = (
            await safety.attach_incident_photo(
                incident.id, reported_by=scenario.driver_user_id, **upload
            )
        ).photo_storage_key

        assert incident.severity == IncidentSeverity.HIGH
        assert first is not None
        assert second is not None
        assert first != second
        assert SandboxStorageProvider.get_object(first) is None
        with pytest.raises(NotFoundError):
            await safety.attach_incident_photo(
                incident.id, reported_by=(await make_user()).id, **upload
            )
        with pytest.raises(FileValidationError):
            await safety.attach_incident_photo(
                incident.id,
                reported_by=scenario.driver_user_id,
                **{**upload, "content_type": "application/pdf"},
            )


class TestManifestDropOff:  # G33
    async def test_each_passenger_shows_where_they_get_off(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        await book(
            db_session, (await make_user()).id, scenario, seat=0, destination=scenario.stop_ids[1]
        )
        await book(db_session, (await make_user()).id, scenario, seat=1)

        manifest = await TripService(db_session).get_manifest(
            scenario.trip_id, scenario.driver_user_id
        )

        assert [entry.dropoff_stop_name for entry in manifest] == [
            scenario.stop_names[LEGON],
            scenario.stop_names[CIRCLE],
        ]
