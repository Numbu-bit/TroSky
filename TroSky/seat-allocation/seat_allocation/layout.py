"""Vehicle seat layouts: load, validate and generate them.

Each seat lists the seats directly on its way to the door (``blocked_by``). A
bare count of blockers would not be enough: to tell whether a pair of passengers
blocks each other, the engine has to know which seats are in the way. The count
requested in the brief, ``blockers_count``, is derived from the list and, when a
layout file states it, checked against it.

Every example layout is an assumption about the fleet:
"verify against the actual fleet before launch".
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

VERIFY = "verify against the actual fleet before launch"
LAYOUT_DIR = Path(__file__).resolve().parent.parent / "layouts"


class LayoutError(ValueError):
    """A layout is inconsistent, so blocking could not be computed from it."""


@dataclass(frozen=True)
class Seat:
    id: str
    row: int
    column: int
    depth_rank: int  # 1 is nearest the exit, highest is rearmost
    exit_door: str
    blocked_by: tuple[str, ...]  # seats directly in the way
    blockers: frozenset[str]  # every seat in the way, however indirectly
    near_driver: bool = False
    accessible: bool = False
    bookable: bool = True
    folding: bool = False
    reserved_for: tuple[str, ...] = ()
    tags: tuple[str, ...] = ()
    neighbours: tuple[str, ...] = ()

    @property
    def blockers_count(self) -> int:
        return len(self.blockers)


@dataclass(frozen=True)
class SeatLayout:
    model: str
    verification: str
    doors: tuple[str, ...]
    seats: tuple[Seat, ...]

    def seat(self, seat_id: str) -> Seat:
        for seat in self.seats:
            if seat.id == seat_id:
                return seat
        raise KeyError(seat_id)

    def bookable_seats(self) -> list[Seat]:
        """Bookable seats, rearmost first: the order the batch rule fills them."""
        return sorted(
            (seat for seat in self.seats if seat.bookable),
            key=lambda s: (-s.depth_rank, -s.row, s.column, s.id),
        )

    def blocks(self, blocker_id: str, seat_id: str) -> bool:
        """True when a passenger in ``blocker_id`` is in the way of ``seat_id``."""
        return blocker_id in self.seat(seat_id).blockers

    def seats_blocked_by(self, blocker_id: str) -> list[Seat]:
        return [seat for seat in self.seats if blocker_id in seat.blockers]

    def is_single_file(self) -> bool:
        """True when every pair of bookable seats is ordered along one exit path."""
        seats = self.bookable_seats()
        return all(
            a.id in b.blockers or b.id in a.blockers
            for i, a in enumerate(seats)
            for b in seats[i + 1 :]
        )

    def to_dict(self) -> dict[str, Any]:
        derived = _derive_neighbours(
            [{"id": seat.id, "row": seat.row, "column": seat.column} for seat in self.seats]
        )
        seats = []
        for seat in self.seats:
            entry: dict[str, Any] = {
                "id": seat.id,
                "row": seat.row,
                "column": seat.column,
                "depth_rank": seat.depth_rank,
                "exit_door": seat.exit_door,
                "blocked_by": list(seat.blocked_by),
                "blockers_count": seat.blockers_count,
                "near_driver": seat.near_driver,
                "accessible": seat.accessible,
                "bookable": seat.bookable,
                "folding": seat.folding,
                "reserved_for": list(seat.reserved_for),
                "tags": list(seat.tags),
            }
            if seat.neighbours != derived[seat.id]:
                entry["neighbours"] = list(seat.neighbours)
            seats.append(entry)
        return {
            "schema_version": 1,
            "model": self.model,
            "verification": self.verification,
            "doors": [{"id": door} for door in self.doors],
            "seats": seats,
        }


def _closure(direct: dict[str, tuple[str, ...]]) -> dict[str, frozenset[str]]:
    """Every seat in the way of each seat. Refuses a loop, which no real path can have."""
    done: dict[str, frozenset[str]] = {}
    visiting: set[str] = set()

    def visit(seat_id: str) -> frozenset[str]:
        if seat_id in done:
            return done[seat_id]
        if seat_id in visiting:
            raise LayoutError(f"seat {seat_id} is in a loop of blocked_by seats")
        visiting.add(seat_id)
        found: set[str] = set()
        for blocker in direct[seat_id]:
            found.add(blocker)
            found |= visit(blocker)
        visiting.discard(seat_id)
        done[seat_id] = frozenset(found)
        return done[seat_id]

    for seat_id in direct:
        visit(seat_id)
    return done


def _derive_neighbours(raw_seats: list[dict[str, Any]]) -> dict[str, tuple[str, ...]]:
    """Beside each other in a row, or one directly behind the other in a column."""
    found: dict[str, list[str]] = {seat["id"]: [] for seat in raw_seats}
    for a in raw_seats:
        for b in raw_seats:
            if a is b:
                continue
            same_row = a["row"] == b["row"] and abs(a["column"] - b["column"]) == 1
            same_column = a["column"] == b["column"] and abs(a["row"] - b["row"]) == 1
            if same_row or same_column:
                found[a["id"]].append(b["id"])
    return {seat_id: tuple(names) for seat_id, names in found.items()}


def layout_from_dict(data: dict[str, Any]) -> SeatLayout:
    """Build a layout, refusing anything that would make blocking counts wrong."""
    verification = data.get("verification")
    if not verification:
        raise LayoutError(f"a layout must say how it was checked, for example: {VERIFY}")
    doors = tuple(door["id"] for door in data.get("doors", []))
    if not doors or len(set(doors)) != len(doors):
        raise LayoutError("a layout needs at least one door, each with a unique id")
    raw_seats = list(data.get("seats", []))
    if not raw_seats:
        raise LayoutError("a layout needs at least one seat")
    ids = [seat["id"] for seat in raw_seats]
    if len(set(ids)) != len(ids):
        raise LayoutError("seat ids must be unique")

    direct: dict[str, tuple[str, ...]] = {}
    for seat in raw_seats:
        blocked_by = tuple(seat.get("blocked_by", ()))
        unknown = set(blocked_by) - set(ids)
        if unknown:
            raise LayoutError(f"seat {seat['id']} is blocked by unknown seats: {sorted(unknown)}")
        if seat["id"] in blocked_by:
            raise LayoutError(f"seat {seat['id']} cannot block itself")
        direct[seat["id"]] = blocked_by
    closure = _closure(direct)
    derived_neighbours = _derive_neighbours(raw_seats)

    ranks = {seat["id"]: int(seat["depth_rank"]) for seat in raw_seats}
    seats = []
    for raw in raw_seats:
        seat_id = raw["id"]
        if raw["exit_door"] not in doors:
            raise LayoutError(f"seat {seat_id} uses unknown door {raw['exit_door']!r}")
        if ranks[seat_id] < 1:
            raise LayoutError(f"seat {seat_id}: depth_rank starts at 1")
        for blocker in closure[seat_id]:
            if ranks[blocker] >= ranks[seat_id]:
                raise LayoutError(
                    f"seat {blocker} blocks seat {seat_id}, so it must have a lower depth_rank"
                )
        stated = raw.get("blockers_count")
        if stated is not None and stated != len(closure[seat_id]):
            raise LayoutError(
                f"seat {seat_id} states {stated} blockers but blocked_by gives "
                f"{len(closure[seat_id])}"
            )
        seats.append(
            Seat(
                id=seat_id,
                row=int(raw["row"]),
                column=int(raw["column"]),
                depth_rank=ranks[seat_id],
                exit_door=raw["exit_door"],
                blocked_by=direct[seat_id],
                blockers=closure[seat_id],
                near_driver=bool(raw.get("near_driver", False)),
                accessible=bool(raw.get("accessible", False)),
                bookable=bool(raw.get("bookable", True)),
                folding=bool(raw.get("folding", False)),
                reserved_for=tuple(raw.get("reserved_for", ())),
                tags=tuple(raw.get("tags", ())),
                neighbours=tuple(raw.get("neighbours", derived_neighbours[seat_id])),
            )
        )
    return SeatLayout(
        model=str(data.get("model", "unnamed")),
        verification=str(verification),
        doors=doors,
        seats=tuple(seats),
    )


def load_layout(name_or_path: str | Path) -> SeatLayout:
    """Load ``minibus_15`` from the layouts folder, or any JSON file by its path."""
    path = Path(name_or_path)
    if not path.suffix:
        path = LAYOUT_DIR / f"{name_or_path}.json"
    return layout_from_dict(json.loads(path.read_text(encoding="utf-8")))


# ------------------------------------------------------------------- generators


def _seat(
    seat_id: str,
    row: int,
    column: int,
    door: str,
    blocked_by: list[str],
    **extra: Any,
) -> dict[str, Any]:
    return {
        "id": seat_id,
        "row": row,
        "column": column,
        "depth_rank": 1,
        "exit_door": door,
        "blocked_by": blocked_by,
        **extra,
    }


def _with_derived_ranks(seats: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """A seat's depth rank is one more than the number of seats in its way."""
    closure = _closure({seat["id"]: tuple(seat["blocked_by"]) for seat in seats})
    for seat in seats:
        seat["depth_rank"] = len(closure[seat["id"]]) + 1
    return seats


