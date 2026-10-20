"""Identity & access domain models: users, roles/permissions, sessions,
refresh tokens, OTP challenges, password resets, device registrations,
emergency contacts, and notification preferences.

Design notes
------------
* ``users.phone_number`` is stored E.164-normalized (validated at the schema
  layer via ``phonenumbers``) and is the primary login identifier; it is
  always required. ``email`` is optional and stored as ``CITEXT`` so
  uniqueness is case-insensitive without extra normalization logic. Both
  are unique only among accounts that are not deleted.
* Role/permission assignment is fully data-driven (``roles``,
  ``permissions``, ``role_permissions``, ``user_roles``) rather than a
  hard-coded enum on ``users`` — this is what lets administrators tune
  authorization without a deployment.
* Refresh tokens are stored **hashed** (`token_hash`, SHA-256 via
  ``app.core.security.hash_opaque_token``); the raw token is only ever
  present in the response body at issuance time, never persisted or logged.
* ``otp_challenges`` targets a raw phone/email string rather than a
  ``user_id`` foreign key because OTPs are used both pre-registration
  (verifying a phone before an account exists) and post-registration.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Index,
    UniqueConstraint,
    text,
)
from sqlalchemy import (
    Enum as PgEnum,
)
from sqlalchemy.dialects.postgresql import CITEXT
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import TIMESTAMP, Boolean, Integer, String

from app.models.base import Base, SoftDeleteMixin, UUIDAuditBase, enum_values


class OtpChannel(StrEnum):
    SMS = "sms"
    EMAIL = "email"


class OtpPurpose(StrEnum):
    REGISTRATION = "registration"
    LOGIN = "login"
    PASSWORD_RESET = "password_reset"  # noqa: S105 - enum value, not a credential
    PHONE_VERIFICATION = "phone_verification"
    EMAIL_VERIFICATION = "email_verification"


class DevicePlatform(StrEnum):
    IOS = "ios"
    ANDROID = "android"
    WEB = "web"


class Role(UUIDAuditBase):
    """A named, assignable authorization role (e.g. ``passenger``, ``admin``)."""

    __tablename__ = "roles"

    slug: Mapped[str] = mapped_column(String(50), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_system: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    permissions: Mapped[list[Permission]] = relationship(
        secondary="role_permissions", back_populates="roles", viewonly=True
    )

    __table_args__ = (UniqueConstraint("slug", name="uq_roles_slug"),)


class Permission(UUIDAuditBase):
    """A fine-grained permission slug (e.g. ``drivers:approve``)."""

    __tablename__ = "permissions"

    code: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)

    roles: Mapped[list[Role]] = relationship(
        secondary="role_permissions", back_populates="permissions", viewonly=True
    )

    __table_args__ = (UniqueConstraint("code", name="uq_permissions_code"),)


class RolePermission(Base):
    """Join table: which permissions a role grants."""

    __tablename__ = "role_permissions"

    role_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("roles.id", ondelete="CASCADE"), primary_key=True
    )
    permission_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("permissions.id", ondelete="CASCADE"), primary_key=True
    )


class User(UUIDAuditBase, SoftDeleteMixin):
    """A platform account. One ``User`` row per human, regardless of how many
    roles (passenger/driver/fleet_owner) they hold."""

    __tablename__ = "users"

    phone_number: Mapped[str] = mapped_column(String(20), nullable=False)
    email: Mapped[str | None] = mapped_column(CITEXT, nullable=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)

    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    is_suspended: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    suspended_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    suspended_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)

    phone_verified_at: Mapped[datetime | None] = mapped_column(
        TIMESTAMP(timezone=True), nullable=True
    )
    email_verified_at: Mapped[datetime | None] = mapped_column(
        TIMESTAMP(timezone=True), nullable=True
    )

    failed_login_attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    locked_until: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    last_login_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)

    profile: Mapped[UserProfile | None] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )

    @property
    def is_verified(self) -> bool:
        """Whether the user has proven their phone or their email by
        entering a code sent to it."""
        return self.phone_verified_at is not None or self.email_verified_at is not None

    __table_args__ = (
        # Unique among accounts not deleted: a deleted account keeps its
        # row, and its number and email are free for a new sign-up.
        Index(
            "uq_users_phone_number",
            "phone_number",
            unique=True,
            postgresql_where=text("deleted_at IS NULL"),
        ),
        Index("uq_users_email", "email", unique=True, postgresql_where=text("deleted_at IS NULL")),
        CheckConstraint("failed_login_attempts >= 0", name="failed_login_attempts_non_negative"),
        Index("ix_users_email", "email"),
    )


class UserProfile(UUIDAuditBase):
    """Extended profile data, kept separate from ``users`` (auth-critical
    fields) so profile edits never touch the authentication row."""

    __tablename__ = "user_profiles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    full_name: Mapped[str] = mapped_column(String(200), nullable=False)
    date_of_birth: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    gender: Mapped[str | None] = mapped_column(String(20), nullable=True)
    preferred_language: Mapped[str] = mapped_column(String(10), nullable=False, default="en")
    avatar_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    # An uploaded photo in the private bucket; served through a short-lived
    # signed URL, so the URL itself is never stored.
    avatar_storage_key: Mapped[str | None] = mapped_column(String(500), nullable=True)
    ghana_card_number: Mapped[str | None] = mapped_column(String(20), nullable=True)
    ghana_card_verified_at: Mapped[datetime | None] = mapped_column(
        TIMESTAMP(timezone=True), nullable=True
    )

    user: Mapped[User] = relationship(back_populates="profile")

    __table_args__ = (UniqueConstraint("user_id", name="uq_user_profiles_user_id"),)


class UserPermission(UUIDAuditBase):
    """A permission granted to one person: how a staff member gets exactly
    the access their job needs. Added to their roles' permissions."""

    __tablename__ = "user_permissions"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    permission_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("permissions.id", ondelete="CASCADE"), nullable=False
    )
    granted_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    __table_args__ = (
        UniqueConstraint("user_id", "permission_id", name="uq_user_permissions_user_permission"),
    )


