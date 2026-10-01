// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DriverResponse _$DriverResponseFromJson(Map<String, dynamic> json) =>
    _DriverResponse(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      licenseNumber: json['license_number'] as String,
      licenseExpiry: DateTime.parse(json['license_expiry'] as String),
      licenseClass: json['license_class'] as String?,
      yearsOfExperience: (json['years_of_experience'] as num?)?.toInt(),
      status: $enumDecode(_$ApprovalStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$DriverResponseToJson(_DriverResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'license_number': instance.licenseNumber,
      'license_expiry': instance.licenseExpiry.toIso8601String(),
      'license_class': ?instance.licenseClass,
      'years_of_experience': ?instance.yearsOfExperience,
      'status': _$ApprovalStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$ApprovalStatusEnumMap = {
  ApprovalStatus.pending: 'pending',
  ApprovalStatus.underReview: 'under_review',
  ApprovalStatus.approved: 'approved',
  ApprovalStatus.rejected: 'rejected',
  ApprovalStatus.suspended: 'suspended',
  ApprovalStatus.expired: 'expired',
};
