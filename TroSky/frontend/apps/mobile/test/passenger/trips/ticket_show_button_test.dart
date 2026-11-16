// Unit tests for the `canShowTicket` derivation on BookingChip. The
// widget-level gating in booking_details_screen also depends on
// [ticketQrEnabled], which only compile-time flips; this test fixes the
// status-based half of the rule.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/trips/domain/booking_view.dart';

void main() {
  group('BookingChip.canShowTicket', () {
    test('paid upcoming / under way / completed carry a ticket', () {
      expect(BookingChip.paidUpcoming.canShowTicket, isTrue);
      expect(BookingChip.paidUnderWay.canShowTicket, isTrue);
      expect(BookingChip.completed.canShowTicket, isTrue);
    });

    test('pre-confirmation statuses do not', () {
      expect(BookingChip.waiting.canShowTicket, isFalse);
      expect(BookingChip.pendingPayment.canShowTicket, isFalse);
    });

    test('ended statuses do not', () {
      expect(BookingChip.cancelled.canShowTicket, isFalse);
      expect(BookingChip.expired.canShowTicket, isFalse);
    });
  });
}
