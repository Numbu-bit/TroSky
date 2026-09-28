"""The address of whoever is really on the other end of a request.

``request.client.host`` is the TCP peer. Behind a reverse proxy that peer is
the proxy, and the original client appears only in ``X-Forwarded-For`` -- a
header any client can also send itself, naming whatever address it likes.

So the header is believed only when the peer is a proxy we run
(``TRUSTED_PROXY_CIDRS``), and even then only as far as our own proxies can
vouch for it. Each proxy *appends* the address it received the request
from, so reading the header right to left walks back through our proxies;
the first address that is not one of them is the client. Anything further
left was written by the client and is never believed.
"""

from __future__ import annotations

import ipaddress
from collections.abc import Sequence
from typing import Any

IPNetwork = ipaddress.IPv4Network | ipaddress.IPv6Network
IPAddress = ipaddress.IPv4Address | ipaddress.IPv6Address


def _parse(value: str) -> IPAddress | None:
    """An address from a peer or forwarded hop, tolerating the port and
    bracket forms some proxies emit (``203.0.113.9:443``, ``[2001:db8::1]:443``)."""
    candidate = value.strip()
    if candidate.startswith("[") and "]" in candidate:
        candidate = candidate[1 : candidate.index("]")]
    elif candidate.count(":") == 1:
        candidate = candidate.split(":", 1)[0]
    try:
        address = ipaddress.ip_address(candidate)
    except ValueError:
        return None
    # A dual-stack socket may report an IPv4 peer as ::ffff:a.b.c.d; judge
    # it by the IPv4 address it really is, so IPv4 proxy ranges still match.
    if isinstance(address, ipaddress.IPv6Address) and address.ipv4_mapped is not None:
        return address.ipv4_mapped
    return address


def _is_trusted(address: IPAddress, proxies: Sequence[IPNetwork]) -> bool:
    return any(address in network for network in proxies)


def resolve_client_ip(request: Any, trusted_proxies: Sequence[IPNetwork]) -> str | None:
    """The client's address, or ``None`` when the request has no peer.

    * Peer not a trusted proxy: the peer *is* the client; any forwarded
      header is ignored, because the client could have written it.
    * Peer is a trusted proxy: walk ``X-Forwarded-For`` from the right and
      return the first hop that is not a trusted proxy.
    * A hop that is not a valid address breaks the chain -- nothing to its
      left can be vouched for -- so the last address that could be is used.
    """
    client = getattr(request, "client", None)
    peer: str | None = client.host if client is not None else None
    if peer is None:
        return None
    peer_address = _parse(peer)
    if peer_address is None or not _is_trusted(peer_address, trusted_proxies):
        return peer

    header: str | None = request.headers.get("x-forwarded-for")
    if not header:
        return peer
    hops = [hop for hop in header.split(",") if hop.strip()]
    last_vouched: str = peer
    for hop in reversed(hops):
        address = _parse(hop)
        if address is None:
            return last_vouched
        if not _is_trusted(address, trusted_proxies):
            return str(address)
        last_vouched = str(address)
    # Every hop is one of ours (e.g. an internal call routed through the
    # proxy); the furthest-left of them is the originator.
    return last_vouched
