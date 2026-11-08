"""Reference fare, driver payout and platform commission engine for Ghana (GH¢, Decimal only).

This implements the publicly documented industry structure (metered fare x demand
multiplier, then a percentage service fee). It is not any company's internal code.
"""

from .config import ConfigError, FareConfig, load_config
from .pricing import DistanceOutOfRange, FareBreakdown, PricingError, price
from .settlement import TripSettlement, settle
from .surge import SurgeContext, SurgeResult, live_surge, static_surge

__all__ = [
    "ConfigError",
    "DistanceOutOfRange",
    "FareBreakdown",
    "FareConfig",
    "PricingError",
    "SurgeContext",
    "SurgeResult",
    "TripSettlement",
    "live_surge",
    "load_config",
    "price",
    "settle",
    "static_surge",
]
