"""Authentication and session management endpoints."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Request, status

from app.api.dependencies import AuthServiceDep, CurrentPrincipal
from app.core.ratelimit import rate_limit
from app.schemas.auth import (
    ForgotPasswordRequest,
    LoginRequest,
    OtpLoginRequest,
    RefreshRequest,
    RegisterRequest,
    RegisterResponse,
    ResendOtpRequest,
    ResetPasswordRequest,
    SessionResponse,
    TokenPairResponse,
    VerifyOtpRequest,
)
from app.schemas.common import MessageResponse

router = APIRouter()


def _client_ip(request: Request) -> str | None:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else None


@router.post(
    "/register",
    response_model=RegisterResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit("auth:register"))],
)
async def register(body: RegisterRequest, auth: AuthServiceDep) -> RegisterResponse:
    """Register a passenger, driver, or fleet-owner account. Never creates
    an administrator account — see README security notes."""
    user, otp_target = await auth.register(body)
    return RegisterResponse(user_id=user.id, phone_number=user.phone_number, otp_sent_to=otp_target)


@router.post(
    "/verify-otp",
    response_model=MessageResponse,
    dependencies=[Depends(rate_limit("auth:otp_verify"))],
)
async def verify_otp(body: VerifyOtpRequest, auth: AuthServiceDep) -> MessageResponse:
    """Verify an OTP for the given purpose. For ``registration`` /
    ``phone_verification`` / ``email_verification``, this also marks the
    corresponding contact detail as verified."""
    await auth.verify_otp(body.target, body.purpose, body.code)
    return MessageResponse(message="OTP verified successfully.")


@router.post(
    "/resend-otp",
    response_model=MessageResponse,
    dependencies=[Depends(rate_limit("auth:otp_request"))],
)
async def resend_otp(body: ResendOtpRequest, auth: AuthServiceDep) -> MessageResponse:
    """Request a new OTP for a given target and purpose (registration,
    login, phone/email verification, or password reset)."""
    await auth.resend_otp(body.target, body.purpose, body.channel)
    return MessageResponse(message="A new verification code has been sent.")


@router.post(
    "/login",
    response_model=TokenPairResponse,
    dependencies=[Depends(rate_limit("auth:login"))],
)
async def login(body: LoginRequest, request: Request, auth: AuthServiceDep) -> TokenPairResponse:
    """Authenticate with a phone number or email + password."""
    return await auth.login_password(
        body.identifier, body.password, body.device, _client_ip(request)
    )


@router.post(
    "/otp-login",
    response_model=TokenPairResponse,
    dependencies=[Depends(rate_limit("auth:login"))],
)
async def otp_login(
    body: OtpLoginRequest, request: Request, auth: AuthServiceDep
) -> TokenPairResponse:
    """Passwordless login: complete with a code previously requested via
    ``POST /auth/resend-otp`` with ``purpose=login``."""
    return await auth.login_otp(body.target, body.code, body.device, _client_ip(request))


@router.post(
    "/refresh",
    response_model=TokenPairResponse,
    dependencies=[Depends(rate_limit("auth:token_refresh"))],
)
async def refresh(body: RefreshRequest, auth: AuthServiceDep) -> TokenPairResponse:
    """Rotate the refresh token and issue a new access/refresh token pair."""
    return await auth.refresh_tokens(body.refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def logout(principal: CurrentPrincipal, auth: AuthServiceDep) -> None:
    """Log out the current device (revokes the current session only)."""
    await auth.logout(principal.session_id)


@router.post("/logout-all", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
async def logout_all(principal: CurrentPrincipal, auth: AuthServiceDep) -> None:
    """Log out every device (revokes all sessions for this account)."""
    await auth.logout_all(principal.user_id)


@router.post(
    "/password/forgot",
    response_model=MessageResponse,
    dependencies=[Depends(rate_limit("auth:password_reset"))],
)
async def forgot_password(body: ForgotPasswordRequest, auth: AuthServiceDep) -> MessageResponse:
    """Request a password reset code. Always returns success, whether or
    not an account exists for the given identifier (prevents enumeration)."""
    await auth.forgot_password(body.identifier)
    return MessageResponse(message="If an account exists, a reset code has been sent.")


@router.post(
    "/password/reset",
    response_model=MessageResponse,
    dependencies=[Depends(rate_limit("auth:password_reset"))],
)
async def reset_password(body: ResetPasswordRequest, auth: AuthServiceDep) -> MessageResponse:
    """Complete a password reset with the code from ``/password/forgot``.
    Revokes every existing session on success."""
    await auth.reset_password(body.token, body.new_password)
    return MessageResponse(message="Password reset successfully. Please log in again.")


@router.get("/sessions", response_model=list[SessionResponse])
async def list_sessions(principal: CurrentPrincipal, auth: AuthServiceDep) -> list[SessionResponse]:
    """List this account's active device sessions."""
    sessions = await auth.list_sessions(principal.user_id)
    return [
        SessionResponse.model_validate(s).model_copy(
            update={"is_current": s.id == principal.session_id}
        )
        for s in sessions
    ]


@router.delete(
    "/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None
)
async def revoke_session(
    session_id: uuid.UUID, principal: CurrentPrincipal, auth: AuthServiceDep
) -> None:
    """Revoke a specific device session (e.g. remote sign-out of a lost phone)."""
    await auth.revoke_session_for_user(principal.user_id, session_id)
