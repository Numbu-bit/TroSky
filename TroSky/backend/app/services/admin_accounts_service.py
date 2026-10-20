"""People, for the admin dashboard: browsing users, one user's details and
signed-in devices, and the admin team itself.

The team is everyone holding the ``super_admin``, ``admin`` or ``staff``
role. Admins hold every permission but managing super admins; staff hold
only the permissions granted to them. Whoever manages the team cannot change
their own access, give a role above their own, or grant a permission they do
not hold -- so no one can raise themselves through someone else.
"""

from __future__ import annotations

import secrets
import uuid
from collections.abc import Awaitable, Callable, Collection
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from typing import Any, Literal, cast

from sqlalchemy import ColumnElement, Select, delete, exists, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.core.config import from_minor_units
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, ValidationAppError
from app.core.logging import get_logger
from app.core.permissions import Permission, Principal, SystemRole
from app.core.security import hash_password_async
from app.models.bookings import Booking, BookingStatus
from app.models.drivers import Driver
from app.models.feedback import Complaint, ComplaintStatus
from app.models.fraud import FraudFlag, FraudFlagStatus
from app.models.identity import Permission as PermissionRow
from app.models.identity import Role, User, UserPermission, UserProfile, UserRole, UserSession
from app.models.payments import PaymentMethod, Wallet
from app.models.routes import Route, Stop
from app.models.trips import Trip
from app.models.vehicles import FleetOwner
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository
from app.services.role_service import grant_role
from app.utilities.phone import InvalidPhoneNumberError, normalize_phone_number

logger = get_logger(__name__)

TEAM_ROLES = (SystemRole.SUPER_ADMIN, SystemRole.ADMIN, SystemRole.STAFF)
_RANK = {SystemRole.STAFF.value: 1, SystemRole.ADMIN.value: 2, SystemRole.SUPER_ADMIN.value: 3}
PAID = (
    BookingStatus.CONFIRMED,
    BookingStatus.COMPLETED,
    BookingStatus.REFUND_PENDING,
    BookingStatus.REFUNDED,
)
UserStatus = Literal["active", "suspended", "inactive"]
UserSort = Literal["created_at", "last_login_at", "full_name"]
TeamRole = Literal["super_admin", "admin", "staff"]


def mask_number(number: str) -> str:
    """``+233245550201`` -> ``+23324•••0201``: enough to recognise it."""
    if len(number) <= 8:
        return "•" * len(number)
    return number[:6] + "•" * (len(number) - 10) + number[-4:]


def _rank(roles: Collection[str]) -> int:
    return max((_RANK.get(role, 0) for role in roles), default=0)


def _roles_of() -> Any:
    return (
        select(func.array_agg(Role.slug))
        .join(UserRole, UserRole.role_id == Role.id)
        .where(UserRole.user_id == User.id)
        .correlate(User)
        .scalar_subquery()
    )


@dataclass(frozen=True, slots=True)
class UserFilters:
    search: str | None = None
    roles: list[SystemRole] | None = None
    status: UserStatus | None = None
    city: str | None = None
    signed_up_from: datetime | None = None
    signed_up_until: datetime | None = None


@dataclass(frozen=True, slots=True)
class UserRow:
    user: User
    full_name: str | None
    roles: list[str]


@dataclass(frozen=True, slots=True)
class UserDetail:
    row: UserRow
    preferred_language: str | None
    payment_methods: list[dict[str, Any]]
    favourite_routes: list[dict[str, Any]]
    bookings: dict[str, int]
    complaints: dict[str, int]
    wallet_balance: Decimal
    wallet_frozen_at: datetime | None
    active_sessions: int
    driver_id: uuid.UUID | None
    fleet_owner_id: uuid.UUID | None
    open_fraud_flags: int


@dataclass(frozen=True, slots=True)
class TeamMember:
    user: User
    full_name: str | None
    role: TeamRole
    granted: list[str]
    permissions: list[str] = field(default_factory=list)


