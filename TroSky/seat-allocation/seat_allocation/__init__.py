"""Smart Seat Allocation for shared passenger vehicles.

Passengers getting off farthest from the pickup sit at the back, and those getting off
nearest sit by the door, so nobody has to climb out to let someone else off.
"""

from .allocator import Allocation, allocate, evaluate
from .config import ConfigError, SeatConfig, load_config
from .layout import LayoutError, SeatLayout, load_layout, minibus_variant, single_file
from .model import Booking, BookingError, FixedReason, FixedSeat

__all__ = [
    "Allocation",
    "Booking",
    "BookingError",
    "ConfigError",
    "FixedReason",
    "FixedSeat",
    "LayoutError",
    "SeatConfig",
    "SeatLayout",
    "allocate",
    "evaluate",
    "load_config",
    "load_layout",
    "minibus_variant",
    "single_file",
]
