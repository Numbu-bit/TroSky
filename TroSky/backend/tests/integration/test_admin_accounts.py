"""People, against a real database: browsing users, one user's details and
devices, managing the admin team without anyone raising themselves, and
asking drivers and fleet owners for new documents."""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from scripts.seed_reference_data import (
    ensure_admin_has_all_permissions,
    ensure_permissions,
    ensure_roles,
)
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth_dependencies import resolve_principal
from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    NotFoundError,
    ValidationAppError,
)
from app.core.permissions import Permission, Principal, SystemRole
from app.core.security import TokenType, create_token
from app.models.drivers import DocumentStatus, DocumentType, DriverDocument, DriverStatusHistory
from app.models.feedback import ComplaintCategory
from app.models.identity import User, UserSession
from app.models.notifications import Notification
from app.models.payments import PaymentMethod, WalletReferenceType
from app.models.routes import Stop
from app.providers.payments.base import PaymentChannel
from app.providers.storage.sandbox import SandboxStorageProvider
from app.repositories.session_repository import SessionRepository
from app.services.admin_accounts_service import AdminAccountsService, UserFilters, mask_number
from app.services.approval_requests_service import ApprovalRequestsService
from app.services.complaint_service import ComplaintService
from app.services.role_service import grant_role
from app.services.wallet_service import WalletService
from tests.integration.scenarios import book, build_trip_scenario, driver_service, fleet_service

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

EVERYTHING = frozenset(permission.value for permission in Permission)


def _principal(user_id: uuid.UUID, role: SystemRole, *permissions: Permission) -> Principal:
    granted = (
        EVERYTHING
        if role == SystemRole.ADMIN and not permissions
        else frozenset(permission.value for permission in permissions)
    )
    return Principal(
        user_id=user_id, session_id=uuid.uuid4(), roles=frozenset({role.value}), permissions=granted
    )


async def _reference(session: AsyncSession) -> None:
    roles = await ensure_roles(session)
    await ensure_admin_has_all_permissions(
        session, roles["admin"], await ensure_permissions(session)
    )


async def _member(session: AsyncSession, make_user, role: SystemRole) -> User:
    await _reference(session)
    user = await make_user()
    await grant_role(session, user.id, role)
    return user


def _phone() -> str:
    return f"+23324{secrets.randbelow(10**7):07d}"


async def _invitations() -> tuple[list[str], object]:
    sent: list[str] = []

    async def send(identifier: str) -> None:
        sent.append(identifier)

    return sent, send


