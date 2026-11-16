import 'package:trosky_api/trosky_api.dart';

/// Entry point to the Trip Details screen (P-04, derived). [BookingResponse]
/// is passed as-is from Booking details / Trips so the screen opens
/// instantly with cached data while the fresh trip fetch runs.
class TripDetailsArgs {
  const TripDetailsArgs({required this.booking, required this.source});

  final BookingResponse booking;

  /// Where the open came from. Emits as `trip_details_opened{from}`.
  final TripDetailsSource source;
}

/// Who linked here. Scalar so it's safe to emit in analytics.
enum TripDetailsSource {
  trips,
  ticket,
  deepLink;

  String get payload => switch (this) {
    TripDetailsSource.trips => 'trips',
    TripDetailsSource.ticket => 'ticket',
    TripDetailsSource.deepLink => 'deep_link',
  };
}

/// Compile-time flag that gates both the TripDetails entry point in
/// Booking details and the screen itself. Set per env.json:
/// staging/demo default `true` after this PR; prod stays `false` until
/// step17/B (live tracking) lands.
const bool tripDetailsEnabled = bool.fromEnvironment('TRIP_DETAILS_ENABLED');
