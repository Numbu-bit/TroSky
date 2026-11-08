"""The trip service: each listed edge case, and the rules no event sequence may break."""

import unittest
from datetime import UTC, datetime, timedelta

from hypothesis import settings
from hypothesis import strategies as st
from hypothesis.stateful import RuleBasedStateMachine, invariant, precondition, rule

from seat_allocation import load_config, minibus_variant, single_file
from seat_allocation.route import Route, Stop
from seat_allocation.service import (
    SeatServiceError,
    SeatStatus,
    Trip,
    TripSeatService,
)

CONFIG = load_config()
ONLINE = CONFIG.replace("assignment", mode="online")
DEPARTURE = datetime(2026, 11, 9, 7, 30, tzinfo=UTC)
ROUTE = Route(
    stops=[
        Stop("s0", "Madina", 0, 0.0),
        Stop("s1", "Legon", 1, 4.0),
        Stop("s2", "37", 2, 8.0),
        Stop("s3", "Circle", 3, 12.0),
    ],
    name="Madina to Circle",
)
POLYLINE_ROUTE = Route(
    polyline=[(5.600, -0.200), (5.600, -0.155), (5.609, -0.155), (5.609, -0.200)]
)


class Clock:
    def __init__(self, now=None):
        self.now = now or DEPARTURE - timedelta(hours=1)

    def __call__(self):
        return self.now


def service(config=CONFIG, layout=None, clock=None, route=ROUTE):
    trip = Trip("t1", "v1", DEPARTURE, route=route)
    return TripSeatService(trip, layout or single_file(5), config, clock=clock or Clock())


def filled(config=CONFIG, kms=(12.0, 3.0, 8.0, 1.0, 6.0), layout=None, clock=None):
    s = service(config=config, layout=layout, clock=clock)
    for i, km in enumerate(kms):
        s.create_booking(f"p{i}", alight=km)
    return s


