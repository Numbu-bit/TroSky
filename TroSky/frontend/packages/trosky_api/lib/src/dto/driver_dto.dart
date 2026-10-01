// `GET /drivers/me`, field for field as in backend/app/schemas/driver.py.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'driver_dto.freezed.dart';
part 'driver_dto.g.dart';

/// `ApprovalStatus` (backend/app/models/drivers.py), shared by drivers and
/// vehicles.
@JsonEnum(fieldRename: FieldRename.snake)
enum ApprovalStatus {
  pending,
  underReview,
  approved,
  rejected,
  suspended,
  expired,
}

/// `DriverResponse`: the driver profile created by `POST /drivers/me`.
@freezed
abstract class DriverResponse with _$DriverResponse {
  const factory DriverResponse({
    required String id,
    required String userId,
    required String licenseNumber,
    required DateTime licenseExpiry,
    String? licenseClass,
    int? yearsOfExperience,
    required ApprovalStatus status,
    required DateTime createdAt,
  }) = _DriverResponse;

  factory DriverResponse.fromJson(Map<String, dynamic> json) =>
      _$DriverResponseFromJson(json);
}
