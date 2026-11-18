// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'safety_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReportIncidentRequest _$ReportIncidentRequestFromJson(
  Map<String, dynamic> json,
) => _ReportIncidentRequest(
  incidentType: $enumDecode(_$IncidentTypeEnumMap, json['incident_type']),
  severity: $enumDecodeNullable(_$IncidentSeverityEnumMap, json['severity']),
  description: json['description'] as String,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
);

Map<String, dynamic> _$ReportIncidentRequestToJson(
  _ReportIncidentRequest instance,
) => <String, dynamic>{
  'incident_type': _$IncidentTypeEnumMap[instance.incidentType]!,
  'severity': ?_$IncidentSeverityEnumMap[instance.severity],
  'description': instance.description,
  'latitude': ?instance.latitude,
  'longitude': ?instance.longitude,
};

const _$IncidentTypeEnumMap = {
  IncidentType.accident: 'accident',
  IncidentType.breakdown: 'breakdown',
  IncidentType.delay: 'delay',
  IncidentType.safetyConcern: 'safety_concern',
  IncidentType.passengerIssue: 'passenger_issue',
  IncidentType.roadHazard: 'road_hazard',
  IncidentType.other: 'other',
};

const _$IncidentSeverityEnumMap = {
  IncidentSeverity.low: 'low',
  IncidentSeverity.medium: 'medium',
  IncidentSeverity.high: 'high',
  IncidentSeverity.critical: 'critical',
};

_IncidentResponse _$IncidentResponseFromJson(Map<String, dynamic> json) =>
    _IncidentResponse(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      reportedBy: json['reported_by'] as String,
      incidentType: $enumDecode(
        _$IncidentTypeEnumMap,
        json['incident_type'],
        unknownValue: IncidentType.other,
      ),
      severity: $enumDecode(
        _$IncidentSeverityEnumMap,
        json['severity'],
        unknownValue: IncidentSeverity.medium,
      ),
      description: json['description'] as String,
      photoUrl: json['photo_url'] as String?,
      status: $enumDecode(
        _$IncidentStatusEnumMap,
        json['status'],
        unknownValue: IncidentStatus.reported,
      ),
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      resolutionNotes: json['resolution_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$IncidentResponseToJson(_IncidentResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'trip_id': instance.tripId,
      'reported_by': instance.reportedBy,
      'incident_type': _$IncidentTypeEnumMap[instance.incidentType]!,
      'severity': _$IncidentSeverityEnumMap[instance.severity]!,
      'description': instance.description,
      'photo_url': ?instance.photoUrl,
      'status': _$IncidentStatusEnumMap[instance.status]!,
      'resolved_by': ?instance.resolvedBy,
      'resolved_at': ?instance.resolvedAt?.toIso8601String(),
      'resolution_notes': ?instance.resolutionNotes,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$IncidentStatusEnumMap = {
  IncidentStatus.reported: 'reported',
  IncidentStatus.inReview: 'in_review',
  IncidentStatus.resolved: 'resolved',
  IncidentStatus.closed: 'closed',
};

_TriggerSosRequest _$TriggerSosRequestFromJson(Map<String, dynamic> json) =>
    _TriggerSosRequest(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$TriggerSosRequestToJson(_TriggerSosRequest instance) =>
    <String, dynamic>{
      'latitude': ?instance.latitude,
      'longitude': ?instance.longitude,
    };

_SosAlertResponse _$SosAlertResponseFromJson(Map<String, dynamic> json) =>
    _SosAlertResponse(
      id: json['id'] as String,
      tripId: json['trip_id'] as String?,
      triggeredBy: json['triggered_by'] as String,
      status: $enumDecode(
        _$SosAlertStatusEnumMap,
        json['status'],
        unknownValue: SosAlertStatus.active,
      ),
      acknowledgedBy: json['acknowledged_by'] as String?,
      acknowledgedAt: json['acknowledged_at'] == null
          ? null
          : DateTime.parse(json['acknowledged_at'] as String),
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      resolutionNotes: json['resolution_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$SosAlertResponseToJson(_SosAlertResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'trip_id': ?instance.tripId,
      'triggered_by': instance.triggeredBy,
      'status': _$SosAlertStatusEnumMap[instance.status]!,
      'acknowledged_by': ?instance.acknowledgedBy,
      'acknowledged_at': ?instance.acknowledgedAt?.toIso8601String(),
      'resolved_by': ?instance.resolvedBy,
      'resolved_at': ?instance.resolvedAt?.toIso8601String(),
      'resolution_notes': ?instance.resolutionNotes,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$SosAlertStatusEnumMap = {
  SosAlertStatus.active: 'active',
  SosAlertStatus.acknowledged: 'acknowledged',
  SosAlertStatus.resolved: 'resolved',
  SosAlertStatus.falseAlarm: 'false_alarm',
};

_RateBookingRequest _$RateBookingRequestFromJson(Map<String, dynamic> json) =>
    _RateBookingRequest(
      score: (json['score'] as num).toInt(),
      comment: json['comment'] as String?,
      safety: (json['safety'] as num?)?.toInt(),
      cleanliness: (json['cleanliness'] as num?)?.toInt(),
      professionalism: (json['professionalism'] as num?)?.toInt(),
      timeliness: (json['timeliness'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RateBookingRequestToJson(_RateBookingRequest instance) =>
    <String, dynamic>{
      'score': instance.score,
      'comment': ?instance.comment,
      'safety': ?instance.safety,
      'cleanliness': ?instance.cleanliness,
      'professionalism': ?instance.professionalism,
      'timeliness': ?instance.timeliness,
    };

_RatingResponse _$RatingResponseFromJson(Map<String, dynamic> json) =>
    _RatingResponse(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      tripId: json['trip_id'] as String,
      driverId: json['driver_id'] as String?,
      score: (json['score'] as num).toInt(),
      comment: json['comment'] as String?,
      safety: (json['safety'] as num?)?.toInt(),
      cleanliness: (json['cleanliness'] as num?)?.toInt(),
      professionalism: (json['professionalism'] as num?)?.toInt(),
      timeliness: (json['timeliness'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$RatingResponseToJson(_RatingResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'booking_id': instance.bookingId,
      'trip_id': instance.tripId,
      'driver_id': ?instance.driverId,
      'score': instance.score,
      'comment': ?instance.comment,
      'safety': ?instance.safety,
      'cleanliness': ?instance.cleanliness,
      'professionalism': ?instance.professionalism,
      'timeliness': ?instance.timeliness,
      'created_at': instance.createdAt.toIso8601String(),
    };