class TestEdgeCases(unittest.TestCase):
    def test_equal_alight_positions(self):
        s = filled(kms=(6.0, 6.0))
        self.assertEqual(s.current_blocking()[0], 0)
        self.assertEqual(sorted(s.seats.values()), ["4", "5"])

    def test_a_single_passenger(self):
        s = service(layout=minibus_variant(15))
        result = s.create_booking("solo", alight=9.0)
        self.assertEqual(s.current_blocking()[0], 0)
        self.assertIn(result.seat, ("F1", "F2"))

    def test_a_full_vehicle_refuses_the_next_booking_and_forgets_it(self):
        s = filled()
        with self.assertRaises(SeatServiceError) as refused:
            s.create_booking("extra", alight=5.0)
        self.assertEqual(refused.exception.code, "NO_SEAT")
        self.assertNotIn("extra", s.bookings)
        self.assertEqual(len(s.seats), 5)

    def split_stretches(self):
        """Each stop has a free seat, but no one seat is free for the whole route."""
        s = service(layout=single_file(2))
        s.create_booking("early", alight=4.0, board=0.0)
        s.create_booking("late", alight=12.0, board=4.0)
        self.assertNotEqual(s.seats["early"], s.seats["late"])
        return s

    def test_people_shift_so_a_new_passenger_can_keep_one_seat_throughout(self):
        s = self.split_stretches()
        result = s.create_booking("long", alight=12.0, board=0.0)
        self.assertEqual(s.seats["early"], s.seats["late"])
        self.assertNotEqual(result.seat, s.seats["early"])
        self.assertEqual(s.current_blocking()[0], 0)

    def test_after_the_lock_nobody_shifts_so_that_booking_is_refused(self):
        s = self.split_stretches()
        seats = dict(s.seats)
        s.lock()
        with self.assertRaises(SeatServiceError) as refused:
            s.create_booking("long", alight=12.0, board=0.0)
        self.assertEqual(refused.exception.code, "NO_SEAT")
        self.assertEqual(s.seats, seats)

    def test_destination_changed_before_the_lock_re_seats_people(self):
        s = filled()
        self.assertEqual(s.seats["p3"], "1")  # the 1 km passenger is by the door
        result = s.change_destination("p3", alight=20.0)
        self.assertEqual(s.seats["p3"], "5")  # now going farthest
        self.assertEqual(s.current_blocking()[0], 0)
        self.assertIsNone(result.warning)
        self.assertTrue(result.other_moves)

    def test_destination_changed_after_the_lock_keeps_the_seat_and_warns(self):
        s = filled()
        s.lock()
        before = dict(s.seats)
        result = s.change_destination("p3", alight=20.0)
        self.assertEqual(s.seats, before)
        self.assertEqual(result.added_blocking, 4)
        self.assertIn("cannot change", result.warning)

    def test_a_destination_behind_the_pickup_is_refused(self):
        s = service()
        with self.assertRaises(SeatServiceError) as refused:
            s.create_booking("a", alight=5.0, board=8.0)
        self.assertEqual(refused.exception.code, "BEHIND_PICKUP")

    def test_a_destination_off_the_route_is_refused(self):
        s = service(route=POLYLINE_ROUTE)
        with self.assertRaises(SeatServiceError) as refused:
            s.create_booking("a", destination_point=(5.70, -0.17))
        self.assertEqual(refused.exception.code, "OFF_ROUTE")

    def test_a_bad_gps_fix_is_refused(self):
        s = service(route=POLYLINE_ROUTE)
        with self.assertRaises(SeatServiceError) as refused:
            s.create_booking("a", destination_point=(0.0, 0.0))
        self.assertEqual(refused.exception.code, "GPS_ERROR")

    def test_a_stop_on_the_route_is_used_with_its_name(self):
        s = service()
        s.create_booking("a", destination_stop="s2")
        self.assertEqual(s.bookings["a"].alight, 8.0)
        self.assertEqual(s.bookings["a"].alight_name, "37")

    def test_passenger_refuses_the_seat_and_sees_the_cost(self):
        s = filled()
        s_before = dict(s.seats)
        quote = s.quote_swap("p0", "1")  # the farthest passenger wants the door seat
        self.assertTrue(quote.allowed)
        self.assertEqual(quote.added_blocking, 4)
        self.assertIn("4 more passengers", quote.warning)
        self.assertEqual(s.seats, s_before, "a quote changes nothing")

    def test_passenger_confirms_and_the_override_sticks(self):
        s = filled()
        s.confirm_swap("p0", "1")
        self.assertEqual(s.seats["p0"], "1")
        self.assertEqual(s.overrides["p0"].added_blocking, 4)
        self.assertEqual(s.current_blocking()[0], 4)
        s.cancel_booking("p3")  # a re-run must not undo their choice
        self.assertEqual(s.seats["p0"], "1")
        self.assertEqual(s.passenger_message("p0"), "Seat 1: the seat you chose.")

    def test_a_swap_that_costs_nothing_has_no_warning(self):
        s = filled(kms=(9.0, 2.0))
        quote = s.quote_swap("p1", "1")
        self.assertTrue(quote.allowed)
        self.assertEqual(quote.added_blocking, 0)
        self.assertIsNone(quote.warning)

    def test_overrides_can_be_switched_off(self):
        config = CONFIG.replace("assignment", allow_passenger_override=False)
        s = filled(config=config)
        quote = s.quote_swap("p0", "1")
        self.assertFalse(quote.allowed)
        with self.assertRaises(SeatServiceError) as refused:
            s.confirm_swap("p0", "1")
        self.assertEqual(refused.exception.code, "SWAP_REFUSED")

    def test_swap_refusals(self):
        s = filled(kms=(12.0, 3.0))
        s.mark_boarded("p0")
        self.assertFalse(s.quote_swap("p0", "1").allowed)  # already on board
        self.assertFalse(s.quote_swap("p1", s.seats["p0"]).allowed)  # taken by someone on board
        self.assertFalse(s.quote_swap("p1", "99").allowed)  # no such seat
        self.assertFalse(s.quote_swap("p1", s.seats["p1"]).allowed)  # already theirs

    def test_a_priority_passengers_seat_cannot_be_taken_by_a_swap(self):
        s = service(layout=minibus_variant(15))
        s.create_booking("old", alight=9.0, category="elderly")
        s.create_booking("a", alight=4.0)
        quote = s.quote_swap("a", s.seats["old"])
        self.assertFalse(quote.allowed)
        self.assertIn("priority", quote.reason)

    def test_after_the_lock_only_an_empty_seat_can_be_chosen(self):
        s = filled(kms=(12.0, 3.0))
        s.lock()
        taken = s.seats["p0"]
        self.assertFalse(s.quote_swap("p1", taken).allowed)
        quote = s.quote_swap("p1", "1")
        self.assertTrue(quote.allowed)
        self.assertEqual(quote.other_moves, ())

    def test_the_driver_seat_cannot_be_requested(self):
        s = service(layout=minibus_variant(15))
        s.create_booking("a", alight=9.0)
        self.assertFalse(s.quote_swap("a", "DRV").allowed)

    def test_a_group_wider_than_the_seats_together(self):
        s = service()
        s.create_booking("x", alight=9.0)
        s.create_booking("y", alight=9.0)
        s.mark_boarded("x", actual_seat="2")
        s.mark_boarded("y", actual_seat="4")
        for name in ("g1", "g2", "g3"):
            s.create_booking(name, alight=9.0, group_id="g")
        self.assertEqual(len(s.seats), 5)
        self.assertEqual(s._view().split_groups[0].group_id, "g")

    def test_needing_access_with_no_accessible_seat_is_refused(self):
        layout = single_file(2)
        s = service(layout=layout)
        s.create_booking("first", alight=9.0, needs_accessible=True)
        with self.assertRaises(SeatServiceError) as refused:
            s.create_booking("second", alight=9.0, needs_accessible=True)
        self.assertEqual(refused.exception.code, "NO_SEAT")
        self.assertIn("A person must arrange", refused.exception.message)

    def test_a_child_with_an_adult(self):
        s = service(layout=minibus_variant(15))
        s.create_booking("mum", alight=8.0, group_id="fam")
        s.create_booking("kid", alight=8.0, group_id="fam", category="child")
        for i in range(6):
            s.create_booking(f"p{i}", alight=2.0 + i)
        layout = minibus_variant(15)
        self.assertIn(s.seats["kid"], layout.seat(s.seats["mum"]).neighbours)

    def test_luggage(self):
        s = service(layout=minibus_variant(15))
        s.create_booking("bag", alight=5.0, luggage="bulky")
        s.create_booking("b", alight=2.0)
        self.assertIn("luggage", s.layout.seat(s.seats["bag"]).tags)

    def test_a_no_show_frees_the_seat_and_others_move_up_before_the_lock(self):
        s = filled()
        s.mark_no_show("p3")
        self.assertNotIn("p3", s.seats)
        self.assertEqual(s.status["p3"], SeatStatus.NO_SHOW)
        self.assertEqual(s.current_blocking()[0], 0)

    def test_a_no_show_after_the_lock_moves_nobody(self):
        s = filled()
        s.lock()
        before = {k: v for k, v in s.seats.items() if k != "p3"}
        s.mark_no_show("p3")
        self.assertEqual(s.seats, before)

    def test_someone_on_board_cannot_be_a_no_show(self):
        s = filled()
        s.mark_boarded("p0")
        with self.assertRaises(SeatServiceError) as refused:
            s.mark_no_show("p0")
        self.assertEqual(refused.exception.code, "ALREADY_BOARDED")

    def test_cancelling_frees_the_seat(self):
        s = filled()
        s.cancel_booking("p0")
        self.assertEqual(len(s.seats), 4)
        s.create_booking("new", alight=30.0)
        self.assertEqual(s.seats["new"], "5")

    def test_a_detour_changes_the_order_of_stops(self):
        s = service()
        s.create_booking("a", destination_stop="s1")
        s.create_booking("b", destination_stop="s2")
        self.assertEqual((s.seats["a"], s.seats["b"]), ("4", "5"))
        detour = Route(
            stops=[
                Stop("s0", "Madina", 0, 0.0),
                Stop("s2", "37", 1, 4.0),
                Stop("s1", "Legon", 2, 9.0),
                Stop("s3", "Circle", 3, 12.0),
            ]
        )
        s.apply_route_change(detour, "road closed at Legon")
        self.assertEqual((s.seats["a"], s.seats["b"]), ("5", "4"))
        self.assertEqual(s.current_blocking()[0], 0)

    def test_a_detour_that_drops_a_stop_is_handed_to_a_person(self):
        s = service()
        s.create_booking("a", destination_stop="s1")
        without = Route(stops=[Stop("s0", "Madina", 0, 0.0), Stop("s3", "Circle", 3, 12.0)])
        self.assertEqual(s.apply_route_change(without), ("a",))

    def test_a_detour_after_the_lock_moves_nobody(self):
        s = service()
        s.create_booking("a", destination_stop="s1")
        s.create_booking("b", destination_stop="s2")
        s.lock()
        before = dict(s.seats)
        detour = Route(
            stops=[
                Stop("s0", "M", 0, 0.0),
                Stop("s2", "37", 1, 4.0),
                Stop("s1", "L", 2, 9.0),
                Stop("s3", "C", 3, 12.0),
            ]
        )
        s.apply_route_change(detour)
        self.assertEqual(s.seats, before)
        self.assertEqual(s.current_blocking()[0], 1)


