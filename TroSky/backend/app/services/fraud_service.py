"""Fraud detection and review: the rules' settings, the detection run that
raises flags, an admin's review of a flag, and the actions taken on one.

A detection run evaluates every enabled rule. A finding whose fingerprint
has no flag yet raises one (``fraud.flagged`` on the admin stream); one
whose flag is still open or under investigation, and that has grown since
(more failures, more accounts), updates it. A flag that was confirmed or
judged a false positive is left as it is: its incident is closed.
"""

from __future__ import annotations

import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any, Literal

from sqlalchemy import delete, func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.admin_events import announce
from app.core.exceptions import NotFoundError, ValidationAppError
from app.core.logging import get_logger
from app.core.permissions import Permission, SystemRole
from app.models.fraud import (
    BlockedDevice,
    FraudFlag,
    FraudFlagEvent,
    FraudFlagStatus,
    FraudRule,
    FraudSeverity,
)
from app.models.identity import RefreshToken, UserSession
from app.repositories.user_repository import UserRepository
from app.repositories.wallet_repository import WalletRepository
from app.services.admin_service import AdminService
from app.services.fraud_rules import DETECTORS, RULES, Detection, RuleConfig, risk_score

logger = get_logger(__name__)

OPEN_FLAGS = (FraudFlagStatus.OPEN, FraudFlagStatus.INVESTIGATING)
CLOSED_FLAGS = (FraudFlagStatus.CONFIRMED, FraudFlagStatus.FALSE_POSITIVE)
HIGH_RISK = 70

FraudAction = Literal[
    "suspend_account", "freeze_wallet", "unfreeze_wallet", "block_device", "unblock_device"
]


@dataclass(frozen=True, slots=True)
class RuleState:
    key: str
    title: str
    threshold_means: str
    enabled: bool
    threshold: Decimal
    window_minutes: int
    severity: FraudSeverity
    changed: bool
    updated_by: uuid.UUID | None
    updated_at: datetime | None


@dataclass(frozen=True, slots=True)
class DetectionRun:
    raised: int
    updated: int
    by_rule: dict[str, int]


