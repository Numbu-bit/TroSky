import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/seats/domain/seat_map_layout.dart';
import 'package:mobile/passenger/seats/domain/seat_selection_args.dart';
import 'package:trosky_api/trosky_api.dart';

import 'seat_helpers.dart';

/// [SeatMapLayout.rows] as seat numbers, `-` where a row has no seat.
List<String> _rows(SeatMapLayout layout) => [
  for (final row in layout.rows)
    [for (final s in row.cells) s?.seatNumber ?? '-'].join(' ') +
        (row.bench ? ' (bench)' : ''),
];

void main() {
  group('the aisle (decision 25)', () {
    test(
      'P7: 4 columns, aisle between 2 and 3, the short back row a bench',
      () {
        final layout = SeatMapLayout.of(p7Seats());
        expect(
          (layout.columns, layout.aisleColumn, layout.aisleAfter),
          (4, null, 2),
        );
        expect(_rows(layout), [
          '1 2 3 4',
          '5 6 7 8',
          '9 10 11 12',
          '13 14 (bench)',
        ]);
        expect(layout.seatInAisle, isFalse);
      },
    );

    test('3 columns: 2 + 1, aisle after column 2', () {
      final layout = SeatMapLayout.of(threeColumnSeats());
      expect(
        (layout.columns, layout.aisleColumn, layout.aisleAfter),
        (3, null, 2),
      );
      expect(_rows(layout), ['1 2 3', '4 5 6', '7 8 9']);
    });

    test(
      'an empty inner column is the aisle; a full back bench sits in it',
      () {
        final layout = SeatMapLayout.of(benchBusSeats());
        expect(
          (layout.columns, layout.aisleColumn, layout.aisleAfter),
          (5, 3, null),
        );
        expect(_rows(layout), [
          '1 2 - 3 4',
          '5 6 - 7 8',
          '9 10 - 11 12',
          '13 14 15 16 17',
        ]);
        expect(layout.seatInAisle, isTrue);
      },
    );

    test(
      'two neighbouring "aisle" seat columns put the aisle between them',
      () {
        // 5 across, typed window · standard · aisle | aisle · window.
        final layout = SeatMapLayout.of([
          for (var row = 1; row <= 3; row++)
            for (var column = 1; column <= 5; column++)
              seatAt(
                '${(row - 1) * 5 + column}',
                row,
                column,
                type: switch (column) {
                  1 || 5 => SeatType.window,
                  3 || 4 => SeatType.aisle,
                  _ => SeatType.standard,
                },
              ),
        ]);
        expect((layout.aisleColumn, layout.aisleAfter), (null, 3));
      },
    );

    test(
      'wider grids without hints split in the middle; 2 columns have none',
      () {
        List<TripSeatResponse> grid(int columns) => [
          for (var row = 1; row <= 2; row++)
            for (var column = 1; column <= columns; column++)
              seatAt('${(row - 1) * columns + column}', row, column),
        ];
        expect(SeatMapLayout.of(grid(5)).aisleAfter, 3);
        expect(SeatMapLayout.of(grid(6)).aisleAfter, 3);
        expect(SeatMapLayout.of(grid(2)).aisleAfter, isNull);
        expect(SeatMapLayout.of(grid(1)).aisleAfter, isNull);
        expect(SeatMapLayout.of(const []).rows, isEmpty);
      },
    );
  });

  test('seat numbers in reading order', () {
    expect(['10', '2', '1', 'A10', 'A2', 'B1']..sort(compareSeatNumbers), [
      '1',
      '2',
      '10',
      'A2',
      'A10',
      'B1',
    ]);
  });

  group('passengers (decision 23)', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    UserResponse user({String? name}) => UserResponse(
      id: 'u1',
      phoneNumber: '+233241234567',
      isActive: true,
      phoneVerified: true,
      emailVerified: false,
      roles: const ['passenger'],
      createdAt: DateTime.utc(2026, 7),
      profile: name == null
          ? null
          : UserProfileResponse(
              fullName: name,
              preferredLanguage: 'en',
              ghanaCardVerified: false,
            ),
    );
    final seats = [seatAt('10', 3, 2), seatAt('4', 1, 4), seatAt('9', 3, 1)];

    test('seat order: the passenger on the first seat, then their guests', () {
      final passengers = passengersFor(
        l10n: l10n,
        user: user(name: 'Ama Mensah'),
        seats: seats,
      );
      expect(
        [for (final p in passengers) (p.seatId, p.fullName, p.phoneNumber)],
        [
          ('seat-4', 'Ama Mensah', '+233241234567'),
          ('seat-9', "Ama's guest 2", null),
          ('seat-10', "Ama's guest 3", null),
        ],
      );
    });

    test('without a name: a fallback the backend accepts', () {
      final passengers = passengersFor(l10n: l10n, user: user(), seats: seats);
      expect(
        [for (final p in passengers) p.fullName],
        ['TroSky passenger', 'Guest 2', 'Guest 3'],
      );
    });
  });
}
