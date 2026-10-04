"""Feature flag rollout: a share of users, the same users every time."""

from __future__ import annotations

import uuid

from app.services.system_settings_service import _in_rollout


class TestRollout:
    def test_none_all_and_about_half(self) -> None:
        users = [uuid.uuid4() for _ in range(2000)]

        half = sum(_in_rollout("trip_share_links", user, 50) for user in users)

        assert not any(_in_rollout("trip_share_links", user, 0) for user in users)
        assert all(_in_rollout("trip_share_links", user, 100) for user in users)
        assert 850 < half < 1150

    def test_the_same_user_always_gets_the_same_answer(self) -> None:
        user = uuid.uuid4()

        answers = {_in_rollout("trip_share_links", user, 37) for _ in range(20)}

        assert len(answers) == 1

    def test_no_user_means_not_in_a_partial_rollout(self) -> None:
        # However large the share: a user must be known to be in it.
        assert _in_rollout("trip_share_links", None, 99) is False
