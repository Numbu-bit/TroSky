-- Reference PostgreSQL schema: fares, payments, payouts and a double-entry ledger.
-- Money is numeric(14,2) in Ghana cedis. Ledger rows are append-only and every
-- ledger transaction must balance when its database transaction commits.

CREATE TABLE config_versions (
    version       text PRIMARY KEY,
    body          jsonb NOT NULL,              -- the full fare_config.toml, parsed
    activated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE quotes (
    quote_id               uuid PRIMARY KEY,
    rider_id               uuid NOT NULL,
    pickup_zone            text NOT NULL,       -- H3 cell or zone id
    predicted_distance_km  numeric(8,3) NOT NULL CHECK (predicted_distance_km >= 0),
    predicted_minutes      numeric(8,2) NOT NULL CHECK (predicted_minutes >= 0),
    surge_multiplier       numeric(4,2) NOT NULL CHECK (surge_multiplier >= 1),
    surge_reasons          text[] NOT NULL DEFAULT '{}',
    fare                   numeric(14,2) NOT NULL CHECK (fare >= 0),
    breakdown              jsonb NOT NULL,       -- FareBreakdown as shown to the rider
    config_version         text NOT NULL REFERENCES config_versions (version),
    created_at             timestamptz NOT NULL DEFAULT now(),
    expires_at             timestamptz NOT NULL,
    confirmed_at           timestamptz,
    CHECK (confirmed_at IS NULL OR confirmed_at <= expires_at)
);

CREATE TABLE trips (
    trip_id             uuid PRIMARY KEY,
    quote_id            uuid NOT NULL UNIQUE REFERENCES quotes (quote_id),
    rider_id            uuid NOT NULL,
    driver_id           uuid,
    payment_type        text NOT NULL CHECK (payment_type IN ('cash', 'momo', 'card')),
    status              text NOT NULL CHECK (status IN ('requested', 'accepted', 'started', 'completed', 'cancelled')),
    started_at          timestamptz,
    completed_at        timestamptz,
    actual_distance_km  numeric(8,3) CHECK (actual_distance_km >= 0),
    actual_minutes      numeric(8,2) CHECK (actual_minutes >= 0),
    distance_source     text CHECK (distance_source IN ('gps', 'gps_capped', 'routed'))
);

CREATE TABLE fare_breakdowns (
    trip_id            uuid PRIMARY KEY REFERENCES trips (trip_id),
    basis              text NOT NULL CHECK (basis IN ('quoted', 'repriced', 'cancelled_before_pickup', 'cancelled_mid_trip')),
    fare               numeric(14,2) NOT NULL CHECK (fare >= 0),
    fare_before_surge  numeric(14,2) NOT NULL,
    surge_multiplier   numeric(4,2) NOT NULL,
    service_fee_rate   numeric(5,4) NOT NULL CHECK (service_fee_rate >= 0 AND service_fee_rate < 1),
    platform_fee       numeric(14,2) NOT NULL CHECK (platform_fee >= 0 AND platform_fee <= fare),
    tolls              numeric(14,2) NOT NULL DEFAULT 0 CHECK (tolls >= 0),
    tips               numeric(14,2) NOT NULL DEFAULT 0 CHECK (tips >= 0),
    incentives         numeric(14,2) NOT NULL DEFAULT 0 CHECK (incentives >= 0),
    promo              numeric(14,2) NOT NULL DEFAULT 0 CHECK (promo >= 0 AND promo <= fare),
    rider_pays         numeric(14,2) NOT NULL,
    driver_payout      numeric(14,2) NOT NULL,
    vat_on_fee         numeric(14,2) NOT NULL DEFAULT 0,
    CHECK (rider_pays + promo + incentives = driver_payout + platform_fee)
);

CREATE TABLE payment_attempts (
    attempt_id               uuid PRIMARY KEY,
    idempotency_key          text NOT NULL UNIQUE,   -- also the reference sent to MTN
    trip_id                  uuid REFERENCES trips (trip_id),
    driver_id                uuid,
    kind                     text NOT NULL CHECK (kind IN ('collection', 'disbursement', 'fee_settlement', 'refund')),
    amount                   numeric(14,2) NOT NULL CHECK (amount > 0),
    msisdn                   text NOT NULL,
    status                   text NOT NULL CHECK (status IN ('initiated', 'pending', 'succeeded', 'declined', 'timed_out', 'failed')),
    provider_transaction_id  text,
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ledger_accounts (
    account       text PRIMARY KEY,      -- e.g. liability:driver_payable:<driver_id>
    account_type  text NOT NULL CHECK (account_type IN ('asset', 'liability', 'income', 'expense')),
    CHECK (split_part(account, ':', 1) = account_type)
);

CREATE TABLE ledger_transactions (
    transaction_id   bigserial PRIMARY KEY,
    idempotency_key  text NOT NULL UNIQUE,
    kind             text NOT NULL,
    trip_id          uuid,
    meta             jsonb NOT NULL DEFAULT '{}',
    posted_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ledger_lines (
    line_id         bigserial PRIMARY KEY,
    transaction_id  bigint NOT NULL REFERENCES ledger_transactions (transaction_id),
    account         text NOT NULL REFERENCES ledger_accounts (account),
    debit           numeric(14,2) NOT NULL DEFAULT 0 CHECK (debit >= 0),
    credit          numeric(14,2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
    CHECK ((debit = 0) <> (credit = 0))     -- exactly one side, never zero
);
CREATE INDEX ledger_lines_account ON ledger_lines (account);
CREATE INDEX ledger_lines_transaction ON ledger_lines (transaction_id);

-- Every ledger transaction balances, checked when the database transaction commits.
CREATE FUNCTION ledger_assert_balanced() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    diff numeric;
BEGIN
    SELECT COALESCE(SUM(debit), 0) - COALESCE(SUM(credit), 0) INTO diff
    FROM ledger_lines WHERE transaction_id = NEW.transaction_id;
    IF diff <> 0 THEN
        RAISE EXCEPTION 'ledger transaction % does not balance (off by %)', NEW.transaction_id, diff;
    END IF;
    RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER ledger_lines_balanced
    AFTER INSERT ON ledger_lines
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION ledger_assert_balanced();

-- Append-only: corrections are reversing transactions, never edits.
CREATE FUNCTION ledger_forbid_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'ledger rows are immutable; post a reversing transaction instead';
END $$;

CREATE TRIGGER ledger_transactions_immutable BEFORE UPDATE OR DELETE ON ledger_transactions
    FOR EACH ROW EXECUTE FUNCTION ledger_forbid_change();
CREATE TRIGGER ledger_lines_immutable BEFORE UPDATE OR DELETE ON ledger_lines
    FOR EACH ROW EXECUTE FUNCTION ledger_forbid_change();

CREATE VIEW account_balances AS
SELECT a.account,
       a.account_type,
       CASE WHEN a.account_type IN ('asset', 'expense')
            THEN COALESCE(SUM(l.debit - l.credit), 0)
            ELSE COALESCE(SUM(l.credit - l.debit), 0)
       END AS balance
FROM ledger_accounts a
LEFT JOIN ledger_lines l ON l.account = a.account
GROUP BY a.account, a.account_type;

CREATE TABLE payouts (
    payout_id           text PRIMARY KEY,     -- payout:<run_id>:<driver_id>, the idempotency key
    run_id              text NOT NULL,
    driver_id           uuid NOT NULL,
    payable_before      numeric(14,2) NOT NULL,
    fees_netted         numeric(14,2) NOT NULL CHECK (fees_netted >= 0),
    amount              numeric(14,2) NOT NULL CHECK (amount >= 0),
    status              text NOT NULL CHECK (status IN ('pending', 'succeeded', 'failed', 'below_minimum', 'nothing_due')),
    payment_attempt_id  uuid REFERENCES payment_attempts (attempt_id),
    UNIQUE (run_id, driver_id)
);

-- One row per cash-trip fee or clawback, for statements. The balance itself lives in the ledger.
CREATE TABLE fee_receivables (
    receivable_id          uuid PRIMARY KEY,
    driver_id              uuid NOT NULL,
    trip_id                uuid REFERENCES trips (trip_id),
    reason                 text NOT NULL CHECK (reason IN ('cash_trip_fee', 'refund_clawback')),
    amount                 numeric(14,2) NOT NULL CHECK (amount > 0),
    ledger_transaction_id  bigint NOT NULL REFERENCES ledger_transactions (transaction_id),
    created_at             timestamptz NOT NULL DEFAULT now()
);
