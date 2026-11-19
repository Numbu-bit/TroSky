import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
import '../dto/auth_dto.dart';
import '../dto/user_dto.dart';

/// `/users/*` (backend/app/api/v1/users.py).
abstract interface class UserRepository {
  /// The signed-in user, with fresh roles.
  Future<Result<UserResponse>> getMe();

  /// Journeys pinned to Home, oldest first (backend gap G4).
  Future<Result<List<FavouriteRouteResponse>>> listFavouriteRoutes();

  /// Pins a journey. 409 `FAVOURITE_ROUTE_EXISTS` when it is pinned
  /// already, 409 `FAVOURITE_ROUTES_LIMIT` at 20.
  Future<Result<FavouriteRouteResponse>> addFavouriteRoute(
    FavouriteRouteCreateRequest request,
  );

  /// `PATCH /users/me` — name, DOB, gender, language, avatarUrl. Email
  /// and phone are not editable here; the backend has separate
  /// change-email / change-phone endpoints (gaps as of Step 20).
  Future<Result<UserResponse>> updateMe(UserProfileUpdateRequest request);

  /// `DELETE /users/me` — soft-deletes the account. The backend signs
  /// every session out; local secure storage must be wiped after.
  Future<Result<MessageResponse>> deleteAccount(AccountDeletionRequest request);
}

/// [UserRepository] against the backend.
class LiveUserRepository implements UserRepository {
  LiveUserRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<UserResponse>> getMe() => apiCall(
    () => _dio.get<Object?>('/users/me'),
    (data) => UserResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<List<FavouriteRouteResponse>>> listFavouriteRoutes() => apiCall(
    () => _dio.get<Object?>('/users/me/favourite-routes'),
    (data) => [
      for (final favourite in data! as List)
        FavouriteRouteResponse.fromJson(jsonObject(favourite)),
    ],
  );

  @override
  Future<Result<FavouriteRouteResponse>> addFavouriteRoute(
    FavouriteRouteCreateRequest request,
  ) => apiCall(
    () => _dio.post<Object?>(
      '/users/me/favourite-routes',
      data: request.toJson(),
    ),
    (data) => FavouriteRouteResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<UserResponse>> updateMe(UserProfileUpdateRequest request) =>
      apiCall(
        () => _dio.patch<Object?>('/users/me', data: request.toJson()),
        (data) => UserResponse.fromJson(jsonObject(data)),
      );

  @override
  Future<Result<MessageResponse>> deleteAccount(
    AccountDeletionRequest request,
  ) => apiCall(
    // Dio's delete accepts a body; the backend takes
    // AccountDeletionRequest { password, reason? }.
    () => _dio.delete<Object?>('/users/me', data: request.toJson()),
    (data) => MessageResponse.fromJson(jsonObject(data)),
  );
}