# -------------------------------------------------------------------- users
class TestUsers:
    async def test_filters(self, db_session: AsyncSession, make_user) -> None:
        await _reference(db_session)
        accounts = AdminAccountsService(db_session)
        driver = await make_user()
        await grant_role(db_session, driver.id, SystemRole.DRIVER)
        suspended = await make_user(is_suspended=True, suspended_reason="Fraud")
        scenario = await build_trip_scenario(
            db_session, make_user, departure=datetime.now(UTC) + timedelta(hours=1)
        )
        city = f"Usertown {secrets.token_hex(3)}"
        await db_session.execute(
            update(Stop).where(Stop.id.in_(scenario.stop_ids)).values(city=city)
        )
        traveller = await make_user()
        await book(db_session, traveller.id, scenario, seat=0)
        long_ago = datetime(2020, 2, 2, 12, tzinfo=UTC)
        old = await make_user(created_at=long_ago)

        async def found(**filters: object) -> set[uuid.UUID]:
            rows, _ = await accounts.list_users(
                UserFilters(**filters),  # type: ignore[arg-type]
                sort="created_at",
                descending=True,
                limit=500,
                offset=0,
            )
            return {row.user.id for row in rows}

        local = "0" + driver.phone_number.removeprefix("+233")
        assert await found(search=local, roles=[SystemRole.DRIVER]) == {driver.id}
        assert await found(search=local, roles=[SystemRole.FLEET_OWNER]) == set()
        assert suspended.id in await found(status="suspended", search=suspended.phone_number)
        assert suspended.id not in await found(status="active", search=suspended.phone_number)
        assert await found(city=city) == {traveller.id}
        assert old.id in await found(
            signed_up_from=long_ago - timedelta(days=1),
            signed_up_until=long_ago + timedelta(days=1),
        )

    async def test_one_users_details(self, db_session: AsyncSession, make_user) -> None:
        await _reference(db_session)
        scenario = await build_trip_scenario(
            db_session, make_user, departure=datetime.now(UTC) + timedelta(hours=1)
        )
        passenger = await make_user()
        for seat in range(2):
            await book(db_session, passenger.id, scenario, seat=seat)
        db_session.add(
            PaymentMethod(
                user_id=passenger.id,
                channel=PaymentChannel.MTN_MOMO,
                phone_number="+233245550201",
                is_default=True,
            )
        )
        db_session.add(UserSession(user_id=passenger.id, last_seen_at=datetime.now(UTC)))
        await ComplaintService(db_session).file_complaint(
            passenger.id,
            booking_id=None,
            trip_id=None,
            category=ComplaintCategory.OTHER,
            subject="Lost bag",
            description="Left a bag on the bus.",
        )
        await WalletService(db_session).credit(
            passenger.id,
            amount=Decimal("12.50"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Top-up",
        )
        await db_session.flush()

        detail = await AdminAccountsService(db_session).user_detail(passenger.id)

        assert detail.payment_methods[0]["number"] == "+23324•••0201"
        assert detail.favourite_routes == [
            {"route_id": scenario.route_id, "route_name": scenario.route_name, "paid_bookings": 2}
        ]
        assert (detail.bookings["total"], detail.bookings["paid"]) == (2, 2)
        assert detail.complaints == {"total": 1, "open": 1}
        assert detail.wallet_balance == Decimal("12.50")
        assert detail.active_sessions == 1
        assert detail.driver_id is None
        with pytest.raises(NotFoundError):
            await AdminAccountsService(db_session).user_detail(uuid.uuid4())

    async def test_signing_a_device_out(self, db_session: AsyncSession, make_user) -> None:
        user, stranger, admin = await make_user(), await make_user(), await make_user()
        sessions = SessionRepository(db_session)
        phone = await sessions.create_session(
            user_id=user.id,
            device_id="phone",
            device_name="Tecno",
            ip_address=None,
            user_agent=None,
        )
        await sessions.create_session(
            user_id=user.id, device_id="tablet", device_name=None, ip_address=None, user_agent=None
        )
        accounts = AdminAccountsService(db_session)

        before = await accounts.sessions(user.id)
        await accounts.sign_out(user.id, phone.id, by=admin.id)
        after = await accounts.sessions(user.id)

        assert len(before) == 2
        assert [s.device_id for s in after] == ["tablet"]
        with pytest.raises(NotFoundError):  # not the stranger's session
            await accounts.sign_out(stranger.id, after[0].id, by=admin.id)

    async def test_masking(self) -> None:
        assert mask_number("+233245550201") == "+23324•••0201"
        assert mask_number("0244") == "••••"


# ----------------------------------------------------------------- the team
class TestTheTeam:
    async def test_inviting_someone_new(self, db_session: AsyncSession, make_user) -> None:
        admin = await _member(db_session, make_user, SystemRole.ADMIN)
        sent, send = await _invitations()

        member, created = await AdminAccountsService(db_session).invite(
            _principal(admin.id, SystemRole.ADMIN),
            full_name="Efua Support",
            phone_number=_phone(),
            email=f"efua-{secrets.token_hex(4)}@example.com",
            role=SystemRole.STAFF,
            permissions=[Permission.COMPLAINTS_MANAGE],
            send_invitation=send,  # type: ignore[arg-type]
        )

        assert created is True
        assert sent == [member.user.email]
        assert (member.role, member.granted) == ("staff", ["complaints:manage"])
        assert member.permissions == ["complaints:manage"]
        assert member.full_name == "Efua Support"

    async def test_an_existing_account_joins_as_it_is(
        self, db_session: AsyncSession, make_user
    ) -> None:
        admin = await _member(db_session, make_user, SystemRole.ADMIN)
        passenger = await make_user(phone_number=_phone())
        sent, send = await _invitations()
        accounts = AdminAccountsService(db_session)

        member, created = await accounts.invite(
            _principal(admin.id, SystemRole.ADMIN),
            full_name="Ignored",
            phone_number=passenger.phone_number,
            email=None,
            role=SystemRole.ADMIN,
            permissions=[],
            send_invitation=send,  # type: ignore[arg-type]
        )
        with pytest.raises(ConflictError):
            await accounts.invite(
                _principal(admin.id, SystemRole.ADMIN),
                full_name="Again",
                phone_number=passenger.phone_number,
                email=None,
                role=SystemRole.STAFF,
                permissions=[],
                send_invitation=send,  # type: ignore[arg-type]
            )

        assert (created, sent, member.user.id, member.role) == (False, [], passenger.id, "admin")
        assert Permission.FRAUD_VIEW.value in member.permissions

    async def test_no_one_raises_anyone_above_themselves(
        self, db_session: AsyncSession, make_user
    ) -> None:
        manager = await _member(db_session, make_user, SystemRole.STAFF)
        staff = _principal(
            manager.id, SystemRole.STAFF, Permission.ADMINS_MANAGE, Permission.COMPLAINTS_MANAGE
        )
        _, send = await _invitations()
        accounts = AdminAccountsService(db_session)

        async def invite(role: SystemRole, *permissions: Permission):
            return await accounts.invite(
                staff,
                full_name="New Person",
                phone_number=_phone(),
                email=None,
                role=role,
                permissions=permissions,
                send_invitation=send,  # type: ignore[arg-type]
            )

        with pytest.raises(ForbiddenError):
            await invite(SystemRole.ADMIN)
        with pytest.raises(ForbiddenError):
            await invite(SystemRole.STAFF, Permission.FRAUD_VIEW)  # not theirs to give
        member, _ = await invite(SystemRole.STAFF, Permission.COMPLAINTS_MANAGE)

        assert member.granted == ["complaints:manage"]

    async def test_an_admin_holds_everything_already(
        self, db_session: AsyncSession, make_user
    ) -> None:
        admin = await _member(db_session, make_user, SystemRole.ADMIN)
        _, send = await _invitations()

        with pytest.raises(ValidationAppError):
            await AdminAccountsService(db_session).invite(
                _principal(admin.id, SystemRole.ADMIN),
                full_name="Kwesi",
                phone_number=_phone(),
                email=None,
                role=SystemRole.ADMIN,
                permissions=[Permission.REPORTS_VIEW],
                send_invitation=send,  # type: ignore[arg-type]
            )

    async def test_changing_a_member(self, db_session: AsyncSession, make_user) -> None:
        admin = await _member(db_session, make_user, SystemRole.ADMIN)
        boss = await _member(db_session, make_user, SystemRole.SUPER_ADMIN)
        _, send = await _invitations()
        accounts = AdminAccountsService(db_session)
        by = _principal(admin.id, SystemRole.ADMIN)
        member, _ = await accounts.invite(
            by,
            full_name="Yaa",
            phone_number=_phone(),
            email=None,
            role=SystemRole.STAFF,
            permissions=[Permission.REPORTS_VIEW],
            send_invitation=send,  # type: ignore[arg-type]
        )

        widened = await accounts.update_member(
            by,
            member.user.id,
            role=None,
            permissions=[Permission.REPORTS_VIEW, Permission.SOS_REVIEW],
            active=None,
        )
        promoted = await accounts.update_member(
            by, member.user.id, role=SystemRole.ADMIN, permissions=None, active=None
        )

        assert widened is not None
        assert widened.granted == ["reports:view", "sos:review"]
        assert promoted is not None
        assert (promoted.role, promoted.granted) == ("admin", [])
        with pytest.raises(ForbiddenError):
            await accounts.update_member(by, admin.id, role=None, permissions=None, active=False)
        with pytest.raises(ForbiddenError):
            await accounts.update_member(by, boss.id, role=None, permissions=None, active=False)
        with pytest.raises(NotFoundError):
            await accounts.update_member(
                by, (await make_user()).id, role=None, permissions=None, active=False
            )

    async def test_taking_someone_off_the_team(self, db_session: AsyncSession, make_user) -> None:
        admin = await _member(db_session, make_user, SystemRole.ADMIN)
        _, send = await _invitations()
        accounts = AdminAccountsService(db_session)
        by = _principal(admin.id, SystemRole.ADMIN)
        member, _ = await accounts.invite(
            by,
            full_name="Leaving",
            phone_number=_phone(),
            email=None,
            role=SystemRole.STAFF,
            permissions=[Permission.REPORTS_VIEW],
            send_invitation=send,  # type: ignore[arg-type]
        )
        signed_in = UserSession(user_id=member.user.id, last_seen_at=datetime.now(UTC))
        db_session.add(signed_in)
        await db_session.flush()

        gone = await accounts.update_member(
            by, member.user.id, role=None, permissions=None, active=False
        )
        await db_session.refresh(signed_in)

        assert gone is None
        assert member.user.id not in {m.user.id for m in await accounts.team()}
        assert signed_in.revoked_reason == "removed_from_admin_team"

    async def test_granted_permissions_count_when_signed_in(
        self, db_session: AsyncSession, make_user
    ) -> None:
        admin = await _member(db_session, make_user, SystemRole.ADMIN)
        _, send = await _invitations()
        member, _ = await AdminAccountsService(db_session).invite(
            _principal(admin.id, SystemRole.ADMIN),
            full_name="Akua",
            phone_number=_phone(),
            email=None,
            role=SystemRole.STAFF,
            permissions=[Permission.COMPLAINTS_MANAGE],
            send_invitation=send,  # type: ignore[arg-type]
        )
        session = await SessionRepository(db_session).create_session(
            user_id=member.user.id,
            device_id=None,
            device_name=None,
            ip_address=None,
            user_agent=None,
        )
        token, _ = create_token(
            user_id=member.user.id,
            session_id=session.id,
            token_type=TokenType.ACCESS,
            roles=["staff"],
        )

        principal = await resolve_principal(db_session, token)

        assert principal.has_permission(Permission.COMPLAINTS_MANAGE)
        assert not principal.has_permission(Permission.FRAUD_VIEW)


# ---------------------------------------------------------------- approvals
class TestApprovalRequests:
    async def test_asking_a_driver_for_new_documents(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user, admin = await make_user(), await make_user()
        from app.schemas.driver import DriverRegisterRequest

        drivers = driver_service(db_session)
        driver = await drivers.register(
            user.id,
            DriverRegisterRequest(
                license_number=f"GHA-{uuid.uuid4().hex[:8]}",
                license_expiry=datetime.now(UTC).date() + timedelta(days=365),
            ),
        )
        uploaded = {}
        for document_type in (DocumentType.DRIVER_LICENSE, DocumentType.PROFILE_PHOTO):
            uploaded[document_type] = await drivers.upload_document(
                user.id,
                document_type=document_type,
                filename="photo.jpg",
                content_type="image/jpeg",
                data=b"fake-jpeg-bytes",
            )

        request = await ApprovalRequestsService(db_session).request_driver_info(
            driver.id,
            document_types=[DocumentType.DRIVER_LICENSE, DocumentType.POLICE_REPORT],
            note="The licence photo is blurred.",
            by=admin.id,
        )
        licence = await db_session.get(DriverDocument, uploaded[DocumentType.DRIVER_LICENSE].id)
        photo = await db_session.get(DriverDocument, uploaded[DocumentType.PROFILE_PHOTO].id)
        history = await db_session.scalar(
            select(DriverStatusHistory.reason).where(
                DriverStatusHistory.driver_id == driver.id,
                DriverStatusHistory.reason.like("Documents requested%"),
            )
        )
        notice = await db_session.scalar(
            select(Notification).where(Notification.user_id == user.id)
        )

        assert request.documents_returned == [licence.id]  # type: ignore[union-attr]
        assert (licence.status, licence.rejection_reason) == (  # type: ignore[union-attr]
            DocumentStatus.REJECTED,
            "The licence photo is blurred.",
        )
        assert photo.status == DocumentStatus.PENDING  # type: ignore[union-attr]
        assert history is not None
        assert history.startswith("Documents requested (driver license, police report)")
        assert notice is not None
        assert notice.data["type"] == "documents_requested"
        with pytest.raises(NotFoundError):
            await ApprovalRequestsService(db_session).request_driver_info(
                uuid.uuid4(), document_types=[DocumentType.OTHER], note="Hello there", by=admin.id
            )

    async def test_asking_a_fleet_owner_for_a_vehicles_documents(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await build_trip_scenario(
            db_session, make_user, departure=datetime.now(UTC) + timedelta(hours=1)
        )

        request = await ApprovalRequestsService(db_session).request_vehicle_info(
            scenario.vehicle_id,
            document_types=[DocumentType.VEHICLE_INSURANCE],
            note="The insurance certificate has expired.",
            by=(await make_user()).id,
        )

        assert request.notified_user_id == scenario.owner_user_id

    async def test_a_link_to_look_at_a_document(self, db_session: AsyncSession, make_user) -> None:
        scenario = await build_trip_scenario(
            db_session, make_user, departure=datetime.now(UTC) + timedelta(hours=1)
        )
        document = await fleet_service(db_session).upload_vehicle_document(
            scenario.owner_user_id,
            scenario.vehicle_id,
            document_type=DocumentType.VEHICLE_INSURANCE,
            filename="insurance.pdf",
            content_type="application/pdf",
            data=b"%PDF-1.4 fake",
        )
        approvals, storage = ApprovalRequestsService(db_session), SandboxStorageProvider()
        reviewer = _principal(uuid.uuid4(), SystemRole.STAFF, Permission.VEHICLES_APPROVE)

        link = await approvals.document_link(document.id, principal=reviewer, storage=storage)

        assert document.storage_key in link.url
        assert (link.owner_type, link.owner_id) == ("vehicle", scenario.vehicle_id)
        assert timedelta(minutes=4) < link.expires_at - datetime.now(UTC) <= timedelta(minutes=5)
        with pytest.raises(ForbiddenError):
            await approvals.document_link(
                document.id,
                principal=_principal(uuid.uuid4(), SystemRole.STAFF, Permission.DRIVERS_APPROVE),
                storage=storage,
            )
        with pytest.raises(NotFoundError):
            await approvals.document_link(uuid.uuid4(), principal=reviewer, storage=storage)