def minibus(cab_seats: int, rows_of_three: int, back_row: int) -> SeatLayout:
    """A trotro-style minibus with a side door and folding seats. [VERIFY]

    The assumed interior, for a left-hand-drive vehicle with its doors on the right:
    seats in the cab beside the driver use the cab door. In each row of three, the
    seat on the door side folds to let people past, and the two beyond it are reached
    across it. To leave any row you pass the folding seat of every row in front. The
    back row is a bench reached the same way. Column 1 is the driver's side.
    """
    if not 1 <= cab_seats <= 2 or rows_of_three < 1 or not 2 <= back_row <= 5:
        raise LayoutError("cab_seats must be 1 or 2, rows_of_three at least 1, back_row 2 to 5")
    seats = [
        _seat(
            "DRV",
            1,
            1,
            "cab",
            [],
            near_driver=True,
            bookable=False,
            reserved_for=["driver"],
            tags=["driver"],
        )
    ]
    for index in range(cab_seats):
        column = 3 - index
        seats.append(
            _seat(
                f"F{index + 1}",
                1,
                column,
                "cab",
                [f"F{index}"] if index else [],
                near_driver=True,
                accessible=index == 0,
                reserved_for=["priority"],
                tags=["front"] + (["door-side"] if index == 0 else []),
            )
        )
    previous_folding: str | None = None
    letters = "ABCDEFG"
    for row_index in range(rows_of_three):
        letter = letters[row_index]
        folding_id = f"{letter}1"
        seats.append(
            _seat(
                folding_id,
                row_index + 2,
                3,
                "side",
                [previous_folding] if previous_folding else [],
                folding=True,
                tags=["folding", "door-side"] + (["front"] if row_index == 0 else ["middle"]),
            )
        )
        seats.append(
            _seat(
                f"{letter}2",
                row_index + 2,
                2,
                "side",
                [folding_id],
                tags=["front"] if row_index == 0 else ["middle"],
            )
        )
        seats.append(
            _seat(
                f"{letter}3",
                row_index + 2,
                1,
                "side",
                [f"{letter}2"],
                tags=(["front"] if row_index == 0 else ["middle"]) + ["window"],
            )
        )
        previous_folding = folding_id
    back = rows_of_three + 2
    for index in range(back_row):
        seats.append(
            _seat(
                f"Z{index + 1}",
                back,
                back_row - index,
                "side",
                [f"Z{index}"] if index else [previous_folding],  # type: ignore[list-item]
                tags=["rear", "luggage"] + (["window"] if index == back_row - 1 else []),
            )
        )
    passenger_seats = cab_seats + 3 * rows_of_three + back_row
    return layout_from_dict(
        {
            "model": f"minibus-{passenger_seats}",
            "verification": VERIFY,
            "doors": [{"id": "cab"}, {"id": "side"}],
            "seats": _with_derived_ranks(seats),
        }
    )


