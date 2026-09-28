"""Unit tests for client IP resolution behind (or in front of) proxies.

The rule under test: ``X-Forwarded-For`` is believed only when the TCP peer
is a proxy we run, and then read right to left, stopping at the first
address that is not one of our proxies. Every entry to the left of that was
written by the client and must never decide who the client is.
"""

from __future__ import annotations

import ipaddress
from types import SimpleNamespace

import pytest
from pydantic import ValidationError

from app.core.client_ip import resolve_client_ip
from app.core.config import Settings

PRIVATE = [ipaddress.ip_network(n) for n in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")]


def _request(peer: str | None, forwarded: str | None = None) -> SimpleNamespace:
    headers = {"x-forwarded-for": forwarded} if forwarded is not None else {}
    return SimpleNamespace(
        client=SimpleNamespace(host=peer) if peer is not None else None, headers=headers
    )


class TestUntrustedPeer:
    def test_a_forged_header_is_ignored(self) -> None:
        """The attack: rotate the header to get a fresh rate-limit bucket."""
        assert resolve_client_ip(_request("203.0.113.9", "1.1.1.1"), PRIVATE) == "203.0.113.9"

    def test_with_no_trusted_proxies_the_peer_is_always_the_client(self) -> None:
        assert resolve_client_ip(_request("10.0.0.5", "1.1.1.1"), []) == "10.0.0.5"

    def test_a_request_with_no_peer_has_no_address(self) -> None:
        assert resolve_client_ip(_request(None, "1.1.1.1"), PRIVATE) is None


class TestTrustedProxy:
    def test_the_address_the_proxy_appended_is_the_client(self) -> None:
        assert resolve_client_ip(_request("10.0.0.5", "198.51.100.7"), PRIVATE) == "198.51.100.7"

    def test_a_forged_entry_left_of_the_real_one_is_ignored(self) -> None:
        """The client sent ``X-Forwarded-For: 1.1.1.1``; the proxy appended
        the real address. Taking the leftmost entry -- the old behaviour --
        would believe the forgery."""
        resolved = resolve_client_ip(_request("10.0.0.5", "1.1.1.1, 198.51.100.7"), PRIVATE)
        assert resolved == "198.51.100.7"

    def test_a_chain_of_our_own_proxies_is_walked_through(self) -> None:
        resolved = resolve_client_ip(
            _request("10.0.0.5", "1.1.1.1, 198.51.100.7, 10.0.0.9, 172.16.4.4"), PRIVATE
        )
        assert resolved == "198.51.100.7"

    def test_when_every_hop_is_ours_the_leftmost_is_the_originator(self) -> None:
        resolved = resolve_client_ip(_request("10.0.0.5", "192.168.1.20, 10.0.0.9"), PRIVATE)
        assert resolved == "192.168.1.20"

    def test_no_header_means_the_proxy_itself_is_the_client(self) -> None:
        assert resolve_client_ip(_request("10.0.0.5"), PRIVATE) == "10.0.0.5"

    def test_an_unreadable_hop_stops_the_walk_at_the_last_vouched_address(self) -> None:
        """Garbage cannot become an identifier -- if it could, a client
        could still mint as many rate-limit buckets as it liked."""
        resolved = resolve_client_ip(_request("10.0.0.5", "not-an-ip, 10.0.0.9"), PRIVATE)
        assert resolved == "10.0.0.9"

    def test_empty_entries_are_skipped(self) -> None:
        assert resolve_client_ip(_request("10.0.0.5", "198.51.100.7, "), PRIVATE) == "198.51.100.7"


class TestAddressForms:
    def test_ipv6_clients_and_proxies(self) -> None:
        proxies = [ipaddress.ip_network("fd00::/8")]
        resolved = resolve_client_ip(_request("fd00::1", "2001:db8::42"), proxies)
        assert resolved == "2001:db8::42"

    def test_ports_and_brackets_are_tolerated(self) -> None:
        resolved = resolve_client_ip(_request("10.0.0.5", "198.51.100.7:51234"), PRIVATE)
        assert resolved == "198.51.100.7"
        resolved = resolve_client_ip(_request("10.0.0.5", "[2001:db8::42]:443"), PRIVATE)
        assert resolved == "2001:db8::42"

    def test_an_ipv4_mapped_peer_matches_ipv4_proxy_ranges(self) -> None:
        """A dual-stack socket can report an IPv4 proxy as ::ffff:10.0.0.5."""
        resolved = resolve_client_ip(_request("::ffff:10.0.0.5", "198.51.100.7"), PRIVATE)
        assert resolved == "198.51.100.7"


def _settings(**overrides: object) -> Settings:
    return Settings(
        SECRET_KEY="a" * 40,
        PAYMENTS_WEBHOOK_SIGNING_SECRET="b" * 40,
        TICKET_QR_SIGNING_SECRET="c" * 40,
        DATABASE_URL="postgresql+asyncpg://u:p@localhost:5432/db",
        DATABASE_URL_SYNC="postgresql+psycopg://u:p@localhost:5432/db",
        **overrides,  # type: ignore[arg-type]
    )


class TestSetting:
    def test_the_default_trusts_no_proxy(self) -> None:
        assert _settings().trusted_proxy_networks == []

    def test_ips_and_cidrs_are_parsed(self) -> None:
        networks = _settings(TRUSTED_PROXY_CIDRS="10.0.0.0/8, 192.0.2.10").trusted_proxy_networks
        assert networks == [ipaddress.ip_network("10.0.0.0/8"), ipaddress.ip_network("192.0.2.10")]

    def test_a_typo_fails_at_startup_rather_than_trusting_nothing(self) -> None:
        with pytest.raises(ValidationError, match="TRUSTED_PROXY_CIDRS"):
            _settings(TRUSTED_PROXY_CIDRS="10.0.0.0/8, 10.0.0/8x")
