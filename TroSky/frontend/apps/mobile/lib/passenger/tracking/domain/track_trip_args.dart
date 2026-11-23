import 'package:trosky_api/trosky_api.dart';

/// Opens P-11 (Live tracking) for a trip the passenger has a booking on.
class TrackTripArgs {
  const TrackTripArgs({required this.booking, required this.trip});

  final BookingResponse booking;

  /// Pre-fetched trip detail (from Trip Details P-04). The screen uses
  /// the vehicle + driver + stops directly rather than re-fetching.
  final TripDetailResponse trip;
}

/// Compile-time flag. Staging/demo default true (env/staging.json),
/// prod stays false until we flip after a day of staging soak.
const bool tripTrackingEnabled = bool.fromEnvironment('TRIP_TRACKING_ENABLED');
