import 'package:trosky_api/trosky_api.dart';

/// What the amber chip at the top of the map says.
enum TrackStatusKind { boardingAtOrigin, arrivingIn, atYourStop, completed }

/// One pass of the status chip's state. The pure function
/// [trackStatusFor] produces it; the widget just renders.
class TrackStatus {
  const TrackStatus({required this.kind, this.etaMinutes, this.etaAt});

  final TrackStatusKind kind;

  /// Set only when [kind] is [TrackStatusKind.arrivingIn].
  final int? etaMinutes;

  /// Set only when [kind] is [TrackStatusKind.arrivingIn]; what time the
  /// ETA resolves to on the phone's clock.
  final DateTime? etaAt;
}

/// Rule (owner-signed for Step 17):
///   trip.in_progress AND distance > 100 m → arrivingIn(etaMinutes)
///   trip.in_progress AND distance ≤ 100 m → atYourStop
///   trip.scheduled   AND now < departure   → boardingAtOrigin
///   trip.completed                         → completed
///   anything else (trip.scheduled past departure, boarding, paused …)
///                                           → boardingAtOrigin (the
///     fallback the design treats as "we're on the way, the chip stays
///     generic until the driver's app flips us into in_progress").
TrackStatus trackStatusFor({
  required TripStatus tripStatus,
  required DateTime departureAt,
  required double distanceToDestinationMeters,
  required int etaMinutes,
  required DateTime etaAt,
  required DateTime now,
}) {
  switch (tripStatus) {
    case TripStatus.completed:
      return const TrackStatus(kind: TrackStatusKind.completed);
    case TripStatus.inProgress:
      if (distanceToDestinationMeters <= 100) {
        return const TrackStatus(kind: TrackStatusKind.atYourStop);
      }
      return TrackStatus(
        kind: TrackStatusKind.arrivingIn,
        etaMinutes: etaMinutes,
        etaAt: etaAt,
      );
    case TripStatus.scheduled:
    case TripStatus.boarding:
    case TripStatus.paused:
    case TripStatus.cancelled:
      // scheduled past departure sits under the same chip: the driver
      // hasn't started the trip yet from the app's point of view.
      return const TrackStatus(kind: TrackStatusKind.boardingAtOrigin);
  }
}
