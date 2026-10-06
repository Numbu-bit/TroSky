import 'package:flutter/foundation.dart';
import 'package:trosky_api/trosky_api.dart';

/// One row of the seat map.
@immutable
class SeatMapRow {
  const SeatMapRow({required this.cells, required this.bench});

  /// One entry per grid column (index 0 is column 1); null where the row has
  /// no seat. For a [bench], just its seats in column order.
  final List<TripSeatResponse?> cells;

  /// A shorter last row, drawn centred without the aisle (P7's back bench).
  final bool bench;
}

/// How `GET /trips/{id}/seats` is drawn (decision 25). Seats sit on a grid
/// of [columns] columns; the aisle is either a whole column
/// ([aisleColumn]) or a gap after a column ([aisleAfter]), or there is none.
@immutable
class SeatMapLayout {
  const SeatMapLayout._({
    required this.columns,
    required this.rows,
    this.aisleColumn,
    this.aisleAfter,
  });

  factory SeatMapLayout.of(List<TripSeatResponse> seats) {
    if (seats.isEmpty) return const SeatMapLayout._(columns: 0, rows: []);
    final columns = seats.map((s) => s.columnNumber).reduce(_max);
    final rowNumbers = {for (final s in seats) s.rowNumber}.toList()..sort();
    final byRow = {
      for (final row in rowNumbers)
        row: [
          for (final s in seats)
            if (s.rowNumber == row) s,
        ]..sort((a, b) => a.columnNumber.compareTo(b.columnNumber)),
    };

    // 1. An inner column with no seat in most rows is the aisle.
    int? aisleColumn;
    var fewest = rowNumbers.length;
    for (var c = 2; c < columns; c++) {
      final used = rowNumbers
          .where((r) => byRow[r]!.any((s) => s.columnNumber == c))
          .length;
      if (used * 2 < rowNumbers.length && used < fewest) {
        aisleColumn = c;
        fewest = used;
      }
    }

    // 2. Otherwise two neighbouring columns of `aisle` seats, in most rows.
    int? aisleAfter;
    if (aisleColumn == null) {
      for (var c = 1; c < columns && aisleAfter == null; c++) {
        final rowsWithPair = rowNumbers.where((r) {
          SeatType? type(int column) => byRow[r]!
              .where((s) => s.columnNumber == column)
              .firstOrNull
              ?.seatType;
          return type(c) == SeatType.aisle && type(c + 1) == SeatType.aisle;
        }).length;
        if (rowsWithPair * 2 > rowNumbers.length) aisleAfter = c;
      }
    }

    // 3. Otherwise by width: 4 → between 2 and 3 (P7); 3 → 2 + 1; wider →
    // after the middle column; 1 or 2 → none.
    if (aisleColumn == null && aisleAfter == null && columns >= 3) {
      aisleAfter = columns.isEven ? columns ~/ 2 : (columns + 1) ~/ 2;
      if (columns == 3) aisleAfter = 2;
    }

    // A shorter last row is a back bench, centred (P7 seats 13 and 14).
    final counts = [for (final r in rowNumbers) byRow[r]!.length];
    final lastShort =
        rowNumbers.length > 1 &&
        counts.last < counts.sublist(0, counts.length - 1).reduce(_max);

    return SeatMapLayout._(
      columns: columns,
      aisleColumn: aisleColumn,
      aisleAfter: aisleAfter,
      rows: [
        for (final (i, r) in rowNumbers.indexed)
          lastShort && i == rowNumbers.length - 1
              ? SeatMapRow(cells: byRow[r]!, bench: true)
              : SeatMapRow(
                  cells: [
                    for (var c = 1; c <= columns; c++)
                      byRow[r]!.where((s) => s.columnNumber == c).firstOrNull,
                  ],
                  bench: false,
                ),
      ],
    );
  }

  final int columns;
  final List<SeatMapRow> rows;

  /// A whole column used as the aisle (rule 1).
  final int? aisleColumn;

  /// The aisle runs after this column (rules 2 and 3).
  final int? aisleAfter;

  /// Whether a seat sits in the aisle column (a full back bench): then that
  /// column is as wide as a seat.
  bool get seatInAisle =>
      aisleColumn != null &&
      rows.any((r) => !r.bench && r.cells[aisleColumn! - 1] != null);

  static int _max(int a, int b) => a > b ? a : b;
}

/// Seat numbers in reading order: "2" before "10", "A2" before "A10".
int compareSeatNumbers(String a, String b) {
  final pattern = RegExp(r'^([^\d]*)(\d*)(.*)$');
  final ma = pattern.firstMatch(a)!;
  final mb = pattern.firstMatch(b)!;
  final byPrefix = ma[1]!.compareTo(mb[1]!);
  if (byPrefix != 0) return byPrefix;
  final na = int.tryParse(ma[2]!);
  final nb = int.tryParse(mb[2]!);
  if (na != null && nb != null && na != nb) return na.compareTo(nb);
  return a.compareTo(b);
}
