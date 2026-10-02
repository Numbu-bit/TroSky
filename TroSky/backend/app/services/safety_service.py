"""Incident reporting and SOS distress alerts.

SOS notification to emergency contacts deliberately bypasses
``NotificationService``/``NotificationPreference`` entirely: emergency
contacts are not platform users (they have no preference row to check),
and a safety-critical alert must never be silenced by an opt-out that
exists for promotional/transactional messages, not this.
"""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import (
    FileValidationError,
    ForbiddenError,
    InvalidStateTransitionError,
    NotFoundError,
    ProviderError,
)
from app.core.logging import get_logger
from app.core.telemetry import SOS_EVENTS_TOTAL
from app.models.bookings import Booking, BookingStatus
from app.models.safety import (
    DEFAULT_SEVERITY,
    Incident,
    IncidentSeverity,
    IncidentStatus,
    IncidentType,
    SosAlert,
    SosAlertStatus,
)
from app.providers.sms.factory import get_sms_provider
from app.providers.storage.base import ObjectStorageProvider
from app.providers.storage.malware_scan import MalwareScanner
from app.repositories.driver_repository import DriverRepository
from app.repositories.profile_repository import EmergencyContactRepository
from app.repositories.safety_repository import IncidentRepository, SosAlertRepository
from app.repositories.trip_repository import TripRepository
from app.services.document_service import store_uploaded_document

logger = get_logger(__name__)

_PHOTO_TYPES = {"image/jpeg", "image/png"}

_ACTIVE_BOOKING_STATUSES = (
    BookingStatus.PENDING,
    BookingStatus.PAYMENT_PENDING,
    BookingStatus.CONFIRMED,
)


