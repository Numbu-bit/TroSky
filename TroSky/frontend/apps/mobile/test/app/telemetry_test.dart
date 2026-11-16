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
}
