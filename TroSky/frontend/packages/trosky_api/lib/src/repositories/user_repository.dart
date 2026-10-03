import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
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
}