class SafetyService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self._session = session
        self._settings = settings or get_settings()
        self._incidents = IncidentRepository(session)
        self._sos = SosAlertRepository(session)
        self._trips = TripRepository(session)
        self._drivers = DriverRepository(session)
        self._contacts = EmergencyContactRepository(session)

    async def _assert_trip_participant(self, trip_id: uuid.UUID, user_id: uuid.UUID) -> None:
        driver = await self._drivers.get_by_user_id(user_id)
        if driver is not None:
            assignment = await self._trips.get_active_driver_assignment(trip_id)
            if assignment is not None and assignment.driver_id == driver.id:
                return
        result = await self._session.execute(
            select(Booking.id).where(
                Booking.trip_id == trip_id,
                Booking.passenger_id == user_id,
                Booking.status.in_(_ACTIVE_BOOKING_STATUSES),
            )
        )
        if result.scalar_one_or_none() is not None:
            return
        raise ForbiddenError("You are not a participant on this trip.")

    # ------------------------------------------------------------------
    # Incidents
    # ------------------------------------------------------------------
    async def report_incident(
        self,
        trip_id: uuid.UUID,
        *,
        reported_by: uuid.UUID,
        incident_type: IncidentType,
        severity: IncidentSeverity | None,
        description: str,
        latitude: float | None,
        longitude: float | None,
    ) -> Incident:
        trip = await self._trips.get_by_id(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        await self._assert_trip_participant(trip_id, reported_by)
        severity = severity or DEFAULT_SEVERITY[incident_type]

        incident = await self._incidents.create(
            trip_id=trip_id,
            reported_by=reported_by,
            incident_type=incident_type,
            severity=severity,
            description=description,
            latitude=latitude,
            longitude=longitude,
        )
        logger.warning(
            "incident_reported",
            incident_id=str(incident.id),
            trip_id=str(trip_id),
            severity=severity.value,
        )
        return incident

    async def attach_incident_photo(
        self,
        incident_id: uuid.UUID,
        *,
        reported_by: uuid.UUID,
        filename: str,
        content_type: str,
        data: bytes,
        storage: ObjectStorageProvider,
        scanner: MalwareScanner,
    ) -> Incident:
        """Attach the one photo an incident can carry, replacing (and
        deleting) an earlier one. Only whoever reported it may add it."""
        incident = await self.get_incident(incident_id, requesting_user_id=reported_by)
        if content_type not in _PHOTO_TYPES:
            raise FileValidationError(
                "Upload a JPEG or PNG image.", details={"allowed_types": sorted(_PHOTO_TYPES)}
            )
        limit = self._settings.INCIDENT_PHOTO_MAX_SIZE_BYTES
        if len(data) > limit:
            raise FileValidationError(
                "The photo is too large.", details={"max_bytes": limit, "actual_bytes": len(data)}
            )
        uploaded = await store_uploaded_document(
            storage=storage,
            scanner=scanner,
            settings=self._settings,
            key_prefix=f"incidents/{incident.id}",
            filename=filename,
            content_type=content_type,
            data=data,
        )
        previous = incident.photo_storage_key
        incident.photo_storage_key = uploaded.storage_key
        await self._session.flush()
        if previous and previous != uploaded.storage_key:
            try:
                await storage.delete_object(previous)
            except Exception:
                # Only costs storage: the old photo is no longer referenced.
                logger.warning("incident_previous_photo_not_deleted", incident_id=str(incident.id))
        return incident

    async def get_incident(
        self, incident_id: uuid.UUID, *, requesting_user_id: uuid.UUID, is_privileged: bool = False
    ) -> Incident:
        incident = await self._incidents.get_by_id(incident_id)
        if incident is None:
            raise NotFoundError("Incident not found.")
        if not is_privileged and incident.reported_by != requesting_user_id:
            raise NotFoundError("Incident not found.")
        return incident

    async def list_incidents(
        self, *, status: IncidentStatus | None, limit: int, offset: int
    ) -> tuple[list[Incident], int]:
        return await self._incidents.list_all(status=status, limit=limit, offset=offset)

    async def resolve_incident(
        self, incident_id: uuid.UUID, *, reviewer_id: uuid.UUID, notes: str | None
    ) -> Incident:
        incident = await self._incidents.get_for_update(incident_id)
        if incident is None:
            raise NotFoundError("Incident not found.")
        if incident.status in (IncidentStatus.RESOLVED, IncidentStatus.CLOSED):
            raise InvalidStateTransitionError(
                f"Cannot resolve an incident already in status '{incident.status.value}'."
            )
        await self._incidents.set_status(
            incident,
            new_status=IncidentStatus.RESOLVED,
            resolved_by=reviewer_id,
            resolution_notes=notes,
        )
        return incident

    # ------------------------------------------------------------------
    # SOS
    # ------------------------------------------------------------------
    async def trigger_sos(
        self,
        trip_id: uuid.UUID,
        *,
        triggered_by: uuid.UUID,
        latitude: float | None,
        longitude: float | None,
    ) -> SosAlert:
        trip = await self._trips.get_by_id(trip_id)
        if trip is None:
            raise NotFoundError("Trip not found.")
        await self._assert_trip_participant(trip_id, triggered_by)

        alert = await self._sos.create(
            trip_id=trip_id, triggered_by=triggered_by, latitude=latitude, longitude=longitude
        )
        SOS_EVENTS_TOTAL.labels(status=alert.status.value).inc()
        logger.warning("sos_triggered", alert_id=str(alert.id), trip_id=str(trip_id))
        await self._notify_emergency_contacts(triggered_by, latitude=latitude, longitude=longitude)
        return alert

    async def trigger_sos_without_trip(
        self, *, triggered_by: uuid.UUID, latitude: float | None, longitude: float | None
    ) -> SosAlert:
        """An emergency outside any trip: the Home screen's SOS button. Same
        alert and the same messages to emergency contacts; there is just no
        trip to attach it to, so the location is the only context."""
        alert = await self._sos.create(
            trip_id=None, triggered_by=triggered_by, latitude=latitude, longitude=longitude
        )
        SOS_EVENTS_TOTAL.labels(status=alert.status.value).inc()
        logger.warning("sos_triggered", alert_id=str(alert.id), trip_id=None)
        await self._notify_emergency_contacts(
            triggered_by, latitude=latitude, longitude=longitude, during_trip=False
        )
        return alert

    async def _notify_emergency_contacts(
        self,
        user_id: uuid.UUID,
        *,
        latitude: float | None,
        longitude: float | None,
        during_trip: bool = True,
    ) -> None:
        contacts = await self._contacts.list_for_user(user_id)
        if not contacts:
            logger.warning("sos_triggered_no_emergency_contacts", user_id=str(user_id))
            return
        location_text = (
            f" Last known location: {latitude}, {longitude}."
            if latitude is not None and longitude is not None
            else ""
        )
        context = " during a trip" if during_trip else ""
        message = (
            f"TroSky SOS Alert: your contact has triggered an emergency alert{context}."
            f"{location_text} Please check on them."
        )
        provider = get_sms_provider(self._settings)
        for contact in contacts:
            try:
                await provider.send_sms(contact.phone_number, message)
            except ProviderError:
                logger.error("sos_emergency_contact_sms_failed", contact_id=str(contact.id))

    async def get_sos_alert(
        self, alert_id: uuid.UUID, *, requesting_user_id: uuid.UUID, is_privileged: bool = False
    ) -> SosAlert:
        alert = await self._sos.get_by_id(alert_id)
        if alert is None:
            raise NotFoundError("SOS alert not found.")
        if not is_privileged and alert.triggered_by != requesting_user_id:
            raise NotFoundError("SOS alert not found.")
        return alert

    async def list_sos_alerts(
        self, *, status: SosAlertStatus | None, limit: int, offset: int
    ) -> tuple[list[SosAlert], int]:
        return await self._sos.list_all(status=status, limit=limit, offset=offset)

    async def acknowledge_sos(self, alert_id: uuid.UUID, *, reviewer_id: uuid.UUID) -> SosAlert:
        alert = await self._sos.get_for_update(alert_id)
        if alert is None:
            raise NotFoundError("SOS alert not found.")
        if alert.status != SosAlertStatus.ACTIVE:
            raise InvalidStateTransitionError(
                f"Cannot acknowledge an SOS alert in status '{alert.status.value}'."
            )
        await self._sos.acknowledge(alert, acknowledged_by=reviewer_id)
        SOS_EVENTS_TOTAL.labels(status=alert.status.value).inc()
        return alert

    async def resolve_sos(
        self,
        alert_id: uuid.UUID,
        *,
        reviewer_id: uuid.UUID,
        notes: str | None,
        false_alarm: bool = False,
    ) -> SosAlert:
        alert = await self._sos.get_for_update(alert_id)
        if alert is None:
            raise NotFoundError("SOS alert not found.")
        if alert.status not in (SosAlertStatus.ACTIVE, SosAlertStatus.ACKNOWLEDGED):
            raise InvalidStateTransitionError(
                f"Cannot resolve an SOS alert in status '{alert.status.value}'."
            )
        status = SosAlertStatus.FALSE_ALARM if false_alarm else SosAlertStatus.RESOLVED
        await self._sos.resolve(
            alert, resolved_by=reviewer_id, resolution_notes=notes, status=status
        )
        SOS_EVENTS_TOTAL.labels(status=alert.status.value).inc()
        return alert
