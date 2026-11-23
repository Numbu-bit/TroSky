// Pure-logic tests for the P-11 status chip derivation. Owner signed
// off on the four cases — one test per case, plus a boundary test.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/tracking/domain/track_status.dart';
import 'package:trosky_api/trosky_api.dart';

void main() {
  final departure = DateTime.utc(2026, 11, 17, 8, 0);
  final now = DateTime.utc(2026, 11, 17, 7, 40);

  group('trackStatusFor', () {
    test('scheduled before departure -> Boarding at origin', () {
      final s = trackStatusFor(
        tripStatus: TripStatus.scheduled,
        departureAt: departure,
        distanceToDestinationMeters: 10000,
        etaMinutes: 30,
        etaAt: departure.add(const Duration(minutes: 30)),
        now: now,
      );
      expect(s.kind, TrackStatusKind.boardingAtOrigin);
    });

    test('in_progress with distance > 100 m -> Arriving in ~<n> min', () {
      final s = trackStatusFor(
        tripStatus: TripStatus.inProgress,
        departureAt: departure,
        distanceToDestinationMeters: 101,
        etaMinutes: 24,
        etaAt: now.add(const Duration(minutes: 24)),
        now: now,
      );
      expect(s.kind, TrackStatusKind.arrivingIn);
      expect(s.etaMinutes, 24);
    });

    test('in_progress at 100 m exactly -> At your stop (inclusive)', () {
      final s = trackStatusFor(
        tripStatus: TripStatus.inProgress,
        departureAt: departure,
        distanceToDestinationMeters: 100,
        etaMinutes: 0,
        etaAt: now,
        now: now,
      );
      expect(s.kind, TrackStatusKind.atYourStop);
    });

    test('completed -> Trip completed (regardless of distance)', () {
      final s = trackStatusFor(
        tripStatus: TripStatus.completed,
        departureAt: departure,
        distanceToDestinationMeters: 9999,
        etaMinutes: 0,
        etaAt: now,
        now: now,
      );
      expect(s.kind, TrackStatusKind.completed);
    });

    test('boarding / paused also show Boarding at origin', () {
      for (final status in [TripStatus.boarding, TripStatus.paused]) {
        final s = trackStatusFor(
          tripStatus: status,
          departureAt: departure,
          distanceToDestinationMeters: 2000,
          etaMinutes: 10,
          etaAt: now,
          now: now,
        );
        expect(s.kind, TrackStatusKind.boardingAtOrigin, reason: '$status');
      }
    });
  });
}