class UserRole(Base):
    """Join table: which roles a user holds. More than one only as
    ``app.services.role_service`` allows: a driver who is also a fleet
    owner, or a team role alongside an app role. Never passenger and
    driver or fleet owner together."""

    __tablename__ = "user_roles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    role_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("roles.id", ondelete="CASCADE"), primary_key=True
    )
    assigned_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )
    assigned_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )


class UserSession(UUIDAuditBase):
    """A logical login session on one device. Revoking a session invalidates
    every refresh token issued under it (and, once its access token expires,
    fully logs the device out)."""

    __tablename__ = "user_sessions"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    device_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    device_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    ip_address: Mapped[str | None] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(String(500), nullable=True)
    last_seen_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )
    revoked_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    revoked_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)

    __table_args__ = (
        Index("ix_user_sessions_user_id", "user_id"),
        Index("ix_user_sessions_active", "user_id", "revoked_at"),
    )


class RefreshToken(UUIDAuditBase):
    """A single refresh token in a session's rotation chain. Only the SHA-256
    hash of the bearer token is stored (see ``app.core.security.hash_opaque_token``)."""

    __tablename__ = "refresh_tokens"

    session_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("user_sessions.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    replaced_by_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("refresh_tokens.id", ondelete="SET NULL"), nullable=True
    )

    __table_args__ = (
        UniqueConstraint("token_hash", name="uq_refresh_tokens_token_hash"),
        Index("ix_refresh_tokens_session_id", "session_id"),
        Index("ix_refresh_tokens_user_id", "user_id"),
    )


class OtpChallenge(UUIDAuditBase):
    """A single OTP challenge (registration, login, password reset, phone/email
    verification). Targets a raw phone/email rather than a user id since some
    purposes (registration, phone verification) predate the user existing."""

    __tablename__ = "otp_challenges"

    target: Mapped[str] = mapped_column(String(255), nullable=False)
    channel: Mapped[OtpChannel] = mapped_column(
        PgEnum(OtpChannel, name="otp_channel", native_enum=True, values_callable=enum_values),
        nullable=False,
    )
    purpose: Mapped[OtpPurpose] = mapped_column(
        PgEnum(OtpPurpose, name="otp_purpose", native_enum=True, values_callable=enum_values),
        nullable=False,
    )
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=True
    )
    expires_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    max_attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=5)
    consumed_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)

    __table_args__ = (
        CheckConstraint("attempts >= 0", name="attempts_non_negative"),
        CheckConstraint("max_attempts > 0", name="max_attempts_positive"),
        Index("ix_otp_challenges_target_purpose", "target", "purpose"),
    )


class PasswordResetToken(UUIDAuditBase):
    """A single-use, hashed password-reset token."""

    __tablename__ = "password_reset_tokens"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)

    __table_args__ = (
        UniqueConstraint("token_hash", name="uq_password_reset_tokens_token_hash"),
        Index("ix_password_reset_tokens_user_id", "user_id"),
    )


class DeviceRegistration(UUIDAuditBase):
    """A device known to a user, holding its current push token. Push
    delivery itself is implemented in Phase 9; this table exists from Phase 2
    so session/device management has something real to list."""

    __tablename__ = "device_registrations"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    device_id: Mapped[str] = mapped_column(String(255), nullable=False)
    platform: Mapped[DevicePlatform] = mapped_column(
        PgEnum(
            DevicePlatform, name="device_platform", native_enum=True, values_callable=enum_values
        ),
        nullable=False,
    )
    push_token: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    last_seen_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default="now()"
    )

    __table_args__ = (
        UniqueConstraint("user_id", "device_id", name="uq_device_registrations_user_device"),
    )


class EmergencyContact(UUIDAuditBase, SoftDeleteMixin):
    """A passenger-managed emergency contact, notified on SOS (Phase 9)."""

    __tablename__ = "emergency_contacts"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    phone_number: Mapped[str] = mapped_column(String(20), nullable=False)
    relationship_label: Mapped[str | None] = mapped_column(String(100), nullable=True)
    is_primary: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    __table_args__ = (Index("ix_emergency_contacts_user_id", "user_id"),)


class FavouriteRoute(UUIDAuditBase):
    """A journey a user pinned to the Home screen: board at one stop, get
    off at another."""

    __tablename__ = "favourite_routes"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    origin_stop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("stops.id", ondelete="RESTRICT"), nullable=False
    )
    destination_stop_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("stops.id", ondelete="RESTRICT"), nullable=False
    )
    label: Mapped[str | None] = mapped_column(String(60), nullable=True)

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "origin_stop_id",
            "destination_stop_id",
            name="uq_favourite_routes_user_journey",
        ),
        CheckConstraint("origin_stop_id <> destination_stop_id", name="distinct_stops"),
    )


class NotificationPreference(UUIDAuditBase):
    """Per-user notification channel opt-in/opt-out. Transactional messages
    (OTP, payment, safety) always bypass promotional opt-out — enforced in
    the notification dispatch service (Phase 9), not here."""

    __tablename__ = "notification_preferences"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    push_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    sms_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    email_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    promotional_opt_in: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    __table_args__ = (UniqueConstraint("user_id", name="uq_notification_preferences_user_id"),)
