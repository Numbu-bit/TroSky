# Provider integration guide

Every third-party integration in this codebase (SMS, email, payments, push,
maps/ETA, object storage) is selected via a settings enum
(`*_PROVIDER` / `PAYMENTS_ACTIVE_PROVIDER`) and resolved through a factory
(`app/providers/*/factory.py`) — switching a vendor in any environment is a
configuration change, never a code change. This is the credentials,
callback-URL, and compliance checklist for taking each **real** adapter
from "code complete" to "actually sending traffic." It does not repeat the
per-provider implementation notes already in each adapter's own module
docstring — read that file alongside this table before going live with it.

Two categories, deliberately not blurred:

- **Production-capable** — implements a stable, publicly documented vendor
  API. Needs only real credentials to work.
- **Configuration-ready skeleton** — every call site above it is fully
  wired (service → provider interface → this class), but the class itself
  raises `ProviderError` on every call. It exists so the *shape* of the
  integration is settled; it deliberately does not guess at a vendor
  contract this codebase's authors could not verify. See
  `docs/adr/0003-sandbox-first-providers-honest-unavailable-skeletons.md`.

## SMS

| Provider | Status | Settings | Notes |
|---|---|---|---|
| `TwilioSmsProvider` | Production-capable | `SMS_PROVIDER=twilio`, `SMS_API_KEY` (Account SID), `SMS_API_SECRET` (Auth Token), `SMS_SENDER_ID` (a Twilio-verified sending number, not the display name `"TroSky"` — the field is reused as a slot, set it to the actual purchased number) | Calls `https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json`. Ghana SMS delivery via Twilio requires either a Twilio-provisioned Ghanaian long code/alphanumeric sender ID or an approved international route — confirm deliverability with Twilio support before launch, not just that the API call succeeds. |
| `HubtelSmsProvider` | Skeleton | `SMS_PROVIDER=hubtel`, `SMS_BASE_URL`, `SMS_API_KEY`, `SMS_API_SECRET` | Raises `ProviderError` until someone with a live Hubtel account confirms the current request/response shape at https://developers.hubtel.com and the skeleton is completed to match it. Hubtel is the locally-relevant Ghanaian SMS aggregator or `TwilioSmsProvider` is the fastest real path — prioritize whichever the business relationship already exists for. |
| `console` / `sandbox` | Dev/test only | default | Never select in production — `app/core/config.py` refuses to boot with `APP_ENV=production` and a non-production-capable provider selected without override. |

## Email

