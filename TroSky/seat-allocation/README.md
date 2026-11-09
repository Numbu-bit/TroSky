# Smart Seat Allocation (reference engine)

Passengers getting off farthest from the pickup sit at the back, and those getting off
nearest sit by the door, so nobody has to climb out to let someone else off.

This is a standalone reference. The TroSky backend and apps do not use it yet; connecting
it to booking is Phase 3 of the plan. Every example vehicle layout is an assumption:
**verify against the actual fleet before launch.**

The specification (definitions, proofs, data model, API contract, screens, plan, KPIs,
risks and open questions) is the shared doc **Smart Seat Allocation**:
https://claude.ai/artifact/RCvt9sZxqfga94kjvjPw8H

The engine needs Python 3.11 or newer and nothing else. The tests also need the packages in
`requirements-dev.txt`.

## Try it

From this folder (`TroSky/seat-allocation`):

```
python -m seat_allocation allocate 12 3 8 1 6
python -m seat_allocation allocate 12 8 6 3 1 --priority 12   # 4 unavoidable pairs, and why
python -m seat_allocation allocate 14 14 9 9 9 4 4 --seats 15 # the 15-seat minibus
python -m seat_allocation simulate --trips 500                # compare seating methods
python examples.py                                            # every worked example
```

## Run the tests

```
pip install -r requirements-dev.txt
python -m unittest discover -s tests -t .
ruff check . && ruff format --check .
```

`schema.sql` needs a PostgreSQL database, which CI provides:

```
psql -v ON_ERROR_STOP=1 -f tests/schema_stubs.sql -f schema.sql -f tests/schema_checks.sql
```

## What is where

| Path | What it is |
| --- | --- |
| `seat_config.toml` | Every weight and rule. Nothing is hard-coded. |
| `layouts/` | The layout schema, example layouts, and the 14 to 18 seat variants |
| `seat_allocation/layout.py` | Loads and checks layouts, and generates the examples |
| `seat_allocation/route.py` | Alight positions along the road, and destination checks |
| `seat_allocation/model.py` | Bookings, and the problem compiled into cost tables |
| `seat_allocation/hungarian.py` | The Hungarian method |
| `seat_allocation/solvers.py` | Sorted seating, the linearised problem, the lower bound, local search and exact search |
| `seat_allocation/allocator.py` | `allocate()`: constraints, the best seating and the report |
| `seat_allocation/online.py` | Distance zones, for passengers booking over time |
| `seat_allocation/service.py` | One trip over time: booking, swaps, locks, boarding, audit log |
| `seat_allocation/messages.py` | Reasons for passengers, SMS text and the conductor's sheet |
| `seat_allocation/simulator.py` | Compares methods over synthetic trips |
| `schema.sql` | Proposed database changes, with their rules enforced by the database |
| `examples.py` | Prints every worked example from the engine |

In `seat_config.toml`, values are labelled [GIVEN], [ASSUMPTION], [PLACEHOLDER] or [VERIFY].
