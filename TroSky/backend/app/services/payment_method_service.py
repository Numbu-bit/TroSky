"""Mobile money numbers a passenger saved to pay with.

Only mobile money can be saved. A card would have to be stored as a token
from a card processor, and TroSky does not have one yet; saving the card
number itself is out of the question.

The full number is kept, since paying needs it, but every response shows
it masked. A saved method is then used by id: ``payment_method_id`` on
``POST /bookings/{id}/pay`` and on wallet top-ups.
"""

from __future__ import annotations

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import ConflictError, NotFoundError, ValidationAppError
from app.models.payments import PaymentMethod
from app.providers.payments.base import PaymentChannel
from app.repositories.payment_method_repository import PaymentMethodRepository
from app.utilities.phone import InvalidPhoneNumberError, normalize_phone_number

SAVABLE_CHANNELS = frozenset(
    {PaymentChannel.MTN_MOMO, PaymentChannel.TELECEL_CASH, PaymentChannel.AIRTELTIGO_MONEY}
)


class PaymentMethodService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self._settings = settings or get_settings()
        self._methods = PaymentMethodRepository(session)

    async def list_methods(self, user_id: uuid.UUID) -> list[PaymentMethod]:
        return await self._methods.list_for_user(user_id)

    async def get_method(self, user_id: uuid.UUID, method_id: uuid.UUID) -> PaymentMethod:
        method = await self._methods.get_for_user(method_id, user_id)
        if method is None:
            raise NotFoundError("Payment method not found.")
        return method

    async def add_method(
        self,
        user_id: uuid.UUID,
        *,
        channel: PaymentChannel,
        phone_number: str,
        label: str | None,
        make_default: bool,
    ) -> PaymentMethod:
        if channel not in SAVABLE_CHANNELS:
            raise ValidationAppError(
                "Only mobile money numbers can be saved.",
                details={"allowed_channels": sorted(c.value for c in SAVABLE_CHANNELS)},
            )
        try:
            number = normalize_phone_number(phone_number)
        except InvalidPhoneNumberError as exc:
            raise ValidationAppError(
                "Enter a valid mobile money number.", details={"field": "phone_number"}
            ) from exc
        if await self._methods.find(user_id, channel, number) is not None:
            raise ConflictError(
                "This number is already saved for that network.", code="PAYMENT_METHOD_EXISTS"
            )
        existing = await self._methods.count_for_user(user_id)
        limit = self._settings.PAYMENT_METHODS_MAX_PER_USER
        if existing >= limit:
            raise ConflictError(
                f"You can save up to {limit} payment methods.",
                code="PAYMENT_METHODS_LIMIT_REACHED",
                details={"limit": limit},
            )
        # The first one saved is the default whatever was asked.
        is_default = make_default or existing == 0
        if is_default:
            await self._methods.clear_default(user_id)
        return await self._methods.create(
            user_id=user_id,
            channel=channel,
            phone_number=number,
            label=label,
            is_default=is_default,
        )

    async def update_method(
        self,
        user_id: uuid.UUID,
        method_id: uuid.UUID,
        *,
        label: str | None,
        label_given: bool,
        make_default: bool,
    ) -> PaymentMethod:
        method = await self.get_method(user_id, method_id)
        if make_default and not method.is_default:
            await self._methods.clear_default(user_id)
            method.is_default = True
        if label_given:
            method.label = label
        return method

    async def delete_method(self, user_id: uuid.UUID, method_id: uuid.UUID) -> None:
        """Remove a saved method. When it was the default, the newest one
        left becomes the default, so there always is one while any exist."""
        method = await self.get_method(user_id, method_id)
        was_default = method.is_default
        await self._methods.delete(method)
        if was_default:
            remaining = await self._methods.list_for_user(user_id)
            if remaining:
                remaining[0].is_default = True
