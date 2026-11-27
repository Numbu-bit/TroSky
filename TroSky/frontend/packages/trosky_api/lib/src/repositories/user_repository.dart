import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
import '../dto/auth_dto.dart';
import '../dto/favourite_place_dto.dart';
import '../dto/notification_dto.dart';
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

  /// `POST /users/me/change-password` — rotate this account's password.
  /// 401 `INVALID_CREDENTIALS` when the current password is wrong; 409
  /// `PASSWORD_UNCHANGED` when the new one is the same; 409
  /// `PASSWORD_POLICY_VIOLATION` when it is too weak. [idempotencyKey]
  /// de-dupes retries of the same attempt on the server. On success
  /// every OTHER session is signed out; this one stays.
  Future<Result<MessageResponse>> changePassword(
    ChangePasswordRequest request, {
    required String idempotencyKey,
  });

  /// `POST /users/me/change-email` — start changing the account email.
  /// The current address stays in use until [confirmEmailChange]. 401
  /// `INVALID_CREDENTIALS`; 409 `EMAIL_UNCHANGED` /
  /// `EMAIL_ALREADY_REGISTERED`; 422 `EMAIL_DOMAIN_NOT_ALLOWED`; 429
  /// inside the resend cooldown. [idempotencyKey] de-dupes retries.
  Future<Result<EmailChangeStartedResponse>> changeEmail(
    ChangeEmailRequest request, {
    required String idempotencyKey,
  });

  /// `POST /users/me/change-email/confirm` — finish an email change
  /// started by [changeEmail], with the OTP sent to the new address.
  /// Wrong, expired or used codes answer as `POST /auth/verify-otp` does.
  Future<Result<UserResponse>> confirmEmailChange(
    ChangeEmailConfirmRequest request,
  );

  /// `DELETE /users/me` — soft-deletes the account. The backend signs
  /// every session out; local secure storage must be wiped after.
  Future<Result<MessageResponse>> deleteAccount(AccountDeletionRequest request);

  /// `DELETE /users/me/favourite-routes/{id}` — forget a pinned
  /// commute route. The list order is by `createdAt`.
  Future<Result<void>> deleteFavouriteRoute(String favouriteId);

  /// `GET /users/me/favourite-places` — saved places (Home / Work /
  /// Custom). Newest first by `createdAt`.
  Future<Result<List<FavouritePlaceResponse>>> listFavouritePlaces();

  /// `POST /users/me/favourite-places` — add a place. The backend
  /// enforces "at most one home" and "at most one work"; set a
  /// matching kind again to replace the earlier one, on the backend.
  Future<Result<FavouritePlaceResponse>> addFavouritePlace(
    FavouritePlaceCreateRequest request,
  );

  /// `PATCH /users/me/favourite-places/{id}` — edit label (custom
  /// places). Backend ignores attempts to rename Home/Work.
  Future<Result<FavouritePlaceResponse>> updateFavouritePlace(
    String placeId,
    FavouritePlaceUpdateRequest request,
  );

  /// `DELETE /users/me/favourite-places/{id}`.
  Future<Result<void>> deleteFavouritePlace(String placeId);

  /// `GET /users/me/notification-preferences` — channel-level opt-outs
  /// (push / SMS / email + promotional). Category-level preferences
  /// (booking/safety/payment) are a backend ask as of Step 20/B.
  Future<Result<NotificationPreferencesResponse>> notificationPreferences();

  /// `PATCH /users/me/notification-preferences`.
  Future<Result<NotificationPreferencesResponse>> updateNotificationPreferences(
    NotificationPreferencesUpdateRequest request,
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

  @override
  Future<Result<UserResponse>> updateMe(UserProfileUpdateRequest request) =>
      apiCall(
        () => _dio.patch<Object?>('/users/me', data: request.toJson()),
        (data) => UserResponse.fromJson(jsonObject(data)),
      );

  @override
  Future<Result<MessageResponse>> changePassword(
    ChangePasswordRequest request, {
    required String idempotencyKey,
  }) => apiCall(
    () => _dio.post<Object?>(
      '/users/me/change-password',
      data: request.toJson(),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
    (data) => MessageResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<EmailChangeStartedResponse>> changeEmail(
    ChangeEmailRequest request, {
    required String idempotencyKey,
  }) => apiCall(
    () => _dio.post<Object?>(
      '/users/me/change-email',
      data: request.toJson(),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
    (data) => EmailChangeStartedResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<UserResponse>> confirmEmailChange(
    ChangeEmailConfirmRequest request,
  ) => apiCall(
    () => _dio.post<Object?>(
      '/users/me/change-email/confirm',
      data: request.toJson(),
    ),
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

  @override
  Future<Result<void>> deleteFavouriteRoute(String favouriteId) => apiCall(
    () => _dio.delete<Object?>('/users/me/favourite-routes/$favouriteId'),
    (_) {},
  );

  @override
  Future<Result<List<FavouritePlaceResponse>>> listFavouritePlaces() => apiCall(
    () => _dio.get<Object?>('/users/me/favourite-places'),
    (data) => [
      for (final p in (data as List? ?? const []))
        FavouritePlaceResponse.fromJson(jsonObject(p)),
    ],
  );

  @override
  Future<Result<FavouritePlaceResponse>> addFavouritePlace(
    FavouritePlaceCreateRequest request,
  ) => apiCall(
    () => _dio.post<Object?>(
      '/users/me/favourite-places',
      data: request.toJson(),
    ),
    (data) => FavouritePlaceResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<FavouritePlaceResponse>> updateFavouritePlace(
    String placeId,
    FavouritePlaceUpdateRequest request,
  ) => apiCall(
    () => _dio.patch<Object?>(
      '/users/me/favourite-places/$placeId',
      data: request.toJson(),
    ),
    (data) => FavouritePlaceResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<void>> deleteFavouritePlace(String placeId) => apiCall(
    () => _dio.delete<Object?>('/users/me/favourite-places/$placeId'),
    (_) {},
  );

  @override
  Future<Result<NotificationPreferencesResponse>> notificationPreferences() =>
      apiCall(
        () => _dio.get<Object?>('/users/me/notification-preferences'),
        (data) => NotificationPreferencesResponse.fromJson(jsonObject(data)),
      );

  @override
  Future<Result<NotificationPreferencesResponse>> updateNotificationPreferences(
    NotificationPreferencesUpdateRequest request,
  ) => apiCall(
    () => _dio.patch<Object?>(
      '/users/me/notification-preferences',
      data: request.toJson(),
    ),
    (data) => NotificationPreferencesResponse.fromJson(jsonObject(data)),
  );
}
