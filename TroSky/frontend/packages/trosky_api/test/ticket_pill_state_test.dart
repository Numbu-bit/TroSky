import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_api/trosky_api.dart';

void main() {
  final departure = DateTime.utc(2026, 11, 16, 8, 30);
  // The trip's end (arrival): used by the issued-after-end case.
  final end = DateTime.utc(2026, 11, 16, 9, 30);

  group('ticketPillStateFor', () {
    test('issued, now before departure - 60 min -> notYetValid', () {
      final state = ticketPillStateFor(
        TicketStatus.issued,
        tripDeparture: departure,
        tripEnd: end,
        now: DateTime.utc(2026, 11, 16, 7, 29),
      );
      expect(state, TicketPillState.notYetValid);
    });

    test('issued, now at the opening boundary -> readyToBoard', () {
      final state = ticketPillStateFor(
        TicketStatus.issued,
        tripDeparture: departure,
        tripEnd: end,
        now: DateTime.utc(2026, 11, 16, 7, 30),
      );
      expect(state, TicketPillState.readyToBoard);
    });

    test('issued, now within the boarding window -> readyToBoard', () {
      final state = ticketPillStateFor(
        TicketStatus.issued,
        tripDeparture: departure,
        tripEnd: end,
        now: DateTime.utc(2026, 11, 16, 8, 29),
      );
      expect(state, TicketPillState.readyToBoard);
    });

    test('issued, now past trip end -> expired', () {
      final state = ticketPillStateFor(
        TicketStatus.issued,
        tripDeparture: departure,
        tripEnd: end,
        now: DateTime.utc(2026, 11, 16, 9, 31),
      );
      expect(state, TicketPillState.expired);
    });

    test('issued with no tripEnd falls back to departure + 2 h', () {
      final state = ticketPillStateFor(
        TicketStatus.issued,
        tripDeparture: departure,
        now: DateTime.utc(2026, 11, 16, 10, 31),
      );
      expect(state, TicketPillState.expired);
    });

    test('validated -> used (regardless of time)', () {
      final state = ticketPillStateFor(
        TicketStatus.validated,
        tripDeparture: departure,
        now: DateTime.utc(2026, 11, 16, 5),
      );
      expect(state, TicketPillState.used);
    });

    test('expired enum -> expired pill', () {
      final state = ticketPillStateFor(
        TicketStatus.expired,
        tripDeparture: departure,
        now: DateTime.utc(2026, 11, 16, 7),
      );
      expect(state, TicketPillState.expired);
    });

    test('revoked -> notValid', () {
      final state = ticketPillStateFor(
        TicketStatus.revoked,
        tripDeparture: departure,
        now: DateTime.utc(2026, 11, 16, 8),
      );
      expect(state, TicketPillState.notValid);
    });
  });
}
