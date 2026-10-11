import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations_en.dart';
import 'package:mobile/passenger/search/presentation/trip_view.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import 'search_helpers.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('prices: whole cedis without decimals, pesewas with two', () {
    expect(formatPrice(l10n, '14.00'), '₵14');
    expect(formatPrice(l10n, '8.5'), '₵8.50');
    expect(formatPrice(l10n, '120'), '₵120');
  });

  test('distances: metres to the nearest 10, then kilometres', () {
    expect(formatDistance(l10n, 4), '0 m');
    expect(formatDistance(l10n, 346), '350 m');
    expect(formatDistance(l10n, 999), '1000 m');
    expect(formatDistance(l10n, 1000), '1.0 km');
    expect(formatDistance(l10n, 1260), '1.3 km');
  });

  test('the saving rounds to a whole percent', () {
    final card = tripCard(
      l10n,
      liveTrip(
        id: 't',
        departs: DateTime(2026, 10, 1, 9),
      ).copyWith(fare: fareOf('12.00', solo: '38.00')),
      bestMatch: false,
    );
    expect(card.fare?.saving, 'Save 68%');
    expect((card.fare?.price, card.fare?.soloPrice), ('₵12', '₵38'));
  });

  test('solo equal to current: no crossed-out price, no saving pill', () {
    final card = tripCard(
      l10n,
      liveTrip(
        id: 't',
        departs: DateTime(2026, 10, 1, 9),
      ).copyWith(fare: fareOf('8.00', solo: '8.00')),
      bestMatch: false,
    );
    expect(
      (card.fare?.price, card.fare?.soloPrice, card.fare?.saving),
      ('₵8', null, null),
    );
  });

  test('a saving under half a percent: crossed out, no "Save 0%"', () {
    final card = tripCard(
      l10n,
      liveTrip(
        id: 't',
        departs: DateTime(2026, 10, 1, 9),
      ).copyWith(fare: fareOf('7.98', solo: '8.00')),
      bestMatch: false,
    );
    expect(
      (card.fare?.price, card.fare?.soloPrice, card.fare?.saving),
      ('₵7.98', '₵8', null),
    );
  });

  test('an older backend without `fare`: the trip fare', () {
    final card = tripCard(
      l10n,
      liveTrip(
        id: 't',
        departs: DateTime(2026, 10, 1, 9),
        fare: '7.50',
      ).copyWith(fare: null),
      bestMatch: false,
    );
    expect((card.fare?.price, card.fare?.soloPrice), ('₵7.50', null));
  });

  test('on the road: "~N min away"; passed: greyed, not bookable', () {
    final coming = tripCard(
      l10n,
      liveTrip(
        id: 'a',
        departs: DateTime(2026, 10, 1, 9),
      ).copyWith(vehicleEtaToPickupMinutes: 4),
      bestMatch: false,
      onPressed: () {},
    );
    expect(coming.badge, '~4 min away · approaching your stop');
    expect(coming.badgeKind, TroskyTripBadgeKind.approaching);
    final gone = tripCard(
      l10n,
      liveTrip(
        id: 'b',
        departs: DateTime(2026, 10, 1, 9),
      ).copyWith(hasPassedPickup: true),
      bestMatch: false,
      onPressed: () {},
    );
    expect(
      (gone.passed, gone.seatsLabel, gone.onPressed),
      (true, 'Passed', null),
    );
  });

  test('BEST MATCH skips full trips; passed ones go in their own block', () {
    final full = liveTrip(
      id: 'full',
      departs: DateTime(2026, 10, 1, 9),
      seats: 0,
    );
    final next = liveTrip(id: 'next', departs: DateTime(2026, 10, 1, 9, 5));
    final view = ResultsView.arrange([
      full.copyWith(vehicleEtaToPickupMinutes: 2),
      next,
      liveTrip(
        id: 'gone',
        departs: DateTime(2026, 10, 1, 8, 50),
      ).copyWith(hasPassedPickup: true),
    ]);
    expect(view.bestMatch?.tripId, 'next');
    expect(view.upcoming.map((t) => t.tripId), ['full', 'next']);
    expect(view.passed.map((t) => t.tripId), ['gone']);
    expect(view.approachKnown, isTrue);
  });

  test('no vehicle on the road: no approaching banner', () {
    final view = ResultsView.arrange([
      liveTrip(id: 'a', departs: DateTime(2026, 10, 1, 9)),
    ]);
    expect(view.approachKnown, isFalse);
  });

  test('vehicle types read as the design names them', () {
    expect(vehicleLabel(l10n, VehicleType.sedan), 'Saloon Car');
    expect(vehicleLabel(l10n, null), 'Vehicle');
  });
}
