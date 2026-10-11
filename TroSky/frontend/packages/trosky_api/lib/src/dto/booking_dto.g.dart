// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TripSeatResponse _$TripSeatResponseFromJson(Map<String, dynamic> json) =>
    _TripSeatResponse(
      id: json['id'] as String,
      seatNumber: json['seat_number'] as String,
      rowNumber: (json['row_number'] as num).toInt(),
      columnNumber: (json['column_number'] as num).toInt(),
      seatType: $enumDecode(
        _$SeatTypeEnumMap,
        json['seat_type'],
        unknownValue: SeatType.standard,
      ),
      isAvailable: json['is_available'] as bool,
    );

Map<String, dynamic> _$TripSeatResponseToJson(_TripSeatResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'seat_number': instance.seatNumber,
      'row_number': instance.rowNumber,
      'column_number': instance.columnNumber,
      'seat_type': _$SeatTypeEnumMap[instance.seatType]!,
      'is_available': instance.isAvailable,
    };

const _$SeatTypeEnumMap = {
  SeatType.standard: 'standard',
  SeatType.vip: 'vip',
  SeatType.window: 'window',
  SeatType.aisle: 'aisle',
};

_TripSeatsResponse _$TripSeatsResponseFromJson(Map<String, dynamic> json) =>
    _TripSeatsResponse(
      tripId: json['trip_id'] as String,
      vehicleId: json['vehicle_id'] as String,
      totalSeats: (json['total_seats'] as num).toInt(),
      availableSeats: (json['available_seats'] as num).toInt(),
      seats: (json['seats'] as List<dynamic>)
          .map((e) => TripSeatResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TripSeatsResponseToJson(_TripSeatsResponse instance) =>
    <String, dynamic>{
      'trip_id': instance.tripId,
      'vehicle_id': instance.vehicleId,
      'total_seats': instance.totalSeats,
      'available_seats': instance.availableSeats,
      'seats': instance.seats.map((e) => e.toJson()).toList(),
    };

_PassengerInput _$PassengerInputFromJson(Map<String, dynamic> json) =>
    _PassengerInput(
      seatId: json['seat_id'] as String,
      fullName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String?,
    );

Map<String, dynamic> _$PassengerInputToJson(_PassengerInput instance) =>
    <String, dynamic>{
      'seat_id': instance.seatId,
      'full_name': instance.fullName,
      'phone_number': ?instance.phoneNumber,
    };

_BookingCreateRequest _$BookingCreateRequestFromJson(
  Map<String, dynamic> json,
) => _BookingCreateRequest(
  tripId: json['trip_id'] as String,
  passengers: (json['passengers'] as List<dynamic>)
      .map((e) => PassengerInput.fromJson(e as Map<String, dynamic>))
      .toList(),
  originStopId: json['origin_stop_id'] as String?,
  destinationStopId: json['destination_stop_id'] as String?,
  pickupLatitude: (json['pickup_latitude'] as num?)?.toDouble(),
  pickupLongitude: (json['pickup_longitude'] as num?)?.toDouble(),
);

Map<String, dynamic> _$BookingCreateRequestToJson(
  _BookingCreateRequest instance,
) => <String, dynamic>{
  'trip_id': instance.tripId,
  'passengers': instance.passengers.map((e) => e.toJson()).toList(),
  'origin_stop_id': ?instance.originStopId,
  'destination_stop_id': ?instance.destinationStopId,
  'pickup_latitude': ?instance.pickupLatitude,
  'pickup_longitude': ?instance.pickupLongitude,
};

_BookingPassengerResponse _$BookingPassengerResponseFromJson(
  Map<String, dynamic> json,
) => _BookingPassengerResponse(
  id: json['id'] as String,
  seatId: json['seat_id'] as String,
  fullName: json['full_name'] as String,
  phoneNumber: json['phone_number'] as String?,
);

Map<String, dynamic> _$BookingPassengerResponseToJson(
  _BookingPassengerResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'seat_id': instance.seatId,
  'full_name': instance.fullName,
  'phone_number': ?instance.phoneNumber,
};

_BookingTripSummaryResponse _$BookingTripSummaryResponseFromJson(
  Map<String, dynamic> json,
) => _BookingTripSummaryResponse(
  scheduledDepartureAt: DateTime.parse(
    json['scheduled_departure_at'] as String,
  ),
  routeName: json['route_name'] as String,
  originStopName: json['origin_stop_name'] as String,
  destinationStopName: json['destination_stop_name'] as String,
  status: $enumDecode(
    _$TripStatusEnumMap,
    json['status'],
    unknownValue: TripStatus.scheduled,
  ),
  vehicleRegistrationNumber: json['vehicle_registration_number'] as String?,
);

Map<String, dynamic> _$BookingTripSummaryResponseToJson(
  _BookingTripSummaryResponse instance,
) => <String, dynamic>{
  'scheduled_departure_at': instance.scheduledDepartureAt.toIso8601String(),
  'route_name': instance.routeName,
  'origin_stop_name': instance.originStopName,
  'destination_stop_name': instance.destinationStopName,
  'status': _$TripStatusEnumMap[instance.status]!,
  'vehicle_registration_number': ?instance.vehicleRegistrationNumber,
};

const _$TripStatusEnumMap = {
  TripStatus.scheduled: 'scheduled',
  TripStatus.boarding: 'boarding',
  TripStatus.inProgress: 'in_progress',
  TripStatus.paused: 'paused',
  TripStatus.completed: 'completed',
  TripStatus.cancelled: 'cancelled',
};

_BookingResponse _$BookingResponseFromJson(Map<String, dynamic> json) =>
    _BookingResponse(
      id: json['id'] as String,
      bookingReference: json['booking_reference'] as String,
      tripId: json['trip_id'] as String,
      status: $enumDecode(
        _$BookingStatusEnumMap,
        json['status'],
        unknownValue: BookingStatus.pending,
      ),
      passengerCount: (json['passenger_count'] as num).toInt(),
      originStopId: json['origin_stop_id'] as String?,
      destinationStopId: json['destination_stop_id'] as String?,
      fareAmount: decimalString(json['fare_amount']),
      platformFee: decimalString(json['platform_fee']),
      totalAmount: decimalString(json['total_amount']),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      passengers: (json['passengers'] as List<dynamic>)
          .map(
            (e) => BookingPassengerResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      trip: json['trip'] == null
          ? null
          : BookingTripSummaryResponse.fromJson(
              json['trip'] as Map<String, dynamic>,
            ),
      boardingStopName: json['boarding_stop_name'] as String?,
      alightingStopName: json['alighting_stop_name'] as String?,
    );

Map<String, dynamic> _$BookingResponseToJson(_BookingResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'booking_reference': instance.bookingReference,
      'trip_id': instance.tripId,
      'status': _$BookingStatusEnumMap[instance.status]!,
      'passenger_count': instance.passengerCount,
      'origin_stop_id': ?instance.originStopId,
      'destination_stop_id': ?instance.destinationStopId,
      'fare_amount': instance.fareAmount,
      'platform_fee': instance.platformFee,
      'total_amount': instance.totalAmount,
      'expires_at': ?instance.expiresAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'passengers': instance.passengers.map((e) => e.toJson()).toList(),
      'trip': ?instance.trip?.toJson(),
      'boarding_stop_name': ?instance.boardingStopName,
      'alighting_stop_name': ?instance.alightingStopName,
    };

const _$BookingStatusEnumMap = {
  BookingStatus.pending: 'pending',
  BookingStatus.paymentPending: 'payment_pending',
  BookingStatus.confirmed: 'confirmed',
  BookingStatus.cancelled: 'cancelled',
  BookingStatus.expired: 'expired',
  BookingStatus.completed: 'completed',
  BookingStatus.refundPending: 'refund_pending',
  BookingStatus.refunded: 'refunded',
};
