"""Application configuration.

All runtime configuration is sourced from environment variables (or a local
``.env`` file in development) via ``pydantic-settings``. Configuration is
validated eagerly at import time so the process fails fast — and loudly — if
critical production configuration is missing, rather than starting in a
broken or insecure state.
"""

from __future__ import annotations

import ipaddress
from decimal import Decimal
from enum import StrEnum
from functools import lru_cache
from typing import Annotated, Any, Literal

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_INSECURE_DEFAULT_MARKERS = ("change-me", "dev-only", "changeme", "insecure")


class AppEnv(StrEnum):
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"
    TEST = "test"


class EmailProviderName(StrEnum):
    CONSOLE = "console"
    SMTP = "smtp"
    SANDBOX = "sandbox"
    SES = "ses"


class SmsProviderName(StrEnum):
    CONSOLE = "console"
    SANDBOX = "sandbox"
    HUBTEL = "hubtel"
    TWILIO = "twilio"


class PaymentProviderName(StrEnum):
    SANDBOX = "sandbox"
    MTN_MOMO = "mtn_momo"
    TELECEL_CASH = "telecel_cash"
    AIRTELTIGO_MONEY = "airteltigo_money"
    CARD_GATEWAY = "card_gateway"


class MapsProviderName(StrEnum):
    LOCAL = "local"
    GOOGLE = "google"
    MAPBOX = "mapbox"
    HERE = "here"


