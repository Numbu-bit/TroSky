import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
import '../dto/notification_dto.dart';
import '../dto/paginated.dart';

/// `/notifications` (backend/app/api/v1/notifications.py).
abstract interface class NotificationRepository {
  /// `GET /notifications` paginated, newest first.
  Future<Result<Paginated<NotificationResponse>>> list({
    bool unreadOnly = false,
    int limit = 20,
    int offset = 0,
  });

  /// `GET /notifications/unread-count` — cheap endpoint for the bell badge.
  Future<Result<UnreadCountResponse>> unreadCount();

  /// `POST /notifications/{id}/read` — marks one item read.
  Future<Result<NotificationResponse>> markRead(String notificationId);

  /// `POST /notifications/read-all` — marks every unread item read.
  Future<Result<MarkAllReadResponse>> markAllRead();
}

class LiveNotificationRepository implements NotificationRepository {
  LiveNotificationRepository(this._dio);
  final Dio _dio;

  @override
  Future<Result<Paginated<NotificationResponse>>> list({
    bool unreadOnly = false,
    int limit = 20,
    int offset = 0,
  }) => apiCall(
    () => _dio.get<Object?>(
      '/notifications',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (unreadOnly) 'unread_only': true,
      },
    ),
    (data) =>
        Paginated.fromJson(jsonObject(data), NotificationResponse.fromJson),
  );

  @override
  Future<Result<UnreadCountResponse>> unreadCount() => apiCall(
    () => _dio.get<Object?>('/notifications/unread-count'),
    (data) => UnreadCountResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<NotificationResponse>> markRead(String notificationId) =>
      apiCall(
        () => _dio.post<Object?>('/notifications/$notificationId/read'),
        (data) => NotificationResponse.fromJson(jsonObject(data)),
      );

  @override
  Future<Result<MarkAllReadResponse>> markAllRead() => apiCall(
    () => _dio.post<Object?>('/notifications/read-all'),
    (data) => MarkAllReadResponse.fromJson(jsonObject(data)),
  );
}
