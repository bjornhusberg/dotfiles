#!/usr/bin/env python3
# <xbar.var>number(AIC_MONTHLY_BUDGET=25000): Monthly AIC budget</xbar.var>
"""
xbar plugin: shows GitHub Copilot AI-credit (AIC) pacing in the macOS menu
bar, read from the local Copilot CLI session store (~/.copilot/session-store.db).

Menu bar shows: a small donut-chart icon that starts as a solid filled ring
at 0% usage; as today's usage grows (as a percentage of today's budget), a
gray background wedge is increasingly revealed, fading to red as usage
approaches/exceeds the budget. Today's budget is the headroom remaining to
reach a proportional cumulative target (monthly budget * worked-days-so-far
/ total working days this month) after subtracting AIC used before today.
If prior days already overdrew that target, today starts already at/over
100% (a fully red ring). The same fully red ring is shown if usage data
can't be read at all (e.g. missing session store), indicating an error.

Dropdown shows (rounded to whole AIC):
  "<Month> · working day <worked days including today> of <total working days this month>"
  "Monthly budget: <monthly budget> AIC", then
  "Used this month: <AIC> (<percentage>%)" and "Remaining: <AIC>"
  "Baseline per working day: <monthly budget / working days> AIC", then
  "Today's budget: <AIC>"
  (what is left of the proportional target after earlier days),
  "Used today: <AIC> (<percentage>%)" and "Remaining"
  (Remaining reads "over budget by <AIC>" when overspent)

Install: this file lives in ~/Library/Application Support/xbar/plugins/ and
must stay executable (chmod +x). The "5m" in the filename tells xbar to
refresh every 5 minutes; rename to e.g. copilot_aic.1m.py for a different
interval.

Tests: run `./copilot_aic.5m.py --test` (xbar never passes arguments, so the
normal menu bar output is unaffected).
"""

import base64
import calendar
import math
import os
import struct
import sqlite3
import sys
import zlib
from calendar import monthrange
from datetime import date, timedelta
from pathlib import Path
from typing import Optional

DB_PATH = Path.home() / ".copilot" / "session-store.db"
DEFAULT_MONTHLY_BUDGET = 25000


def parse_monthly_budget(value: Optional[str]) -> int:
    """Parses the AIC_MONTHLY_BUDGET setting; falls back to the default if missing, invalid or not positive."""
    try:
        budget = int(float(value)) if value is not None else 0
    except (ValueError, OverflowError):
        return DEFAULT_MONTHLY_BUDGET
    return budget if budget > 0 else DEFAULT_MONTHLY_BUDGET


# xbar passes plugin variables (set in its UI, stored in copilot_aic.5m.py.vars.json) as env vars.
MONTHLY_BUDGET = parse_monthly_budget(os.environ.get("AIC_MONTHLY_BUDGET"))


def _png_bytes(width: int, height: int, pixel_rgba) -> bytes:
    """Build a minimal RGBA PNG (stdlib-only) where pixel_rgba(x, y) -> (r, g, b, a), each 0-255."""
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type 0 (none)
        for x in range(width):
            raw += bytes(pixel_rgba(x, y))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    sig = b"\x89PNG\r\n\x1a\n"
    # 144 DPI (5669 px/m) tells macOS this is a @2x image, so it is drawn at half the pixel size
    phys = struct.pack(">IIB", 5669, 5669, 1)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), 9)
    return sig + chunk(b"IHDR", ihdr) + chunk(b"pHYs", phys) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


_IS_DARK_MENU_BAR = os.environ.get("BitBarDarkMode") == "true"
# Near-white in dark mode, near-black in light mode, so the neutral foreground
# always contrasts against the menu bar instead of blending into it.
NORMAL_COLOR = (255, 255, 255) if _IS_DARK_MENU_BAR else (30, 30, 30)
FADE_START = 75  # percentage where the revealed background starts fading towards red
FADE_DANGER = 100  # percentage at which the revealed background is fully red
# Gray "background" revealed behind the shrinking neutral fill as usage grows,
# matching the dimmed background used by macOS's own menu bar/Control Center
# gauges (e.g. volume, brightness). The icon intentionally always uses the
# dark-menu-bar palette, regardless of the current system appearance, so it
# looks the same at all times.

TRACK_COLOR = (144, 152, 158)  # Apple's systemGray

DANGER_COLOR = (197, 17, 30)

def _lerp_color(
    start: tuple[int, int, int], end: tuple[int, int, int], fraction: float
) -> tuple[int, int, int]:
    fraction = min(1.0, max(0.0, fraction))
    return tuple(round(s + (e - s) * fraction) for s, e in zip(start, end))


