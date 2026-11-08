import io
import unittest
from contextlib import redirect_stderr, redirect_stdout

from fare_engine.cli import main


def run(*argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = main(list(argv))
    return code, out.getvalue(), err.getvalue()


class TestCli(unittest.TestCase):
    def test_quote_with_fixed_surge(self):
        code, out, _ = run("quote", "8", "--surge", "1.3")
        self.assertEqual(code, 0)
        self.assertIn("fare GH¢9.20", out)
        self.assertIn("GH¢7.36", out)  # driver
        self.assertIn("Platform fee GH¢1.84", out)

    def test_quote_25_percent(self):
        _, out, _ = run("quote", "8", "--fee", "0.25")
        self.assertIn("Platform fee GH¢1.78", out)
        self.assertIn("GH¢5.32", out)

    def test_quote_from_factor_table(self):
        _, out, _ = run("quote", "8", "--at", "2026-11-04 17:30", "--weather", "light_rain")
        self.assertIn("surge x1.50 (High demand: evening rush, rain)", out)
        self.assertIn("fare GH¢10.70", out)

    def test_capped_surge_is_explained(self):
        _, out, _ = run(
            "quote", "8", "--at", "2026-11-04 18:00", "--weather", "heavy_rain",
            "--occasion", "festive_season", "--occasion", "major_event",
        )
        self.assertIn("add up to x2.25; capped at x2.00", out)
        self.assertIn("fare GH¢14.20", out)

    def test_per_block_and_mode_b(self):
        self.assertIn("fare GH¢14.20", run("quote", "9", "--per-block")[1])
        self.assertIn("fare GH¢4.70", run("quote", "8", "--mode", "B")[1])

    def test_cash_trip_shows_fee_owed(self):
        _, out, _ = run("quote", "8", "--payment", "cash")
        self.assertIn("driver collects GH¢7.10 and owes the platform GH¢1.42", out)

    def test_compare(self):
        code, out, _ = run("compare")
        self.assertEqual(code, 0)
        self.assertIn("35.50", out)
        self.assertIn("20.20", out)

    def test_bad_input_is_a_clear_error(self):
        code, _, err = run("quote", "8", "--surge", "3")
        self.assertEqual(code, 2)
        self.assertIn("outside", err)
        code, _, err = run("quote", "45", "--mode", "B")
        self.assertEqual(code, 2)
        self.assertIn("beyond the last Mode B band", err)


if __name__ == "__main__":
    unittest.main()
