import 'package:trosky_api/trosky_api.dart';

/// Compile-time flags per screen. Staging + demo on (`env/staging.json`);
/// prod off until Maher-007 runs a sandbox SOS and reviews.
const bool sosEnabled = bool.fromEnvironment('SOS_ENABLED');
const bool reportEnabled = bool.fromEnvironment('REPORT_ENABLED');
const bool rateEnabled = bool.fromEnvironment('RATE_ENABLED');

/// Opens P-12. Trip-context: `tripId` + optional `booking` for the
/// confirmation summary. Off-trip (Tester menu / Home SOS): both null.
class SosArgs {
  const SosArgs({this.tripId, this.booking});
  final String? tripId;
  final BookingResponse? booking;
  bool get inTrip => tripId != null;
}

/// Opens P-13. `tripId` is null for a general "Report a problem"
/// opened from Profile — the report is still captured in the safety
/// outbox and the submit button shows success without calling the
/// `/incidents` endpoint (that endpoint requires a trip). When
/// `tripId` is set, the trip-scoped flow is used. `bookingReference`
/// is shown at the top as context.
class ReportArgs {
  const ReportArgs({this.tripId, this.bookingReference});
  final String? tripId;
  final String? bookingReference;
  bool get inTrip => tripId != null;
}

/// Opens P-14. Rating is per-booking (binds to trip + driver).
class RateArgs {
  const RateArgs({required this.booking});
  final BookingResponse booking;
}

/// The reason chip the user picked on P-12 — client-side only. The
/// backend's SOS request takes no category; this drives the
/// `sos_sent {category}` analytics event.
enum SosReason { driverDanger, accident, medical, other }

/// Snake-case name for analytics.
String sosReasonName(SosReason reason) => switch (reason) {
  SosReason.driverDanger => 'driver_danger',
  SosReason.accident => 'accident',
  SosReason.medical => 'medical',
  SosReason.other => 'other',
};
