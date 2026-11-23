// The sanitiser is the PII gate. Every ticket-related payload must
// survive it unchanged; anything with a banned-key substring or a
// non-scalar value is stripped.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';

void main() {
  group('TelemetryEvent.sanitised', () {
    test('ticket_saved / ticket_shared carry only seat_index', () {
      final saved = TelemetryEvent('ticket_saved', {'seat_index': 1});
      final shared = TelemetryEvent('ticket_shared', {'seat_index': 0});
      expect(saved.sanitised, {'seat_index': 1});
      expect(shared.sanitised, {'seat_index': 0});
    });

    test('ticket_swiped carries only from/to ints', () {
      final event = TelemetryEvent('ticket_swiped', {'from': 0, 'to': 1});
      expect(event.sanitised, {'from': 0, 'to': 1});
    });

    test('ticket_fetch_failed carries only the reason string', () {
      final event = TelemetryEvent('ticket_fetch_failed', {
        'reason': 'network',
      });
      expect(event.sanitised, {'reason': 'network'});
    });

    test('banned keys are dropped: token, phone, name, email, coordinates', () {
      final event = TelemetryEvent('ticket_opened', {
        'seat_index': 0,
        'qr_token': 'bearer.abc',
        'passenger_name': 'Kofi',
        'passenger_phone': '0245550201',
        'email': 'kofi@example.com',
        'lat': 5.6037,
        'lng': -0.1870,
        'address': 'Madina, Accra',
      });
      expect(event.sanitised, {'seat_index': 0});
    });

    test('non-scalar values are dropped', () {
      final event = TelemetryEvent('ticket_opened', {
        'seat_index': 0,
        'passenger': {'id': 'x'},
        'ids': [1, 2, 3],
      });
      expect(event.sanitised, {'seat_index': 0});
    });

    test('scalar strings, numbers and booleans pass through', () {
      final event = TelemetryEvent('ticket_opened', {
        'booking_status': 'confirmed',
        'seat_count': 2,
        'is_first_open': true,
      });
      expect(event.sanitised, {
        'booking_status': 'confirmed',
        'seat_count': 2,
        'is_first_open': true,
      });
    });
  });

  group('TelemetryEvent.sanitised schema (C5)', () {
    test('unknown event name returns null', () {
      final event = TelemetryEvent('ticket_mint_free_money', {'amount': 999});
      expect(event.sanitised, isNull);
    });

    test('key not in event allow-list is dropped', () {
      // ticket_opened allows {booking_status, seat_index, seat_count,
      // is_first_open} — nothing else.
      final event = TelemetryEvent('ticket_opened', {
        'booking_status': 'confirmed',
        'driver_id': 'not-allowed',
      });
      expect(event.sanitised, {'booking_status': 'confirmed'});
    });

    test('oversized string is dropped', () {
      final event = TelemetryEvent('pii_edit_failed', {
        'field': 'name',
        'reason': 'x' * 128,
      });
      expect(event.sanitised, {'field': 'name'});
    });

    test('out-of-range int is dropped', () {
      final event = TelemetryEvent('wallet_topup_submitted', {
        'amount': 1 << 40,
      });
      expect(event.sanitised, isEmpty);
    });

    test('non-finite double is dropped', () {
      final event = TelemetryEvent('wallet_topup_submitted', {
        'amount': double.infinity,
      });
      expect(event.sanitised, isEmpty);
    });

    test('sanitised map is unmodifiable', () {
      final event = TelemetryEvent('home_bell_tapped');
      expect(event.sanitised, isNotNull);
      expect(() => event.sanitised!['x'] = 1, throwsUnsupportedError);
    });

    test('ConsoleTelemetryService silently drops unknown events', () {
      // Nothing to assert directly without a sink spy; the contract is
      // "emit does not throw" and "sanitised was null for the drop".
      const sink = ConsoleTelemetryService();
      sink.emit(TelemetryEvent('totally_undeclared_event', {'x': 1}));
    });
  });
}
