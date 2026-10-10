"""Fraud detection against a real database: what each rule finds, how
findings become flags, how flags are reviewed, and what the actions do.

Other tests' data is in the database too, so tests look for the flags of
their own making (by fingerprint) rather than counting everything found.
"""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import (
    InvalidStateTransitionError,
    NotFoundError,
    TicketValidationError,
    ValidationAppError,
    WalletFrozenError,
)
from app.models.bookings import BookingStatus, BookingStatusHistory
from app.models.fraud import BlockedDevice, FraudFlag, FraudFlagEvent, FraudFlagStatus
from app.models.identity import UserSession
from app.models.payments import (
    Payment,
    PaymentMethod,
    PaymentPurpose,
    PaymentStatus,
    WalletReferenceType,
)
from app.models.tickets import Ticket
from app.models.tracking import TripLocation
from app.models.trips import Trip, TripStatus
from app.providers.payments.base import PaymentChannel
from app.services.fraud_rules import DETECTORS, RULES, Detection, RuleConfig, risk_score
from app.services.fraud_service import FraudService
from app.services.ticket_service import TicketService
from app.services.wallet_service import WalletService
from app.services.withdrawal_service import WithdrawalService
from app.utilities.geo import latlng_to_wkt
from tests.integration.scenarios import TripScenario, book, build_trip_scenario
from tests.integration.test_admin_workflow import _admin

pytestmark = [pytest.mark.integration, pytest.mark.asyncio]


def _config(key: str, **changes: object) -> RuleConfig:
    rule = RULES[key]
    return RuleConfig(
        key=key,
        enabled=True,
        threshold=Decimal(str(changes.get("threshold", rule.threshold))),
        window_minutes=int(str(changes.get("window_minutes", rule.window_minutes))),
        severity=rule.severity,
    )


async def _found(session: AsyncSession, key: str, **changes: object) -> dict[str, Detection]:
    detections = await DETECTORS[key](session, _config(key, **changes), datetime.now(UTC))
    return {detection.fingerprint: detection for detection in detections}


async def _scenario(session: AsyncSession, make_user, *, seats: int = 4) -> TripScenario:
    return await build_trip_scenario(
        session, make_user, departure=datetime.now(UTC) + timedelta(hours=1), seats=seats
    )


async def _failed_payments(
    session: AsyncSession,
    user_id: uuid.UUID,
    count: int,
    *,
    status: PaymentStatus = PaymentStatus.FAILED,
) -> None:
    for _ in range(count):
        session.add(
            Payment(
                user_id=user_id,
                purpose=PaymentPurpose.BOOKING_PAYMENT,
                channel=PaymentChannel.MTN_MOMO,
                status=status,
                amount=Decimal("8.00"),
                internal_reference=f"PAY-{secrets.token_hex(6).upper()}",
                payer_phone_number="+233245550000",
            )
        )
    await session.flush()


async def _complete(session: AsyncSession, trip_id: uuid.UUID) -> None:
    await session.execute(
        update(Trip)
        .where(Trip.id == trip_id)
        .values(status=TripStatus.COMPLETED, actual_arrival_at=datetime.now(UTC))
    )


async def _track(
    session: AsyncSession, trip_id: uuid.UUID, points: list[tuple[float, float, int]]
) -> None:
    """``(latitude, longitude, seconds after the first)`` per position."""
    start = datetime.now(UTC) - timedelta(minutes=30)
    for latitude, longitude, seconds in points:
        session.add(
            TripLocation(
                trip_id=trip_id,
                location=latlng_to_wkt(latitude, longitude),
                recorded_at=start + timedelta(seconds=seconds),
            )
        )
    await session.flush()


