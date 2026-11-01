"""Build the specification page. Every table of numbers comes from the engine.

Run: python build_spec.py   (writes spec/fare-engine-spec.html)
"""

from __future__ import annotations

import html
import json
import subprocess
import sys
from datetime import datetime
from decimal import Decimal as D
from pathlib import Path

import examples as ex
from fare_engine import SurgeContext, load_config, price, settle, static_surge
from fare_engine.money import show
from fare_engine.quotes import create_quote, final_fare
from fare_engine.settlement import driver_receipt, rider_breakdown

ROOT = Path(__file__).resolve().parent
CONFIG = load_config()
e = html.escape


def table(headers, rows, num_cols=()):
    head = "".join(f'<th class="{"n" if i in num_cols else ""}">{e(h)}</th>' for i, h in enumerate(headers))
    body = []
    for row in rows:
        cells = "".join(f'<td class="{"n" if i in num_cols else ""}">{c}</td>' for i, c in enumerate(row))
        body.append(f"<tr>{cells}</tr>")
    return f'<div class="tw"><table><thead><tr>{head}</tr></thead><tbody>{"".join(body)}</tbody></table></div>'


def comparison():
    rows = []
    for r in ex.comparison_rows():
        note = ' <span class="tag g">minimum</span>' if r["a_note"] else ""
        rows.append([f'{r["km"]} km', r["a_raw"], r["a"] + note, r["block"], r["b"], f'+{r["gap"]}', f'+{r["gap_pct"]}'])
    return table(
        ["Distance", "Mode A raw", "Mode A linear", "Mode A per block", "Mode B bands", "A minus B", "A above B"],
        rows,
        num_cols=(1, 2, 3, 4, 5, 6),
    )


def vectors():
    rows = []
    for r in ex.vector_rows():
        rows.append(
            [e(r["label"]), r["surge"], r["rate"], r["raw"], r["fare"], r["fee"], r["driver"], e(r["expected"]), '<span class="ok">Matches</span>']
        )
    return table(
        ["Trip", "Surge", "Fee", "Raw fare", "Fare", "Platform", "Driver", "Expected (prompt)", "Result"],
        rows,
        num_cols=(1, 3, 4, 5, 6),
    )


def surge_factor_table():
    rows = []
    for f in CONFIG.surge.factors:
        when = (
            f"{f.start:%H:%M}–{f.end:%H:%M}" if f.kind == "time" else ", ".join(sorted(f.conditions)) if f.kind == "weather" else f.occasion
        )
        rows.append([e(f.kind.title()), e(f.id.replace("_", " ")), e(when), f"+{show(f.uplift)}", e(f.reason), f"{f.valid_from} to {f.valid_to}"])
    return table(["Kind", "Factor", "When", "Uplift", "Rider sees", "Valid"], rows, num_cols=(3,))


def surge_vectors():
    rows = [[e(r["label"]), r["uncapped"], r["multiplier"], r["fare"], r["fee"], r["driver"], e(r["message"])] for r in ex.surge_rows()]
    return table(["8 km trip, 20% fee", "Uncapped", "Multiplier", "Fare", "Platform", "Driver", "Message"], rows, num_cols=(1, 2, 3, 4, 5))


def receipts():
    ctx = SurgeContext(at=datetime(2026, 11, 4, 17, 30), weather="light_rain")
    surge = static_surge(ctx, CONFIG)
    b = price("8", "0", surge.multiplier, CONFIG)
    s = settle(b.fare, CONFIG, tips="2.00")
    r_lines = "".join(f'<div class="rl"><span>{e(a)}</span><span class="n">{e(v)}</span></div>' for a, v in rider_breakdown(b, s, surge))
    d_lines = "".join(f'<div class="rl"><span>{e(a)}</span><span class="n">{e(v)}</span></div>' for a, v in driver_receipt(b, s))
    return (
        '<div class="receipts">'
        f'<div class="receipt"><p class="rh">Rider sees before booking</p>{r_lines}</div>'
        f'<div class="receipt"><p class="rh">Driver receipt after the trip</p>{d_lines}</div>'
        "</div>"
    )


def promo():
    s = ex.promo_example()
    rows = [
        ["Fare", show(s.fare)],
        ["Promotion (platform-funded)", "−" + show(s.promo)],
        ["Rider pays", show(s.rider_pays)],
        ["Platform fee on the full fare", show(s.platform_fee)],
        ["Driver payout", show(s.driver_payout)],
        ["Platform net after the promotion", show(s.platform_net)],
    ]
    return table(["8 km, GH¢2.00 promotion", "GH¢"], rows, num_cols=(1,))


def cash():
    c = ex.cash_example()
    p = c["payout"]
    rows = [
        ["1. Cash trip, 8 km, x1.0", "Driver collects GH¢7.10 from the rider. Fee of GH¢1.42 recorded as owed by the driver.",
         "; ".join(f"{a}: {v}" for a, v in c["after_trip"])],
        ["2. MoMo trip, 8 km, x1.3", "Platform collects GH¢9.20. Driver is owed GH¢7.36.", "Owed to driver: 7.36"],
        ["3. Weekly payout", f"GH¢{show(p.fees_netted)} of fees netted against GH¢{show(p.payable_before)} earned. GH¢{show(p.amount)} sent by MoMo.",
         "; ".join(f"{a}: {v}" for a, v in c["after_payout"])],
        ["Alternative to step 2", "No digital earnings that week: the driver pays the GH¢1.42 by MoMo collection.",
         "; ".join(f"{a}: {v}" for a, v in c["settled"])],
    ]
    return table(["Step", "What happens", "Balances after (GH¢)"], rows)


