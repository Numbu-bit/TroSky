"""Unit tests for the trip state machine transition table (pure logic, no
database required)."""

from __future__ import annotations

import pytest

from app.core.exceptions import InvalidStateTransitionError
from app.models.trips import TripStatus
from app.services.trip_service import TRIP_TRANSITIONS, TripService


class TestTripTransitionsTable:
    def test_every_status_has_an_entry(self) -> None:
        assert set(TRIP_TRANSITIONS.keys()) == set(TripStatus)

    def test_terminal_states_have_no_outgoing_transitions(self) -> None:
        assert TRIP_TRANSITIONS[TripStatus.COMPLETED] == set()
        assert TRIP_TRANSITIONS[TripStatus.CANCELLED] == set()

    def test_scheduled_can_reach_boarding_in_progress_or_cancelled(self) -> None:
        assert TRIP_TRANSITIONS[TripStatus.SCHEDULED] == {
            TripStatus.BOARDING,
            TripStatus.IN_PROGRESS,
            TripStatus.CANCELLED,
        }

    def test_in_progress_can_pause_complete_or_cancel(self) -> None:
        assert TRIP_TRANSITIONS[TripStatus.IN_PROGRESS] == {
            TripStatus.PAUSED,
            TripStatus.COMPLETED,
            TripStatus.CANCELLED,
        }

    def test_paused_can_only_resume_or_cancel(self) -> None:
        assert TRIP_TRANSITIONS[TripStatus.PAUSED] == {
            TripStatus.IN_PROGRESS,
            TripStatus.CANCELLED,
        }

    def test_no_status_can_transition_to_scheduled(self) -> None:
        # SCHEDULED is only ever the initial state, never a transition target.
        for status, targets in TRIP_TRANSITIONS.items():
            assert TripStatus.SCHEDULED not in targets, status


class TestAssertTransitionAllowed:
    def test_allows_a_valid_transition(self) -> None:
        TripService._assert_transition_allowed(TripStatus.SCHEDULED, TripStatus.IN_PROGRESS)

    def test_rejects_an_invalid_transition(self) -> None:
        with pytest.raises(InvalidStateTransitionError):
            TripService._assert_transition_allowed(TripStatus.COMPLETED, TripStatus.IN_PROGRESS)

    def test_rejects_transition_from_cancelled(self) -> None:
        with pytest.raises(InvalidStateTransitionError):
            TripService._assert_transition_allowed(TripStatus.CANCELLED, TripStatus.SCHEDULED)

    def test_rejects_skipping_from_scheduled_to_paused(self) -> None:
        with pytest.raises(InvalidStateTransitionError):
            TripService._assert_transition_allowed(TripStatus.SCHEDULED, TripStatus.PAUSED)
