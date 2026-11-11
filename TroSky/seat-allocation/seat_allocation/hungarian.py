"""The Hungarian method for the minimum-cost assignment problem.

Assigns each row to a different column at the lowest total cost, with at least as
many columns as rows, in O(rows^2 x columns) time. Costs are whole numbers, so the
result is exact. A cell of ``None`` is a pair that may not be matched.
"""

from __future__ import annotations

from collections.abc import Sequence


class InfeasibleAssignment(ValueError):
    """Some row has no column it can take."""


def solve_assignment(cost: Sequence[Sequence[int | None]]) -> tuple[list[int], int]:
    """Returns (column of each row, total cost)."""
    rows = len(cost)
    if rows == 0:
        return [], 0
    columns = len(cost[0])
    if rows > columns:
        raise InfeasibleAssignment(f"{rows} rows cannot fit in {columns} columns")
    largest = max((abs(cell) for row in cost for cell in row if cell is not None), default=0)
    forbidden = (largest + 1) * (rows + 1)
    matrix = [[forbidden if cell is None else cell for cell in row] for row in cost]

    row_potential = [0] * (rows + 1)
    column_potential = [0] * (columns + 1)
    row_of_column = [0] * (columns + 1)  # 0 means free; rows are numbered from 1 here
    previous = [0] * (columns + 1)
    for row in range(1, rows + 1):
        row_of_column[0] = row
        column = 0
        best = [float("inf")] * (columns + 1)
        used = [False] * (columns + 1)
        while True:
            used[column] = True
            current_row = row_of_column[column]
            delta = float("inf")
            next_column = 0
            line = matrix[current_row - 1]
            potential = row_potential[current_row]
            for j in range(1, columns + 1):
                if used[j]:
                    continue
                reduced = line[j - 1] - potential - column_potential[j]
                if reduced < best[j]:
                    best[j] = reduced
                    previous[j] = column
                if best[j] < delta:
                    delta = best[j]
                    next_column = j
            for j in range(columns + 1):
                if used[j]:
                    row_potential[row_of_column[j]] += delta
                    column_potential[j] -= delta
                else:
                    best[j] -= delta
            column = next_column
            if row_of_column[column] == 0:
                break
        while column:
            row_of_column[column] = row_of_column[previous[column]]
            column = previous[column]

    assignment = [-1] * rows
    for j in range(1, columns + 1):
        if row_of_column[j]:
            assignment[row_of_column[j] - 1] = j - 1
    total = 0
    for i, j in enumerate(assignment):
        if cost[i][j] is None:
            raise InfeasibleAssignment(f"row {i} has no column it can take")
        total += cost[i][j]  # type: ignore[operator]
    return assignment, total