def momo():
    m = ex.momo_example()
    step_rows = [[e(label), "; ".join(f"{a}: {v}" for a, v in bal)] for label, bal in m["steps"]]
    txn_rows = []
    for t in m["transactions"]:
        for i, line in enumerate(t.lines):
            txn_rows.append([e(t.kind) if i == 0 else "", f"<code>{e(line.account)}</code>", show(line.debit) if line.debit else "", show(line.credit) if line.credit else ""])
    return (
        table(["Step", "Balances after (GH¢)"], step_rows)
        + "<p>The ledger entries behind those steps, exactly as the reference ledger posted them:</p>"
        + table(["Transaction", "Account", "Debit", "Credit"], txn_rows, num_cols=(2, 3))
        + f'<p class="small">Trial balance after all three steps: {m["trial_balance"]}.</p>'
    )


def api_examples():
    ctx = SurgeContext(at=datetime(2026, 11, 4, 17, 30), weather="light_rain")
    surge = static_surge(ctx, CONFIG)
    now = datetime(2026, 11, 4, 17, 30)
    q = create_quote(quote_id="5f0c…", rider_id="r_301", pickup_zone="8a754e64992ffff", distance_km="8", minutes="24", surge=surge, config=CONFIG, now=now)
    quote_response = {
        "quote_id": "qt_5f0c2b",
        "currency": "GHS",
        "fare": show(q.fare),
        "breakdown": {
            "distance_km": show(q.predicted_distance_km),
            "fare_before_surge": show(q.breakdown.fare_before_surge),
            "surge_multiplier": show(surge.multiplier),
            "surge_amount": show(q.breakdown.surge_amount),
            "minimum_fare_applied": q.breakdown.minimum_applied,
        },
        "surge_message": surge.rider_message,
        "expires_at": q.expires_at.isoformat() + "Z",
        "config_version": CONFIG.config_version,
    }
    final = final_fare(q, "8.3", "27", CONFIG)
    s = settle(final.amount, CONFIG, tips="2.00")
    complete_response = {
        "trip_id": "tr_88a1",
        "basis": final.basis,
        "fare": show(final.amount),
        "tips": show(s.tips),
        "rider_pays": show(s.rider_pays),
        "platform_fee": show(s.platform_fee),
        "driver_payout": show(s.driver_payout),
        "payment": {"type": "momo", "status": "pending", "attempt_id": "pa_19c2"},
    }
    return (
        f'<pre class="code"><code>{e(json.dumps(quote_response, indent=2))}</code></pre>',
        f'<pre class="code"><code>{e(json.dumps(complete_response, indent=2))}</code></pre>',
    )


def sources():
    files = [
        "fare_config.toml",
        "fare_engine/money.py",
        "fare_engine/config.py",
        "fare_engine/pricing.py",
        "fare_engine/surge.py",
        "fare_engine/quotes.py",
        "fare_engine/settlement.py",
        "fare_engine/ledger.py",
        "fare_engine/reconciliation.py",
        "fare_engine/cli.py",
        "schema.sql",
        "tests/test_pricing.py",
        "tests/test_surge.py",
        "tests/test_settlement_and_quotes.py",
        "tests/test_ledger.py",
        "tests/test_reconciliation_and_simulation.py",
        "tests/test_cli.py",
        "examples.py",
    ]
    blocks = []
    for name in files:
        text = (ROOT / name).read_text(encoding="utf-8")
        lines = text.count("\n") + 1
        blocks.append(
            f'<details class="src"><summary><code>{e(name)}</code><span class="small">{lines} lines</span></summary>'
            f'<button type="button" class="copy" data-copy>Copy</button><pre class="code"><code>{e(text)}</code></pre></details>'
        )
    return "\n".join(blocks)


def test_summary():
    out = subprocess.run(
        [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-t", "."], cwd=ROOT, capture_output=True, text=True
    )
    last = [l for l in out.stderr.strip().splitlines() if l.startswith("Ran ") or l in ("OK",) or l.startswith("FAILED")]
    return " · ".join(last), out.returncode


def main():
    reach, rise = ex.minimum_reach()
    tests, code = test_summary()
    if code != 0:
        raise SystemExit(f"tests failed, not building: {tests}")
    quote_json, complete_json = api_examples()
    page = (ROOT / "spec_template.html").read_text(encoding="utf-8")
    replacements = {
        "{{comparison}}": comparison(),
        "{{vectors}}": vectors(),
        "{{surge_factors}}": surge_factor_table(),
        "{{surge_vectors}}": surge_vectors(),
        "{{receipts}}": receipts(),
        "{{promo}}": promo(),
        "{{cash}}": cash(),
        "{{momo}}": momo(),
        "{{quote_json}}": quote_json,
        "{{complete_json}}": complete_json,
        "{{sources}}": sources(),
        "{{tests}}": e(tests),
        "{{min_reach}}": reach,
        "{{min_rise}}": rise,
        "{{config_version}}": CONFIG.config_version,
    }
    for key, value in replacements.items():
        if key not in page:
            raise SystemExit(f"template is missing {key}")
        page = page.replace(key, value)
    out = ROOT / "spec" / "fare-engine-spec.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(page, encoding="utf-8")
    print(f"wrote {out} ({len(page):,} bytes); tests: {tests}")


if __name__ == "__main__":
    main()
