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

/// `FavouriteRouteCreateRequest` for `POST /users/me/favourite-routes`.
@freezed
abstract class FavouriteRouteCreateRequest with _$FavouriteRouteCreateRequest {
  const factory FavouriteRouteCreateRequest({
    required String originStopId,
    required String destinationStopId,
    String? label,
  }) = _FavouriteRouteCreateRequest;

  factory FavouriteRouteCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$FavouriteRouteCreateRequestFromJson(json);
}

/// `FavouriteRouteResponse` from `GET /users/me/favourite-routes` (backend
/// gap G4): a journey pinned to Home, from one stop to another.
@freezed
abstract class FavouriteRouteResponse with _$FavouriteRouteResponse {
  const factory FavouriteRouteResponse({
    required String id,
    required String originStopId,
    required String originStopName,
    required String destinationStopId,
    required String destinationStopName,

    /// The passenger's own name for it, e.g. "Home to work".
    String? label,
    required DateTime createdAt,
  }) = _FavouriteRouteResponse;

  factory FavouriteRouteResponse.fromJson(Map<String, dynamic> json) =>
      _$FavouriteRouteResponseFromJson(json);
}
