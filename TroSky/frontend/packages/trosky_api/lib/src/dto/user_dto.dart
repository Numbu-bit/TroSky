// `GET /users/me`, field for field as in backend/app/schemas/user.py.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_dto.freezed.dart';
part 'user_dto.g.dart';

/// `UserProfileResponse`.
@freezed
abstract class UserProfileResponse with _$UserProfileResponse {
  const factory UserProfileResponse({
    required String fullName,
    DateTime? dateOfBirth,
    String? gender,
    required String preferredLanguage,
    String? avatarUrl,
    String? ghanaCardNumber,
    required bool ghanaCardVerified,
  }) = _UserProfileResponse;

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) =>
      _$UserProfileResponseFromJson(json);
}

/// `UserResponse`. [roles] are role slugs such as `passenger`, `driver`,
/// `fleet_owner`.
@freezed
abstract class UserResponse with _$UserResponse {
  const factory UserResponse({
    required String id,
    required String phoneNumber,
    String? email,
    required bool isActive,
    required bool phoneVerified,
    required bool emailVerified,
    required List<String> roles,
    required DateTime createdAt,
    UserProfileResponse? profile,
  }) = _UserResponse;

  factory UserResponse.fromJson(Map<String, dynamic> json) =>
      _$UserResponseFromJson(json);
}
