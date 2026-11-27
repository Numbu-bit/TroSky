"""Integration tests for SafetyService: incident reporting and SOS alerts,
including the trip-participant guard and emergency-contact SMS fan-out
(which always bypasses notification preferences) — against a real
Postgres."""

from __future__ import annotations

import uuid
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError, InvalidStateTransitionError, NotFoundError
from app.models.safety import IncidentSeverity, IncidentStatus, IncidentType, SosAlertStatus
from app.providers.sms.sandbox import SandboxSmsProvider
from app.repositories.profile_repository import EmergencyContactRepository
from app.services.booking_service import BookingService
from app.services.safety_service import MARKED_SAFE_NOTE, SafetyService
from tests.integration.test_tracking_service import _make_in_progress_trip

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


@pytest.fixture(autouse=True)
def _clear_sandbox():
    SandboxSmsProvider.clear()
    yield
    SandboxSmsProvider.clear()


class TestIncidentReporting:
    async def test_assigned_driver_can_report_incident(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, driver_user_id = await _make_in_progress_trip(db_session, make_user)
        service = SafetyService(db_session)
        incident = await service.report_incident(
            trip_id,
            reported_by=driver_user_id,
            incident_type=IncidentType.BREAKDOWN,
            severity=IncidentSeverity.MEDIUM,
            description="Flat tire",
            latitude=5.6,
            longitude=-0.19,
        )
        assert incident.status == IncidentStatus.REPORTED

    async def test_unrelated_user_cannot_report_incident(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, _ = await _make_in_progress_trip(db_session, make_user)
        service = SafetyService(db_session)
        with pytest.raises(ForbiddenError):
            await service.report_incident(
                trip_id,
                reported_by=uuid.uuid4(),
                incident_type=IncidentType.OTHER,
                severity=IncidentSeverity.LOW,
                description="x",
                latitude=None,
                longitude=None,
            )

    async def test_resolve_incident(self, db_session: AsyncSession, make_user) -> None:
        trip_id, driver_user_id = await _make_in_progress_trip(db_session, make_user)
        service = SafetyService(db_session)
        incident = await service.report_incident(
            trip_id,
            reported_by=driver_user_id,
            incident_type=IncidentType.DELAY,
            severity=IncidentSeverity.LOW,
            description="Traffic",
            latitude=None,
            longitude=None,
        )
        resolved = await service.resolve_incident(
            incident.id, reviewer_id=(await make_user()).id, notes="Noted"
        )
        assert resolved.status == IncidentStatus.RESOLVED


class TestSosAlerts:
    async def test_passenger_with_active_booking_can_trigger_sos(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, _ = await _make_in_progress_trip(db_session, make_user)
        passenger_id = (await make_user()).id
        await BookingService(db_session)._bookings.create_booking(
            passenger_id=passenger_id,
            trip_id=trip_id,
            passenger_count=1,
            origin_stop_id=None,
            destination_stop_id=None,
            fare_amount=Decimal("25.00"),
            platform_fee=Decimal("0.00"),
            total_amount=Decimal("25.00"),
            expires_at=None,
            idempotency_key=None,
            idempotency_request_hash=None,
        )
        await EmergencyContactRepository(db_session).create(
            user_id=passenger_id,
            name="Mom",
            phone_number="0244000099",
            relationship_label="Mother",
            is_primary=True,
        )

        service = SafetyService(db_session)
        alert = await service.trigger_sos(
            trip_id, triggered_by=passenger_id, latitude=5.6, longitude=-0.19
        )
        assert alert.status == SosAlertStatus.ACTIVE

        messages = SandboxSmsProvider.get_sent_messages("0244000099")
        assert len(messages) == 1
        assert "SOS" in messages[0]

    async def test_unrelated_user_cannot_trigger_sos(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, _ = await _make_in_progress_trip(db_session, make_user)
        service = SafetyService(db_session)
        with pytest.raises(ForbiddenError):
            await service.trigger_sos(
                trip_id, triggered_by=uuid.uuid4(), latitude=None, longitude=None
            )

    async def test_acknowledge_then_resolve(self, db_session: AsyncSession, make_user) -> None:
        trip_id, driver_user_id = await _make_in_progress_trip(db_session, make_user)
        service = SafetyService(db_session)
        alert = await service.trigger_sos(
            trip_id, triggered_by=driver_user_id, latitude=None, longitude=None
        )
        reviewer_id = (await make_user()).id
        acknowledged = await service.acknowledge_sos(alert.id, reviewer_id=reviewer_id)
        assert acknowledged.status == SosAlertStatus.ACKNOWLEDGED

        resolved = await service.resolve_sos(
            alert.id, reviewer_id=reviewer_id, notes="False alert", false_alarm=True
        )
        assert resolved.status == SosAlertStatus.FALSE_ALARM

    async def test_cannot_acknowledge_a_resolved_alert(
        self, db_session: AsyncSession, make_user
    ) -> None:
        trip_id, driver_user_id = await _make_in_progress_trip(db_session, make_user)
        service = SafetyService(db_session)
        alert = await service.trigger_sos(
            trip_id, triggered_by=driver_user_id, latitude=None, longitude=None
        )
        reviewer_id = (await make_user()).id
        await service.resolve_sos(alert.id, reviewer_id=reviewer_id, notes=None)
        with pytest.raises(InvalidStateTransitionError):
            await service.acknowledge_sos(alert.id, reviewer_id=reviewer_id)


class TestMarkedSafe:  # G-sos-marked-safe
    async def _raise(self, db_session: AsyncSession, make_user, *, contact: str | None = None):
        user_id = (await make_user()).id
        if contact is not None:
            await EmergencyContactRepository(db_session).create(
                user_id=user_id,
                name="Mom",
                phone_number=contact,
                relationship_label="Mother",
                is_primary=True,
            )
        service = SafetyService(db_session)
        alert = await service.trigger_sos_without_trip(
            triggered_by=user_id, latitude=5.6, longitude=-0.19
        )
        return service, alert, user_id

    async def test_the_sender_marks_themselves_safe(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service, alert, user_id = await self._raise(db_session, make_user, contact="0244000098")

        safe = await service.mark_safe(alert.id, user_id=user_id)

        assert safe.status == SosAlertStatus.RESOLVED
        assert safe.resolved_by == user_id
        assert safe.resolved_at is not None
        assert safe.resolution_notes == MARKED_SAFE_NOTE
        messages = SandboxSmsProvider.get_sent_messages("0244000098")
        assert len(messages) == 2  # the alert, then the all-clear
        assert "safe now" in messages[1]

    async def test_an_acknowledged_alert_can_be_marked_safe(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service, alert, user_id = await self._raise(db_session, make_user)
        await service.acknowledge_sos(alert.id, reviewer_id=(await make_user()).id)

        safe = await service.mark_safe(alert.id, user_id=user_id)

        assert safe.status == SosAlertStatus.RESOLVED

    async def test_nobody_else_can_mark_it_safe(self, db_session: AsyncSession, make_user) -> None:
        service, alert, _ = await self._raise(db_session, make_user)

        with pytest.raises(NotFoundError):
            await service.mark_safe(alert.id, user_id=(await make_user()).id)
        with pytest.raises(NotFoundError):
            await service.mark_safe(uuid.uuid4(), user_id=alert.triggered_by)
        assert (
            await service.get_sos_alert(alert.id, requesting_user_id=alert.triggered_by)
        ).status == (SosAlertStatus.ACTIVE)

    async def test_an_alert_already_closed_stays_as_it_is(
        self, db_session: AsyncSession, make_user
    ) -> None:
        service, alert, user_id = await self._raise(db_session, make_user, contact="0244000097")
        reviewer_id = (await make_user()).id
        await service.resolve_sos(
            alert.id, reviewer_id=reviewer_id, notes="Called them", false_alarm=True
        )

        again = await service.mark_safe(alert.id, user_id=user_id)

        assert again.status == SosAlertStatus.FALSE_ALARM
        assert again.resolved_by == reviewer_id
        assert again.resolution_notes == "Called them"
        assert len(SandboxSmsProvider.get_sent_messages("0244000097")) == 1  # the alert only
