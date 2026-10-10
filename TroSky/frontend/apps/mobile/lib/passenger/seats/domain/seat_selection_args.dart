import 'package:flutter/foundation.dart';
import 'package:trosky_api/trosky_api.dart';

import '../../../l10n/app_localizations.dart';
import '../../search/domain/journey.dart';
import 'seat_map_layout.dart';

/// The trip chosen on Search Results, for Seat Selection (P-05).
@immutable
class SeatSelectionArgs {
  const SeatSelectionArgs({
    required this.trip,
    required this.boardingStopId,
    required this.boardingStopName,
    required this.alightingStop,
    this.pickupLatitude,
    this.pickupLongitude,
  });

  final TripSearchResultResponse trip;

  /// Where the passenger boards: the chosen stop, or the one the backend
  /// picked from the phone's position.
  final String? boardingStopId;
  final String boardingStopName;
  final SearchStop alightingStop;

  /// The phone's position when the search used it: the booking sends it
  /// instead of a stop, and the backend snaps it to this trip's route.
  final double? pickupLatitude;
  final double? pickupLongitude;

  bool get fromPhonePosition => pickupLatitude != null;
}

/// The passengers of a booking (decision 23), one per seat in seat order:
/// the first seat for the signed-in user with their phone, the others
/// `"Kwame's guest 2"`, `"… guest 3"`, with no phone.
List<PassengerInput> passengersFor({
  required AppLocalizations l10n,
  required UserResponse user,
  required List<TripSeatResponse> seats,
}) {
  final ordered = [...seats]
    ..sort((a, b) => compareSeatNumbers(a.seatNumber, b.seatNumber));
  final fullName = user.profile?.fullName.trim() ?? '';
  final firstName = fullName.split(RegExp(r'\s+')).first;
  return [
    for (final (i, seat) in ordered.indexed)
      i == 0
          ? PassengerInput(
              seatId: seat.id,
              fullName: fullName.length >= 2
                  ? fullName
                  : l10n.bookingPassengerFallback,
              phoneNumber: user.phoneNumber,
            )
          : PassengerInput(
              seatId: seat.id,
              fullName: firstName.length >= 2
                  ? l10n.bookingGuestName(firstName, i + 1)
                  : l10n.bookingGuestFallback(i + 1),
            ),
  ];
}
