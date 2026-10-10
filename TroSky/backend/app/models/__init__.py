"""ORM model package.

Every model module must be imported here so it registers its tables on
``Base.metadata`` before Alembic (or anything else) inspects it — this is
the single place new model modules are wired in as later phases add them.
"""

from __future__ import annotations

from app.models import (  # noqa: F401
    admin,
    analytics,
    bookings,
    driver_actions,
    drivers,
    feedback,
    fraud,
    identity,
    notifications,
    payments,
    routes,
    safety,
    tickets,
    tracking,
    trips,
    vehicles,
)
from app.models.base import Base

__all__ = ["Base"]