class AdminAccountsService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._users = UserRepository(session)

    # -------------------------------------------------------------- users
    def _user_rows(self) -> Select[Any]:
        return (
            select(User, UserProfile.full_name, _roles_of())
            .outerjoin(UserProfile, UserProfile.user_id == User.id)
            .where(User.deleted_at.is_(None))
        )

    async def list_users(
        self,
        filters: UserFilters,
        *,
        sort: UserSort,
        descending: bool,
        limit: int,
        offset: int,
    ) -> tuple[list[UserRow], int]:
        conditions: list[ColumnElement[bool]] = []
        if filters.search:
            text = f"%{filters.search.strip()}%"
            matches = [
                User.phone_number.ilike(text),
                User.email.ilike(text),
                UserProfile.full_name.ilike(text),
            ]
            digits = filters.search.replace(" ", "").replace("-", "")
            if digits.startswith("0") and digits[1:].isdigit():
                matches.append(User.phone_number.ilike(f"%+233{digits[1:]}%"))
            conditions.append(or_(*matches))
        if filters.roles:
            conditions.append(
                exists(
                    select(UserRole.user_id)
                    .join(Role, Role.id == UserRole.role_id)
                    .where(
                        UserRole.user_id == User.id,
                        Role.slug.in_([role.value for role in filters.roles]),
                    )
                )
            )
        if filters.status == "active":
            conditions += [User.is_active.is_(True), User.is_suspended.is_(False)]
        elif filters.status == "suspended":
            conditions.append(User.is_suspended.is_(True))
        elif filters.status == "inactive":
            conditions.append(User.is_active.is_(False))
        if filters.city:
            route, origin = aliased(Route), aliased(Stop)
            conditions.append(
                exists(
                    select(Booking.id)
                    .join(Trip, Trip.id == Booking.trip_id)
                    .join(route, route.id == Trip.route_id)
                    .join(
                        origin,
                        origin.id == func.coalesce(Booking.origin_stop_id, route.origin_stop_id),
                    )
                    .where(
                        Booking.passenger_id == User.id,
                        func.lower(origin.city) == filters.city.strip().lower(),
                    )
                )
            )
        if filters.signed_up_from is not None:
            conditions.append(User.created_at >= filters.signed_up_from)
        if filters.signed_up_until is not None:
            conditions.append(User.created_at < filters.signed_up_until)
        rows = self._user_rows().where(*conditions)
        total = int(
            await self._session.scalar(select(func.count()).select_from(rows.subquery())) or 0
        )
        column: Any = {
            "created_at": User.created_at,
            "last_login_at": User.last_login_at,
            "full_name": UserProfile.full_name,
        }[sort]
        ordered = column.desc().nulls_last() if descending else column.asc().nulls_last()
        result = await self._session.execute(
            rows.order_by(ordered, User.id).limit(limit).offset(offset)
        )
        return [UserRow(user, name, list(roles or [])) for user, name, roles in result.all()], total

    async def _row(self, user_id: uuid.UUID) -> UserRow:
        found = (await self._session.execute(self._user_rows().where(User.id == user_id))).first()
        if found is None:
            raise NotFoundError("User not found.")
        user, name, roles = found
        return UserRow(user, name, list(roles or []))

    async def user_detail(self, user_id: uuid.UUID) -> UserDetail:
        """A user's profile, saved numbers (masked), favourite routes, and
        what they have booked and complained about."""
        row = await self._row(user_id)
        methods = (
            await self._session.execute(
                select(PaymentMethod)
                .where(PaymentMethod.user_id == user_id)
                .order_by(PaymentMethod.is_default.desc(), PaymentMethod.created_at)
            )
        ).scalars()
        paid = func.count(Booking.id).label("bookings")
        favourites = await self._session.execute(
            select(Route.id, Route.name, paid)
            .join(Trip, Trip.route_id == Route.id)
            .join(Booking, Booking.trip_id == Trip.id)
            .where(Booking.passenger_id == user_id, Booking.status.in_(PAID))
            .group_by(Route.id, Route.name)
            .order_by(paid.desc(), Route.name)
            .limit(3)
        )
        bookings = (
            await self._session.execute(
                select(
                    func.count(Booking.id),
                    func.count(Booking.id).filter(Booking.status.in_(PAID)),
                    func.count(Booking.id).filter(Booking.status == BookingStatus.COMPLETED),
                    func.count(Booking.id).filter(
                        Booking.status.in_(
                            (
                                BookingStatus.CANCELLED,
                                BookingStatus.REFUND_PENDING,
                                BookingStatus.REFUNDED,
                            )
                        )
                    ),
                ).where(Booking.passenger_id == user_id)
            )
        ).one()
        complaints = (
            await self._session.execute(
                select(
                    func.count(Complaint.id),
                    func.count(Complaint.id).filter(
                        Complaint.status.in_((ComplaintStatus.OPEN, ComplaintStatus.IN_REVIEW))
                    ),
                ).where(Complaint.filed_by == user_id)
            )
        ).one()
        wallet = await self._session.scalar(select(Wallet).where(Wallet.user_id == user_id))
        profile_language = await self._session.scalar(
            select(UserProfile.preferred_language).where(UserProfile.user_id == user_id)
        )
        return UserDetail(
            row=row,
            preferred_language=profile_language,
            payment_methods=[
                {
                    "id": method.id,
                    "channel": method.channel.value,
                    "number": mask_number(method.phone_number),
                    "label": method.label,
                    "is_default": method.is_default,
                }
                for method in methods
            ],
            favourite_routes=[
                {"route_id": route_id, "route_name": name, "paid_bookings": int(count)}
                for route_id, name, count in favourites.all()
            ],
            bookings={
                "total": int(bookings[0]),
                "paid": int(bookings[1]),
                "completed": int(bookings[2]),
                "cancelled": int(bookings[3]),
            },
            complaints={"total": int(complaints[0]), "open": int(complaints[1])},
            wallet_balance=from_minor_units(wallet.balance_minor_units) if wallet else Decimal(0),
            wallet_frozen_at=wallet.frozen_at if wallet else None,
            active_sessions=int(
                await self._session.scalar(
                    select(func.count(UserSession.id)).where(
                        UserSession.user_id == user_id, UserSession.revoked_at.is_(None)
                    )
                )
                or 0
            ),
            driver_id=await self._session.scalar(
                select(Driver.id).where(Driver.user_id == user_id)
            ),
            fleet_owner_id=await self._session.scalar(
                select(FleetOwner.id).where(FleetOwner.user_id == user_id)
            ),
            open_fraud_flags=int(
                await self._session.scalar(
                    select(func.count(FraudFlag.id)).where(
                        FraudFlag.subject_user_id == user_id,
                        FraudFlag.status.in_((FraudFlagStatus.OPEN, FraudFlagStatus.INVESTIGATING)),
                    )
                )
                or 0
            ),
        )

    # ----------------------------------------------------------- sessions
    async def sessions(self, user_id: uuid.UUID) -> list[UserSession]:
        """The user's signed-in devices, most recently used first."""
        await self._row(user_id)
        result = await self._session.execute(
            select(UserSession)
            .where(UserSession.user_id == user_id, UserSession.revoked_at.is_(None))
            .order_by(UserSession.last_seen_at.desc())
        )
        return list(result.scalars().all())

    async def sign_out(self, user_id: uuid.UUID, session_id: uuid.UUID, *, by: uuid.UUID) -> None:
        """End one of the user's sessions: that device must sign in again."""
        found = await self._session.scalar(
            select(UserSession.id).where(
                UserSession.id == session_id, UserSession.user_id == user_id
            )
        )
        if found is None:
            raise NotFoundError("Session not found.")
        await SessionRepository(self._session).revoke_session(
            session_id, reason="signed_out_by_admin"
        )
        logger.info("session_signed_out_by_admin", user_id=str(user_id), by=str(by))

    # --------------------------------------------------------------- team
    async def _member(self, user: User, name: str | None, roles: list[str]) -> TeamMember:
        team = [role for role in roles if role in _RANK]
        role = max(team, key=lambda slug: _RANK[slug])
        granted = sorted(await self._users.get_granted_permissions(user.id))
        if role == SystemRole.SUPER_ADMIN.value:
            permissions = sorted(permission.value for permission in Permission)
        else:
            permissions = sorted(await self._users.get_permissions_for_roles(roles) | set(granted))
        return TeamMember(user, name, cast(TeamRole, role), granted, permissions)

    async def team(self) -> list[TeamMember]:
        result = await self._session.execute(
            self._user_rows()
            .where(
                exists(
                    select(UserRole.user_id)
                    .join(Role, Role.id == UserRole.role_id)
                    .where(
                        UserRole.user_id == User.id,
                        Role.slug.in_([role.value for role in TEAM_ROLES]),
                    )
                )
            )
            .order_by(UserProfile.full_name, User.created_at)
        )
        return [
            await self._member(user, name, list(roles or [])) for user, name, roles in result.all()
        ]

    async def team_member(self, user_id: uuid.UUID) -> TeamMember:
        row = await self._row(user_id)
        if not any(role in _RANK for role in row.roles):
            raise NotFoundError("Not on the admin team.")
        return await self._member(row.user, row.full_name, row.roles)

    def _check_grant(
        self, by: Principal, role: SystemRole, permissions: Collection[Permission]
    ) -> None:
        if _RANK[role.value] > _rank(by.roles):
            raise ForbiddenError("You cannot give someone a role above your own.")
        if role != SystemRole.STAFF and permissions:
            raise ValidationAppError(
                "Only staff are given permissions one by one; an admin holds them all.",
                details={"param": "permissions"},
            )
        if not by.has_role(SystemRole.SUPER_ADMIN):
            beyond = {permission.value for permission in permissions} - set(by.permissions)
            if beyond:
                raise ForbiddenError(
                    "You cannot grant a permission you do not hold.",
                    details={"permissions": sorted(beyond)},
                )

    async def _set_permissions(
        self, user_id: uuid.UUID, permissions: Collection[Permission], *, by: uuid.UUID
    ) -> None:
        await self._session.execute(delete(UserPermission).where(UserPermission.user_id == user_id))
        if permissions:
            rows = await self._session.execute(
                select(PermissionRow.id).where(
                    PermissionRow.code.in_([permission.value for permission in permissions])
                )
            )
            for permission_id in rows.scalars():
                self._session.add(
                    UserPermission(user_id=user_id, permission_id=permission_id, granted_by=by)
                )
        await self._session.flush()

    async def _set_team_role(self, user_id: uuid.UUID, role: SystemRole | None) -> None:
        """Make ``role`` the person's only team role; ``None`` takes them off
        the team."""
        others = select(Role.id).where(Role.slug.in_([r.value for r in TEAM_ROLES if r != role]))
        await self._session.execute(
            delete(UserRole).where(UserRole.user_id == user_id, UserRole.role_id.in_(others))
        )
        if role is not None:
            await grant_role(self._session, user_id, role)
        await self._session.flush()

    async def invite(
        self,
        by: Principal,
        *,
        full_name: str,
        phone_number: str,
        email: str | None,
        role: SystemRole,
        permissions: Collection[Permission],
        send_invitation: Callable[[str], Awaitable[None]],
    ) -> tuple[TeamMember, bool]:
        """Add someone to the team: their existing account if the number or
        email has one, a new one if not -- which gets a code to set its
        password. Returns the member and whether the account is new."""
        self._check_grant(by, role, permissions)
        try:
            phone = normalize_phone_number(phone_number)
        except InvalidPhoneNumberError as exc:
            raise ValidationAppError(str(exc), details={"param": "phone_number"}) from exc
        user = await self._users.get_by_phone(phone)
        if user is None and email:
            user = await self._users.get_by_email(email)
        created = user is None
        if user is None:
            user = await self._users.create(
                phone_number=phone,
                email=email,
                # Unusable until they set their own with the code sent below.
                password_hash=await hash_password_async(secrets.token_urlsafe(32)),
                full_name=full_name,
            )
        elif any(r in _RANK for r in await self._users.get_roles_for_user(user.id)):
            raise ConflictError("This person is already on the admin team.", code="ALREADY_ON_TEAM")
        await self._set_team_role(user.id, role)
        await self._set_permissions(user.id, permissions, by=by.user_id)
        if created:
            await send_invitation(email or phone)
        logger.info("admin_team_member_added", user_id=str(user.id), role=role.value)
        return await self.team_member(user.id), created

    async def update_member(
        self,
        by: Principal,
        member_id: uuid.UUID,
        *,
        role: SystemRole | None,
        permissions: Collection[Permission] | None,
        active: bool | None,
    ) -> TeamMember | None:
        """Change a member's role or permissions, or take them off the team
        (``active=False``: their team roles and permissions go, and they are
        signed out everywhere). ``None`` when they are no longer on it."""
        if member_id == by.user_id:
            raise ForbiddenError("You cannot change your own access.")
        member = await self.team_member(member_id)
        if _RANK[member.role] > _rank(by.roles):
            raise ForbiddenError("You cannot change someone whose role is above your own.")
        if active is False:
            await self._set_team_role(member_id, None)
            await self._set_permissions(member_id, (), by=by.user_id)
            await SessionRepository(self._session).revoke_all_sessions_for_user(
                member_id, reason="removed_from_admin_team"
            )
            logger.warning("admin_team_member_removed", user_id=str(member_id), by=str(by.user_id))
            return None
        new_role = role or SystemRole(member.role)
        new_permissions = (
            permissions
            if permissions is not None
            else [Permission(code) for code in member.granted]
            if new_role == SystemRole.STAFF
            else []
        )
        self._check_grant(by, new_role, new_permissions)
        await self._set_team_role(member_id, new_role)
        await self._set_permissions(member_id, new_permissions, by=by.user_id)
        return await self.team_member(member_id)