| Provider | Status | Settings | Notes |
|---|---|---|---|
| `SmtpEmailProvider` | Production-capable | `EMAIL_PROVIDER=smtp`, `EMAIL_SMTP_HOST`, `EMAIL_SMTP_PORT`, `EMAIL_SMTP_USERNAME`, `EMAIL_SMTP_PASSWORD`, `EMAIL_SMTP_USE_TLS`, `EMAIL_FROM_ADDRESS` | Works against any standard SMTP relay (a transactional-email vendor's SMTP endpoint, or self-hosted). Simplest path if the team already has SMTP credentials from somewhere. |
| `SesEmailProvider` | Production-capable | `EMAIL_PROVIDER=ses`, plus standard AWS credential resolution (env vars / IAM role / shared credentials file — **not** an app setting, deliberately, since this reuses the same boto3 session `storage/s3.py` uses) | `EMAIL_FROM_ADDRESS` must be a **verified** SES sender identity/domain in the target account+region, and the account must be out of the SES sandbox (default new accounts can only send to verified recipient addresses) before it can email arbitrary passengers. Confirm both before launch. |
| `console` / `sandbox` | Dev/test only | default | Same production-boot guard as SMS. |

## Payments

| Provider | Status | Settings | Notes |
|---|---|---|---|
| `MtnMomoProvider` | Production-capable (Collections only) | `PAYMENTS_ACTIVE_PROVIDER=mtn_momo`, `PAYMENTS_MTN_MOMO_BASE_URL` (sandbox vs. production host differ), `PAYMENTS_MTN_MOMO_API_KEY`, `PAYMENTS_MTN_MOMO_API_SECRET`, `PAYMENTS_MTN_MOMO_SUBSCRIPTION_KEY`, plus `PAYMENTS_WEBHOOK_SIGNING_SECRET` (the bearer token you register as MTN's callback auth — MTN does not HMAC-sign callback payloads the way Stripe does; the registered callback URL *is* the trust boundary, protected by this shared secret) | Register at https://momodeveloper.mtn.com, subscribe to the **Collections** product specifically. **Disbursements (payouts) is a separate MTN product/subscription this codebase does not provision** — `refund()` intentionally raises `ProviderError` rather than fake a payout call; withdrawals stay admin-confirmed (see `WithdrawalRequest`) until Disbursements credentials exist. Webhook URL to register with MTN: the deployed `POST /api/v1/payments/webhooks/mtn_momo` route. |
| `TelecelCashProvider`, `AirtelTigoMoneyProvider` | Skeleton | `PAYMENTS_TELECEL_CASH_*`, `PAYMENTS_AIRTELTIGO_*` | Raise `ProviderError` until each vendor's request contract is confirmed by someone with a live merchant account — same reasoning as Hubtel. These are the other two mobile-money rails with real Ghanaian market share; prioritize whichever the business has a merchant agreement with first. |
| Card gateway | Skeleton | `PAYMENTS_CARD_GATEWAY_*` | No specific vendor was named in the original spec; pick one (Paystack and Flutterwave both operate in Ghana) before implementing — the skeleton exists so the booking/payment flow above it doesn't need to change once a vendor is chosen. |
| `sandbox` | Dev/test only | default | Deterministic in-memory success/failure, used by every automated test. |

## Push notifications

| Provider | Status | Settings | Notes |
|---|---|---|---|
| `FirebasePushProvider` | Production-capable | `FIREBASE_ENABLED=true`, `FIREBASE_CREDENTIALS_JSON` (inline service-account JSON) or `FIREBASE_CREDENTIALS_PATH` (file path — pick exactly one) | Standard `firebase-admin` service-account auth. Requires the mobile apps to actually register device tokens via `POST /api/v1/users/devices` (`DeviceRegistration`) before any push can be delivered — this backend never invents a token. |
| `sandbox` | Dev/test only | default | |

## Maps / ETA

| Provider | Status | Settings | Notes |
|---|---|---|---|
| `LocalHeuristicMapsProvider` | Intentionally not a real routing provider | `MAPS_PROVIDER=local` (default) | Great-circle distance + a configured average speed, not road-network routing. This is a deliberate MVP simplification, not a placeholder — it's cheap, has zero external dependency, and is honest about what it computes. |
| Google Directions / Mapbox / HERE | Skeleton (`unavailable.py`) | `MAPS_PROVIDER=google\|mapbox\|here`, `MAPS_API_KEY` | Raises `ProviderError`. All three have stable, well-documented APIs — unlike the SMS/payment skeletons above, completing one of these is mostly a matter of budget/vendor choice, not contract uncertainty. Google Directions is the most feature-complete for Ghanaian road coverage as of this writing; confirm current coverage before committing. |

## Object storage

| Provider | Status | Settings | Notes |
|---|---|---|---|
| `S3StorageProvider` | Production-capable | `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_USE_SSL`, `S3_PRESIGNED_URL_TTL_SECONDS` | Works against real AWS S3 (set `S3_ENDPOINT` to the regional AWS endpoint) or any S3-compatible store (MinIO in dev/self-hosted, or a managed alternative) — same client, just a different endpoint. Bucket must exist and the credentials must have `PutObject`/`GetObject`/presigned-URL permission before driver/vehicle document upload will work. |
| `SandboxStorageProvider` | Dev/test only | default | In-memory, no network calls. |

## Before flipping any provider to production in a real environment

1. Confirm the credential fields above are populated as real secrets (via
   the deployment's actual secret manager — see
   `deployments/kubernetes/secret.example.yaml`'s header — never committed
   to the repo or `.env`).
2. `app/core/config.py` already fails closed: `APP_ENV=production` refuses
   to start if a payment provider is selected without its credentials
   configured, or if any signing secret looks like a development
   placeholder. Treat a boot failure here as the config working correctly,
   not a bug to route around.
3. Register the real callback/webhook URLs with each vendor (MTN MoMo,
   and any future SMS/payment vendor with delivery-status webhooks) —
   pointing at the deployed API's public HTTPS URL, never `localhost`.
4. Run one real end-to-end transaction per vendor in their sandbox/test
   mode (Twilio has a test-credentials mode; MTN MoMo's developer portal
   provisions a sandbox subscription separate from production) before
   the first real customer transaction.
5. For payments specifically: confirm reconciliation
   (`app.services.payment_service`'s reconciliation sweep) is scheduled
   via Celery Beat in the target environment — a webhook can be missed;
   the sweep is the backstop, not a nice-to-have.
