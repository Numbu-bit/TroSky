import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations_en.dart';
import 'package:mobile/passenger/search/presentation/trip_view.dart';
import 'package:trosky_api/trosky_api.dart';

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
      ).copyWith(soloFareAmount: '38.00', sharedFareAmount: '12.00'),
      bestMatch: false,
    );
    expect(card.fare?.saving, 'Save 68%');
    expect(card.fare?.price, '₵12');
  });

  test('no saving pill when the shared fare is not lower', () {
    final card = tripCard(
      l10n,
      liveTrip(
        id: 't',
        departs: DateTime(2026, 10, 1, 9),
      ).copyWith(soloFareAmount: '8.00', sharedFareAmount: '8.00'),
      bestMatch: false,
    );
    expect(
      (card.fare?.price, card.fare?.soloPrice, card.fare?.saving),
      ('₵8', null, null),
    );
  });

  test(
    'BEST MATCH skips full trips; passed ones sit after the approaching',
    () {
      final full = liveTrip(
        id: 'full',
        departs: DateTime(2026, 10, 1, 9),
        seats: 0,
      );
      final next = liveTrip(id: 'next', departs: DateTime(2026, 10, 1, 9, 5));
      final view = ResultsView.arrange([
        full.copyWith(pickupEtaMinutes: 2),
        liveTrip(
          id: 'gone',
          departs: DateTime(2026, 10, 1, 8, 50),
        ).copyWith(passedPickup: true),
        next,
      ]);
      expect(view.bestMatch?.tripId, 'next');
      expect(view.upcoming.map((t) => t.tripId), ['full', 'next']);
      expect(view.passed.map((t) => t.tripId), ['gone']);
      expect(view.passedAt, 1);
      expect(view.approachKnown, isTrue);
    },
  );

  test('vehicle types read as the design names them', () {
    expect(vehicleLabel(l10n, VehicleType.sedan), 'Saloon Car');
    expect(vehicleLabel(l10n, null), 'Vehicle');
  });
}
