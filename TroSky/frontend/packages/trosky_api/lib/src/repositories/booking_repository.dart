import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
import '../dto/booking_dto.dart';
import '../dto/paginated.dart';

/// `/bookings` (backend/app/api/v1/bookings.py).
abstract interface class BookingRepository {
  /// Holds the seats. With booking acceptance on (the backend's default)
  /// the booking is `awaiting_acceptance` until the driver answers, by
  /// `expires_at` (`BOOKING_ACCEPT_TIMEOUT_SECONDS`, 120 s); accepted, it is
  /// `pending` for `SEAT_RESERVATION_HOLD_SECONDS` (600 s) to pay. With it
  /// off, it is `pending` straight away. Unanswered or declined, it moves to
  /// another vehicle (a new `trip_id`, still `awaiting_acceptance`) or ends
  /// (`expired` or `cancelled`). [idempotencyKey] makes a retry of the same
  /// request return the same booking instead of a second one.
  ///
  /// 409 `SEAT_NOT_AVAILABLE` (`details.seat_id`), 409 `TRIP_NOT_BOOKABLE`,
  /// 403 `ACCOUNT_NOT_VERIFIED`, 422 `STOP_NOT_ON_ROUTE` / validation.
  Future<Result<BookingResponse>> create(
    BookingCreateRequest request, {
    required String idempotencyKey,
  });

  /// The signed-in passenger's bookings, newest first; [statuses] and
  /// [upcoming] narrow them (backend gap G12).
  Future<Result<Paginated<BookingResponse>>> list({
    List<BookingStatus>? statuses,
    bool? upcoming,
    int limit = 20,
    int offset = 0,
  });

  /// The Trip History card (G25): paid trips departing in [month]
  /// ("2026-10"; the backend's default is this month), what they cost and
  /// what sharing saved.
  Future<Result<BookingSummaryResponse>> summary({String? month});

  Future<Result<BookingResponse>> get(String bookingId);

  /// Before the trip starts, or while the driver hasn't answered, this is
  /// decided at once: the seats are released and the booking is
  /// `cancelled`, or `refund_pending` when it was paid (an admin then
  /// approves the refund, back the way it was paid). Once the trip has
  /// started, the request waits for an admin and the booking comes back
  /// unchanged. 409 `INVALID_STATE_TRANSITION` when it already ended.
  Future<Result<BookingResponse>> cancel(String bookingId, {String? reason});
}

/// [BookingRepository] against the backend.
class LiveBookingRepository implements BookingRepository {
  LiveBookingRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<BookingResponse>> create(
    BookingCreateRequest request, {
    required String idempotencyKey,
  }) => apiCall(
    () => _dio.post<Object?>(
      '/bookings',
      data: request.toJson(),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
    (data) => BookingResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<Paginated<BookingResponse>>> list({
    List<BookingStatus>? statuses,
    bool? upcoming,
    int limit = 20,
    int offset = 0,
  }) => apiCall(
    () => _dio.get<Object?>(
      '/bookings',
      queryParameters: {
        if (statuses != null && statuses.isNotEmpty)
          'status': statuses.map(bookingStatusName).join(','),
        'upcoming': ?upcoming,
        'limit': limit,
        'offset': offset,
      },
    ),
    (data) => Paginated.fromJson(jsonObject(data), BookingResponse.fromJson),
  );

  @override
  Future<Result<BookingSummaryResponse>> summary({String? month}) => apiCall(
    () => _dio.get<Object?>(
      '/bookings/summary',
      queryParameters: {'month': ?month},
    ),
    (data) => BookingSummaryResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<BookingResponse>> get(String bookingId) => apiCall(
    () => _dio.get<Object?>('/bookings/$bookingId'),
    (data) => BookingResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<BookingResponse>> cancel(String bookingId, {String? reason}) =>
      apiCall(
        () => _dio.post<Object?>(
          '/bookings/$bookingId/cancel',
          data: {'reason': ?reason},
        ),
        (data) => BookingResponse.fromJson(jsonObject(data)),
      );
}

/// The backend's name for [status] ("payment_pending").
String bookingStatusName(BookingStatus status) => status.name.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => '_${m[0]!.toLowerCase()}',
);
