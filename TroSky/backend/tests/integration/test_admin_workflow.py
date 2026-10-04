"""The admin dashboard's step 4 against a real database: the complaint
workflow and its figures, SOS escalations and details, the alerts feed,
global search and trip replay."""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

import pytest
from scripts.seed_reference_data import (
    ensure_admin_has_all_permissions,
    ensure_permissions,
    ensure_roles,
)
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import (
    ForbiddenError,
    InvalidStateTransitionError,
    NotFoundError,
    ValidationAppError,
)
from app.core.permissions import Permission, Principal
from app.models.drivers import ApprovalStatus, DocumentStatus, DocumentType, DriverStatusHistory
from app.models.feedback import (
    Complaint,
    ComplaintCategory,
    ComplaintNoteKind,
    ComplaintPriority,
    ComplaintStatus,
)
from app.models.identity import User, UserRole
from app.models.notifications import Notification
from app.models.payments import Payment, PaymentPurpose, PaymentStatus
from app.models.routes import Stop
from app.models.safety import EscalationContactType, SosAlert, SosAlertStatus
from app.models.tracking import TripLocation
from app.models.trips import Trip, TripStatus
from app.models.vehicles import VehicleDocument
from app.providers.payments.base import PaymentChannel
from app.repositories.admin_complaints_repository import (
    AdminComplaintsRepository,
    ComplaintFilters,
)
from app.schemas.driver import DriverRegisterRequest
from app.services.admin_analytics_service import AdminAnalyticsService, Period
from app.services.admin_ops_service import AdminOpsService
from app.services.complaint_service import ComplaintService
from app.services.safety_service import SafetyService
from app.utilities.geo import latlng_to_wkt
from tests.integration.scenarios import (
    TripScenario,
    book,
    build_trip_scenario,
    driver_service,
    fleet_service,
)

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

SLA = {"low": 72, "medium": 48, "high": 24, "urgent": 4}


def _announced(session: AsyncSession) -> list[str]:
    return [event["type"] for event in session.info.get("trosky.admin_events", [])]


def _principal(*permissions: Permission) -> Principal:
    return Principal(
        user_id=uuid.uuid4(),
        session_id=uuid.uuid4(),
        roles=frozenset({"admin"}),
        permissions=frozenset(permission.value for permission in permissions),
    )


async def _admin(session: AsyncSession, make_user) -> User:
    """A user holding the admin role, which holds every permission."""
    roles = await ensure_roles(session)
    await ensure_admin_has_all_permissions(
        session, roles["admin"], await ensure_permissions(session)
    )
    user = await make_user()
    session.add(UserRole(user_id=user.id, role_id=roles["admin"].id))
    await session.flush()
    return user


async def _complaint(
    session: AsyncSession,
    filed_by: uuid.UUID,
    *,
    category: ComplaintCategory = ComplaintCategory.OTHER,
    trip_id: uuid.UUID | None = None,
    hours_ago: float = 0,
) -> Complaint:
    complaint = await ComplaintService(session).file_complaint(
        filed_by,
        booking_id=None,
        trip_id=trip_id,
        category=category,
        subject="Bus was late",
        description="Waited forty minutes at Legon.",
    )
    if hours_ago:
        complaint.created_at = datetime.now(UTC) - timedelta(hours=hours_ago)
        await session.flush()
    return complaint


async def _scenario(session: AsyncSession, make_user, *, minutes: int = 30) -> TripScenario:
    return await build_trip_scenario(
        session, make_user, departure=datetime.now(UTC) + timedelta(minutes=minutes)
    )


async def _sos(session: AsyncSession, make_user) -> tuple[SosAlert, TripScenario, User]:
    scenario = await _scenario(session, make_user)
    passenger = await make_user()
    await book(session, passenger.id, scenario, seat=0)
    alert = await SafetyService(session).trigger_sos(
        scenario.trip_id, triggered_by=passenger.id, latitude=5.65, longitude=-0.18
    )
    return alert, scenario, passenger