def pie_color_for(percentage: float) -> tuple[int, int, int]:
    """Color of the revealed background wedge: gray up to FADE_START, then
    fading hue (same lightness as the gray) towards red as usage
    approaches/exceeds the budget.
    """
    if percentage <= FADE_START:
        return TRACK_COLOR
    fraction = (percentage - FADE_START) / (FADE_DANGER - FADE_START)
    return _lerp_color(TRACK_COLOR, DANGER_COLOR, fraction)


def pie_chart_image(percentage: float, points: int = 18, scale: int = 2, supersample: int = 4) -> str:
    """Render an inverted donut-chart gauge icon: at 0% usage it's a solid
    neutral-filled ring (no background visible), and as usage grows, more
    of a gray "background" wedge is revealed clockwise from the top (12
    o'clock), sized to actually fit the macOS menu bar (xbar draws images
    pixels 1:1, it does not auto-scale large images down). A thin
    transparent radial line (center to edge), carved only out of the
    background wedge (never the foreground), separates the background from
    the neutral foreground at both of its angular boundaries, for contrast
    against a white menu bar. The center hole (1/2 of the full
    circle's diameter) is fully transparent. Anti-aliased edges come from
    per-pixel supersampling, not from shipping an oversized image. The
    revealed background fades from gray to red between FADE_START and
    FADE_DANGER (see pie_color_for), and is returned as base64-encoded PNG
    bytes suitable for xbar's image= parameter. Not a templateImage because
    those are forced monochrome by macOS, which would discard the danger
    color.
    """
    clamped = max(0.0, min(100.0, percentage))
    target_angle = clamped / 100.0 * 360.0
    draw_seams = 0.0 < clamped < 100.0

    size = points * scale  # pixels; displayed as `points` thanks to the 144 DPI PNG metadata
    center = size / 2.0
    outer_r = size / 2.0 - scale
    inner_r = outer_r / 2.0
    seam_fade_degrees = 22.0  # angular distance over which the background fades from transparent to opaque at each boundary
    revealed_color = pie_color_for(percentage)
    subpixels = supersample * supersample

    def pixel_rgba(x: int, y: int) -> tuple[int, int, int, int]:
        in_circle = 0
        in_revealed = 0
        for sy in range(supersample):
            for sx in range(supersample):
                px = x + (sx + 0.5) / supersample
                py = y + (sy + 0.5) / supersample
                dx = px - center
                dy = py - center
                r = math.hypot(dx, dy)
                if r > outer_r or r < inner_r:
                    continue
                angle = math.degrees(math.atan2(dx, -dy))
                if angle < 0:
                    angle += 360.0

                in_background = angle <= target_angle
                weight = 1.0
                if draw_seams and in_background:
                    # Fade the background wedge out towards both boundaries (never
                    # touching the foreground), so a near-100% foreground sliver
                    # stays full width.
                    t = min(1.0, min(angle, target_angle - angle) / seam_fade_degrees)
                    weight = t * t * (3.0 - 2.0 * t)  # smoothstep

                in_circle += weight
                if in_background:
                    in_revealed += weight

        if in_circle == 0:
            return (0, 0, 0, 0)

        in_remaining = in_circle - in_revealed
        rgb = tuple(
            round((rv * in_revealed + rm * in_remaining) / in_circle)
            for rv, rm in zip(revealed_color, NORMAL_COLOR)
        )
        alpha = round(in_circle / subpixels * 255)
        return (*rgb, alpha)

    png = _png_bytes(size, size, pixel_rgba)
    return base64.b64encode(png).decode()


def aic_used(conn: sqlite3.Connection, date_prefix: str) -> float:
    row = conn.execute(
        """
        SELECT COALESCE(SUM(total_nano_aiu), 0)
        FROM assistant_usage_events
        WHERE substr(datetime(created_at, 'localtime'), 1, ?) = ?
        """,
        (len(date_prefix), date_prefix),
    ).fetchone()
    return (row[0] or 0) / 1e9


def aic_used_between(conn: sqlite3.Connection, start: date, end: date) -> float:
    """AIC used on local dates in [start, end)."""
    row = conn.execute(
        """
        SELECT COALESCE(SUM(total_nano_aiu), 0)
        FROM assistant_usage_events
        WHERE date(created_at, 'localtime') >= ? AND date(created_at, 'localtime') < ?
        """,
        (start.isoformat(), end.isoformat()),
    ).fetchone()
    return (row[0] or 0) / 1e9


def last_working_day(day: date) -> date:
    """Returns day itself on weekdays, otherwise the preceding Friday."""
    while day.weekday() >= 5:
        day -= timedelta(days=1)
    return day