class TestNobodyLosesTheirSeat(unittest.TestCase):
    def test_a_priority_booking_cannot_take_a_seat_from_someone_on_a_full_vehicle(self):
        for config in (CONFIG, ONLINE):
            with self.subTest(mode=config.assignment.mode):
                s = filled(config=config)
                before = dict(s.seats)
                log_length = len(s.audit)
                with self.assertRaises(SeatServiceError) as refused:
                    s.create_booking("old", alight=4.0, category="elderly")
                self.assertEqual(refused.exception.code, "NO_SEAT")
                self.assertIn("full", refused.exception.message)
                self.assertEqual(s.seats, before)
                self.assertEqual(len(s.audit), log_length, "a refused booking leaves no trace")

    def test_a_passenger_needing_access_can_displace_someone_only_provisional(self):
        for config in (CONFIG, ONLINE):
            with self.subTest(mode=config.assignment.mode):
                s = service(config=config, layout=single_file(3))
                s.create_booking("a", alight=9.0)
                s.create_booking("b", alight=2.0)
                s.seats["b"] = "1"  # b holds the only accessible seat, provisionally
                result = s.create_booking("wheels", alight=5.0, needs_accessible=True)
                self.assertEqual(result.seat, "1")
                self.assertNotEqual(s.seats["b"], "1")

    def test_an_accessible_seat_held_by_someone_on_board_is_a_refusal(self):
        s = service(layout=single_file(3))
        s.create_booking("a", alight=9.0)
        s.mark_boarded("a", actual_seat="1")
        with self.assertRaises(SeatServiceError) as refused:
            s.create_booking("wheels", alight=5.0, needs_accessible=True)
        self.assertEqual(refused.exception.code, "NO_SEAT")

    def test_a_longer_ride_cannot_run_into_the_next_passenger_on_that_seat(self):
        s = filled(kms=(5.0,), layout=single_file(1))
        s.create_booking("next", alight=9.0, board=5.0)
        s.lock()
        before = s.bookings["p0"]
        with self.assertRaises(SeatServiceError) as refused:
            s.change_destination("p0", alight=7.0)
        self.assertEqual(refused.exception.code, "SEAT_CONFLICT")
        self.assertEqual(s.bookings["p0"], before)

    def test_a_longer_ride_on_a_full_vehicle_is_refused_before_the_lock(self):
        s = filled(kms=(5.0,), layout=single_file(1))
        s.create_booking("next", alight=9.0, board=5.0)
        before = s.bookings["p0"]
        with self.assertRaises(SeatServiceError) as refused:
            s.change_destination("p0", alight=7.0)
        self.assertEqual(refused.exception.code, "NO_SEAT")
        self.assertEqual(s.bookings["p0"], before)

    def test_a_detour_that_would_double_book_a_locked_seat_goes_to_a_person(self):
        s = service(layout=single_file(1))
        s.create_booking("first", destination_stop="s1")
        s.create_booking("second", destination_stop="s2", pickup_stop="s1")
        s.lock()
        longer = Route(
            stops=[
                Stop("s0", "Madina", 0, 0.0),
                Stop("s1", "Legon", 1, 6.0),
                Stop("s2", "37", 2, 8.0),
            ]
        )
        # The first passenger would now get off at km 6, after the second boarded at km 4.
        self.assertEqual(s.apply_route_change(longer), ("first",))
        self.assertEqual(s.current_blocking()[0], 0)

    def test_sitting_in_an_unknown_seat_is_refused(self):
        s = filled(kms=(9.0,))
        with self.assertRaises(SeatServiceError) as refused:
            s.mark_boarded("p0", actual_seat="99")
        self.assertEqual(refused.exception.code, "UNKNOWN_SEAT")


