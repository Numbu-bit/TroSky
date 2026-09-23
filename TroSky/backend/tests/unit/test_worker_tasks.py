"""Unit tests for baseline Celery task logic, invoked directly (no broker)."""

from __future__ import annotations

from app.workers.tasks.health import heartbeat


class TestHeartbeatTask:
    def test_heartbeat_returns_ok(self) -> None:
        # `.run()` (or calling the task instance directly with no bound
        # context) executes the underlying function synchronously without
        # requiring a running broker/worker.
        assert heartbeat.run() == "ok"
