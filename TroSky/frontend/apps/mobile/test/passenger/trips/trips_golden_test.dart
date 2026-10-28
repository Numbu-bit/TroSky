@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/trosky_mobile_app.dart';

import '../../entry/auth/auth_helpers.dart';
import 'trips_helpers.dart';

/// Trip History (P-15) and Booking details (P-16) at the design frame,
/// 390 x 844, in mock mode on Ama Mensah's week of bookings (Thursday 15
/// Oct 2026, 10:00). The whole app is captured, so the cancel sheet shows
/// over its screen. Shadows are blurred, as on a phone.
void _goldenTest(
  String description,
  String name,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(TroskyMobileApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    } finally {
      debugDisableShadows = true;
    }
  });
}

void main() {
  const frame = Size(390, 844);

  _goldenTest('Trip History, Upcoming', 'trips_upcoming_390', (tester) async {
    await openTrips(tester, size: frame);
  });

  _goldenTest('Trip History, Past', 'trips_past_390', (tester) async {
    await openTrips(tester, size: frame);
    await showPast(tester);
  });

  _goldenTest('Trip History on the TECNO BG6 (360 x 806)', 'trips_past_360', (
    tester,
  ) async {
    await openTrips(tester);
    await showPast(tester);
  });

  for (final (name, from, to, past) in const [
    ('details_paid_390', 'Madina', 'Circle', false),
    ('details_under_way_390', 'Achimota', 'Lapaz', false),
    ('details_waiting_390', 'Legon', 'Osu', false),
    ('details_pending_390', 'Circle', 'Tema', false),
    ('details_refund_requested_390', 'Osu', 'Circle', true),
    ('details_completed_390', 'Circle', 'Tema', true),
    ('details_refunded_390', 'Kaneshie', 'Lapaz', true),
    ('details_expired_390', 'Lapaz', 'Madina', true),
  ]) {
    _goldenTest('Booking details: $from → $to', name, (tester) async {
      await openTrips(tester, size: frame);
      if (past) await showPast(tester);
      await openBooking(tester, from, to);
    });
  }

  _goldenTest('the cancel sheet, paid', 'cancel_sheet_390', (tester) async {
    await openTrips(tester, size: frame);
    await openBooking(tester, 'Madina', 'Circle');
    await tester.tap(link('Cancel booking'));
    await tester.pumpAndSettle();
  });

  _goldenTest('cancelled, the refund requested', 'cancelled_390', (
    tester,
  ) async {
    await openTrips(tester, size: frame);
    await openBooking(tester, 'Madina', 'Circle');
    await tester.tap(link('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel booking').last);
    await tester.pumpAndSettle();
  });

  _goldenTest(
    'cancel requested: the trip is under way',
    'cancel_requested_390',
    (tester) async {
      await openTrips(tester, size: frame);
      await openBooking(tester, 'Achimota', 'Lapaz');
      await tester.tap(link('Cancel booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel booking').last);
      await tester.pumpAndSettle();
    },
  );
}