class FraudService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    # -------------------------------------------------------------- rules
    async def rules(self) -> list[RuleState]:
        """Every rule with its settings now: an admin's, or the defaults."""
        stored = {
            row.key: row for row in (await self._session.execute(select(FraudRule))).scalars()
        }
        states = []
        for key, rule in RULES.items():
            row = stored.get(key)
            states.append(
                RuleState(
                    key=key,
                    title=rule.title,
                    threshold_means=rule.threshold_means,
                    enabled=row.enabled if row else True,
                    threshold=row.threshold if row else rule.threshold,
                    window_minutes=row.window_minutes if row else rule.window_minutes,
                    severity=row.severity if row else rule.severity,
                    changed=row is not None,
                    updated_by=row.updated_by if row else None,
                    updated_at=row.updated_at if row else None,
                )
            )
        return states

    async def update_rule(
        self,
        key: str,
        *,
        enabled: bool | None,
        threshold: Decimal | None,
        window_minutes: int | None,
        severity: FraudSeverity | None,
        by: uuid.UUID,
    ) -> RuleState:
        if key not in RULES:
            raise NotFoundError("No such fraud rule.")
        current = next(state for state in await self.rules() if state.key == key)
        row = await self._session.get(FraudRule, key)
        if row is None:
            row = FraudRule(key=key)
            self._session.add(row)
        row.enabled = current.enabled if enabled is None else enabled
        row.threshold = current.threshold if threshold is None else threshold
        row.window_minutes = current.window_minutes if window_minutes is None else window_minutes
        row.severity = current.severity if severity is None else severity
        row.updated_by, row.updated_at = by, datetime.now(UTC)
        await self._session.flush()
        return next(state for state in await self.rules() if state.key == key)

    # ---------------------------------------------------------- detection
    async def detect(self, now: datetime | None = None) -> DetectionRun:
        """Run every enabled rule; raise or update flags."""
        now = now or datetime.now(UTC)
        raised = updated = 0
        by_rule: dict[str, int] = {}
        for state in await self.rules():
            if not state.enabled:
                continue
            config = RuleConfig(
                key=state.key,
                enabled=state.enabled,
                threshold=state.threshold,
                window_minutes=state.window_minutes,
                severity=state.severity,
            )
            detections = await DETECTORS[state.key](self._session, config, now)
            by_rule[state.key] = len(detections)
            for detection in detections:
                outcome = await self._record(config, detection, now)
                raised += outcome == "raised"
                updated += outcome == "updated"
        logger.info("fraud_detection_run", raised=raised, updated=updated)
        return DetectionRun(raised=raised, updated=updated, by_rule=by_rule)

    async def _record(
        self, config: RuleConfig, detection: Detection, now: datetime
    ) -> Literal["raised", "updated", "unchanged"]:
        rule = RULES[config.key]
        score = risk_score(rule, config, detection.observed)
        existing = await self._session.scalar(
            select(FraudFlag).where(FraudFlag.fingerprint == detection.fingerprint)
        )
        if existing is None:
            flag = FraudFlag(
                rule=config.key,
                fingerprint=detection.fingerprint,
                severity=config.severity,
                risk_score=score,
                entity_type=detection.entity_type,
                entity_id=detection.entity_id,
                subject_user_id=detection.subject_user_id,
                summary=detection.summary[:500],
                amount_at_risk=detection.amount_at_risk,
                observed=detection.observed,
                evidence=detection.evidence,
                status=FraudFlagStatus.OPEN,
                first_detected_at=now,
                last_detected_at=now,
                occurrences=1,
            )
            try:
                # Another run may have raised it a moment ago.
                async with self._session.begin_nested():
                    self._session.add(flag)
                    await self._session.flush()
            except IntegrityError:
                return "unchanged"
            self._event(flag, "detected", None, {"observed": str(detection.observed)})
            announce(
                self._session,
                "fraud.flagged",
                flag_id=flag.id,
                rule=flag.rule,
                severity=flag.severity,
                risk_score=flag.risk_score,
                summary=flag.summary,
            )
            return "raised"
        worse = (
            detection.observed < existing.observed
            if rule.below
            else (detection.observed > existing.observed)
        )
        if existing.status not in OPEN_FLAGS or not worse:
            return "unchanged"
        existing.observed = detection.observed
        existing.risk_score = max(existing.risk_score, score)
        existing.summary = detection.summary[:500]
        existing.amount_at_risk = detection.amount_at_risk
        existing.evidence = detection.evidence
        existing.last_detected_at = now
        existing.occurrences += 1
        self._event(existing, "detected_again", None, {"observed": str(detection.observed)})
        await self._session.flush()
        return "updated"

    def _event(
        self, flag: FraudFlag, kind: str, actor: uuid.UUID | None, details: dict[str, Any]
    ) -> None:
        self._session.add(
            FraudFlagEvent(flag_id=flag.id, kind=kind, actor_id=actor, details=details)
        )

    # ------------------------------------------------------------- review
    async def get_flag(self, flag_id: uuid.UUID) -> FraudFlag:
        flag = await self._session.get(FraudFlag, flag_id)
        if flag is None:
            raise NotFoundError("Fraud flag not found.")
        return flag

    async def timeline(self, flag_id: uuid.UUID) -> Sequence[FraudFlagEvent]:
        result = await self._session.execute(
            select(FraudFlagEvent)
            .where(FraudFlagEvent.flag_id == flag_id)
            .order_by(FraudFlagEvent.created_at, FraudFlagEvent.id)
        )
        return result.scalars().all()

    async def update_flag(
        self,
        flag_id: uuid.UUID,
        *,
        status: FraudFlagStatus | None,
        assign: bool,
        assigned_to: uuid.UUID | None,
        reason: str | None,
        by: uuid.UUID,
    ) -> FraudFlag:
        """Assign the flag (or unassign it), or set its status. Confirming
        a flag, or calling it a false positive, needs a reason; either can
        be undone by setting the status back."""
        flag = await self.get_flag(flag_id)
        if assign and assigned_to != flag.assigned_to:
            if assigned_to is not None:
                await self._ensure_reviews_fraud(assigned_to)
            flag.assigned_to = assigned_to
            self._event(flag, "assigned", by, {"assigned_to": str(assigned_to)})
        if status is not None and status != flag.status:
            if status in CLOSED_FLAGS and not (reason and reason.strip()):
                raise ValidationAppError(
                    "Say why the flag is confirmed or a false positive.",
                    details={"param": "reason"},
                )
            self._event(
                flag,
                "status_changed",
                by,
                {"from": flag.status.value, "to": status.value, "reason": reason},
            )
            flag.status = status
            if status in CLOSED_FLAGS:
                flag.reviewed_by, flag.reviewed_at = by, datetime.now(UTC)
                flag.review_reason = reason
            else:
                flag.reviewed_by = flag.reviewed_at = flag.review_reason = None
        await self._session.flush()
        announce(
            self._session,
            "fraud.updated",
            flag_id=flag.id,
            status=flag.status,
            assigned_to=flag.assigned_to,
        )
        return flag

    async def _ensure_reviews_fraud(self, user_id: uuid.UUID) -> None:
        users = UserRepository(self._session)
        user = await users.get_by_id(user_id)
        allowed = False
        if user is not None and user.is_active and not user.is_suspended:
            roles = await users.get_roles_for_user(user_id)
            granted = await users.get_permissions_for_roles(roles)
            allowed = SystemRole.SUPER_ADMIN.value in roles or bool(
                {Permission.FRAUD_VIEW.value, Permission.FRAUD_MANAGE.value} & set(granted)
            )
        if not allowed:
            raise ValidationAppError(
                "Flags can only be assigned to an active admin who reviews fraud.",
                details={"param": "assigned_to"},
            )

    # ------------------------------------------------------------ actions
    async def act(
        self,
        flag_id: uuid.UUID,
        *,
        action: FraudAction,
        reason: str,
        user_id: uuid.UUID | None,
        device_id: str | None,
        by: uuid.UUID,
    ) -> FraudFlagEvent:
        """Suspend the account, freeze its wallet (and so its payouts), or
        block a device -- or undo the last two. The account defaults to the
        flag's subject, the device to the flag's device."""
        flag = await self.get_flag(flag_id)
        target: str
        if action in ("block_device", "unblock_device"):
            device = device_id or (flag.entity_id if flag.entity_type == "device" else None)
            if device is None:
                raise ValidationAppError(
                    "Name the device to act on.", details={"param": "device_id"}
                )
            target = device
            if action == "block_device":
                await self._block_device(device, reason=reason, flag_id=flag.id, by=by)
            else:
                await self._session.execute(
                    delete(BlockedDevice).where(BlockedDevice.device_id == device)
                )
        else:
            account = user_id or flag.subject_user_id
            if account is None:
                raise ValidationAppError(
                    "Name the account to act on.", details={"param": "user_id"}
                )
            target = str(account)
            if action == "suspend_account":
                await AdminService(self._session).suspend_user(
                    account, reason=reason, actioned_by=by
                )
            else:
                await self._freeze(account, frozen=action == "freeze_wallet", reason=reason, by=by)
        if flag.status == FraudFlagStatus.OPEN:
            flag.status = FraudFlagStatus.INVESTIGATING
        event = FraudFlagEvent(
            flag_id=flag.id,
            kind="action",
            actor_id=by,
            details={"action": action, "target": target, "reason": reason},
        )
        self._session.add(event)
        await self._session.flush()
        logger.warning("fraud_action", flag_id=str(flag.id), action=action, target=target)
        announce(self._session, "fraud.updated", flag_id=flag.id, status=flag.status, action=action)
        return event

    async def _block_device(
        self, device_id: str, *, reason: str, flag_id: uuid.UUID, by: uuid.UUID
    ) -> None:
        if (
            await self._session.scalar(
                select(BlockedDevice.id).where(BlockedDevice.device_id == device_id)
            )
            is None
        ):
            self._session.add(
                BlockedDevice(device_id=device_id, reason=reason, blocked_by=by, flag_id=flag_id)
            )
        # Every session on the device ends now; signing in again is refused.
        sessions = select(UserSession.id).where(
            UserSession.device_id == device_id, UserSession.revoked_at.is_(None)
        )
        now = datetime.now(UTC)
        await self._session.execute(
            update(RefreshToken)
            .where(RefreshToken.session_id.in_(sessions), RefreshToken.revoked_at.is_(None))
            .values(revoked_at=now)
        )
        await self._session.execute(
            update(UserSession)
            .where(UserSession.device_id == device_id, UserSession.revoked_at.is_(None))
            .values(revoked_at=now, revoked_reason="device_blocked")
        )
        await self._session.flush()

    async def _freeze(
        self, user_id: uuid.UUID, *, frozen: bool, reason: str, by: uuid.UUID
    ) -> None:
        if await UserRepository(self._session).get_by_id(user_id) is None:
            raise NotFoundError("User not found.")
        wallet = await WalletRepository(self._session).get_or_create_for_update(user_id)
        if frozen:
            wallet.frozen_at = wallet.frozen_at or datetime.now(UTC)
            wallet.frozen_reason, wallet.frozen_by = reason[:500], by
        else:
            wallet.frozen_at = wallet.frozen_reason = wallet.frozen_by = None
        await self._session.flush()

    # -------------------------------------------------------------- stats
    async def open_counts(self) -> tuple[int, int, Decimal]:
        """Flags open or under investigation; of those, high-risk; and the
        money they put at risk."""
        row = (
            await self._session.execute(
                select(
                    func.count(),
                    func.count().filter(FraudFlag.risk_score >= HIGH_RISK),
                    func.coalesce(func.sum(FraudFlag.amount_at_risk), 0),
                ).where(FraudFlag.status.in_(OPEN_FLAGS))
            )
        ).one()
        return int(row[0]), int(row[1]), Decimal(row[2])
