"""Drivers must renew their insurance within 30 days of it expiring.

Once a driver's insurance has expired they are warned, along with the fleet
owners whose vehicles they drive. If it still hasn't been renewed after
``INSURANCE_GRACE_DAYS`` days, the driver is blocked: they can't accept or start
trips, and they come off the trips they haven't begun. A trip already boarding
or under way carries on, because its passengers are on board.

A blocked driver can still sign in, because they need to upload the renewal.
That's why this sets ``drivers.status`` rather than ``users.is_suspended``, which
refuses sign-in. When an admin confirms a later date they are unblocked at once.

Only dates an admin has confirmed count, so a driver with no confirmed date is
left alone rather than blocked for a gap in the records.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from enum import StrEnum
from typing import Literal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import NotFoundError
from app.core.logging import get_logger
from app.models.drivers import ApprovalStatus, Driver
from app.models.notifications import NotificationCategory
from app.repositories.driver_repository import DriverRepository
from app.repositories.insurance_repository import InsuranceRepository
from app.services.notification_service import NotificationService
from app.services.trip_service import TripService

logger = get_logger(__name__)

BLOCK_REASON = "insurance_expired"
WARNING_ACTION = "insurance_warning"


class InsuranceOutcome(StrEnum):
    NOTHING = "nothing"
    WARNED = "warned"
    BLOCKED = "blocked"
    UNBLOCKED = "unblocked"


@dataclass(frozen=True, slots=True)
class InsuranceStanding:
    status: Literal["unknown", "valid", "expired", "blocked"]
    expiry_date: date | None
    renew_by: date | None


def _today() -> date:
    return datetime.now(UTC).date()


def _day(value: date) -> str:
    return f"{value:%d %b %Y}"


class InsuranceService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self._session = session
        self._settings = settings or get_settings()
        self._insurance = InsuranceRepository(session)
        self._drivers = DriverRepository(session)
        self._notifications = NotificationService(session)

    def _renew_by(self, expiry: date) -> date:
        return expiry + timedelta(days=self._settings.INSURANCE_GRACE_DAYS)

    async def _blocked_for_insurance(self, driver: Driver) -> bool:
        if driver.status != ApprovalStatus.SUSPENDED:
            return False
        reason = await self._insurance.last_suspension_reason(driver.id)
        return reason is not None and reason.startswith(BLOCK_REASON)

    async def standing(self, driver: Driver, *, today: date | None = None) -> InsuranceStanding:
        """What to show the driver about their insurance."""
        today = today or _today()
        expiry = (await self._insurance.latest_expiries([driver.id])).get(driver.id)
        if await self._blocked_for_insurance(driver):
            return InsuranceStanding(status="blocked", expiry_date=expiry, renew_by=None)
        if expiry is None:
            return InsuranceStanding(status="unknown", expiry_date=None, renew_by=None)
        if expiry >= today:
            return InsuranceStanding(status="valid", expiry_date=expiry, renew_by=None)
        return InsuranceStanding(
            status="expired", expiry_date=expiry, renew_by=self._renew_by(expiry)
        )

    async def check_driver(
        self, driver_id: uuid.UUID, *, today: date | None = None
    ) -> InsuranceOutcome:
        """Warn, block or unblock this driver, if it's due. Safe to repeat."""
        today = today or _today()
        driver = await self._drivers.get_by_id(driver_id)
        if driver is None:
            raise NotFoundError("Driver not found.")
        expiry = (await self._insurance.latest_expiries([driver_id])).get(driver_id)

        if await self._blocked_for_insurance(driver):
            if expiry is None or expiry < today:
                return InsuranceOutcome.NOTHING
            await self._unblock(driver, expiry)
            return InsuranceOutcome.UNBLOCKED
        if driver.status != ApprovalStatus.APPROVED or expiry is None or expiry >= today:
            return InsuranceOutcome.NOTHING

        days_late = (today - expiry).days
        if days_late > self._settings.INSURANCE_GRACE_DAYS:
            await self._block(driver, expiry)
            return InsuranceOutcome.BLOCKED
        return await self._warn_if_due(driver, expiry, days_late)

    async def _warn_if_due(self, driver: Driver, expiry: date, days_late: int) -> InsuranceOutcome:
        """The latest warning due, once: if the worker slept through some,
        the driver gets one warning rather than several at once."""
        due = max(
            (day for day in self._settings.insurance_warning_days if day <= days_late),
            default=None,
        )
        if due is None:
            return InsuranceOutcome.NOTHING
        sent = await self._insurance.warning_days_sent(
            driver.user_id, action=WARNING_ACTION, expiry=expiry
        )
        if sent and max(sent) >= due:
            return InsuranceOutcome.NOTHING

        renew_by = self._renew_by(expiry)
        data = {
            "action": WARNING_ACTION,
            "expiry_date": expiry.isoformat(),
            "renew_by": renew_by.isoformat(),
            "day": due,
        }
        await self._notifications.notify(
            driver.user_id,
            category=NotificationCategory.TRANSACTIONAL,
            title="Renew your insurance",
            body=(
                f"Your insurance expired on {_day(expiry)}. Renew it by {_day(renew_by)}, or your "
                "driver account will be blocked. Upload the new document in the app."
            ),
            data=data,
        )
        await self._tell_fleet_owners(
            driver,
            title="A driver's insurance has expired",
            body=(
                f"Insurance for {await self._name(driver)} expired on {_day(expiry)}. Unless it's "
                f"renewed by {_day(renew_by)}, their driver account will be blocked."
            ),
            data=data,
        )
        logger.info("insurance_warning_sent", driver_id=str(driver.id), day=due)
        return InsuranceOutcome.WARNED

    async def _block(self, driver: Driver, expiry: date) -> None:
        await self._drivers.set_status(
            driver,
            new_status=ApprovalStatus.SUSPENDED,
            changed_by=None,
            reason=f"{BLOCK_REASON}: expired {expiry.isoformat()}",
        )
        trips = await TripService(self._session).withdraw_driver_from_upcoming_trips(
            driver.id, reason="Their insurance has expired."
        )
        data = {"action": "insurance_blocked", "expiry_date": expiry.isoformat()}
        await self._notifications.notify(
            driver.user_id,
            category=NotificationCategory.TRANSACTIONAL,
            title="Your driver account is blocked",
            body=(
                f"Your insurance expired on {_day(expiry)} and wasn't renewed within "
                f"{self._settings.INSURANCE_GRACE_DAYS} days, so you can't take trips. Upload the "
                "new document in the app. You'll be unblocked once it's confirmed."
            ),
            data=data,
        )
        await self._tell_fleet_owners(
            driver,
            title="A driver has been blocked",
            body=(
                f"{await self._name(driver)} can't take trips because their insurance, which "
                f"expired on {_day(expiry)}, wasn't renewed."
            ),
            data=data,
        )
        logger.warning(
            "driver_blocked_insurance_expired",
            driver_id=str(driver.id),
            trips_withdrawn=len(trips),
        )

    async def _unblock(self, driver: Driver, expiry: date) -> None:
        await self._drivers.set_status(
            driver,
            new_status=ApprovalStatus.APPROVED,
            changed_by=None,
            reason=f"insurance_renewed: expires {expiry.isoformat()}",
        )
        await self._notifications.notify(
            driver.user_id,
            category=NotificationCategory.TRANSACTIONAL,
            title="Your driver account is unblocked",
            body=f"Your insurance is confirmed until {_day(expiry)}. You can take trips again.",
            data={"action": "insurance_unblocked", "expiry_date": expiry.isoformat()},
        )
        logger.info("driver_unblocked_insurance_renewed", driver_id=str(driver.id))

    async def _name(self, driver: Driver) -> str:
        return await self._insurance.full_name(driver.user_id) or "One of your drivers"

    async def _tell_fleet_owners(
        self, driver: Driver, *, title: str, body: str, data: dict[str, object]
    ) -> None:
        for owner in await self._insurance.fleet_owners_of_driver(driver.id):
            if owner != driver.user_id:  # an owner-driver has already been told
                await self._notifications.notify(
                    owner,
                    category=NotificationCategory.TRANSACTIONAL,
                    title=title,
                    body=body,
                    data={**data, "driver_id": str(driver.id)},
                )
