"""Database access for saved payment methods."""

from __future__ import annotations

import uuid

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.payments import PaymentMethod
from app.providers.payments.base import PaymentChannel


class PaymentMethodRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_for_user(self, user_id: uuid.UUID) -> list[PaymentMethod]:
        """The default first, then newest first."""
        result = await self._session.execute(
            select(PaymentMethod)
            .where(PaymentMethod.user_id == user_id)
            .order_by(PaymentMethod.is_default.desc(), PaymentMethod.created_at.desc())
        )
        return list(result.scalars().all())

    async def get_for_user(self, method_id: uuid.UUID, user_id: uuid.UUID) -> PaymentMethod | None:
        result = await self._session.execute(
            select(PaymentMethod).where(
                PaymentMethod.id == method_id, PaymentMethod.user_id == user_id
            )
        )
        return result.scalar_one_or_none()

    async def find(
        self, user_id: uuid.UUID, channel: PaymentChannel, phone_number: str
    ) -> PaymentMethod | None:
        result = await self._session.execute(
            select(PaymentMethod).where(
                PaymentMethod.user_id == user_id,
                PaymentMethod.channel == channel,
                PaymentMethod.phone_number == phone_number,
            )
        )
        return result.scalar_one_or_none()

    async def count_for_user(self, user_id: uuid.UUID) -> int:
        result = await self._session.execute(
            select(func.count(PaymentMethod.id)).where(PaymentMethod.user_id == user_id)
        )
        return int(result.scalar_one())

    async def clear_default(self, user_id: uuid.UUID) -> None:
        # Flushed straight away: the partial unique index allows one default
        # per user, so the old one must be cleared before a new one is set.
        await self._session.execute(
            update(PaymentMethod)
            .where(PaymentMethod.user_id == user_id, PaymentMethod.is_default.is_(True))
            .values(is_default=False)
            .execution_options(synchronize_session="fetch")
        )

    async def create(
        self,
        *,
        user_id: uuid.UUID,
        channel: PaymentChannel,
        phone_number: str,
        label: str | None,
        is_default: bool,
    ) -> PaymentMethod:
        method = PaymentMethod(
            user_id=user_id,
            channel=channel,
            phone_number=phone_number,
            label=label,
            is_default=is_default,
        )
        self._session.add(method)
        await self._session.flush()
        return method

    async def delete(self, method: PaymentMethod) -> None:
        await self._session.delete(method)
        await self._session.flush()
