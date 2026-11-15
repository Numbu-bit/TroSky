import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../booking/presentation/booking_format.dart';
import '../../shared/cancel_booking_sheet.dart';

/// What a booking's status shows on Trip History (P-15) and Booking
/// details (P-16): the chip, and what the passenger can do.
enum BookingChip {
  waiting(TroskyTagTone.amber, TroskyTagTone.amber),
  pendingPayment(TroskyTagTone.amber, TroskyTagTone.amber),
  paidUpcoming(TroskyTagTone.green, TroskyTagTone.green),

  /// Not in the design: paid, and the trip is boarding or under way.
  paidUnderWay(TroskyTagTone.green, TroskyTagTone.green),
  completed(TroskyTagTone.gray, TroskyTagTone.green),
  cancelled(TroskyTagTone.red, TroskyTagTone.red),
  expired(TroskyTagTone.gray, TroskyTagTone.gray);

  const BookingChip(this.chip, this.tag);

  /// The chip on Booking details (the design's status variants: Completed
  /// is grey there).
  final TroskyTagTone chip;

  /// On a Trip History row (P13 draws "Completed" green there).
  final TroskyTagTone tag;

  static BookingChip of(BookingResponse booking, {TripStatus? tripStatus}) =>
      switch (booking.status) {
        BookingStatus.awaitingAcceptance => waiting,
        BookingStatus.pending || BookingStatus.paymentPending => pendingPayment,
        BookingStatus.confirmed => switch (tripStatus ?? booking.trip?.status) {
          TripStatus.boarding ||
          TripStatus.inProgress ||
          TripStatus.paused => paidUnderWay,
          _ => paidUpcoming,
        },
        BookingStatus.completed => completed,
        BookingStatus.cancelled ||
        BookingStatus.refundPending ||
        BookingStatus.refunded => cancelled,
        BookingStatus.expired => expired,
      };

  String label(AppLocalizations l10n) => switch (this) {
    waiting => l10n.bookingStatusWaiting,
    pendingPayment => l10n.bookingStatusPendingPayment,
    paidUpcoming => l10n.bookingStatusPaidUpcoming,
    paidUnderWay => l10n.bookingStatusPaidUnderWay,
    completed => l10n.bookingStatusCompleted,
    cancelled => l10n.bookingStatusCancelled,
    expired => l10n.bookingStatusExpired,
  };

  /// The price is crossed out: nothing was, or is still, paid for it.
  bool get struck => this == cancelled || this == expired;

  /// "Pay now": opens Payment (P-07) to pay.
  bool get canPay => this == pendingPayment;

  /// "View status": opens Payment (P-07) while the driver decides.
  bool get canViewStatus => this == waiting;

  /// "Cancel booking". While the driver decides, Payment's "Cancel request"
  /// does it, as designed.
  bool get canCancel =>
      this == pendingPayment || this == paidUpcoming || this == paidUnderWay;
}

/// The refund line on Booking details, if the booking has one.
String? refundLine(AppLocalizations l10n, BookingResponse booking) =>
    switch (booking.status) {
      BookingStatus.refundPending => l10n.bookingRefundRequested(
        cedis(l10n, booking.totalAmount),
      ),
      BookingStatus.refunded => l10n.bookingRefunded(
        cedis(l10n, booking.totalAmount),
      ),
      _ => null,
    };

/// One-line summary on Booking details for a cancelled or expired
/// booking (G37). Degrades gracefully when the backend hasn't returned
/// `cancelled_by` / `cancel_reason` yet: the left half ("Cancelled by
/// you") shows alone, no placeholder dot, no "unknown". Returns null
/// for statuses where there's nothing to say.
String? cancellationLine(AppLocalizations l10n, BookingResponse booking) {
  if (booking.status == BookingStatus.expired) return l10n.bookingExpiredLine;
  final by = booking.cancelledBy ?? cancelledByFromStatus(booking.status);
  if (by == null) return null;
  final left = switch (by) {
    CancelledBy.user => l10n.bookingCancelledByYou,
    CancelledBy.trosky => l10n.bookingCancelledByTroSky,
    // `system` for a non-expired booking is unlikely; fall through to
    // the TroSky wording rather than invent a new label.
    CancelledBy.system => l10n.bookingCancelledByTroSky,
  };
  final reason = booking.cancelReason;
  if (reason == null) return left;
  return l10n.bookingCancelledLine(left, cancelReasonLabel(l10n, reason));
}