class TestLocksAndBoarding(unittest.TestCase):
    def test_the_lock_arrives_on_its_own_at_the_configured_time(self):
        clock = Clock()
        s = filled(kms=(9.0, 2.0), clock=clock)
        self.assertFalse(s.locked)
        clock.now = DEPARTURE - timedelta(minutes=CONFIG.assignment.lock_minutes_before_departure)
        s.seat_map()
        self.assertTrue(s.locked)
        self.assertEqual(s.status["p0"], SeatStatus.LOCKED)

    def test_a_boarded_passenger_never_moves_even_when_re_optimising(self):
        s = filled(kms=(9.0, 2.0))
        s.mark_boarded("p0", actual_seat="1")  # sat by the door, going far
        seat = s.seats["p0"]
        s.create_booking("a", alight=5.0)
        s.create_booking("b", alight=1.0)
        s.change_destination("p1", alight=20.0)
        self.assertEqual(s.seats["p0"], seat)
        self.assertEqual(seat, "1")

    def test_sitting_elsewhere_is_counted_and_the_seat_owner_is_re_seated(self):
        s = filled(kms=(9.0, 2.0))
        owner_seat = s.seats["p1"]
        s.mark_boarded("p0", actual_seat=owner_seat)
        self.assertEqual(s.seats["p0"], owner_seat)
        self.assertNotEqual(s.seats["p1"], owner_seat)
        self.assertEqual(s.seat_ignored_count, 1)

    def test_a_seat_already_occupied_on_board_is_a_conflict_for_a_person(self):
        s = filled(kms=(9.0, 2.0))
        s.mark_boarded("p0")
        with self.assertRaises(SeatServiceError) as refused:
            s.mark_boarded("p1", actual_seat=s.seats["p0"])
        self.assertEqual(refused.exception.code, "SEAT_TAKEN")

    def test_marking_boarded_twice_changes_nothing(self):
        s = filled(kms=(9.0, 2.0))
        first = s.mark_boarded("p0")
        count = len(s.audit)
        self.assertEqual(s.mark_boarded("p0"), first)
        self.assertEqual(len(s.audit), count)

    def test_alighting_records_who_really_moved(self):
        s = filled(kms=(12.0, 3.0))
        s.confirm_swap("p0", "1")
        s.mark_boarded("p0")
        s.mark_boarded("p1")
        result = s.mark_alighted("p1")
        self.assertEqual(result.had_to_move, ("p0",))
        self.assertEqual(s.blocking_events, 1)

    def test_no_blocking_event_when_seated_in_order(self):
        s = filled(kms=(12.0, 3.0))
        s.mark_boarded("p0")
        s.mark_boarded("p1")
        self.assertEqual(s.mark_alighted("p1").had_to_move, ())
        self.assertEqual(s.blocking_events, 0)

    def test_seat_map_shows_boarding_order_and_who_is_next_off(self):
        s = filled()
        view = s.seat_map()
        self.assertEqual(view.boarding_order, ("p0", "p2", "p4", "p1", "p3"))
        self.assertEqual(view.next_off, ("p3",))
        self.assertEqual([row.seat for row in view.rows], ["5", "4", "3", "2", "1"])
        self.assertTrue(next(row for row in view.rows if row.booking_id == "p3").next_off)
        s.mark_boarded("p0")
        s.mark_boarded("p2")
        self.assertEqual(s.seat_map().next_off, ("p2",))

    def test_an_unknown_booking_is_refused(self):
        s = service()
        with self.assertRaises(SeatServiceError) as refused:
            s.mark_boarded("ghost")
        self.assertEqual(refused.exception.code, "UNKNOWN_BOOKING")

    def test_a_duplicate_booking_is_refused(self):
        s = service()
        s.create_booking("a", alight=4.0)
        with self.assertRaises(SeatServiceError) as refused:
            s.create_booking("a", alight=4.0)
        self.assertEqual(refused.exception.code, "DUPLICATE_BOOKING")


