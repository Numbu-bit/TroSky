import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../l10n/app_localizations.dart';

/// [trips] arranged for the screen, in the backend's order (decision 22:
/// it sorts and filters): the ones still available ([upcoming]), the ones
/// that passed the stop ([passed], G21; the backend sends them last), and
/// the best match.
@immutable
class ResultsView {
  factory ResultsView.arrange(List<TripSearchResultResponse> trips) {
    final upcoming = [...trips.where((t) => !t.hasPassedPickup)];
    return ResultsView._(
      upcoming: upcoming,
      passed: [...trips.where((t) => t.hasPassedPickup)],
      bestMatch: upcoming.where((t) => t.availableSeats > 0).firstOrNull,
      approachKnown: trips.any(
        (t) => t.hasPassedPickup || t.vehicleEtaToPickupMinutes != null,
      ),
    );
  }

  const ResultsView._({
    required this.upcoming,
    required this.passed,
    required this.bestMatch,
    required this.approachKnown,
  });

  final List<TripSearchResultResponse> upcoming;
  final List<TripSearchResultResponse> passed;

  /// The first card that can still be booked.
  final TripSearchResultResponse? bestMatch;

  /// Whether any vehicle is already on the road, approaching the stop or
  /// past it (G21): only then the banner and the passed cards show
  /// (decision 21).
  final bool approachKnown;
}

/// What one seat costs from the pickup now: the backend's current fare
/// (G20), or the trip's fare from an older backend.
double mainPrice(TripSearchResultResponse trip) =>
    double.parse(trip.fare?.current ?? trip.fareAmount);

/// When the vehicle reaches the destination: the scheduled arrival, else
/// departure plus the route's duration, else the departure.
DateTime arrival(TripSearchResultResponse trip) =>
    trip.scheduledArrivalAt ??
    trip.scheduledDepartureAt.add(
      Duration(minutes: trip.estimatedDurationMinutes ?? 0),
    );

/// "07:15", on the phone's clock, as the design writes times.
String clockTime(DateTime time) => DateFormat('HH:mm').format(time.toLocal());

/// "₵14", or "₵8.50" when there are pesewas.
String formatPrice(AppLocalizations l10n, String amount) {
  final value = double.parse(amount);
  final whole = value == value.roundToDouble();
  return l10n.priceCedis(
    whole ? value.round().toString() : value.toStringAsFixed(2),
  );
}

/// "350 m" (to the nearest 10 m) or "1.2 km".
String formatDistance(AppLocalizations l10n, double metres) => metres < 1000
    ? l10n.distanceMetres((metres / 10).round() * 10)
    : l10n.distanceKilometres((metres / 1000).toStringAsFixed(1));

String vehicleLabel(AppLocalizations l10n, VehicleType? type) => switch (type) {
  VehicleType.bus => l10n.vehicleBus,
  VehicleType.minibus => l10n.vehicleMinibus,
  VehicleType.shuttle => l10n.vehicleShuttle,
  VehicleType.sedan => l10n.vehicleSedan,
  VehicleType.other || null => l10n.vehicleOther,
};

/// A free seat count at or under this is amber, as the design's 2-seat
/// card.
const int fewSeats = 2;

/// [trip] as a [TroskyTripCard] (P6, with the fare of G20 and the
/// approaching / passed state of G21).
TroskyTripCard tripCard(
  AppLocalizations l10n,
  TripSearchResultResponse trip, {
  required bool bestMatch,
  VoidCallback? onPressed,
}) {
  final passed = trip.hasPassedPickup;
  final seats = trip.availableSeats;
  final (seatsLabel, seatsColor) = passed
      ? (l10n.resultsPassed, TroskyChipColor.gray)
      : seats <= 0
      ? (l10n.resultsFull, TroskyChipColor.gray)
      : (
          l10n.resultsSeats(seats),
          seats <= fewSeats ? TroskyChipColor.amber : TroskyChipColor.green,
        );
  final departs = clockTime(trip.scheduledDepartureAt);
  final hasArrival =
      trip.scheduledArrivalAt != null || trip.estimatedDurationMinutes != null;
  final times = hasArrival
      ? l10n.resultsTimes(departs, clockTime(arrival(trip)))
      : l10n.resultsDeparts(departs);

  String? badge;
  var badgeKind = TroskyTripBadgeKind.approaching;
  if (trip.vehicleEtaToPickupMinutes case final minutes?) {
    badge = l10n.resultsApproachingBadge(minutes);
  } else if (trip.pickupStopName case final stop?) {
    badgeKind = TroskyTripBadgeKind.boardAt;
    badge = switch (trip.pickupDistanceM) {
      final metres? => l10n.resultsBoardAt(stop, formatDistance(l10n, metres)),
      null => l10n.resultsBoardAtStop(stop),
    };
  }

  TroskyTripFare? fare;
  if (seats > 0 && !passed) {
    final current = trip.fare?.current ?? trip.fareAmount;
    final price = formatPrice(l10n, current);
    // Sharing makes it cheaper than riding alone: the solo fare crossed
    // out and the saving, rounded to a whole percent. Not when they're
    // equal (nobody to share with yet).
    final solo = double.parse(trip.fare?.solo ?? current);
    final shared = double.parse(current);
    if (solo > shared) {
      final saving = ((solo - shared) / solo * 100).round();
      fare = TroskyTripFare(
        price: price,
        soloPrice: formatPrice(l10n, trip.fare!.solo),
        saving: saving > 0 ? l10n.resultsSave(saving) : null,
      );
    } else {
      fare = TroskyTripFare(price: price);
    }
  }

  final vehicle = vehicleLabel(l10n, trip.vehicleType);
  final label = [
    l10n.resultsTripLabel(
      vehicle,
      trip.vehicleRegistrationNumber ?? '',
      times,
      seatsLabel,
    ),
    if (bestMatch) l10n.resultsBestMatch,
    if (passed) l10n.resultsPassedNote,
    ?badge,
    if (fare != null) fare.price,
    if (fare?.soloPrice case final solo?) l10n.resultsWas(solo),
    ?fare?.saving,
  ].join('. ');

  return TroskyTripCard(
    key: ValueKey(trip.tripId),
    title: vehicle,
    plate: trip.vehicleRegistrationNumber,
    times: times,
    seatsLabel: seatsLabel,
    seatsColor: seatsColor,
    tag: bestMatch ? l10n.resultsBestMatch : null,
    highlighted: bestMatch,
    badge: passed ? null : badge,
    badgeKind: badgeKind,
    fare: fare,
    passed: passed,
    passedNote: l10n.resultsPassedNote,
    semanticsLabel: label,
    onPressed: seats > 0 && !passed ? onPressed : null,
  );
}