# ---------------------------------------------------------------- the rules
class TestTheRules:
    async def test_a_ticket_shown_again_or_on_another_trip(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario, other = (
            await _scenario(db_session, make_user),
            await _scenario(db_session, make_user),
        )
        booking = await book(db_session, (await make_user()).id, scenario, seat=0)
        ticket = await db_session.scalar(select(Ticket).where(Ticket.booking_id == booking.id))
        assert ticket is not None
        tickets = TicketService(db_session)
        code = tickets.get_qr_token(ticket)
        await tickets.validate_qr(
            code, trip_id=scenario.trip_id, validated_by=scenario.driver_user_id
        )

        for _ in range(2):
            with pytest.raises(InvalidStateTransitionError):
                await tickets.validate_qr(
                    code, trip_id=scenario.trip_id, validated_by=scenario.driver_user_id
                )
        with pytest.raises(TicketValidationError):
            await tickets.validate_qr(
                code, trip_id=other.trip_id, validated_by=other.driver_user_id
            )
        kept = db_session.info.get("trosky.keep_on_failure")
        found = (await _found(db_session, "ticket_reused"))[f"ticket_reused:{ticket.id}"]

        assert kept is True  # the refusals outlive the failed requests
        assert found.observed == 3
        assert found.evidence["on_another_trip"] == 1
        assert found.subject_user_id == booking.passenger_id
        assert found.amount_at_risk == booking.fare_amount
        assert set(found.evidence["links"]["trips"]) == {
            str(scenario.trip_id),
            str(other.trip_id),
        }

    async def test_repeated_payment_failures(self, db_session: AsyncSession, make_user) -> None:
        many, few = await make_user(), await make_user()
        await _failed_payments(db_session, many.id, 5)
        await _failed_payments(db_session, few.id, 4)
        await _failed_payments(db_session, few.id, 3, status=PaymentStatus.SUCCESSFUL)

        found = await _found(db_session, "payment_failures")

        today = datetime.now(UTC).date()
        assert found[f"payment_failures:{many.id}:{today}"].observed == 5
        assert f"payment_failures:{few.id}:{today}" not in found
        assert len(found[f"payment_failures:{many.id}:{today}"].evidence["links"]["payments"]) == 5

    async def test_several_accounts_on_one_device(
        self, db_session: AsyncSession, make_user
    ) -> None:
        device = f"device-{secrets.token_hex(6)}"
        users = [await make_user() for _ in range(3)]
        for user in users:
            db_session.add(
                UserSession(user_id=user.id, device_id=device, last_seen_at=datetime.now(UTC))
            )
            # Signed in from a browser, say: no device to share.
            db_session.add(
                UserSession(user_id=user.id, device_id=None, last_seen_at=datetime.now(UTC))
            )
        await db_session.flush()

        found = (await _found(db_session, "shared_device"))[f"shared_device:{device}"]

        assert (found.entity_type, found.entity_id, found.observed) == ("device", device, 3)
        assert "shared_device:None" not in await _found(db_session, "shared_device")
        assert set(found.evidence["links"]["users"]) == {str(user.id) for user in users}
        assert f"shared_device:{device}" not in await _found(
            db_session, "shared_device", threshold=4
        )

    async def test_several_accounts_paying_with_one_number(
        self, db_session: AsyncSession, make_user
    ) -> None:
        number = f"+23324{secrets.randbelow(10**7):07d}"
        for _ in range(3):
            db_session.add(
                PaymentMethod(
                    user_id=(await make_user()).id,
                    channel=PaymentChannel.MTN_MOMO,
                    phone_number=number,
                )
            )
        await db_session.flush()

        found = await _found(db_session, "shared_momo_number")

        assert found[f"shared_momo_number:{number}"].observed == 3

    async def test_reservations_left_to_expire(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user, seats=10)
        passenger, patient = await make_user(), await make_user()
        for seat in range(5, 10):  # held, not expired
            await book(db_session, patient.id, scenario, seat=seat, confirm=False)
        for seat in range(5):
            booking = await book(db_session, passenger.id, scenario, seat=seat, confirm=False)
            db_session.add(
                BookingStatusHistory(
                    booking_id=booking.id,
                    from_status=booking.status,
                    to_status=BookingStatus.EXPIRED,
                    changed_at=datetime.now(UTC),
                )
            )
        await db_session.flush()

        found = await _found(db_session, "expired_reservations")

        [mine] = [d for d in found.values() if d.subject_user_id == passenger.id]
        assert (mine.observed, mine.evidence["seats_held"]) == (5, 5)
        assert patient.id not in {d.subject_user_id for d in found.values()}

    async def test_a_high_share_refunded(self, db_session: AsyncSession, make_user) -> None:
        scenario = await _scenario(db_session, make_user, seats=8)
        passenger, careful = await make_user(), await make_user()
        bookings = [await book(db_session, passenger.id, scenario, seat=seat) for seat in range(4)]
        for booking in bookings[:2]:
            booking.status = BookingStatus.REFUNDED
        others = [await book(db_session, careful.id, scenario, seat=seat) for seat in range(4, 8)]
        others[0].status = BookingStatus.REFUNDED  # a quarter
        await db_session.flush()

        found = await _found(db_session, "refund_share")

        [mine] = [d for d in found.values() if d.subject_user_id == passenger.id]
        assert mine.observed == Decimal("0.5")
        assert careful.id not in {d.subject_user_id for d in found.values()}
        assert mine.amount_at_risk == bookings[0].fare_amount + bookings[1].fare_amount

    async def test_a_trip_that_never_moved(self, db_session: AsyncSession, make_user) -> None:
        still, moving = (
            await _scenario(db_session, make_user),
            await _scenario(db_session, make_user),
        )
        await _track(
            db_session, still.trip_id, [(5.6, -0.2 + i * 0.0001, i * 60) for i in range(5)]
        )
        await _track(
            db_session, moving.trip_id, [(5.6 + i * 0.005, -0.2, i * 60) for i in range(5)]
        )
        for scenario in (still, moving):
            await _complete(db_session, scenario.trip_id)

        found = await _found(db_session, "stationary_trip")

        assert found[f"stationary_trip:{still.trip_id}"].observed < Decimal("0.1")
        assert found[f"stationary_trip:{still.trip_id}"].subject_user_id == still.driver_user_id
        assert f"stationary_trip:{moving.trip_id}" not in found

    async def test_a_jump_no_bus_could_make(self, db_session: AsyncSession, make_user) -> None:
        scenario, slow = (
            await _scenario(db_session, make_user),
            await _scenario(db_session, make_user),
        )
        # 0.01 degrees of latitude (1.1 km) in 10 seconds: ~400 km/h.
        await _track(db_session, scenario.trip_id, [(5.60, -0.2, 0), (5.61, -0.2, 10)])
        # The same in two minutes: ~33 km/h.
        await _track(db_session, slow.trip_id, [(5.60, -0.2, 0), (5.61, -0.2, 120)])

        everything = await _found(db_session, "impossible_speed")
        found = everything[f"impossible_speed:{scenario.trip_id}"]

        assert Decimal("350") < found.observed < Decimal("450")
        assert found.evidence["jumps"] == 1
        assert f"impossible_speed:{slow.trip_id}" not in everything

    async def test_a_driver_who_scans_few_tickets(
        self, db_session: AsyncSession, make_user
    ) -> None:
        scenario = await _scenario(db_session, make_user, seats=10)
        bookings = [
            await book(db_session, (await make_user()).id, scenario, seat=seat)
            for seat in range(10)
        ]
        tickets = TicketService(db_session)
        for booking in bookings[:2]:
            ticket = await db_session.scalar(select(Ticket).where(Ticket.booking_id == booking.id))
            assert ticket is not None
            await tickets.validate_qr(
                tickets.get_qr_token(ticket),
                trip_id=scenario.trip_id,
                validated_by=scenario.driver_user_id,
            )
        await _complete(db_session, scenario.trip_id)

        found = await _found(db_session, "low_scan_compliance")

        [mine] = [d for d in found.values() if d.entity_id == str(scenario.driver_id)]
        assert mine.observed == Decimal("0.2")  # 2 of 10
        assert mine.subject_user_id == scenario.driver_user_id

    async def test_unusual_top_ups(self, db_session: AsyncSession, make_user) -> None:
        big, small = await make_user(), await make_user()
        wallets = WalletService(db_session)
        for user, amount in ((big, "2500.00"), (small, "500.00")):
            await wallets.credit(
                user.id,
                amount=Decimal(amount),
                reference_type=WalletReferenceType.WALLET_TOPUP,
                reference_id=None,
                description="Top-up",
            )

        found = await _found(db_session, "unusual_topups")

        today = datetime.now(UTC).date()
        assert found[f"unusual_topups:{big.id}:{today}"].amount_at_risk == Decimal("2500.00")
        assert f"unusual_topups:{small.id}:{today}" not in found


# ---------------------------------------------------------------- the flags
async def _flag(session: AsyncSession, fingerprint: str) -> FraudFlag:
    flag = await session.scalar(select(FraudFlag).where(FraudFlag.fingerprint == fingerprint))
    assert flag is not None
    return flag


class TestFlags:
    async def test_a_finding_raises_one_flag_and_grows_it(
        self, db_session: AsyncSession, make_user
    ) -> None:
        user = await make_user()
        await _failed_payments(db_session, user.id, 5)
        fraud = FraudService(db_session)
        fingerprint = f"payment_failures:{user.id}:{datetime.now(UTC).date()}"

        await fraud.detect()
        flag = await _flag(db_session, fingerprint)
        first = (flag.status, flag.risk_score, flag.occurrences, flag.observed)
        await fraud.detect()  # nothing new
        unchanged = flag.occurrences
        await _failed_payments(db_session, user.id, 3)
        await fraud.detect()
        events = (
            await db_session.scalars(
                select(FraudFlagEvent.kind)
                .where(FraudFlagEvent.flag_id == flag.id)
                .order_by(FraudFlagEvent.created_at)
            )
        ).all()

        assert first == (FraudFlagStatus.OPEN, 50, 1, 5)
        assert unchanged == 1
        assert (flag.occurrences, flag.observed, flag.risk_score) == (2, 8, 62)
        assert sorted(events) == ["detected", "detected_again"]
        flagged = [
            e for e in db_session.info["trosky.admin_events"] if e["type"] == "fraud.flagged"
        ]
        assert str(flag.id) in {e["data"]["flag_id"] for e in flagged}

    async def test_a_closed_flag_stays_closed(self, db_session: AsyncSession, make_user) -> None:
        user, reviewer = await make_user(), await make_user()
        await _failed_payments(db_session, user.id, 5)
        fraud = FraudService(db_session)
        await fraud.detect()
        flag = await _flag(db_session, f"payment_failures:{user.id}:{datetime.now(UTC).date()}")
        await fraud.update_flag(
            flag.id,
            status=FraudFlagStatus.FALSE_POSITIVE,
            assign=False,
            assigned_to=None,
            reason="The MoMo network was down that hour.",
            by=reviewer.id,
        )

        await _failed_payments(db_session, user.id, 5)
        await fraud.detect()

        assert (flag.status, flag.observed, flag.occurrences) == (
            FraudFlagStatus.FALSE_POSITIVE,
            5,
            1,
        )

    async def test_rule_settings(self, db_session: AsyncSession, make_user) -> None:
        admin, user = await make_user(), await make_user()
        await _failed_payments(db_session, user.id, 3)
        fraud = FraudService(db_session)
        fingerprint = f"payment_failures:{user.id}:{datetime.now(UTC).date()}"

        state = await fraud.update_rule(
            "payment_failures",
            enabled=None,
            threshold=Decimal("3"),
            window_minutes=None,
            severity=None,
            by=admin.id,
        )
        await fraud.detect()
        lowered = await db_session.scalar(
            select(FraudFlag.id).where(FraudFlag.fingerprint == fingerprint)
        )
        await fraud.update_rule(
            "payment_failures",
            enabled=False,
            threshold=None,
            window_minutes=None,
            severity=None,
            by=admin.id,
        )
        run = await fraud.detect()

        assert (state.threshold, state.changed, state.window_minutes) == (Decimal("3"), True, 60)
        assert lowered is not None
        assert "payment_failures" not in run.by_rule

    async def test_an_unknown_rule(self, db_session: AsyncSession, make_user) -> None:
        with pytest.raises(NotFoundError):
            await FraudService(db_session).update_rule(
                "astrology",
                enabled=False,
                threshold=None,
                window_minutes=None,
                severity=None,
                by=(await make_user()).id,
            )


class TestReview:
    async def _raised(self, session: AsyncSession, make_user) -> FraudFlag:
        user = await make_user()
        await _failed_payments(session, user.id, 5)
        await FraudService(session).detect()
        return await _flag(session, f"payment_failures:{user.id}:{datetime.now(UTC).date()}")

    async def test_confirming_needs_a_reason_and_can_be_undone(
        self, db_session: AsyncSession, make_user
    ) -> None:
        flag, reviewer = await self._raised(db_session, make_user), await make_user()
        fraud = FraudService(db_session)

        with pytest.raises(ValidationAppError):
            await fraud.update_flag(
                flag.id,
                status=FraudFlagStatus.CONFIRMED,
                assign=False,
                assigned_to=None,
                reason=" ",
                by=reviewer.id,
            )
        await fraud.update_flag(
            flag.id,
            status=FraudFlagStatus.CONFIRMED,
            assign=False,
            assigned_to=None,
            reason="Card testing from a burner number.",
            by=reviewer.id,
        )
        confirmed = (flag.reviewed_by, flag.review_reason)
        await fraud.update_flag(
            flag.id,
            status=FraudFlagStatus.OPEN,
            assign=False,
            assigned_to=None,
            reason=None,
            by=reviewer.id,
        )

        assert confirmed == (reviewer.id, "Card testing from a burner number.")
        assert (flag.status, flag.reviewed_by, flag.review_reason) == (
            FraudFlagStatus.OPEN,
            None,
            None,
        )

    async def test_only_fraud_reviewers_are_assigned(
        self, db_session: AsyncSession, make_user
    ) -> None:
        flag = await self._raised(db_session, make_user)
        reviewer, passenger = await _admin(db_session, make_user), await make_user()
        fraud = FraudService(db_session)

        with pytest.raises(ValidationAppError):
            await fraud.update_flag(
                flag.id,
                status=None,
                assign=True,
                assigned_to=passenger.id,
                reason=None,
                by=reviewer.id,
            )
        await fraud.update_flag(
            flag.id, status=None, assign=True, assigned_to=reviewer.id, reason=None, by=reviewer.id
        )

        assert flag.assigned_to == reviewer.id


class TestActions:
    async def _raised(self, session: AsyncSession, make_user):
        user = await make_user()
        await _failed_payments(session, user.id, 5)
        await FraudService(session).detect()
        flag = await _flag(session, f"payment_failures:{user.id}:{datetime.now(UTC).date()}")
        return flag, user

    async def test_freezing_a_wallet_stops_money_leaving_it(
        self, db_session: AsyncSession, make_user
    ) -> None:
        flag, user = await self._raised(db_session, make_user)
        admin = await make_user()
        wallets = WalletService(db_session)
        await wallets.credit(
            user.id,
            amount=Decimal("50.00"),
            reference_type=WalletReferenceType.WALLET_TOPUP,
            reference_id=None,
            description="Top-up",
        )
        fraud = FraudService(db_session)

        event = await fraud.act(
            flag.id,
            action="freeze_wallet",
            reason="Looking into it",
            user_id=None,
            device_id=None,
            by=admin.id,
        )
        with pytest.raises(WalletFrozenError):
            await wallets.debit(
                user.id,
                amount=Decimal("10.00"),
                reference_type=WalletReferenceType.BOOKING_PAYMENT,
                reference_id=None,
                description="A fare",
            )
        with pytest.raises(WalletFrozenError):
            await WithdrawalService(db_session).request_withdrawal(
                user.id,
                amount=Decimal("20.00"),
                channel=PaymentChannel.MTN_MOMO,
                destination_phone_number="+233245550000",
            )
        clawed_back = await wallets.debit(  # an admin's adjustment still may
            user.id,
            amount=Decimal("5.00"),
            reference_type=WalletReferenceType.ADMIN_ADJUSTMENT,
            reference_id=admin.id,
            description="Recovered",
        )
        await fraud.act(
            flag.id,
            action="unfreeze_wallet",
            reason="All clear",
            user_id=None,
            device_id=None,
            by=admin.id,
        )
        paid = await wallets.debit(
            user.id,
            amount=Decimal("10.00"),
            reference_type=WalletReferenceType.BOOKING_PAYMENT,
            reference_id=None,
            description="A fare",
        )

        assert event.details == {
            "action": "freeze_wallet",
            "target": str(user.id),
            "reason": "Looking into it",
        }
        assert flag.status == FraudFlagStatus.INVESTIGATING
        assert clawed_back.amount_minor_units == 500
        assert paid.amount_minor_units == 1000

    async def test_suspending_the_account(self, db_session: AsyncSession, make_user) -> None:
        flag, user = await self._raised(db_session, make_user)

        await FraudService(db_session).act(
            flag.id,
            action="suspend_account",
            reason="Confirmed card testing",
            user_id=None,
            device_id=None,
            by=(await make_user()).id,
        )

        assert user.is_suspended is True

    async def test_blocking_a_device_ends_its_sessions(
        self, db_session: AsyncSession, make_user
    ) -> None:
        flag, user = await self._raised(db_session, make_user)
        device = f"device-{secrets.token_hex(6)}"
        signed_in = UserSession(user_id=user.id, device_id=device, last_seen_at=datetime.now(UTC))
        db_session.add(signed_in)
        await db_session.flush()
        fraud = FraudService(db_session)
        admin = await make_user()

        await fraud.act(
            flag.id,
            action="block_device",
            reason="Farm of accounts",
            user_id=None,
            device_id=device,
            by=admin.id,
        )
        await db_session.refresh(signed_in)
        blocked = await db_session.scalar(
            select(BlockedDevice).where(BlockedDevice.device_id == device)
        )
        await fraud.act(
            flag.id,
            action="unblock_device",
            reason="Wrong phone",
            user_id=None,
            device_id=device,
            by=admin.id,
        )
        unblocked = await db_session.scalar(
            select(BlockedDevice.id).where(BlockedDevice.device_id == device)
        )

        assert blocked is not None
        assert blocked.flag_id == flag.id
        assert signed_in.revoked_reason == "device_blocked"
        assert unblocked is None

    async def test_an_action_needs_a_target(self, db_session: AsyncSession, make_user) -> None:
        flag, _ = await self._raised(db_session, make_user)

        with pytest.raises(ValidationAppError):
            await FraudService(db_session).act(
                flag.id,
                action="block_device",  # a user's flag names no device
                reason="Why not",
                user_id=None,
                device_id=None,
                by=(await make_user()).id,
            )


class TestRiskScores:
    async def test_from_the_severity_up_to_twenty_more(self) -> None:
        rule = RULES["payment_failures"]  # medium: 50
        config = _config("payment_failures")

        assert risk_score(rule, config, Decimal("5")) == 50  # at the threshold
        assert risk_score(rule, config, Decimal("8")) == 62  # 1.6 times
        assert risk_score(rule, config, Decimal("50")) == 70  # capped

    async def test_rules_where_less_is_worse(self) -> None:
        rule = RULES["stationary_trip"]  # medium; 0.2 km at most
        config = _config("stationary_trip")

        assert risk_score(rule, config, Decimal("0.2")) == 50
        assert risk_score(rule, config, Decimal("0.1")) == 70
        assert risk_score(rule, config, Decimal("0")) == 70
