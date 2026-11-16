// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TicketResponse _$TicketResponseFromJson(Map<String, dynamic> json) =>
    _TicketResponse(
      id: json['id'] as String,
      ticketReference: json['ticket_reference'] as String,
      bookingId: json['booking_id'] as String,
      bookingPassengerId: json['booking_passenger_id'] as String,
      tripId: json['trip_id'] as String,
      status: $enumDecode(
        _$TicketStatusEnumMap,
        json['status'],
        unknownValue: TicketStatus.issued,
      ),
      issuedAt: DateTime.parse(json['issued_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      validatedAt: json['validated_at'] == null
          ? null
          : DateTime.parse(json['validated_at'] as String),
      qrToken: json['qr_token'] as String,
    );

Map<String, dynamic> _$TicketResponseToJson(_TicketResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ticket_reference': instance.ticketReference,
      'booking_id': instance.bookingId,
      'booking_passenger_id': instance.bookingPassengerId,
      'trip_id': instance.tripId,
      'status': _$TicketStatusEnumMap[instance.status]!,
      'issued_at': instance.issuedAt.toIso8601String(),
      'expires_at': instance.expiresAt.toIso8601String(),
      'validated_at': ?instance.validatedAt?.toIso8601String(),
      'qr_token': instance.qrToken,
    };

const _$TicketStatusEnumMap = {
  TicketStatus.issued: 'issued',
  TicketStatus.validated: 'validated',
  TicketStatus.expired: 'expired',
  TicketStatus.revoked: 'revoked',
};