class TestAuditLog(unittest.TestCase):
    def test_every_seat_change_is_logged_with_a_reason(self):
        s = filled()
        s.change_destination("p3", alight=20.0)
        changes = [entry for entry in s.audit if entry.action == "seat_changed"]
        self.assertTrue(changes)
        for entry in changes:
            self.assertTrue(entry.reason)
            self.assertIsNotNone(entry.from_seat)
            self.assertIsNotNone(entry.to_seat)

    def test_the_log_can_rebuild_every_passenger_seat(self):
        s = filled()
        s.change_destination("p3", alight=20.0)
        s.confirm_swap("p0", "1")
        rebuilt = {}
        for entry in s.audit:
            if entry.action in ("seat_assigned", "seat_changed") and entry.to_seat:
                rebuilt[entry.booking_id] = entry.to_seat
        self.assertEqual(rebuilt, s.seats)

    def test_entries_are_numbered_and_cannot_be_edited(self):
        s = filled(kms=(9.0, 2.0))
        self.assertEqual([e.seq for e in s.audit], list(range(1, len(s.audit) + 1)))
        with self.assertRaises(AttributeError):
            s.audit[0].reason = "changed"  # type: ignore[misc]
        self.assertIsInstance(s.audit, tuple)

    def test_each_run_records_before_and_after(self):
        s = filled()
        run = s.runs[-1]
        self.assertEqual(run.blocking_after, 0)
        self.assertEqual(run.mode, "batch")
        self.assertIn("new booking", run.trigger)


