// Pure unit tests for the Safety feature: analytics payload contract,
// SOS reason naming, outbox entry serialization.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/passenger/safety/data/safety_outbox.dart';
import 'package:mobile/passenger/safety/domain/safety_args.dart';

void main() {
  group('analytics PII contract', () {
    final events = [
      TelemetryEvent('sos_opened', {'from': 'trip'}),
      TelemetryEvent('sos_hold_started'),
      TelemetryEvent('sos_hold_cancelled'),
      TelemetryEvent('sos_sent', {
        'category': 'other',
        'location_attached': true,
      }),
      TelemetryEvent('sos_send_failed', {'reason': 'timeout'}),
      TelemetryEvent('sos_marked_safe'),
      TelemetryEvent('sos_call_911_tapped'),
      TelemetryEvent('report_opened'),
      TelemetryEvent('report_category_picked', {'category': 'safety_concern'}),
      TelemetryEvent('report_submitted', {
        'category': 'accident',
        'has_photos': false,
      }),
      TelemetryEvent('report_submit_failed', {'reason': 'network'}),
      TelemetryEvent('rate_opened', {'from': 'trips_banner'}),
      TelemetryEvent('rate_star_selected', {'stars': 4}),
      TelemetryEvent('rate_submitted', {'stars': 5, 'has_comment': true}),
      TelemetryEvent('rate_dismissed'),
    ];
    // Mirrors the live `TelemetryEvent._bannedKeys` sanitiser: these are
    // the substrings that must never appear in an analytics payload key.
    final pii = RegExp(
      r'token|phone|name|email|lat|lng|coord|address',
      caseSensitive: false,
    );
    for (final e in events) {
      test('${e.name} keys have no PII', () {
        for (final k in e.params.keys) {
          expect(pii.hasMatch(k), isFalse, reason: '${e.name}.$k');
        }
      });
      test('${e.name} params survive sanitisation', () {
        final out = e.sanitised;
        expect(out, isNotNull, reason: '${e.name} missing from schema');
        expect(out!.keys.toSet(), e.params.keys.toSet());
      });
    }
  });

  group('sosReasonName', () {
    test('snake_cases each reason', () {
      expect(sosReasonName(SosReason.driverDanger), 'driver_danger');
      expect(sosReasonName(SosReason.accident), 'accident');
      expect(sosReasonName(SosReason.medical), 'medical');
      expect(sosReasonName(SosReason.other), 'other');
    });
  });

  group('SafetyOutboxEntry', () {
    test('round-trips to and from JSON without losing fields', () {
      final at = DateTime.utc(2026, 11, 18, 9, 15);
      final entry = SafetyOutboxEntry(
        id: 'abc-123',
        kind: SafetyOutboxKind.sosTrip,
        tripId: 't-1',
        payload: const {'latitude': 5.6, 'longitude': -0.2},
        enqueuedAt: at,
      );
      final json = entry.toJson();
      expect(json['id'], 'abc-123');
      expect(json['kind'], 'sosTrip');
      expect(json['trip_id'], 't-1');
      expect(json['payload'], const {'latitude': 5.6, 'longitude': -0.2});
      final back = SafetyOutboxEntry.fromJson(json);
      expect(back.id, 'abc-123');
      expect(back.kind, SafetyOutboxKind.sosTrip);
      expect(back.tripId, 't-1');
      expect(back.payload, const {'latitude': 5.6, 'longitude': -0.2});
      expect(back.enqueuedAt.toUtc(), at);
    });
  });
}