# --------------------------------------------------------------- complaints
class TestComplaintWorkflow:
    async def test_safety_complaints_start_high(self, db_session: AsyncSession, make_user) -> None:
        filer = (await make_user()).id

        safety = await _complaint(db_session, filer, category=ComplaintCategory.SAFETY)
        other = await _complaint(db_session, filer)

        assert (safety.priority, other.priority) == (
            ComplaintPriority.HIGH,
            ComplaintPriority.MEDIUM,
        )
        assert _announced(db_session).count("complaint.created") == 2

    async def test_assign_review_and_unassign(self, db_session: AsyncSession, make_user) -> None:
        handler = await _admin(db_session, make_user)
        complaint = await _complaint(db_session, (await make_user()).id)
        complaints = ComplaintService(db_session)

        await complaints.update(
            complaint.id,
            assign=True,
            assigned_to=handler.id,
            priority=ComplaintPriority.URGENT,
            in_review=True,
        )
        assigned = (complaint.assigned_to, complaint.priority, complaint.status)
        responded = complaint.first_response_at
        await complaints.update(complaint.id, assign=True, assigned_to=None)

        assert assigned == (handler.id, ComplaintPriority.URGENT, ComplaintStatus.IN_REVIEW)
        assert responded is not None
        assert (complaint.assigned_to, complaint.assigned_at) == (None, None)
        assert complaint.priority == ComplaintPriority.URGENT  # left as it was
        assert _announced(db_session)[-1] == "complaint.updated"

    async def test_only_someone_who_handles_complaints_is_assigned(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger = await make_user()
        complaint = await _complaint(db_session, passenger.id)

        with pytest.raises(ValidationAppError):
            await ComplaintService(db_session).update(
                complaint.id, assign=True, assigned_to=passenger.id
            )

    async def test_a_decided_complaint_cannot_change(
        self, db_session: AsyncSession, make_user
    ) -> None:
        complaint = await _complaint(db_session, (await make_user()).id)
        complaints = ComplaintService(db_session)
        await complaints.resolve(complaint.id, reviewer_id=(await make_user()).id, notes="Refunded")

        with pytest.raises(InvalidStateTransitionError):
            await complaints.update(complaint.id, priority=ComplaintPriority.LOW)
        assert complaint.first_response_at == complaint.resolved_at

    async def test_a_message_reaches_the_passenger_and_a_note_does_not(
        self, db_session: AsyncSession, make_user
    ) -> None:
        passenger, agent = await make_user(), await make_user()
        complaint = await _complaint(db_session, passenger.id)
        complaints = ComplaintService(db_session)

        await complaints.add_note(
            complaint.id, author_id=agent.id, kind=ComplaintNoteKind.INTERNAL, body="Check GPS."
        )
        responded_after_note = complaint.first_response_at
        message = await complaints.add_note(
            complaint.id,
            author_id=agent.id,
            kind=ComplaintNoteKind.MESSAGE,
            body="We are sorry about the wait. " * 20,
        )
        seen = await complaints.list_messages(complaint.id, requesting_user_id=passenger.id)
        notification = await db_session.scalar(
            select(Notification).where(Notification.user_id == passenger.id)
        )

        assert responded_after_note is None
        assert complaint.first_response_at is not None
        assert [m.id for m in seen] == [message.id]
        assert notification is not None
        assert notification.data["complaint_id"] == str(complaint.id)
        assert len(notification.body) == 200
        assert notification.body.endswith("…")
        with pytest.raises(NotFoundError):
            await complaints.list_messages(complaint.id, requesting_user_id=agent.id)

    async def test_due_times_follow_priority_and_the_setting(
        self, db_session: AsyncSession, make_user
    ) -> None:
        handler, filer = await _admin(db_session, make_user), (await make_user()).id
        high = await _complaint(db_session, filer, category=ComplaintCategory.SAFETY, hours_ago=30)
        medium = await _complaint(db_session, filer, hours_ago=30)
        decided = await _complaint(
            db_session, filer, category=ComplaintCategory.SAFETY, hours_ago=30
        )
        decided.status = ComplaintStatus.DISMISSED
        for complaint in (high, medium, decided):
            complaint.assigned_to = handler.id  # keeps this test's complaints apart
        await db_session.flush()
        complaints = AdminComplaintsRepository(db_session)
        now = datetime.now(UTC)

        async def overdue(sla: dict[str, int]) -> set[uuid.UUID]:
            rows, _ = await complaints.list_complaints(
                ComplaintFilters(assigned_to=handler.id, overdue=True),
                sla_hours=sla,
                now=now,
                sort="due_at",
                descending=False,
                limit=10,
                offset=0,
            )
            return {row.complaint.id for row in rows}

        assert await overdue(SLA) == {high.id}  # 24 h for high, 48 h for medium
        assert await overdue({**SLA, "medium": 12}) == {high.id, medium.id}
        row = await complaints.get(medium.id, sla_hours=SLA)
        assert row is not None
        assert row.due_at == medium.created_at + timedelta(hours=48)


class TestComplaintStats:
    async def test_the_figures_for_a_city(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user, minutes=-8 * 60)
        city = f"Testville {secrets.token_hex(3)}"
        await db_session.execute(
            update(Stop).where(Stop.id == scenario.stop_ids[0]).values(city=city)
        )
        await db_session.execute(
            update(Trip).where(Trip.id == scenario.trip_id).values(status=TripStatus.COMPLETED)
        )
        filer = (await make_user()).id
        answered = await _complaint(
            db_session, filer, trip_id=scenario.trip_id, category=ComplaintCategory.DRIVER_CONDUCT
        )
        decided = await _complaint(db_session, filer, trip_id=scenario.trip_id)
        filed_at = datetime.now(UTC) - timedelta(hours=6)
        answered.created_at = decided.created_at = filed_at
        answered.status = ComplaintStatus.IN_REVIEW
        answered.first_response_at = filed_at + timedelta(hours=2)
        decided.status = ComplaintStatus.RESOLVED
        decided.resolved_at = decided.first_response_at = filed_at + timedelta(hours=5)
        await db_session.flush()
        today = datetime.now(UTC).date()

        stats = await AdminAnalyticsService(db_session).complaints(
            Period(today - timedelta(days=1), today), city, sla_hours=SLA
        )

        assert stats.filed.value == 2
        assert stats.per_1000_trips.value == Decimal("2000.00")  # 2 complaints, 1 trip
        assert stats.avg_first_response_hours.value == Decimal("3.5")  # 2 h and 5 h
        assert stats.avg_resolution_hours.value == Decimal("5.0")
        assert stats.by_category[ComplaintCategory.DRIVER_CONDUCT].value == 1
        assert stats.by_category[ComplaintCategory.OTHER].value == 1
        medium = next(c for c in stats.open_now if c.priority == ComplaintPriority.MEDIUM)
        assert (medium.open, medium.unassigned, medium.overdue) == (1, 1, 0)


# ---------------------------------------------------------------------- SOS
class TestSosEscalation:
    async def test_calling_for_help_picks_the_alert_up(
        self, db_session: AsyncSession, make_user
    ) -> None:
        alert, _, _ = await _sos(db_session, make_user)
        admin = await make_user()

        escalation = await SafetyService(db_session).escalate_sos(
            alert.id,
            logged_by=admin.id,
            contact_type=EscalationContactType.POLICE,
            contact_name="Legon Police",
            phone_number="191",
            contacted_at=None,
            notes="A patrol is on the way.",
        )

        assert (alert.status, alert.acknowledged_by) == (SosAlertStatus.ACKNOWLEDGED, admin.id)
        assert escalation.contacted_at <= datetime.now(UTC)
        events = _announced(db_session)
        assert "sos.created" in events
        assert events[-1] == "sos.updated"

    async def test_later_escalations_keep_the_status(
        self, db_session: AsyncSession, make_user
    ) -> None:
        alert, _, _ = await _sos(db_session, make_user)
        admin = (await make_user()).id
        safety = SafetyService(db_session)
        await safety.acknowledge_sos(alert.id, reviewer_id=admin)
        for contact in (EscalationContactType.AMBULANCE, EscalationContactType.FLEET_OWNER):
            await safety.escalate_sos(
                alert.id,
                logged_by=admin,
                contact_type=contact,
                contact_name=None,
                phone_number=None,
                contacted_at=None,
                notes=None,
            )

        escalations = await safety.list_escalations(alert.id)

        assert alert.status == SosAlertStatus.ACKNOWLEDGED
        assert [e.contact_type for e in escalations] == [
            EscalationContactType.AMBULANCE,
            EscalationContactType.FLEET_OWNER,
        ]

    @pytest.mark.parametrize("offset", [timedelta(hours=1), timedelta(hours=-1)])
    async def test_the_contact_time_must_be_plausible(
        self, db_session: AsyncSession, make_user, offset: timedelta
    ) -> None:
        alert, _, _ = await _sos(db_session, make_user)
        moment = (datetime.now(UTC) if offset > timedelta(0) else alert.created_at) + offset

        with pytest.raises(ValidationAppError):
            await SafetyService(db_session).escalate_sos(
                alert.id,
                logged_by=(await make_user()).id,
                contact_type=EscalationContactType.POLICE,
                contact_name=None,
                phone_number=None,
                contacted_at=moment,
                notes=None,
            )

    async def test_the_details_to_act_on(self, db_session: AsyncSession, make_user) -> None:
        alert, scenario, passenger = await _sos(db_session, make_user)
        db_session.add(
            TripLocation(
                trip_id=scenario.trip_id,
                location=latlng_to_wkt(5.66, -0.19),
                speed_kmh=Decimal("32.5"),
                recorded_at=datetime.now(UTC),
            )
        )
        await SafetyService(db_session).escalate_sos(
            alert.id,
            logged_by=(await make_user()).id,
            contact_type=EscalationContactType.FLEET_OWNER,
            contact_name=None,
            phone_number=None,
            contacted_at=None,
            notes=None,
        )

        detail = await AdminOpsService(db_session).sos_detail(alert.id)

        assert detail.latitude is not None
        assert detail.longitude is not None
        assert (round(detail.latitude, 4), round(detail.longitude, 4)) == (5.65, -0.18)
        assert detail.triggered_by_phone == passenger.phone_number
        assert detail.trip is not None
        assert detail.trip.summary.vehicle_registration_number == scenario.registration_number
        assert detail.trip.driver_phone is not None
        assert detail.trip.fleet_owner_phone is not None
        assert detail.trip.last_position is not None
        assert detail.trip.last_position.speed_kmh == Decimal("32.50")
        assert [e.contact_type for e, _ in detail.escalations] == [
            EscalationContactType.FLEET_OWNER
        ]
        with pytest.raises(NotFoundError):
            await AdminOpsService(db_session).sos_detail(uuid.uuid4())


# ------------------------------------------------------------------- alerts
async def _approved_document(
    session: AsyncSession,
    vehicle_id: uuid.UUID,
    *,
    expires: date,
    document_type: DocumentType = DocumentType.VEHICLE_INSURANCE,
) -> None:
    session.add(
        VehicleDocument(
            vehicle_id=vehicle_id,
            document_type=document_type,
            storage_key=f"vehicles/{vehicle_id}/{uuid.uuid4()}",
            original_filename="insurance.pdf",
            mime_type="application/pdf",
            file_size_bytes=10,
            status=DocumentStatus.APPROVED,
            expiry_date=expires,
        )
    )
    await session.flush()


class TestAlerts:
    async def test_everything_waiting_most_severe_first(
        self, db_session: AsyncSession, make_user
    ) -> None:
        alert, scenario, _ = await _sos(db_session, make_user)
        late = await _complaint(
            db_session, (await make_user()).id, category=ComplaintCategory.SAFETY, hours_ago=30
        )
        minor = await _complaint(db_session, (await make_user()).id, hours_ago=100)
        minor.priority = ComplaintPriority.LOW  # 72 h
        today = datetime.now(UTC).date()
        await _approved_document(db_session, scenario.vehicle_id, expires=today + timedelta(days=3))
        await _approved_document(
            db_session,
            scenario.vehicle_id,
            expires=today - timedelta(days=2),
            document_type=DocumentType.ROADWORTHINESS_CERTIFICATE,
        )
        applicant = await make_user()
        driver = await driver_service(db_session).register(
            applicant.id,
            DriverRegisterRequest(
                license_number=f"GHA-{uuid.uuid4().hex[:8]}",
                license_expiry=today + timedelta(days=365),
            ),
        )
        three_days_ago = datetime.now(UTC) - timedelta(days=3)
        await db_session.execute(
            update(DriverStatusHistory)
            .where(DriverStatusHistory.driver_id == driver.id)
            .values(changed_at=three_days_ago)
        )
        newcomer = await driver_service(db_session).register(
            (await make_user()).id,
            DriverRegisterRequest(
                license_number=f"GHA-{uuid.uuid4().hex[:8]}",
                license_expiry=today + timedelta(days=365),
            ),
        )
        everything = _principal(
            Permission.SOS_REVIEW,
            Permission.COMPLAINTS_MANAGE,
            Permission.DRIVERS_APPROVE,
            Permission.VEHICLES_APPROVE,
        )

        alerts, counts = await AdminOpsService(db_session).alerts(everything, limit=500)

        found = {(a.type, a.entity_id): a for a in alerts if a.type != "document_expiring"}
        assert found["sos_active", alert.id].severity == "critical"
        assert found["complaint_overdue", late.id].severity == "high"
        assert found["complaint_overdue", minor.id].severity == "low"
        documents = {
            a.details["document_type"]: a.severity
            for a in alerts
            if a.type == "document_expiring" and a.entity_id == scenario.vehicle_id
        }
        assert documents == {
            DocumentType.VEHICLE_INSURANCE.value: "medium",  # in 3 days
            DocumentType.ROADWORTHINESS_CERTIFICATE.value: "high",  # expired
        }
        assert ("approval_waiting", newcomer.id) not in found  # under the 48 h target
        waiting = found["approval_waiting", driver.id]
        assert waiting.details["waiting_hours"] >= 71
        assert waiting.details["status"] == ApprovalStatus.PENDING.value
        order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
        assert [order[a.severity] for a in alerts] == sorted(order[a.severity] for a in alerts)
        assert set(counts) == {
            "sos_active",
            "complaint_overdue",
            "document_expiring",
            "approval_waiting",
        }

    async def test_each_admin_sees_their_part(self, db_session: AsyncSession, make_user) -> None:
        await _sos(db_session, make_user)
        await _complaint(db_session, (await make_user()).id, hours_ago=100)

        alerts, counts = await AdminOpsService(db_session).alerts(
            _principal(Permission.COMPLAINTS_MANAGE), limit=500
        )

        assert set(counts) == {"complaint_overdue"}
        assert {a.type for a in alerts} == {"complaint_overdue"}

    async def test_a_renewed_document_clears_its_alert(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        today = datetime.now(UTC).date()
        await _approved_document(db_session, scenario.vehicle_id, expires=today + timedelta(days=3))
        await _approved_document(
            db_session, scenario.vehicle_id, expires=today + timedelta(days=365)
        )

        alerts, _ = await AdminOpsService(db_session).alerts(
            _principal(Permission.VEHICLES_APPROVE), limit=500
        )

        assert scenario.vehicle_id not in {a.entity_id for a in alerts}


# ------------------------------------------------------------------- search
class TestSearch:
    async def test_by_phone_plate_reference_and_id(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)
        local = f"024{secrets.randbelow(10**7):07d}"
        passenger = await make_user(phone_number=f"+233{local[1:]}")
        booking = await book(db_session, passenger.id, scenario, seat=0)
        payment = Payment(
            user_id=passenger.id,
            booking_id=booking.id,
            purpose=PaymentPurpose.BOOKING_PAYMENT,
            channel=PaymentChannel.MTN_MOMO,
            status=PaymentStatus.SUCCESSFUL,
            amount=Decimal("8.50"),
            internal_reference=f"PAY-{secrets.token_hex(6).upper()}",
        )
        db_session.add(payment)
        await db_session.flush()
        ops = AdminOpsService(db_session)
        everything = _principal(*Permission)

        async def found(query: str, kind: str) -> set[uuid.UUID]:
            _, results = await ops.search(everything, query, limit=20)
            return {hit.id for hit in results[kind]}

        spaced = f"{local[:3]} {local[3:6]} {local[6:]}"
        plate = scenario.registration_number.replace("-", " ").lower()
        assert passenger.id in await found(spaced, "users")
        assert scenario.vehicle_id in await found(plate, "vehicles")
        assert booking.id in await found(booking.booking_reference[:6].lower(), "bookings")
        assert payment.id in await found(payment.internal_reference.lower(), "payments")
        assert scenario.trip_id in await found(str(scenario.trip_id)[:8], "trips")
        assert scenario.trip_id in await found(scenario.route_name, "trips")

    async def test_each_admin_searches_what_they_may_see(self, db_session: AsyncSession) -> None:
        ops = AdminOpsService(db_session)

        searched, results = await ops.search(
            _principal(Permission.BOOKINGS_VIEW_ANY), "TRS", limit=5
        )

        assert searched == ["bookings"]
        assert results["users"] == []
        with pytest.raises(ForbiddenError):
            await ops.search(_principal(Permission.REPORTS_VIEW), "TRS", limit=5)


# -------------------------------------------------------------- trip replay
class TestTrack:
    async def test_replay(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user)
        start = datetime.now(UTC) - timedelta(minutes=10)
        for minute, (latitude, speed) in enumerate([(5.60, 0), (5.61, 40), (5.62, 55)]):
            db_session.add(
                TripLocation(
                    trip_id=scenario.trip_id,
                    location=latlng_to_wkt(latitude, -1.0),
                    speed_kmh=Decimal(speed),
                    recorded_at=start + timedelta(minutes=minute),
                )
            )
        await db_session.flush()
        ops = AdminOpsService(db_session)

        whole = await ops.track(scenario.trip_id, since=None, until=None)
        cut = await ops.track(scenario.trip_id, since=None, until=None, limit=2)
        later = await ops.track(scenario.trip_id, since=start + timedelta(minutes=1), until=None)

        assert [round(p.latitude, 2) for p in whole.points] == [5.60, 5.61, 5.62]
        assert Decimal("2.2") < whole.distance_km < Decimal("2.3")  # 0.02 degrees of latitude
        assert whole.max_speed_kmh == Decimal("55.00")
        assert not whole.truncated
        assert (cut.truncated, len(cut.points)) == (True, 2)
        assert len(later.points) == 2
        with pytest.raises(NotFoundError):
            await ops.track(uuid.uuid4(), since=None, until=None)


# ---------------------------------------------------------------- approvals
class TestApprovalEvents:
    async def test_registrations_and_documents_are_announced(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user)  # registers a driver and a vehicle
        await driver_service(db_session).upload_document(
            scenario.driver_user_id,
            document_type=DocumentType.POLICE_REPORT,
            filename="report.jpg",
            content_type="image/jpeg",
            data=b"fake-jpeg-bytes",
        )
        await fleet_service(db_session).upload_vehicle_document(
            scenario.owner_user_id,
            scenario.vehicle_id,
            document_type=DocumentType.VEHICLE_INSURANCE,
            filename="insurance.jpg",
            content_type="image/jpeg",
            data=b"fake-jpeg-bytes",
        )

        events = [
            (event["type"], event["data"]["kind"])
            for event in db_session.info["trosky.admin_events"]
            if event["type"].startswith("approval.")
        ]

        assert events == [
            ("approval.requested", "driver"),
            ("approval.requested", "vehicle"),
            ("approval.document_uploaded", "driver"),
            ("approval.document_uploaded", "vehicle"),
        ]
