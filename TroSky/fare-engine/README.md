# Fare, payout and commission engine (reference)

Prices the rider, pays the driver and calculates what the platform keeps, in
Ghana cedis with Decimal arithmetic only. It follows the publicly documented
industry structure (metered fare x demand multiplier, then a percentage service
fee). It is not any company's internal code.

This is a standalone reference. The TroSky backend and apps do not use it yet;
wiring it into booking and payments is a separate change.

Needs Python 3.11 or newer. No third-party packages.

## Test it yourself

From this folder (`TroSky/fare-engine`):

```
python -m unittest discover -s tests -t .
```

You should see `OK` and the number of tests run. Then price any trip:

```
python -m fare_engine quote 8                         # 8 km, no surge, 20% fee
python -m fare_engine quote 8 --surge 1.3             # fare 9.20, platform 1.84, driver 7.36
python -m fare_engine quote 8 --fee 0.25              # the 25% scenario
python -m fare_engine quote 9 --per-block             # two started 8 km blocks: 14.20
python -m fare_engine quote 8 --mode B                # shared-taxi bands: 4.70
python -m fare_engine quote 8 --at "2026-11-04 17:30" --weather light_rain
                                                      # surge from the factor table: x1.50
python -m fare_engine quote 8 --tips 2 --promo 2 --payment cash
python -m fare_engine compare                         # Mode A vs Mode B, 1 to 40 km
```

`python -m fare_engine quote --help` lists every option. To try other rates,
copy `fare_config.toml`, change it, and pass `--config your_copy.toml`.

Run `python examples.py` to print every worked example, and `python build_spec.py`
to rebuild the specification page in `spec/` (not committed) from the code.

## What is where

| Path | What it is |
|---|---|
| `fare_config.toml` | Every rate, fee, cap, factor and placeholder. Money is written as strings. |
| `fare_engine/pricing.py` | Mode A (linear or per block) and Mode B (tapered bands), minimum fare, rounding |
| `fare_engine/surge.py` | Static factor table, live demand/supply surge with smoothing, cap, kill switch |
| `fare_engine/quotes.py` | Upfront quotes, locking, repricing, cancellations, GPS checks |
| `fare_engine/settlement.py` | Platform fee, driver payout, promotions, rider and driver receipts |
| `fare_engine/ledger.py` | Double-entry ledger, cash fee receivables, netting, payouts, refunds |
| `fare_engine/reconciliation.py` | Daily MoMo-to-trip reconciliation |
| `fare_engine/cli.py` | The `python -m fare_engine` command |
| `schema.sql` | PostgreSQL schema with a balance-at-commit trigger and an append-only ledger |
| `examples.py`, `build_spec.py`, `spec_template.html` | Worked examples and the specification page |

Labels in the config: [GIVEN], [ASSUMPTION], [PLACEHOLDER], [VERIFY BEFORE LAUNCH].
Every Ghana-specific fee, tax, rule and MoMo behaviour must be verified before launch.
