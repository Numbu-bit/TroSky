// Seats and bookings, field for field as in backend/app/schemas/trip.py
// (seats) and backend/app/schemas/booking.py.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_decimal.dart';
import 'route_dto.dart';

part 'booking_dto.freezed.dart';
part 'booking_dto.g.dart';

/// `SeatType` (backend/app/models/vehicles.py). A type added later reads as
/// [standard].
@JsonEnum()
enum SeatType { standard, vip, window, aisle }

/// `TripSeatResponse`: one seat of the trip's vehicle and whether it is
/// free (no held or confirmed reservation).
@freezed
abstract class TripSeatResponse with _$TripSeatResponse {
  const factory TripSeatResponse({
    required String id,
    required String seatNumber,
    required int rowNumber,
    required int columnNumber,
    @JsonKey(unknownEnumValue: SeatType.standard) required SeatType seatType,
    required bool isAvailable,
  }) = _TripSeatResponse;

  factory TripSeatResponse.fromJson(Map<String, dynamic> json) =>
      _$TripSeatResponseFromJson(json);
}

/// `TripSeatsResponse` from `GET /trips/{id}/seats`. Its price comes from
/// `GET /trips/{id}/fare-quote`.
@freezed
abstract class TripSeatsResponse with _$TripSeatsResponse {
  const factory TripSeatsResponse({
    required String tripId,
    required String vehicleId,
    required int totalSeats,
    required int availableSeats,
    required List<TripSeatResponse> seats,
  }) = _TripSeatsResponse;

  factory TripSeatsResponse.fromJson(Map<String, dynamic> json) =>
      _$TripSeatsResponseFromJson(json);
}

/// `PassengerInput`: who sits in one seat.
@freezed
abstract class PassengerInput with _$PassengerInput {
  const factory PassengerInput({
    required String seatId,
    required String fullName,
    String? phoneNumber,
  }) = _PassengerInput;

  factory PassengerInput.fromJson(Map<String, dynamic> json) =>
      _$PassengerInputFromJson(json);
}

/// `BookingCreateRequest` for `POST /bookings`: 1 to 10 passengers, one
/// seat each. The pickup is [originStopId] when the passenger chose a stop,
/// else the phone's position (both coordinates or neither).
@freezed
abstract class BookingCreateRequest with _$BookingCreateRequest {
  const factory BookingCreateRequest({
    required String tripId,
    required List<PassengerInput> passengers,
    String? originStopId,
    String? destinationStopId,
    double? pickupLatitude,
    double? pickupLongitude,
  }) = _BookingCreateRequest;

  factory BookingCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$BookingCreateRequestFromJson(json);
}

/// `BookingStatus` (backend/app/models/bookings.py). A new booking is
/// [awaitingAcceptance]: it holds its seats until the trip's driver (or an
/// admin) answers, by `expires_at`, and can't be paid for yet. Accepted, it
/// is [pending] (or [paymentPending] once payment started), with a new
/// `expires_at` to pay by.
@JsonEnum(fieldRename: FieldRename.snake)
enum BookingStatus {
  awaitingAcceptance,
  pending,
  paymentPending,
  confirmed,
  cancelled,
  expired,
  completed,
  refundPending,
  refunded,
}

@freezed
abstract class BookingPassengerResponse with _$BookingPassengerResponse {
  const factory BookingPassengerResponse({
    required String id,
    required String seatId,
    required String fullName,
    String? phoneNumber,
  }) = _BookingPassengerResponse;

  factory BookingPassengerResponse.fromJson(Map<String, dynamic> json) =>
      _$BookingPassengerResponseFromJson(json);
}

/// `BookingTripSummaryResponse`: enough of the trip for a booking card.
@freezed
abstract class BookingTripSummaryResponse with _$BookingTripSummaryResponse {
  const factory BookingTripSummaryResponse({
    required DateTime scheduledDepartureAt,
    required String routeName,
    required String originStopName,
    required String destinationStopName,
    @JsonKey(unknownEnumValue: TripStatus.scheduled) required TripStatus status,
    String? vehicleRegistrationNumber,
  }) = _BookingTripSummaryResponse;

  factory BookingTripSummaryResponse.fromJson(Map<String, dynamic> json) =>
      _$BookingTripSummaryResponseFromJson(json);
}

/// `BookingSummaryResponse` from `GET /bookings/summary` (G25): the Trip
/// History card for one month.
@freezed
abstract class BookingSummaryResponse with _$BookingSummaryResponse {
  const factory BookingSummaryResponse({
    /// "2026-10".
    required String month,
    required String currency,

    /// Paid trips departing that month.
    required int tripsCount,

    /// What they cost, fees included.
    @JsonKey(fromJson: decimalString) required String totalSpent,
    @JsonKey(fromJson: decimalString) required String averageFare,

    /// What sharing saved: the unshared price less the fare paid.
    @JsonKey(fromJson: decimalString) required String totalSaved,
  }) = _BookingSummaryResponse;

  factory BookingSummaryResponse.fromJson(Map<String, dynamic> json) =>
      _$BookingSummaryResponseFromJson(json);
}

/// `BookingResponse`. Money stays exactly as sent ("16.50").
@freezed
abstract class BookingResponse with _$BookingResponse {
  const factory BookingResponse({
    required String id,
    required String bookingReference,
    required String tripId,
    @JsonKey(unknownEnumValue: BookingStatus.pending)
    required BookingStatus status,
    required int passengerCount,
    String? originStopId,
    String? destinationStopId,
    @JsonKey(fromJson: decimalString) required String fareAmount,
    @JsonKey(fromJson: decimalString) required String platformFee,
    @JsonKey(fromJson: decimalString) required String totalAmount,

    /// The deadline: for the driver's answer ([BookingStatus.
    /// awaitingAcceptance]), then for paying ([BookingStatus.pending]).
    DateTime? expiresAt,
    required DateTime createdAt,
    required List<BookingPassengerResponse> passengers,
    BookingTripSummaryResponse? trip,
    String? boardingStopName,
    String? alightingStopName,
  }) = _BookingResponse;

  factory BookingResponse.fromJson(Map<String, dynamic> json) =>
      _$BookingResponseFromJson(json);
}