def minibus_variant(passenger_seats: int) -> SeatLayout:
    """A 14 to 18 seat minibus, from the variants table in the layouts folder. [VERIFY]"""
    table = json.loads((LAYOUT_DIR / "minibus_variants.json").read_text(encoding="utf-8"))
    variant = table["variants"].get(str(passenger_seats))
    if variant is None:
        known = ", ".join(table["variants"])
        raise LayoutError(f"no {passenger_seats}-seat variant is defined; known sizes: {known}")
    return minibus(variant["cab_seats"], variant["rows_of_three"], variant["back_row"])


def from_grid(rows: int, columns: int, *, model: str = "grid") -> SeatLayout:
    """A first guess from what TroSky stores today, a grid of rows and columns. [VERIFY]

    Names seats A1, A2, ... like the demo fleet. Column 1 is taken to be the door
    side and to fold. It lets a vehicle join a pilot before anyone has surveyed it,
    and it is a guess, so such a vehicle's numbers should not be trusted until
    someone has checked its real seats.
    """
    if rows < 1 or columns < 1:
        raise LayoutError("a grid needs at least one row and one column")
    seats = []
    previous_folding: str | None = None
    for row_index in range(rows):
        letter = chr(ord("A") + row_index)
        for column in range(1, columns + 1):
            if column == 1:
                blocked_by = [previous_folding] if previous_folding else []
            else:
                blocked_by = [f"{letter}{column - 1}"]
            folds = column == 1 and row_index < rows - 1
            seats.append(
                _seat(f"{letter}{column}", row_index + 1, column, "side", blocked_by, folding=folds)
            )
        previous_folding = f"{letter}1"
    return layout_from_dict(
        {
            "model": model,
            "verification": f"guessed from a {rows} by {columns} grid; {VERIFY}",
            "doors": [{"id": "side"}],
            "seats": _with_derived_ranks(seats),
        }
    )


