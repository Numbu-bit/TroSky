import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/passenger/trips/domain/booking_view.dart';
import 'package:trosky_api/trosky_api.dart';

BookingResponse _b({
  required BookingStatus status,
  CancelledBy? cancelledBy,
  CancelReason? cancelReason,
}) => BookingResponse(
  id: 'b1',
  bookingReference: 'TS-X',
  tripId: 't1',
  status: status,
  passengerCount: 1,
  fareAmount: '8.00',
  platformFee: '0.50',
  totalAmount: '8.50',
  createdAt: DateTime.utc(2026, 10, 1),
  passengers: const [],
  cancelledBy: cancelledBy,
  cancelReason: cancelReason,
);

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await _l10n();
  });

  group('cancellationLine (G37 graceful degrade)', () {
    test('user + reason: full line', () {
      final line = cancellationLine(
        l10n,
        _b(
          status: BookingStatus.cancelled,
          cancelledBy: CancelledBy.user,
          cancelReason: CancelReason.changeOfPlans,
        ),
      );
      expect(line, 'Cancelled by you · Change of plans');
    });

    test('trosky + reason: full line', () {
      final line = cancellationLine(
        l10n,
        _b(
          status: BookingStatus.cancelled,
          cancelledBy: CancelledBy.trosky,
          cancelReason: CancelReason.departureTime,
        ),
      );
      expect(line, "Cancelled by TroSky · Departure time doesn't suit me");
    });

    test('expired: fixed line, no placeholder', () {
      final line = cancellationLine(l10n, _b(status: BookingStatus.expired));
      expect(line, 'Expired · Not paid in time');
    });

    test('graceful degrade: no cancelledBy and no cancelReason (G37 not '
        'shipped) — infer from status, show only the left half', () {
      // cancelled → infer "user", no reason: just "Cancelled by you".
      expect(
        cancellationLine(l10n, _b(status: BookingStatus.cancelled)),
        'Cancelled by you',
      );
      // refundPending (paid-then-cancelled) → also infer "user".
      expect(
        cancellationLine(l10n, _b(status: BookingStatus.refundPending)),
        'Cancelled by you',
      );
    });

    test('returns null for statuses that are not cancelled or expired', () {
      for (final status in [
        BookingStatus.awaitingAcceptance,
        BookingStatus.pending,
        BookingStatus.paymentPending,
        BookingStatus.confirmed,
        BookingStatus.completed,
        BookingStatus.refunded,
      ]) {
        expect(
          cancellationLine(l10n, _b(status: status)),
          isNull,
          reason: '$status should not render a cancellation line',
        );
      }
    });
  });
}
