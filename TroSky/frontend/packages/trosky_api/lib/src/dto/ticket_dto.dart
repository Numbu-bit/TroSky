// Tickets, field for field as in backend/app/schemas/ticket.py. One
// ticket per booked seat: the backend issues them when a booking moves
// to `confirmed`.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'ticket_dto.freezed.dart';
part 'ticket_dto.g.dart';

/// `TicketStatus` from backend/app/models/tickets.py. A status added
/// later reads as [issued].
@JsonEnum(fieldRename: FieldRename.snake)
enum TicketStatus { issued, validated, expired, revoked }

/// `TicketResponse` from `GET /tickets/{id}` and
/// `GET /bookings/{id}/tickets`. [qrToken] is bearer-like: never log it,
/// never send it to analytics, never display as text.
@freezed
abstract class TicketResponse with _$TicketResponse {
  const factory TicketResponse({
    required String id,
    required String ticketReference,
    required String bookingId,
    required String bookingPassengerId,
    required String tripId,
    @JsonKey(unknownEnumValue: TicketStatus.issued)
    required TicketStatus status,
    required DateTime issuedAt,
    required DateTime expiresAt,
    DateTime? validatedAt,
    required String qrToken,
  }) = _TicketResponse;

  factory TicketResponse.fromJson(Map<String, dynamic> json) =>
      _$TicketResponseFromJson(json);
}

/// The pill shown above the QR. Derived from [TicketStatus] plus trip
/// time: the backend only has one pre-trip status ([TicketStatus.issued])
/// so the split between `notYetValid` and `readyToBoard` is a client-side
/// derivation. See [ticketPillStateFor].
enum TicketPillState { notYetValid, readyToBoard, used, expired, notValid }

/// Opens-at-boarding rule: the Ready-to-Board pill switches on this many
/// minutes before the trip's scheduled departure.
const Duration ticketBoardingWindow = Duration(minutes: 60);

/// Pure mapping used by [TicketScreen]'s status pill. Takes the ticket
/// [status], the trip's scheduled [tripDeparture], an optional [tripEnd]
/// (falls back to `tripDeparture + 2 h` for the Ghana-minibus case where
/// arrival isn't scheduled), and [now].
///
/// Rules (owner-signed for Step 16):
///   issued AND now < departure - 60 min      → notYetValid
///   issued AND departure - 60 min ≤ now ≤ end → readyToBoard
///   issued AND now > end                      → expired
///   validated                                 → used
///   expired                                   → expired
///   revoked                                   → notValid
TicketPillState ticketPillStateFor(
  TicketStatus status, {
  required DateTime tripDeparture,
  DateTime? tripEnd,
  required DateTime now,
}) {
  switch (status) {
    case TicketStatus.validated:
      return TicketPillState.used;
    case TicketStatus.expired:
      return TicketPillState.expired;
    case TicketStatus.revoked:
      return TicketPillState.notValid;
    case TicketStatus.issued:
      final end = tripEnd ?? tripDeparture.add(const Duration(hours: 2));
      final opensAt = tripDeparture.subtract(ticketBoardingWindow);
      if (now.isBefore(opensAt)) return TicketPillState.notYetValid;
      if (now.isAfter(end)) return TicketPillState.expired;
      return TicketPillState.readyToBoard;
  }
}
