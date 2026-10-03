import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../l10n/app_localizations.dart';

/// The order of Search Results (decision 22).
enum ResultsSort {
  /// As the backend sends them: earliest departure first.
  departure,

  /// Lowest price first.
  cheapest,

  /// Earliest arrival (ETA) first.
  fastest,
}

/// [trips] arranged for the screen (decision 22): the ones still
/// available ([upcoming]) sorted by [sort], minibuses only with
/// [minibusOnly]; the ones that passed the stop ([passed], G21) by
/// departure; and the best match.
///
/// The passed ones (or the button that shows them) go at [passedAt]: after
/// the last vehicle reported approaching the stop, as in the design. With
/// many pages of later departures, the end of the list would be too far.
@immutable
class ResultsView {
  factory ResultsView.arrange(
    List<TripSearchResultResponse> trips, {
    ResultsSort sort = ResultsSort.departure,
    bool minibusOnly = false,
  }) {
    final shown = minibusOnly
        ? trips.where((t) => t.vehicleType == VehicleType.minibus)
        : trips;
    final upcoming = [...shown.where((t) => t.passedPickup != true)];
    final passed = [...shown.where((t) => t.passedPickup == true)];
    int byDeparture(TripSearchResultResponse a, TripSearchResultResponse b) =>
        a.scheduledDepartureAt.compareTo(b.scheduledDepartureAt);
    upcoming.sort(
      (a, b) => switch (sort) {
        ResultsSort.departure => 0,
        ResultsSort.cheapest => mainPrice(a).compareTo(mainPrice(b)),
        ResultsSort.fastest => arrival(a).compareTo(arrival(b)),
      }.orElse(() => byDeparture(a, b)),
    );
    passed.sort(byDeparture);
    final lastApproaching = upcoming.lastIndexWhere(
      (t) => t.pickupEtaMinutes != null,
    );
    return ResultsView._(
      upcoming: upcoming,
      passed: passed,
      passedAt: lastApproaching + 1,
      bestMatch: upcoming.where((t) => t.availableSeats > 0).firstOrNull,
      approachKnown: trips.any(
        (t) => t.passedPickup != null || t.pickupEtaMinutes != null,
      ),
    );
  }

  const ResultsView._({
    required this.upcoming,
    required this.passed,
    required this.passedAt,
    required this.bestMatch,
    required this.approachKnown,
  });

  final List<TripSearchResultResponse> upcoming;
  final List<TripSearchResultResponse> passed;

  /// Where in [upcoming] the passed block goes.
  final int passedAt;

  /// The first card after sorting that can still be booked.
  final TripSearchResultResponse? bestMatch;

  /// Whether the API says which vehicles approach or passed the stop
  /// (G21): only then the banner and the passed cards show (decision 21).
  final bool approachKnown;
}

extension on int {
  int orElse(int Function() next) => this != 0 ? this : next();
}

/// What the passenger pays: the shared fare for their stretch when the API
/// gives it (G20), else the trip's fare (decision 20).
double mainPrice(TripSearchResultResponse trip) =>
    double.parse(trip.sharedFareAmount ?? trip.fareAmount);

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

/// [trip] as a [TroskyTripCard] (P6, decisions 20 and 21).
TroskyTripCard tripCard(
  AppLocalizations l10n,
  TripSearchResultResponse trip, {
  required bool bestMatch,
  VoidCallback? onPressed,
}) {
  final passed = trip.passedPickup ?? false;
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
  if (trip.pickupEtaMinutes case final minutes?) {
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
    final price = formatPrice(l10n, trip.sharedFareAmount ?? trip.fareAmount);
    final solo = trip.soloFareAmount;
    final shared = trip.sharedFareAmount;
    if (solo != null && shared != null && double.parse(solo) > 0) {
      final saving =
          ((double.parse(solo) - double.parse(shared)) /
                  double.parse(solo) *
                  100)
              .round();
      fare = saving > 0
          ? TroskyTripFare(
              price: price,
              soloPrice: formatPrice(l10n, solo),
              saving: l10n.resultsSave(saving),
            )
          : TroskyTripFare(price: price);
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
