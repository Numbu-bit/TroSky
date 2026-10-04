"""Payment domain models: payments, inbound-webhook audit trail, refund
requests, and the wallet double-entry ledger.

Concurrency-safety design:

* ``payments`` uses the same idempotent-create pattern as ``bookings``
  (``UniqueConstraint(user_id, idempotency_key)``) plus a unique
  ``internal_reference`` — the value sent to the provider as its
  external/reference id and the value inbound webhooks are correlated
  against.
* ``payment_webhook_events`` carries a unique constraint on
  ``(channel, provider_reference, event_status)`` so a literal duplicate
  delivery of the same event is caught by the database (via the same
  SAVEPOINT-and-catch-``IntegrityError`` pattern
  ``BookingRepository.create_seat_reservation`` uses) rather than
  reprocessed — replay protection enforced by the database, not by hoping
  the vendor never redelivers.
* ``wallets``/``wallet_transactions`` follow a classic append-only ledger:
  every balance mutation both row-locks the wallet (``SELECT ... FOR
  UPDATE``, applied in ``WalletRepository``) and appends an immutable
  ``wallet_transactions`` row recording the balance *after* the mutation,
  so the running balance is always reconstructable/auditable from the
  ledger independent of the cached ``wallets.balance_minor_units`` column.
  Amounts are stored as integer minor units (pesewas) — never
  ``Decimal``/``float`` — eliminating rounding ambiguity entirely for the
  one table where it matters most; ``app.core.config.to_minor_units`` /
  ``from_minor_units`` convert at the API boundary.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum
from typing import Any

from sqlalchemy import BigInteger, CheckConstraint, ForeignKey, Index, UniqueConstraint, text
from sqlalchemy import Enum as PgEnum
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import TIMESTAMP, Boolean, Numeric, String

from app.models.base import UUIDAuditBase, enum_values
from app.providers.payments.base import PaymentChannel


class PaymentPurpose(StrEnum):
    BOOKING_PAYMENT = "booking_payment"
    WALLET_TOPUP = "wallet_topup"


class PaymentStatus(StrEnum):
    PENDING = "pending"
    PROCESSING = "processing"
    SUCCESSFUL = "successful"
    FAILED = "failed"
    CANCELLED = "cancelled"
    REFUNDED = "refunded"
    PARTIALLY_REFUNDED = "partially_refunded"


class RefundStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    COMPLETED = "completed"
    FAILED = "failed"


class WalletEntryType(StrEnum):
    CREDIT = "credit"
    DEBIT = "debit"


class WalletReferenceType(StrEnum):
    BOOKING_PAYMENT = "booking_payment"
    WALLET_TOPUP = "wallet_topup"
    REFUND = "refund"
    ADMIN_ADJUSTMENT = "admin_adjustment"
    TRIP_EARNING = "trip_earning"
    WITHDRAWAL = "withdrawal"


class WithdrawalStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    COMPLETED = "completed"
    FAILED = "failed"


class Payment(UUIDAuditBase):
    __tablename__ = "payments"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    booking_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("bookings.id", ondelete="RESTRICT"), nullable=True
    )
    purpose: Mapped[PaymentPurpose] = mapped_column(
        PgEnum(
            PaymentPurpose, name="payment_purpose", native_enum=True, values_callable=enum_values
        ),
        nullable=False,
    )
    channel: Mapped[PaymentChannel] = mapped_column(
        PgEnum(
            PaymentChannel, name="payment_channel", native_enum=True, values_callable=enum_values
        ),
        nullable=False,
    )
    status: Mapped[PaymentStatus] = mapped_column(
        PgEnum(PaymentStatus, name="payment_status", native_enum=True, values_callable=enum_values),
        nullable=False,
        default=PaymentStatus.PENDING,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="GHS")
    refunded_amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False, default=Decimal("0.00"), server_default="0.00"
    )
    payer_phone_number: Mapped[str | None] = mapped_column(String(20), nullable=True)
    internal_reference: Mapped[str] = mapped_column(String(40), nullable=False)
    provider_reference: Mapped[str | None] = mapped_column(String(100), nullable=True)
    idempotency_key: Mapped[uuid.UUID | None] = mapped_column(nullable=True)
    idempotency_request_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    failure_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    initiated_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    version: Mapped[int] = mapped_column(nullable=False, default=1, server_default="1")

    __table_args__ = (
        UniqueConstraint("internal_reference", name="uq_payments_internal_reference"),
        UniqueConstraint("user_id", "idempotency_key", name="uq_payments_user_idempotency_key"),
        CheckConstraint("amount > 0", name="amount_positive"),
        CheckConstraint("refunded_amount >= 0", name="refunded_amount_non_negative"),
        Index("ix_payments_user_id", "user_id"),
        Index("ix_payments_booking_id", "booking_id"),
        Index("ix_payments_status", "status"),
    )

    __mapper_args__ = {"version_id_col": version}  # noqa: RUF012 - SQLAlchemy special attribute


class PaymentWebhookEvent(UUIDAuditBase):
    __tablename__ = "payment_webhook_events"

    channel: Mapped[PaymentChannel] = mapped_column(
        PgEnum(
            PaymentChannel,
            name="payment_channel",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=False,
    )
    provider_reference: Mapped[str] = mapped_column(String(100), nullable=False)
    event_status: Mapped[str] = mapped_column(String(20), nullable=False)
    signature_valid: Mapped[bool] = mapped_column(Boolean, nullable=False)
    payment_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("payments.id", ondelete="SET NULL"), nullable=True
    )
    raw_payload: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False)
    processed_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)

    __table_args__ = (
        UniqueConstraint(
            "channel",
            "provider_reference",
            "event_status",
            name="uq_payment_webhook_events_channel_reference_status",
        ),
        Index("ix_payment_webhook_events_provider_reference", "provider_reference"),
        Index("ix_payment_webhook_events_payment_id", "payment_id"),
    )


class RefundRequest(UUIDAuditBase):
    __tablename__ = "refund_requests"

    payment_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("payments.id", ondelete="RESTRICT"), nullable=False
    )
    booking_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("bookings.id", ondelete="RESTRICT"), nullable=True
    )
    requested_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[RefundStatus] = mapped_column(
        PgEnum(RefundStatus, name="refund_status", native_enum=True, values_callable=enum_values),
        nullable=False,
        default=RefundStatus.PENDING,
    )
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    decision_notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    provider_refund_reference: Mapped[str | None] = mapped_column(String(100), nullable=True)
    failure_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    version: Mapped[int] = mapped_column(nullable=False, default=1, server_default="1")

    __table_args__ = (
        CheckConstraint("amount > 0", name="amount_positive"),
        Index("ix_refund_requests_payment_id", "payment_id"),
        Index("ix_refund_requests_booking_id", "booking_id"),
        Index("ix_refund_requests_status", "status"),
    )

    __mapper_args__ = {"version_id_col": version}  # noqa: RUF012 - SQLAlchemy special attribute


class PaymentMethod(UUIDAuditBase):
    """A mobile money number a user saved to pay with. Only mobile money:
    a card could be saved only as a provider token, which needs a card
    processor TroSky does not have yet."""

    __tablename__ = "payment_methods"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    channel: Mapped[PaymentChannel] = mapped_column(
        PgEnum(
            PaymentChannel,
            name="payment_channel",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=False,
    )
    # E.164; only ever shown masked.
    phone_number: Mapped[str] = mapped_column(String(20), nullable=False)
    label: Mapped[str | None] = mapped_column(String(60), nullable=True)
    is_default: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id", "channel", "phone_number", name="uq_payment_methods_user_number"
        ),
        # At most one default per user.
        Index(
            "uq_payment_methods_one_default",
            "user_id",
            unique=True,
            postgresql_where=text("is_default"),
        ),
    )


class Wallet(UUIDAuditBase):
    __tablename__ = "wallets"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    balance_minor_units: Mapped[int] = mapped_column(
        BigInteger, nullable=False, default=0, server_default="0"
    )
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="GHS")
    # Set while an admin looks into possible fraud: no debits, no payouts.
    frozen_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    frozen_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    frozen_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    version: Mapped[int] = mapped_column(nullable=False, default=1, server_default="1")

    __table_args__ = (
        UniqueConstraint("user_id", name="uq_wallets_user_id"),
        CheckConstraint("balance_minor_units >= 0", name="balance_non_negative"),
    )

    __mapper_args__ = {"version_id_col": version}  # noqa: RUF012 - SQLAlchemy special attribute


class WalletTransaction(UUIDAuditBase):
    """Append-only ledger entry. Never updated or deleted after creation."""

    __tablename__ = "wallet_transactions"

    wallet_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("wallets.id", ondelete="RESTRICT"), nullable=False
    )
    entry_type: Mapped[WalletEntryType] = mapped_column(
        PgEnum(
            WalletEntryType, name="wallet_entry_type", native_enum=True, values_callable=enum_values
        ),
        nullable=False,
    )
    amount_minor_units: Mapped[int] = mapped_column(BigInteger, nullable=False)
    balance_after_minor_units: Mapped[int] = mapped_column(BigInteger, nullable=False)
    reference_type: Mapped[WalletReferenceType] = mapped_column(
        PgEnum(
            WalletReferenceType,
            name="wallet_reference_type",
            native_enum=True,
            values_callable=enum_values,
        ),
        nullable=False,
    )
    reference_id: Mapped[uuid.UUID | None] = mapped_column(nullable=True)
    description: Mapped[str] = mapped_column(String(255), nullable=False)
    idempotency_key: Mapped[str | None] = mapped_column(String(64), nullable=True)

    __table_args__ = (
        CheckConstraint("amount_minor_units > 0", name="amount_minor_units_positive"),
        CheckConstraint("balance_after_minor_units >= 0", name="balance_after_non_negative"),
        UniqueConstraint(
            "wallet_id", "idempotency_key", name="uq_wallet_transactions_wallet_idempotency_key"
        ),
        Index("ix_wallet_transactions_wallet_id", "wallet_id"),
    )


class WithdrawalRequest(UUIDAuditBase):
    """A driver/fleet-owner cashing out their wallet balance to a mobile
    money account. The wallet is debited at *approval* time (funds are
    reserved/removed from the spendable balance immediately, mirroring how
    a real bank hold works) — not at request time (a pending request must
    not tie up funds the requester might still need for something else
    before it's reviewed) and not at completion (a driver shouldn't be
    able to spend money that's already been approved for payout).

    No automated mobile-money disbursement is wired up (see
    ``app.providers.payments.mtn_momo`` — Collections has no payout
    endpoint of its own; a real one needs the separate Disbursements
    product this codebase doesn't have credentials for), so completion is
    an explicit admin action taken once the payout has actually been sent
    by some other means — an honest reflection of what this MVP can
    automate versus what it can only track.
    """

    __tablename__ = "withdrawal_requests"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    channel: Mapped[PaymentChannel] = mapped_column(
        PgEnum(
            PaymentChannel,
            name="payment_channel",
            native_enum=True,
            values_callable=enum_values,
            create_type=False,
        ),
        nullable=False,
    )
    destination_phone_number: Mapped[str] = mapped_column(String(20), nullable=False)
    status: Mapped[WithdrawalStatus] = mapped_column(
        PgEnum(
            WithdrawalStatus,
            name="withdrawal_status",
            native_enum=True,
            values_callable=enum_values,
        ),
        nullable=False,
        default=WithdrawalStatus.PENDING,
    )
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    decision_notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    provider_reference: Mapped[str | None] = mapped_column(String(100), nullable=True)
    failure_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    version: Mapped[int] = mapped_column(nullable=False, default=1, server_default="1")

    __table_args__ = (
        CheckConstraint("amount > 0", name="amount_positive"),
        Index("ix_withdrawal_requests_user_id", "user_id"),
        Index("ix_withdrawal_requests_status", "status"),
    )

    __mapper_args__ = {"version_id_col": version}  # noqa: RUF012 - SQLAlchemy special attribute
