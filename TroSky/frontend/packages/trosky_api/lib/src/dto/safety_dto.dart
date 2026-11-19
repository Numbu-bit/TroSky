// Safety domain: incident reports and SOS alerts, field-for-field as
// backend/app/schemas/safety.py.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'safety_dto.freezed.dart';
part 'safety_dto.g.dart';

/// `IncidentType` (backend/app/models/safety.py). The P-13 category list.
@JsonEnum(fieldRename: FieldRename.snake)
enum IncidentType {
  accident,
  breakdown,
  delay,
  safetyConcern,
  passengerIssue,
  roadHazard,
  other,
}

@JsonEnum(fieldRename: FieldRename.snake)
enum IncidentSeverity { low, medium, high, critical }

@JsonEnum(fieldRename: FieldRename.snake)
enum IncidentStatus { reported, inReview, resolved, closed }

@JsonEnum(fieldRename: FieldRename.snake)
enum SosAlertStatus { active, acknowledged, resolved, falseAlarm }

/// `ReportIncidentRequest` for `POST /trips/{trip_id}/incidents`.
@freezed
abstract class ReportIncidentRequest with _$ReportIncidentRequest {
  const factory ReportIncidentRequest({
    required IncidentType incidentType,
    IncidentSeverity? severity,
    required String description,
    double? latitude,
    double? longitude,
  }) = _ReportIncidentRequest;

  factory ReportIncidentRequest.fromJson(Map<String, dynamic> json) =>
      _$ReportIncidentRequestFromJson(json);
}

@freezed
abstract class IncidentResponse with _$IncidentResponse {
  const factory IncidentResponse({
    required String id,
    required String tripId,
    required String reportedBy,
    @JsonKey(unknownEnumValue: IncidentType.other)
    required IncidentType incidentType,
    @JsonKey(unknownEnumValue: IncidentSeverity.medium)
    required IncidentSeverity severity,
    required String description,
    String? photoUrl,
    @JsonKey(unknownEnumValue: IncidentStatus.reported)
    required IncidentStatus status,
    String? resolvedBy,
    DateTime? resolvedAt,
    String? resolutionNotes,
    required DateTime createdAt,
  }) = _IncidentResponse;

  factory IncidentResponse.fromJson(Map<String, dynamic> json) =>
      _$IncidentResponseFromJson(json);
}

/// `TriggerSosRequest` — accepts optional coords. Backend texts the
/// user's registered emergency contacts regardless of coords.
@freezed
abstract class TriggerSosRequest with _$TriggerSosRequest {
  const factory TriggerSosRequest({double? latitude, double? longitude}) =
      _TriggerSosRequest;

  factory TriggerSosRequest.fromJson(Map<String, dynamic> json) =>
      _$TriggerSosRequestFromJson(json);
}

@freezed
abstract class SosAlertResponse with _$SosAlertResponse {
  const factory SosAlertResponse({
    required String id,

    /// Null for an off-trip SOS (`POST /sos`).
    String? tripId,
    required String triggeredBy,
    @JsonKey(unknownEnumValue: SosAlertStatus.active)
    required SosAlertStatus status,
    String? acknowledgedBy,
    DateTime? acknowledgedAt,
    String? resolvedBy,
    DateTime? resolvedAt,
    String? resolutionNotes,
    required DateTime createdAt,
  }) = _SosAlertResponse;

  factory SosAlertResponse.fromJson(Map<String, dynamic> json) =>
      _$SosAlertResponseFromJson(json);
}

/// `RateBookingRequest` for `POST /bookings/{booking_id}/rating`.
@freezed
abstract class RateBookingRequest with _$RateBookingRequest {
  const factory RateBookingRequest({
    required int score,
    String? comment,
    int? safety,
    int? cleanliness,
    int? professionalism,
    int? timeliness,
  }) = _RateBookingRequest;

  factory RateBookingRequest.fromJson(Map<String, dynamic> json) =>
      _$RateBookingRequestFromJson(json);
}

@freezed
abstract class RatingResponse with _$RatingResponse {
  const factory RatingResponse({
    required String id,
    required String bookingId,
    required String tripId,
    String? driverId,
    required int score,
    String? comment,
    int? safety,
    int? cleanliness,
    int? professionalism,
    int? timeliness,
    required DateTime createdAt,
  }) = _RatingResponse;

  factory RatingResponse.fromJson(Map<String, dynamic> json) =>
      _$RatingResponseFromJson(json);
}