class TripEvents(RuleBasedStateMachine):
    """Any order of events must keep the service's promises."""

    def __init__(self):
        super().__init__()
        self.clock = Clock()
        self.service = TripSeatService(
            Trip("t", "v", DEPARTURE, route=ROUTE), minibus_variant(14), ONLINE, clock=self.clock
        )
        self.count = 0
        self.boarded_seats = {}
        self.locked_seats = None

    def _active_ids(self):
        return sorted(b.id for b in self.service.active())

    def _unboarded(self):
        return [b for b in self._active_ids() if self.service.status[b] is not SeatStatus.BOARDED]

    @rule(
        km=st.integers(1, 12),
        board=st.sampled_from((0, 0, 0, 4)),
        category=st.sampled_from(("standard", "standard", "elderly", "child")),
        group=st.sampled_from((None, None, "g1", "g2")),
    )
    def book(self, km, board, category, group):
        self.count += 1
        try:
            self.service.create_booking(
                f"b{self.count}",
                alight=float(board + km),
                board=float(board),
                category=category,
                group_id=group,
            )
        except SeatServiceError:
            pass

    @precondition(lambda self: self._unboarded())
    @rule(pick=st.integers(0, 100))
    def board(self, pick):
        ids = self._unboarded()
        name = ids[pick % len(ids)]
        self.boarded_seats[name] = self.service.mark_boarded(name)

    @precondition(lambda self: self._unboarded())
    @rule(pick=st.integers(0, 100))
    def cancel(self, pick):
        ids = self._unboarded()
        self.service.cancel_booking(ids[pick % len(ids)])

    @precondition(lambda self: self._unboarded())
    @rule(pick=st.integers(0, 100))
    def no_show(self, pick):
        ids = self._unboarded()
        self.service.mark_no_show(ids[pick % len(ids)])

    @precondition(lambda self: self._active_ids())
    @rule(pick=st.integers(0, 100), km=st.integers(5, 14))
    def change_destination(self, pick, km):
        ids = self._active_ids()
        try:
            self.service.change_destination(ids[pick % len(ids)], alight=float(km))
        except SeatServiceError:
            pass

    @precondition(lambda self: self._unboarded())
    @rule(pick=st.integers(0, 100), seat=st.integers(0, 40))
    def swap(self, pick, seat):
        ids = self._unboarded()
        seats = self.service.layout.bookable_seats()
        target = seats[seat % len(seats)].id
        quote = self.service.quote_swap(ids[pick % len(ids)], target)
        if quote.allowed:
            self.service.confirm_swap(ids[pick % len(ids)], target)

    @rule()
    def lock(self):
        self.service.lock()
        if self.locked_seats is None:
            self.locked_seats = dict(self.service.seats)

    @precondition(lambda self: self.service.boarded())
    @rule(pick=st.integers(0, 100))
    def alight(self, pick):
        ids = sorted(self.service.boarded())
        name = ids[pick % len(ids)]
        self.service.mark_alighted(name)
        self.boarded_seats.pop(name, None)

    @invariant()
    def boarded_passengers_never_move(self):
        for name, seat in self.boarded_seats.items():
            assert self.service.seats[name] == seat

    @invariant()
    def nobody_shares_a_seat_while_overlapping(self):
        active = self.service.active()
        for i, a in enumerate(active):
            for b in active[i + 1 :]:
                if self.service.seats.get(a.id) == self.service.seats.get(b.id):
                    assert a.alight <= b.board or b.alight <= a.board

    @invariant()
    def every_active_booking_has_a_seat(self):
        for booking in self.service.active():
            assert booking.id in self.service.seats

    @invariant()
    def after_the_lock_only_a_chosen_seat_changes(self):
        if self.locked_seats is None:
            return
        chosen = set(self.service.overrides)
        for name, seat in self.locked_seats.items():
            if name in self.service.seats and name not in chosen:
                assert self.service.seats[name] == seat, name

    @invariant()
    def the_log_explains_every_seat(self):
        rebuilt = {}
        for entry in self.service.audit:
            if entry.action in ("seat_assigned", "seat_changed"):
                assert entry.reason
                rebuilt[entry.booking_id] = entry.to_seat
        for name, seat in self.service.seats.items():
            assert rebuilt[name] == seat


TripEvents.TestCase.settings = settings(max_examples=25, stateful_step_count=25, deadline=None)
TestTripEvents = TripEvents.TestCase


if __name__ == "__main__":
    unittest.main()
