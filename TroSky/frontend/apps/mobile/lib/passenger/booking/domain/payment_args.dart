import 'package:flutter/foundation.dart';
import 'package:trosky_api/trosky_api.dart';

/// How Payment closed, for the screen under it.
enum PaymentOutcome {
  /// The booking was cancelled; the seats are free again.
  cancelled,

  /// The hold ran out, or no driver accepted the booking.
  expired,

  /// The passenger went back to change seats and released them (the
  /// booking is cancelled).
  released,
}

/// A booking for Payment (P-07): just made on Seat Selection, or reopened
/// by Home.
@immutable
class PaymentArgs {
  const PaymentArgs({
    required this.booking,
    this.seatNumbers,
    this.restored = false,
  });

  final BookingResponse booking;

  /// The booked seats' numbers; looked up from the seat map when unknown
  /// (a booking reopened after the app restarted, or moved to another
  /// vehicle).
  final List<String>? seatNumbers;

  /// Reopened by Home after a restart, not reached from Seat Selection.
  final bool restored;
}