def single_file(seat_count: int) -> SeatLayout:
    """The test model: one line of seats, seat 1 nearest the exit. Seat 1 is reserved."""
    if seat_count < 1:
        raise LayoutError("a layout needs at least one seat")
    seats = [
        _seat(
            str(number),
            number,
            1,
            "exit",
            [str(number - 1)] if number > 1 else [],
            reserved_for=["priority"] if number == 1 else [],
            accessible=number == 1,
        )
        for number in range(1, seat_count + 1)
    ]
    return layout_from_dict(
        {
            "model": f"single-file-{seat_count}",
            "verification": f"a test model, not a real vehicle; {VERIFY}",
            "doors": [{"id": "exit"}],
            "seats": _with_derived_ranks(seats),
        }
    )


def two_door_bus(rows: int = 7) -> SeatLayout:
    """A bus with a central aisle, two doors and two folding aisle seats. [VERIFY]

    Rows of 2 + 2. An aisle seat blocks the window seat beside it, and the aisle
    itself is free, except where a folding seat sits in it: that seat blocks every
    seat behind it on the way to its door. Rows up to row 3 use the front door and
    the others the rear door, which is taken to be level with row 4.
    """
    if rows < 5:
        raise LayoutError("the two-door example needs at least 5 rows")
    seats = []
    for row in range(1, rows + 1):
        door = "front" if row <= 3 else "rear"
        if row == 3:
            aisle_blockers = ["J1"]
        elif row > 5:
            aisle_blockers = ["J2"]
        else:
            aisle_blockers = []
        tags = ["front" if row <= 2 else "rear" if row >= rows - 1 else "middle"]
        for side, aisle_column, window_column in (("L", 2, 1), ("R", 4, 5)):
            aisle_id, window_id = f"{row}{side}A", f"{row}{side}W"
            walk = row - 1 if row <= 3 else abs(row - 4)
            aisle = _seat(
                aisle_id,
                row,
                aisle_column,
                door,
                list(aisle_blockers),
                tags=tags,
                reserved_for=["priority"] if row == 1 else [],
                accessible=row == 1,
            )
            aisle["depth_rank"] = 2 * walk + 1
            window = _seat(window_id, row, window_column, door, [aisle_id], tags=[*tags, "window"])
            window["depth_rank"] = 2 * walk + 2
            seats.extend([aisle, window])
    for seat_id, row, door in (("J1", 2, "front"), ("J2", 5, "rear")):
        folding = _seat(seat_id, row, 3, door, [], folding=True, tags=["folding"])
        folding["depth_rank"] = 3  # one row from its door
        seats.append(folding)
    return layout_from_dict(
        {
            "model": f"bus-{4 * rows + 2}-two-door",
            "verification": VERIFY,
            "doors": [{"id": "front"}, {"id": "rear"}],
            "seats": seats,
        }
    )