class Settings(BaseSettings):
    """Central, validated application settings.

    Instantiated once via :func:`get_settings` (cached). Never mutate a
    ``Settings`` instance after startup — configuration is treated as
    immutable for the lifetime of the process.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    # --- Application ---------------------------------------------------
    APP_ENV: AppEnv = AppEnv.DEVELOPMENT
    APP_NAME: str = "TroSky Backend"
    APP_VERSION: str = "0.1.0"
    DEBUG: bool = False
    API_PREFIX: str = "/api/v1"
    TIMEZONE_DISPLAY: str = "Africa/Accra"

    # --- Security / JWT --------------------------------------------------
    SECRET_KEY: SecretStr
    JWT_SIGNING_ALGORITHM: str = "HS256"
    JWT_SECRET_KEY: SecretStr | None = None
    JWT_PRIVATE_KEY: SecretStr | None = None
    JWT_PUBLIC_KEY: str | None = None
    JWT_ISSUER: str = "trosky.africa"
    JWT_AUDIENCE: str = "trosky-mobile-clients"
    ACCESS_TOKEN_TTL_SECONDS: int = Field(default=900, gt=0)
    REFRESH_TOKEN_TTL_SECONDS: int = Field(default=2_592_000, gt=0)
    # How often an open tracking WebSocket re-runs the full session check.
    # HTTP re-validates on every request; a socket has no requests, so this
    # bounds how long a logout, suspension or token expiry can go unnoticed.
    WS_AUTH_RECHECK_SECONDS: int = Field(default=30, gt=0, le=3600)

    # --- Database --------------------------------------------------------
    DATABASE_URL: str
    DATABASE_URL_SYNC: str
    DATABASE_POOL_SIZE: int = Field(default=10, ge=1)
    DATABASE_MAX_OVERFLOW: int = Field(default=20, ge=0)
    DATABASE_POOL_TIMEOUT_SECONDS: int = Field(default=30, ge=1)
    DATABASE_ECHO: bool = False

    # --- Redis -------------------------------------------------------------
    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_MAX_CONNECTIONS: int = Field(default=50, ge=1)

    # --- Celery ---------------------------------------------------------
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"

    # --- Object storage --------------------------------------------------
    S3_ENDPOINT: str = "http://localhost:9000"
    S3_REGION: str = "us-east-1"
    S3_BUCKET: str = "trosky-documents"
    S3_ACCESS_KEY: str = ""
    S3_SECRET_KEY: SecretStr = SecretStr("")
    S3_USE_SSL: bool = False
    S3_PRESIGNED_URL_TTL_SECONDS: int = Field(default=300, gt=0)
    MAX_UPLOAD_SIZE_BYTES: int = Field(default=10 * 1024 * 1024, gt=0)
    ALLOWED_UPLOAD_MIME_TYPES: str = "image/jpeg,image/png,application/pdf"

    # --- Firebase ----------------------------------------------------------
    FIREBASE_CREDENTIALS_JSON: str = ""
    FIREBASE_CREDENTIALS_PATH: str = ""
    FIREBASE_ENABLED: bool = False

    # --- Email -----------------------------------------------------------
    EMAIL_PROVIDER: EmailProviderName = EmailProviderName.CONSOLE
    EMAIL_FROM_ADDRESS: str = "no-reply@trosky.africa"
    EMAIL_SMTP_HOST: str = "localhost"
    EMAIL_SMTP_PORT: int = 1025
    EMAIL_SMTP_USERNAME: str = ""
    EMAIL_SMTP_PASSWORD: SecretStr = SecretStr("")
    EMAIL_SMTP_USE_TLS: bool = False

    # --- SMS ---------------------------------------------------------------
    SMS_PROVIDER: SmsProviderName = SmsProviderName.CONSOLE
    SMS_SENDER_ID: str = "TroSky"
    SMS_API_KEY: SecretStr = SecretStr("")
    SMS_API_SECRET: SecretStr = SecretStr("")
    SMS_BASE_URL: str = ""

    # --- Payments ----------------------------------------------------------
    PAYMENTS_ACTIVE_PROVIDER: PaymentProviderName = PaymentProviderName.SANDBOX
    PAYMENTS_DEFAULT_CURRENCY: str = "GHS"
    # Platform booking fee -- TroSky's per-booking revenue (business plan
    # section 4A: "Bus fare: GHS 8, Platform fee: GHS 0.50"). Charged on top
    # of the operator's fare, so the operator is always paid in full.
    # The flat component is per seat; the percentage applies to the fare.
    PLATFORM_FEE_FLAT_PER_SEAT: Decimal = Field(default=Decimal("0.50"), ge=0)
    PLATFORM_FEE_PERCENT: Decimal = Field(default=Decimal("0"), ge=0, le=100)

    # --- Fare sharing (see app.services.fare_service) ---------------------
    # Distance pro-rating is always on; FARE_SHARING_ENABLED controls only
    # whether the segment cost is then divided between the passengers
    # aboard. The floor stops a full bus pricing a seat into the ground:
    # 0.25 means nobody ever pays less than a quarter of the solo fare.
    FARE_SHARING_ENABLED: bool = True
    FARE_SHARING_MIN_RATIO: Decimal = Field(default=Decimal("0.25"), gt=0, le=1)
    FARE_MINIMUM_AMOUNT: Decimal = Field(default=Decimal("1.00"), ge=0)

    # --- GPS pickup ---------------------------------------------------------
    # A passenger's device location is the default pickup: the backend snaps
    # it to the nearest stop within walking distance. An explicitly chosen
    # stop always wins over coordinates, so manual selection overrides GPS.
    PICKUP_MAX_WALK_METERS: int = Field(default=1000, gt=0, le=20_000)
    PICKUP_NEARBY_LIMIT: int = Field(default=5, gt=0, le=50)
    PAYMENTS_WEBHOOK_SIGNING_SECRET: SecretStr
    PAYMENTS_MTN_MOMO_BASE_URL: str = ""
    PAYMENTS_MTN_MOMO_API_KEY: SecretStr = SecretStr("")
    PAYMENTS_MTN_MOMO_API_SECRET: SecretStr = SecretStr("")
    PAYMENTS_MTN_MOMO_SUBSCRIPTION_KEY: SecretStr = SecretStr("")
    PAYMENTS_TELECEL_CASH_BASE_URL: str = ""
    PAYMENTS_TELECEL_CASH_API_KEY: SecretStr = SecretStr("")
    PAYMENTS_TELECEL_CASH_API_SECRET: SecretStr = SecretStr("")
    PAYMENTS_AIRTELTIGO_BASE_URL: str = ""
    PAYMENTS_AIRTELTIGO_API_KEY: SecretStr = SecretStr("")
    PAYMENTS_AIRTELTIGO_API_SECRET: SecretStr = SecretStr("")
    PAYMENTS_CARD_GATEWAY_BASE_URL: str = ""
    PAYMENTS_CARD_GATEWAY_PUBLIC_KEY: str = ""
    PAYMENTS_CARD_GATEWAY_SECRET_KEY: SecretStr = SecretStr("")

    # --- Maps / ETA ------------------------------------------------------
    MAPS_PROVIDER: MapsProviderName = MapsProviderName.LOCAL
    MAPS_API_KEY: SecretStr = SecretStr("")

    # --- CORS / hosts --------------------------------------------------
    CORS_ALLOWED_ORIGINS: str = "http://localhost:3000"
    TRUSTED_HOSTS: str = "localhost,127.0.0.1"
    # Reverse proxies whose X-Forwarded-For may be believed: comma-separated
    # IPs or CIDRs. Empty means none -- the TCP peer is taken as the client
    # and forwarded headers, which any client can forge, are ignored. Behind
    # a proxy this MUST cover the proxy's addresses, or every client shares
    # the proxy's single rate-limit bucket. See app.core.client_ip.
    TRUSTED_PROXY_CIDRS: str = ""

    # --- Logging / observability -----------------------------------------
    LOG_LEVEL: str = "INFO"
    LOG_JSON: bool = True
    OTEL_ENABLED: bool = False
    OTEL_EXPORTER_OTLP_ENDPOINT: str = "http://localhost:4318"
    OTEL_SERVICE_NAME: str = "trosky-backend"
    METRICS_ENABLED: bool = True
    EXPOSE_HEALTH_DETAILS: bool = True

    # --- Earnings / withdrawals -------------------------------------------
    DRIVER_EARNINGS_SHARE_PERCENT: Decimal = Field(default=Decimal("80.00"), ge=0, le=100)
    MIN_WITHDRAWAL_AMOUNT_GHS: Decimal = Field(default=Decimal("10.00"), gt=0)

    # --- Reservations / OTP / rate limits ---------------------------------
    SEAT_RESERVATION_HOLD_SECONDS: int = Field(default=600, gt=0)
    OTP_LENGTH: int = Field(default=6, ge=4, le=10)
    OTP_EXPIRATION_SECONDS: int = Field(default=300, gt=0)
    OTP_RESEND_COOLDOWN_SECONDS: int = Field(default=60, gt=0)
    OTP_MAX_ATTEMPTS: int = Field(default=5, gt=0)
    # How verification codes (registration, login, password reset) reach
    # the user. "email" sends them to the account's email address instead
    # of by SMS -- for running without a paid SMS provider. Registration
    # then requires an email address.
    OTP_DELIVERY_CHANNEL: Literal["sms", "email"] = "sms"
    # Email domains a new account's address must be on, comma-separated.
    # While set, registration requires an email address on one of them
    # (by default a Gmail address). Empty accepts any domain, and no
    # email at all unless codes go by email.
    REGISTRATION_EMAIL_DOMAINS: str = "gmail.com,googlemail.com"
    # Send verification and password-reset codes after the response instead
    # of making the request wait for the mail/SMS server. A failed send is
    # logged, and the user can ask for a new code straight away.
    OTP_SEND_IN_BACKGROUND: bool = True
    # Accounts must prove their phone or email (by entering a code sent to
    # it) before they can log in with a password or book a seat.
    REQUIRE_VERIFIED_ACCOUNT: bool = True
    PASSWORD_RESET_TOKEN_TTL_SECONDS: int = Field(default=1800, gt=0)
    LOGIN_MAX_FAILED_ATTEMPTS: int = Field(default=5, gt=0)
    LOGIN_LOCKOUT_SECONDS: int = Field(default=900, gt=0)
    RATE_LIMIT_DEFAULT_PER_MINUTE: int = Field(default=60, gt=0)
    RATE_LIMIT_OVERRIDES: str = Field(
        default="",
        description=(
            "Per-rule overrides for app.core.ratelimit.DEFAULT_RULES, as "
            "'rule:limit:window_seconds' entries separated by commas — e.g. "
            "'auth:register:100:3600,auth:login:100:300'. Intended for loosening "
            "limits in development; production should keep the stricter defaults."
        ),
    )

    # --- Password policy (configurable, applied at registration & reset) --
    PASSWORD_MIN_LENGTH: int = Field(default=8, ge=8)
    PASSWORD_REQUIRE_UPPERCASE: bool = True
    PASSWORD_REQUIRE_LOWERCASE: bool = True
    PASSWORD_REQUIRE_DIGIT: bool = True
    PASSWORD_REQUIRE_SYMBOL: bool = False

    # --- GPS -----------------------------------------------------------
    GPS_UPDATE_MIN_INTERVAL_SECONDS: int = Field(default=5, gt=0)
    GPS_STALE_THRESHOLD_SECONDS: int = Field(default=30, gt=0)
    GPS_MAX_PLAUSIBLE_SPEED_KMH: int = Field(default=140, gt=0)
    GPS_RAW_RETENTION_DAYS: int = Field(default=30, gt=0)

    # --- Ticketing -----------------------------------------------------
    TICKET_QR_SIGNING_SECRET: SecretStr

    # --- Request limits --------------------------------------------------
    MAX_REQUEST_BODY_BYTES: int = Field(default=5 * 1024 * 1024, gt=0)
    REQUEST_TIMEOUT_SECONDS: int = Field(default=30, gt=0)

    # ------------------------------------------------------------------
    # Derived helpers
    # ------------------------------------------------------------------
    @property
    def is_production(self) -> bool:
        return self.APP_ENV == AppEnv.PRODUCTION

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.CORS_ALLOWED_ORIGINS.split(",") if o.strip()]

    @property
    def trusted_hosts(self) -> list[str]:
        return [h.strip() for h in self.TRUSTED_HOSTS.split(",") if h.strip()]

    @property
    def trusted_proxy_networks(self) -> list[ipaddress.IPv4Network | ipaddress.IPv6Network]:
        return [
            ipaddress.ip_network(entry.strip(), strict=False)
            for entry in self.TRUSTED_PROXY_CIDRS.split(",")
            if entry.strip()
        ]

    @property
    def registration_email_domains(self) -> frozenset[str]:
        """Parsed ``REGISTRATION_EMAIL_DOMAINS``, lower-cased; empty means
        any domain is accepted."""
        return frozenset(
            entry.strip().lstrip("@").lower()
            for entry in self.REGISTRATION_EMAIL_DOMAINS.split(",")
            if entry.strip()
        )

    @property
    def rate_limit_overrides(self) -> dict[str, tuple[int, int]]:
        """Parsed ``RATE_LIMIT_OVERRIDES``, keyed by rule name. Rule names
        themselves contain a colon (``auth:register``), so each entry is
        split from the right: the last two fields are limit and window."""
        overrides: dict[str, tuple[int, int]] = {}
        for entry in self.RATE_LIMIT_OVERRIDES.split(","):
            entry = entry.strip()
            if not entry:
                continue
            name, _, rest = entry.rpartition(":")
            name, _, limit_part = name.rpartition(":")
            if not name:
                raise ValueError(f"Malformed RATE_LIMIT_OVERRIDES entry: {entry!r}")
            try:
                limit, window = int(limit_part), int(rest)
            except ValueError:
                raise ValueError(f"Malformed RATE_LIMIT_OVERRIDES entry: {entry!r}") from None
            if limit <= 0 or window <= 0:
                raise ValueError(f"RATE_LIMIT_OVERRIDES entry must be positive: {entry!r}")
            overrides[name] = (limit, window)
        return overrides

    @property
    def allowed_upload_mime_types(self) -> list[str]:
        return [m.strip() for m in self.ALLOWED_UPLOAD_MIME_TYPES.split(",") if m.strip()]

    @property
    def payments_default_currency_minor_unit(self) -> int:
        """GHS uses 2 decimal places (pesewas)."""
        return 2

    @property
    def jwt_effective_secret(self) -> SecretStr:
        return self.JWT_SECRET_KEY or self.SECRET_KEY

    # ------------------------------------------------------------------
    # Validators
    # ------------------------------------------------------------------
    @field_validator("TRUSTED_PROXY_CIDRS")
    @classmethod
    def _validate_trusted_proxy_cidrs(cls, value: str) -> str:
        for entry in value.split(","):
            if entry.strip():
                try:
                    ipaddress.ip_network(entry.strip(), strict=False)
                except ValueError as exc:
                    raise ValueError(f"TRUSTED_PROXY_CIDRS entry {entry.strip()!r}: {exc}") from exc
        return value

    @field_validator("PAYMENTS_DEFAULT_CURRENCY")
    @classmethod
    def _currency_must_be_ghs_for_mvp(cls, v: str) -> str:
        if v.upper() != "GHS":
            raise ValueError("Only GHS is supported for MVP monetary storage.")
        return v.upper()

    @model_validator(mode="after")
    def _validate_production_safety(self) -> Settings:
        """Fail securely: refuse to boot with insecure config in production."""
        if not self.is_production:
            return self

        errors: list[str] = []
        if self.DEBUG:
            errors.append("DEBUG must be false in production")
        if self.EXPOSE_HEALTH_DETAILS:
            errors.append("EXPOSE_HEALTH_DETAILS must be false in production")

        webhook_secret = self.PAYMENTS_WEBHOOK_SIGNING_SECRET.get_secret_value()
        secrets_to_check: dict[str, str] = {
            "SECRET_KEY": self.SECRET_KEY.get_secret_value(),
            "PAYMENTS_WEBHOOK_SIGNING_SECRET": webhook_secret,
            "TICKET_QR_SIGNING_SECRET": self.TICKET_QR_SIGNING_SECRET.get_secret_value(),
        }
        if self.JWT_SECRET_KEY is not None:
            secrets_to_check["JWT_SECRET_KEY"] = self.JWT_SECRET_KEY.get_secret_value()

        for name, value in secrets_to_check.items():
            if len(value) < 32:
                errors.append(f"{name} must be at least 32 characters in production")
            lowered = value.lower()
            if any(marker in lowered for marker in _INSECURE_DEFAULT_MARKERS):
                errors.append(f"{name} looks like a development placeholder value")

        if self.PAYMENTS_ACTIVE_PROVIDER != PaymentProviderName.SANDBOX and not any(
            [
                self.PAYMENTS_MTN_MOMO_API_KEY.get_secret_value(),
                self.PAYMENTS_TELECEL_CASH_API_KEY.get_secret_value(),
                self.PAYMENTS_AIRTELTIGO_API_KEY.get_secret_value(),
                self.PAYMENTS_CARD_GATEWAY_SECRET_KEY.get_secret_value(),
            ]
        ):
            errors.append(
                f"PAYMENTS_ACTIVE_PROVIDER={self.PAYMENTS_ACTIVE_PROVIDER} requires provider "
                "credentials to be configured"
            )

        if errors:
            joined = "; ".join(errors)
            raise ValueError(f"Insecure production configuration detected: {joined}")
        return self


@lru_cache
def get_settings() -> Settings:
    """Return the process-wide cached settings instance.

    Cached via ``lru_cache`` so configuration is parsed and validated exactly
    once per process. Tests override this via FastAPI's dependency-override
    mechanism or by clearing the cache explicitly (``get_settings.cache_clear()``).
    """
    return Settings()


# Money helpers -----------------------------------------------------------
MINOR_UNITS_PER_GHS = Decimal(100)

MoneyAmount = Annotated[Decimal, Field(max_digits=14, decimal_places=2)]


def to_minor_units(amount: Decimal) -> int:
    """Convert a Decimal GHS amount to integer minor units (pesewas)."""
    return int((amount * MINOR_UNITS_PER_GHS).to_integral_value())


def from_minor_units(amount: int) -> Decimal:
    """Convert integer minor units (pesewas) to a Decimal GHS amount."""
    return (Decimal(amount) / MINOR_UNITS_PER_GHS).quantize(Decimal("0.01"))


def redact_secrets(data: dict[str, Any]) -> dict[str, Any]:
    """Best-effort redaction helper for logging dict payloads."""
    sensitive_markers = (
        "password",
        "secret",
        "token",
        "otp",
        "pin",
        "cvv",
        "card_number",
        "authorization",
        "api_key",
        "private_key",
    )
    redacted: dict[str, Any] = {}
    for key, value in data.items():
        if isinstance(value, dict):
            redacted[key] = redact_secrets(value)
        elif any(marker in key.lower() for marker in sensitive_markers):
            redacted[key] = "***REDACTED***"
        else:
            redacted[key] = value
    return redacted
