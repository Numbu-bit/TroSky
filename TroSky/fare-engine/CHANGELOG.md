# Changelog

## 0.1.0 - 2026-11-01

- Reference fare, driver payout and platform commission engine for Ghana: GH¢7.10 per 8 km (per-km rate derived, never stored rounded), Mode A linear and per block, Mode B tapered bands, minimum fare and ROUND_HALF_UP rounding, a static surge factor table and a smoothed live surge with cap and kill switch, quote locking, a double-entry ledger with cash fee receivables and payouts, daily MoMo reconciliation, a PostgreSQL schema, a `python -m fare_engine` command for trying fares, and 81 tests that reproduce every agreed test vector. Standalone: the backend does not use it yet.
