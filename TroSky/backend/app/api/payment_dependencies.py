"""Money: payments, the in-app wallet, refunds and driver withdrawals."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends

from app.api.common_dependencies import DbSession
from app.services.payment_method_service import PaymentMethodService
from app.services.payment_service import PaymentService
from app.services.refund_service import RefundService
from app.services.wallet_service import WalletService
from app.services.withdrawal_service import WithdrawalService


def get_payment_service(db: DbSession) -> PaymentService:
    return PaymentService(db)


def get_payment_method_service(db: DbSession) -> PaymentMethodService:
    return PaymentMethodService(db)


def get_wallet_service(db: DbSession) -> WalletService:
    return WalletService(db)


def get_refund_service(db: DbSession) -> RefundService:
    return RefundService(db)


def get_withdrawal_service(db: DbSession) -> WithdrawalService:
    return WithdrawalService(db)


PaymentServiceDep = Annotated[PaymentService, Depends(get_payment_service)]
WalletServiceDep = Annotated[WalletService, Depends(get_wallet_service)]
PaymentMethodServiceDep = Annotated[PaymentMethodService, Depends(get_payment_method_service)]
RefundServiceDep = Annotated[RefundService, Depends(get_refund_service)]
WithdrawalServiceDep = Annotated[WithdrawalService, Depends(get_withdrawal_service)]
