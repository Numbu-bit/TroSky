import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
import '../dto/ticket_dto.dart';

/// `/bookings/{id}/tickets` and `/tickets/{id}` (backend/app/api/v1/
/// tickets.py). Tickets are issued by the backend when a booking moves
/// to `confirmed`; the list is empty until then.
abstract interface class TicketRepository {
  /// Every ticket issued for [bookingId] (one per booked seat). Empty
  /// list until the booking is confirmed.
  Future<Result<List<TicketResponse>>> listForBooking(String bookingId);
}

/// [TicketRepository] against the backend.
class LiveTicketRepository implements TicketRepository {
  LiveTicketRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<List<TicketResponse>>> listForBooking(String bookingId) =>
      apiCall(
        () => _dio.get<Object?>('/bookings/$bookingId/tickets'),
        (data) => (data as List)
            .cast<Map<String, dynamic>>()
            .map(TicketResponse.fromJson)
            .toList(),
      );
}
