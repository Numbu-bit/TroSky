"""Payment, wallet, and inbound-webhook endpoints.

``POST /payments/webhooks/{channel}`` is deliberately unauthenticated (no
``Authorization`` header — the caller is a payment provider, not one of our
users) and reads the raw request body directly rather than binding to a
Pydantic model, because signature verification must run against the exact
bytes the provider signed before any of it is trusted or parsed as JSON.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Request, status

from app.api.dependencies import (
    CurrentPrincipal,
    OptionalIdempotencyKey,
    Pagination,
    PaymentServiceDep,
    WalletServiceDep,
    WithdrawalServiceDep,
)
from app.api.payment_dependencies import PaymentMethodServiceDep
from app.api.v1.views import payment_source
from app.core.config import from_minor_units
from app.core.permissions import Permission
from app.core.ratelimit import rate_limit
from app.models.payments import Payment, WalletReferenceType
from app.providers.payments.base import PaymentChannel
from app.schemas.common import MessageResponse, PaginatedResponse
from app.schemas.payment import (
    PaymentResponse,
    WalletResponse,
    WalletTopupRequest,
    WalletTransactionResponse,
)
from app.schemas.withdrawal import RequestWithdrawalRequest, WithdrawalResponse

router = APIRouter()


def _payment_response(payment: Payment) -> PaymentResponse:
    return PaymentResponse.model_validate(payment)


@router.post("/payments/webhooks/{channel}", response_model=MessageResponse)
# The same for PUT, left out of the API description (one operation there).
@router.put(
    "/payments/webhooks/{channel}", response_model=MessageResponse, include_in_schema=False
)
async def receive_payment_webhook(
    channel: PaymentChannel, request: Request, service: PaymentServiceDep
) -> MessageResponse:
    """A payment provider reports an outcome. POST or PUT: MTN MoMo has
    been seen to call back with either. An MTN callback is not believed
    itself: the payment it names is checked with MTN."""
    raw_body = await request.body()
    await service.process_webhook(channel, dict(request.headers), raw_body)
    return MessageResponse(message="Received.")


@router.get("/payments", response_model=PaginatedResponse[PaymentResponse])
async def list_my_payments(
    principal: CurrentPrincipal, service: PaymentServiceDep, pagination: Pagination
) -> PaginatedResponse[PaymentResponse]:
    payments, total = await service.list_own_payments(
        principal.user_id, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[_payment_response(p) for p in payments],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.get("/payments/{payment_id}", response_model=PaymentResponse)
async def get_payment(
    payment_id: uuid.UUID, principal: CurrentPrincipal, service: PaymentServiceDep
) -> PaymentResponse:
    is_privileged = principal.has_permission(Permission.PAYMENTS_REVIEW)
    payment = await service.get_payment(
        payment_id, requesting_user_id=principal.user_id, is_privileged=is_privileged
    )
    return _payment_response(payment)


@router.post("/payments/{payment_id}/sync", response_model=PaymentResponse)
async def sync_payment(
    payment_id: uuid.UUID, principal: CurrentPrincipal, service: PaymentServiceDep
) -> PaymentResponse:
    """Manually re-polls the provider for a payment stuck pending — the
    passenger-facing fallback for a delayed webhook (ownership-checked via
    ``get_payment`` first; the sync call itself trusts the id after that)."""
    await service.get_payment(payment_id, requesting_user_id=principal.user_id)
    payment = await service.sync_payment_status(payment_id)
    return _payment_response(payment)


@router.post(
    "/wallet/topups",
    response_model=PaymentResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit("payments:initiate"))],
)
async def create_wallet_topup(
    body: WalletTopupRequest,
    principal: CurrentPrincipal,
    service: PaymentServiceDep,
    methods: PaymentMethodServiceDep,
    idempotency_key: OptionalIdempotencyKey,
) -> PaymentResponse:
    channel, payer_phone = await payment_source(body, principal.user_id, methods)
    payment = await service.initiate_wallet_topup(
        principal.user_id,
        amount=body.amount,
        channel=channel,
        payer_phone=payer_phone,
        idempotency_key=idempotency_key,
    )
    return _payment_response(payment)


@router.get("/wallet", response_model=WalletResponse)
async def get_wallet(principal: CurrentPrincipal, service: WalletServiceDep) -> WalletResponse:
    balance = await service.get_balance(principal.user_id)
    return WalletResponse(balance=balance)


@router.get("/wallet/transactions", response_model=PaginatedResponse[WalletTransactionResponse])
async def list_wallet_transactions(
    principal: CurrentPrincipal,
    service: WalletServiceDep,
    pagination: Pagination,
    reference_type: WalletReferenceType | None = None,
) -> PaginatedResponse[WalletTransactionResponse]:
    """Newest first. ``reference_type`` narrows to one kind of entry --
    ``trip_earning`` lists a driver's earnings."""
    transactions, total = await service.list_transactions(
        principal.user_id,
        reference_type=reference_type,
        limit=pagination.limit,
        offset=pagination.offset,
    )
    items = [
        WalletTransactionResponse(
            id=t.id,
            entry_type=t.entry_type,
            amount=from_minor_units(t.amount_minor_units),
            balance_after=from_minor_units(t.balance_after_minor_units),
            reference_type=t.reference_type,
            reference_id=t.reference_id,
            description=t.description,
            created_at=t.created_at,
        )
        for t in transactions
    ]
    return PaginatedResponse(
        items=items, total=total, limit=pagination.limit, offset=pagination.offset
    )


@router.post(
    "/wallet/withdrawals", response_model=WithdrawalResponse, status_code=status.HTTP_201_CREATED
)
async def request_withdrawal(
    body: RequestWithdrawalRequest, principal: CurrentPrincipal, service: WithdrawalServiceDep
) -> WithdrawalResponse:
    """Requests a payout of the caller's own wallet balance to a mobile
    money number. The wallet is not debited yet — only once an admin
    approves the request (``POST /admin/withdrawals/{id}/approve``)."""
    withdrawal = await service.request_withdrawal(
        principal.user_id,
        amount=body.amount,
        channel=body.channel,
        destination_phone_number=body.destination_phone_number,
    )
    return WithdrawalResponse.model_validate(withdrawal)


@router.get("/wallet/withdrawals", response_model=PaginatedResponse[WithdrawalResponse])
async def list_my_withdrawals(
    principal: CurrentPrincipal, service: WithdrawalServiceDep, pagination: Pagination
) -> PaginatedResponse[WithdrawalResponse]:
    withdrawals, total = await service.list_own_withdrawals(
        principal.user_id, limit=pagination.limit, offset=pagination.offset
    )
    return PaginatedResponse(
        items=[WithdrawalResponse.model_validate(w) for w in withdrawals],
        total=total,
        limit=pagination.limit,
        offset=pagination.offset,
    )


@router.get("/wallet/withdrawals/{withdrawal_id}", response_model=WithdrawalResponse)
async def get_my_withdrawal(
    withdrawal_id: uuid.UUID, principal: CurrentPrincipal, service: WithdrawalServiceDep
) -> WithdrawalResponse:
    is_privileged = principal.has_permission(Permission.WITHDRAWALS_REVIEW)
    withdrawal = await service.get_withdrawal(
        withdrawal_id, requesting_user_id=principal.user_id, is_privileged=is_privileged
    )
    return WithdrawalResponse.model_validate(withdrawal)
