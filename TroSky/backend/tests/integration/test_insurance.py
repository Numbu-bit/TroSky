"""Drivers are warned once their insurance expires, and blocked after 30 days."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import DriverBlockedError, ForbiddenError
from app.models.drivers import (
    ApprovalStatus,
    DocumentStatus,
    DocumentType,
    Driver,
    DriverDocument,
    DriverStatusHistory,
)
from app.models.notifications import Notification
from app.models.trips import Trip, TripStatus
from app.models.vehicles import VehicleDocument
from app.repositories.driver_repository import DriverRepository
from app.repositories.trip_repository import TripRepository
from app.services.insurance_service import BLOCK_REASON, InsuranceOutcome, InsuranceService
from app.services.trip_service import TripService
from tests.integration.scenarios import TripScenario, approved_driver, build_trip_scenario
from tests.integration.scenarios import fleet_service as make_fleet_service

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

EXPIRED_ON = date(2026, 10, 1)


def _day(days_after_expiry: int) -> date:
    return EXPIRED_ON + timedelta(days=days_after_expiry)


async def _give_insurance(
    session: AsyncSession,
    driver: Driver,
    *,
    expires: date | None = EXPIRED_ON,
    status: DocumentStatus = DocumentStatus.APPROVED,
) -> DriverDocument:
    document = DriverDocument(
        driver_id=driver.id,
        document_type=DocumentType.VEHICLE_INSURANCE,
        storage_key="drivers/insurance.pdf",
        original_filename="insurance.pdf",
        mime_type="application/pdf",
        file_size_bytes=100,
        status=status,
        expiry_date=expires,
    )
    session.add(document)
    await session.flush()
    return document


async def _notifications(session: AsyncSession, user_id) -> list[Notification]:
    result = await session.execute(
        select(Notification)
        .where(Notification.user_id == user_id)
        .order_by(Notification.created_at)
    )
    return list(result.scalars().all())


async def _warnings(session: AsyncSession, user_id) -> list[int]:
    return [
        note.data["day"]
        for note in await _notifications(session, user_id)
        if note.data.get("action") == "insurance_warning"
    ]


async def _trip(session: AsyncSession, make_user) -> TripScenario:
    return await build_trip_scenario(
        session, make_user, departure=datetime.now(UTC) + timedelta(hours=2)
    )


class TestWhoIsChecked:
    async def test_a_driver_with_no_confirmed_date_is_left_alone(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user, driver = await approved_driver(db_session, make_user)
        outcome = await InsuranceService(db_session).check_driver(driver.id, today=_day(40))
        assert outcome == InsuranceOutcome.NOTHING
        assert driver.status == ApprovalStatus.APPROVED
        assert await _notifications(db_session, user.id) == []

    async def test_a_date_no_admin_has_confirmed_does_not_count(
        self, db_session: AsyncSession, make_user
    ) -> None:
        _, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver, status=DocumentStatus.PENDING)
        outcome = await InsuranceService(db_session).check_driver(driver.id, today=_day(40))
        assert outcome == InsuranceOutcome.NOTHING
        assert driver.status == ApprovalStatus.APPROVED

    async def test_insurance_is_valid_on_the_day_it_expires(
        self, db_session: AsyncSession, make_user
    ) -> None:
        _, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        outcome = await InsuranceService(db_session).check_driver(driver.id, today=_day(0))
        assert outcome == InsuranceOutcome.NOTHING

    async def test_the_latest_date_counts(self, db_session: AsyncSession, make_user) -> None:
        _, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        await _give_insurance(db_session, driver, expires=_day(365))
        outcome = await InsuranceService(db_session).check_driver(driver.id, today=_day(40))
        assert outcome == InsuranceOutcome.NOTHING

    async def test_the_insurance_of_a_vehicle_they_are_assigned_to_counts(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _trip(db_session, make_user)
        await make_fleet_service(db_session).assign_driver(
            scenario.owner_user_id, scenario.vehicle_id, scenario.driver_id
        )
        db_session.add(
            VehicleDocument(
                vehicle_id=scenario.vehicle_id,
                document_type=DocumentType.VEHICLE_INSURANCE,
                storage_key="vehicles/insurance.pdf",
                original_filename="insurance.pdf",
                mime_type="application/pdf",
                file_size_bytes=100,
                status=DocumentStatus.APPROVED,
                expiry_date=EXPIRED_ON,
            )
        )
        await db_session.flush()
        outcome = await InsuranceService(db_session).check_driver(scenario.driver_id, today=_day(1))
        assert outcome == InsuranceOutcome.WARNED
        assert await _warnings(db_session, scenario.owner_user_id) == [1]


class TestWarnings:
    async def test_the_first_day_after_it_expires_brings_a_warning(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        outcome = await InsuranceService(db_session).check_driver(driver.id, today=_day(1))
        assert outcome == InsuranceOutcome.WARNED
        note = (await _notifications(db_session, user.id))[-1]
        assert note.title == "Renew your insurance"
        assert "01 Oct 2026" in note.body
        assert "31 Oct 2026" in note.body
        assert note.data["renew_by"] == "2026-10-31"

    async def test_running_again_the_same_day_warns_nobody_twice(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        service = InsuranceService(db_session)
        await service.check_driver(driver.id, today=_day(1))
        assert await service.check_driver(driver.id, today=_day(1)) == InsuranceOutcome.NOTHING
        assert await _warnings(db_session, user.id) == [1]

    async def test_warnings_come_on_the_days_set(self, db_session: AsyncSession, make_user) -> None:
        user, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        service = InsuranceService(db_session)
        for day in range(1, 31):
            await service.check_driver(driver.id, today=_day(day))
        assert await _warnings(db_session, user.id) == [1, 7, 14, 21, 25, 28, 29, 30]

    async def test_a_worker_that_slept_sends_only_the_latest_warning(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        await InsuranceService(db_session).check_driver(driver.id, today=_day(20))
        assert await _warnings(db_session, user.id) == [14]

    async def test_a_new_expiry_date_starts_the_warnings_again(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        service = InsuranceService(db_session)
        await service.check_driver(driver.id, today=_day(1))
        await _give_insurance(db_session, driver, expires=_day(100))
        await service.check_driver(driver.id, today=_day(101))
        assert await _warnings(db_session, user.id) == [1, 1]


class TestBlocking:
    async def test_day_30_is_the_last_day_to_renew(
        self, db_session: AsyncSession, make_user
    ) -> None:
        _, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        outcome = await InsuranceService(db_session).check_driver(driver.id, today=_day(30))
        assert outcome == InsuranceOutcome.WARNED
        assert driver.status == ApprovalStatus.APPROVED

    async def test_day_31_blocks_them_and_says_why(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        outcome = await InsuranceService(db_session).check_driver(driver.id, today=_day(31))
        assert outcome == InsuranceOutcome.BLOCKED
        assert driver.status == ApprovalStatus.SUSPENDED
        history = await db_session.scalar(
            select(DriverStatusHistory.reason).where(
                DriverStatusHistory.driver_id == driver.id,
                DriverStatusHistory.to_status == ApprovalStatus.SUSPENDED,
            )
        )
        assert history is not None
        assert history.startswith(BLOCK_REASON)
        notes = await _notifications(db_session, user.id)
        assert notes[-1].title == "Your driver account is blocked"

    async def test_a_blocked_driver_is_not_blocked_or_told_again(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        service = InsuranceService(db_session)
        await service.check_driver(driver.id, today=_day(31))
        before = len(await _notifications(db_session, user.id))
        assert await service.check_driver(driver.id, today=_day(32)) == InsuranceOutcome.NOTHING
        assert len(await _notifications(db_session, user.id)) == before

    async def test_they_come_off_a_trip_that_has_not_begun(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _trip(db_session, make_user)
        driver = await DriverRepository(db_session).get_by_id(scenario.driver_id)
        assert driver is not None
        await _give_insurance(db_session, driver)
        await InsuranceService(db_session).check_driver(driver.id, today=_day(31))
        trips = TripRepository(db_session)
        assert await trips.get_active_driver_assignment(scenario.trip_id) is None

    @pytest.mark.parametrize("status", [TripStatus.BOARDING, TripStatus.IN_PROGRESS])
    async def test_a_trip_with_passengers_on_board_stays_with_them(
        self, db_session: AsyncSession, make_user, status: TripStatus
    ) -> None:
        scenario = await _trip(db_session, make_user)
        trip = await db_session.get(Trip, scenario.trip_id)
        assert trip is not None
        trip.status = status
        driver = await DriverRepository(db_session).get_by_id(scenario.driver_id)
        assert driver is not None
        await _give_insurance(db_session, driver)
        await InsuranceService(db_session).check_driver(driver.id, today=_day(31))
        trips = TripRepository(db_session)
        assert await trips.get_active_driver_assignment(scenario.trip_id) is not None

    async def test_a_blocked_driver_cannot_accept_a_trip(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _trip(db_session, make_user)
        driver = await DriverRepository(db_session).get_by_id(scenario.driver_id)
        assert driver is not None
        await DriverRepository(db_session).set_status(
            driver, new_status=ApprovalStatus.SUSPENDED, changed_by=None, reason=BLOCK_REASON
        )
        with pytest.raises(DriverBlockedError):
            await TripService(db_session).respond(
                scenario.trip_id,
                actor_id=scenario.driver_user_id,
                accept=True,
                reason=None,
                as_admin=False,
            )

    async def test_a_blocked_driver_cannot_start_a_scheduled_trip(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _trip(db_session, make_user)
        driver = await DriverRepository(db_session).get_by_id(scenario.driver_id)
        assert driver is not None
        await DriverRepository(db_session).set_status(
            driver, new_status=ApprovalStatus.SUSPENDED, changed_by=None, reason=BLOCK_REASON
        )
        with pytest.raises(DriverBlockedError):
            await TripService(db_session).start_trip(scenario.trip_id, scenario.driver_user_id)

    async def test_a_blocked_driver_cannot_be_given_a_trip(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _trip(db_session, make_user)
        _, driver = await approved_driver(db_session, make_user)
        await DriverRepository(db_session).set_status(
            driver, new_status=ApprovalStatus.SUSPENDED, changed_by=None, reason=BLOCK_REASON
        )
        with pytest.raises(ForbiddenError):
            await TripService(db_session).assign_driver(
                scenario.trip_id, driver.id, assigned_by=None
            )


class TestRenewal:
    async def test_a_later_confirmed_date_unblocks_them(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        service = InsuranceService(db_session)
        await service.check_driver(driver.id, today=_day(31))
        await _give_insurance(db_session, driver, expires=_day(400))
        assert await service.check_driver(driver.id, today=_day(32)) == InsuranceOutcome.UNBLOCKED
        assert driver.status == ApprovalStatus.APPROVED
        notes = await _notifications(db_session, user.id)
        assert notes[-1].title == "Your driver account is unblocked"

    async def test_a_date_still_in_the_past_does_not(
        self, db_session: AsyncSession, make_user
    ) -> None:
        _, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        service = InsuranceService(db_session)
        await service.check_driver(driver.id, today=_day(31))
        await _give_insurance(db_session, driver, expires=_day(5))
        assert await service.check_driver(driver.id, today=_day(32)) == InsuranceOutcome.NOTHING
        assert driver.status == ApprovalStatus.SUSPENDED

    async def test_someone_suspended_for_another_reason_stays_suspended(
        self, db_session: AsyncSession, make_user
    ) -> None:
        _, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver, expires=_day(400))
        await DriverRepository(db_session).set_status(
            driver, new_status=ApprovalStatus.SUSPENDED, changed_by=None, reason="Complaints"
        )
        outcome = await InsuranceService(db_session).check_driver(driver.id, today=_day(32))
        assert outcome == InsuranceOutcome.NOTHING
        assert driver.status == ApprovalStatus.SUSPENDED


class TestStanding:
    async def test_with_no_confirmed_date(self, db_session: AsyncSession, make_user) -> None:
        _, driver = await approved_driver(db_session, make_user)
        standing = await InsuranceService(db_session).standing(driver, today=_day(1))
        assert standing.status == "unknown"

    async def test_in_date(self, db_session: AsyncSession, make_user) -> None:
        _, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        standing = await InsuranceService(db_session).standing(driver, today=_day(0))
        assert standing.status == "valid"
        assert standing.expiry_date == EXPIRED_ON
        assert standing.renew_by is None

    async def test_expired_says_when_to_renew_by(self, db_session: AsyncSession, make_user) -> None:
        _, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        standing = await InsuranceService(db_session).standing(driver, today=_day(3))
        assert standing.status == "expired"
        assert standing.renew_by == _day(30)

    async def test_blocked(self, db_session: AsyncSession, make_user) -> None:
        _, driver = await approved_driver(db_session, make_user)
        await _give_insurance(db_session, driver)
        service = InsuranceService(db_session)
        await service.check_driver(driver.id, today=_day(31))
        assert (await service.standing(driver, today=_day(31))).status == "blocked"
