"""Unit tests for rate-limit rule definitions and client-identifier resolution
(the pure-logic parts of ``app.core.ratelimit`` that don't require Redis)."""

from __future__ import annotations

from types import SimpleNamespace

from app.core.ratelimit import DEFAULT_RULES, RateLimitRule, _client_identifier


class TestDefaultRules:
    def test_known_rules_exist_with_positive_limits(self) -> None:
        for name in (
            "auth:register",
            "auth:login",
            "auth:otp_request",
            "auth:otp_verify",
            "auth:password_reset",
            "auth:token_refresh",
            "payments:initiate",
            "tickets:validate",
            "sos:trigger",
            "tracking:location_publish",
        ):
            rule = DEFAULT_RULES[name]
            assert isinstance(rule, RateLimitRule)
            assert rule.limit > 0
            assert rule.window_seconds > 0


class TestClientIdentifier:
    def _request(self, *, principal=None, headers=None, client_host="1.2.3.4"):
        state = SimpleNamespace(principal=principal)
        client = SimpleNamespace(host=client_host) if client_host else None
        return SimpleNamespace(state=state, headers=headers or {}, client=client)

    def test_prefers_authenticated_principal(self) -> None:
        import uuid

        principal = SimpleNamespace(user_id=uuid.UUID(int=1))
        request = self._request(principal=principal)
        assert _client_identifier(request) == f"user:{principal.user_id}"

    def test_ignores_forwarded_for_from_an_untrusted_peer(self) -> None:
        """This used to return ``ip:9.9.9.9`` -- the address the *client*
        wrote -- which let anyone dodge a limit by varying the header. With
        no trusted proxies configured, the TCP peer is the client."""
        request = self._request(headers={"x-forwarded-for": "9.9.9.9, 1.1.1.1"})
        assert _client_identifier(request) == "ip:1.2.3.4"

    def test_believes_forwarded_for_from_a_trusted_proxy(self, monkeypatch) -> None:
        """Behind our own proxy, the hop it appended identifies the client --
        not the leftmost entry, which the client controls."""
        import ipaddress

        monkeypatch.setattr(
            "app.core.ratelimit.get_settings",
            lambda: SimpleNamespace(trusted_proxy_networks=[ipaddress.ip_network("10.0.0.0/8")]),
        )
        request = self._request(
            headers={"x-forwarded-for": "9.9.9.9, 198.51.100.7"}, client_host="10.1.2.3"
        )
        assert _client_identifier(request) == "ip:198.51.100.7"

    def test_falls_back_to_client_host(self) -> None:
        request = self._request(client_host="5.5.5.5")
        assert _client_identifier(request) == "ip:5.5.5.5"

    def test_falls_back_to_unknown_when_no_client(self) -> None:
        request = self._request(client_host=None)
        assert _client_identifier(request) == "ip:unknown"