def _count_working_days(start: date, end: date) -> int:
    """Counts Monday-Friday days in the inclusive range [start, end]."""
    count = 0
    day = start
    while day <= end:
        if day.weekday() < 5:  # Monday-Friday
            count += 1
        day += timedelta(days=1)
    return count


def total_working_days(today: date) -> int:
    last_day = monthrange(today.year, today.month)[1]
    return _count_working_days(date(today.year, today.month, 1), date(today.year, today.month, last_day))


def worked_working_days(today: date) -> int:
    """Working days from the start of the month through today, inclusive."""
    return _count_working_days(date(today.year, today.month, 1), today)


def compute_usage(conn: sqlite3.Connection, real_today: date) -> dict:
    today = last_working_day(real_today)
    # A weekend at the very start of a month has no working day yet in the new
    # month, so show the new month with a budget of 0 instead of last month's Friday.
    new_month_weekend = today.month != real_today.month
    if new_month_weekend:
        today = real_today

    used_this_month = aic_used(conn, today.strftime("%Y-%m"))
    used_before_today = 0.0 if new_month_weekend else aic_used_between(conn, today.replace(day=1), today)
    used_today = used_this_month if new_month_weekend else aic_used(conn, today.isoformat())

    days_total = total_working_days(today)
    worked_days_incl_today = worked_working_days(today)
    target_to_date = (
        (MONTHLY_BUDGET / days_total) * worked_days_incl_today if days_total > 0 else MONTHLY_BUDGET
    )

    # Today's "max" is whatever headroom is left to reach target_to_date: if prior days
    # already overdrew the budget, this is negative and today starts already over 100%.
    max_today = target_to_date - used_before_today
    if max_today > 0:
        percentage = used_today / max_today * 100
    else:
        percentage = 100 if used_today > 0 else 0

    return {
        "month": calendar.month_name[today.month],
        "worked_days": worked_days_incl_today,
        "days_total": days_total,
        "used_month": used_this_month,
        "used_today": used_today,
        "max_today": max_today,
        "ideal_daily": MONTHLY_BUDGET / days_total if days_total > 0 else 0,
        "percentage": percentage,
    }


def format_remaining(remaining: float) -> str:
    if round(remaining) < 0:
        return f"over budget by {-remaining:,.0f} AIC"
    return f"{remaining:,.0f} AIC"


def main() -> None:
    if not DB_PATH.exists():
        print(f" | image={pie_chart_image(100)}")
        print("---")
        print("Copilot session store not found")
        return

    conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    try:
        u = compute_usage(conn, date.today())
        if u["used_today"] <= 0:
            return
        pie_icon = pie_chart_image(u["percentage"])

        print(f" | image={pie_icon}")
        print("---")
        print(f"{u['month']} · working day {u['worked_days']} of {u['days_total']}")
        print("---")
        print(f"Monthly budget: {MONTHLY_BUDGET:,} AIC")
        print(f"Used this month: {u['used_month']:,.0f} AIC ({u['used_month'] / MONTHLY_BUDGET * 100:.0f}%)")
        print(f"Remaining: {format_remaining(MONTHLY_BUDGET - u['used_month'])}")
        print("---")
        print(f"Baseline per working day: {u['ideal_daily']:,.0f} AIC")
        print(f"Today's budget: {max(u['max_today'], 0):,.0f} AIC")
        print(f"Used today: {u['used_today']:,.0f} AIC ({u['percentage']:.0f}%)")
        print(f"Remaining: {format_remaining(u['max_today'] - u['used_today'])}")
    except Exception as e:
        print(f" | image={pie_chart_image(100)}")
        print("---")
        print(f"Error reading Copilot usage data: {e}")
    finally:
        conn.close()


def run_tests() -> None:
    import unittest
    from datetime import datetime, timezone

    def make_conn(usage_by_day: dict) -> sqlite3.Connection:
        """In-memory store with one event per date at 23:30 local time (stored as UTC)."""
        conn = sqlite3.connect(":memory:")
        conn.execute("CREATE TABLE assistant_usage_events (created_at TEXT, total_nano_aiu INTEGER)")
        for day, aic in usage_by_day.items():
            local = datetime(day.year, day.month, day.day, 23, 30).astimezone(timezone.utc)
            conn.execute(
                "INSERT INTO assistant_usage_events VALUES (?, ?)",
                (local.strftime("%Y-%m-%dT%H:%M:%S.000Z"), int(aic * 1e9)),
            )
        return conn

    class Tests(unittest.TestCase):
        def test_last_working_day(self):
            self.assertEqual(last_working_day(date(2026, 10, 16)), date(2026, 10, 16))
            self.assertEqual(last_working_day(date(2026, 10, 17)), date(2026, 10, 16))
            self.assertEqual(last_working_day(date(2026, 10, 18)), date(2026, 10, 16))

        def test_working_day_counts(self):
            self.assertEqual(total_working_days(date(2026, 10, 1)), 22)
            self.assertEqual(worked_working_days(date(2026, 10, 12)), 8)
            self.assertEqual(worked_working_days(date(2026, 8, 1)), 0)

        def test_local_time_bucketing(self):
            conn = make_conn({date(2026, 10, 12): 100})
            self.assertEqual(aic_used(conn, "2026-10-12"), 100)
            self.assertEqual(aic_used(conn, "2026-10-13"), 0)
            self.assertEqual(aic_used(conn, "2026-10"), 100)

        def test_weekday(self):
            conn = make_conn({date(2026, 10, 9): 1000, date(2026, 10, 12): 500})
            u = compute_usage(conn, date(2026, 10, 12))
            target = MONTHLY_BUDGET / 22 * 8
            self.assertEqual(u["worked_days"], 8)
            self.assertEqual(u["month"], "October")
            self.assertAlmostEqual(u["ideal_daily"], MONTHLY_BUDGET / 22)
            self.assertAlmostEqual(u["used_today"], 500)
            self.assertAlmostEqual(u["max_today"], target - 1000)
            self.assertAlmostEqual(u["percentage"], 500 / (target - 1000) * 100)

        def test_weekend_shows_friday(self):
            conn = make_conn({date(2026, 10, 15): 1000, date(2026, 10, 16): 500, date(2026, 10, 17): 300})
            weekday = compute_usage(conn, date(2026, 10, 16))
            for weekend_day in (date(2026, 10, 17), date(2026, 10, 18)):
                u = compute_usage(conn, weekend_day)
                self.assertEqual(u["worked_days"], weekday["worked_days"])
                self.assertAlmostEqual(u["used_today"], 500)
                self.assertAlmostEqual(u["max_today"], weekday["max_today"])
                self.assertAlmostEqual(u["used_month"], 1800)

        def test_saturday_first_of_month_has_zero_budget(self):
            conn = make_conn({date(2026, 7, 31): 900})
            u = compute_usage(conn, date(2026, 8, 1))
            self.assertEqual((u["worked_days"], u["days_total"]), (0, 21))
            self.assertEqual(u["max_today"], 0)
            self.assertEqual(u["used_month"], 0)
            self.assertEqual(u["percentage"], 0)

        def test_new_month_weekend_with_usage_is_over_budget(self):
            conn = make_conn({date(2026, 8, 1): 50, date(2026, 8, 2): 25})
            u = compute_usage(conn, date(2026, 8, 2))
            self.assertEqual(u["used_today"], 75)
            self.assertEqual(u["max_today"], 0)
            self.assertEqual(u["percentage"], 100)

        def test_overdrawn_budget_is_100_percent(self):
            conn = make_conn({date(2026, 10, 9): 10000, date(2026, 10, 12): 1})
            u = compute_usage(conn, date(2026, 10, 12))
            self.assertLess(u["max_today"], 0)
            self.assertEqual(u["percentage"], 100)

        def test_zero_usage_today_never_shows_red(self):
            cases = [
                (make_conn({}), date(2026, 10, 12)),
                (make_conn({date(2026, 10, 9): 10000}), date(2026, 10, 12)),  # overdrawn earlier
                (make_conn({date(2026, 10, 9): 10000}), date(2026, 10, 17)),  # weekend after overdrawn
                (make_conn({date(2026, 7, 31): 900}), date(2026, 8, 1)),  # new-month weekend, budget 0
            ]
            for conn, day in cases:
                u = compute_usage(conn, day)
                self.assertEqual(u["used_today"], 0, day)
                self.assertEqual(u["percentage"], 0, day)

        def test_monthly_budget_setting(self):
            self.assertEqual(parse_monthly_budget("30000"), 30000)
            self.assertEqual(parse_monthly_budget("30000.0"), 30000)
            for bad in (None, "", "abc", "0", "-5", "nan", "inf"):
                self.assertEqual(parse_monthly_budget(bad), DEFAULT_MONTHLY_BUDGET, bad)

        def test_icon_is_valid_png(self):
            for pct in (0, 24, 100):
                png = base64.b64decode(pie_chart_image(pct))
                self.assertTrue(png.startswith(b"\x89PNG\r\n\x1a\n"))

    suite = unittest.defaultTestLoader.loadTestsFromTestCase(Tests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    if "--test" in sys.argv[1:]:
        run_tests()
    else:
        main()
