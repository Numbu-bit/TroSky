// Providers for the Notifications inbox + preferences + bell badge.
// Wire the live NotificationRepository through trosky_auth's envProvider
// and apiClientProvider, matching the pattern of other repositories.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

/// `/notifications/*`. Only wired for live mode today; mock mode shows
/// an empty inbox (the mock backend has no notifications seed).
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => switch (ref.watch(envProvider).apiMode) {
    ApiMode.live => LiveNotificationRepository(ref.watch(apiClientProvider)),
    ApiMode.mock => _EmptyNotifications(),
  },
);

/// `GET /notifications` first page for the Inbox.
final notificationsInboxProvider =
    FutureProvider<Result<Paginated<NotificationResponse>>>((ref) {
      return ref.read(notificationRepositoryProvider).list(limit: 20);
    });

/// `GET /notifications/unread-count` for the Home bell badge. Refresh
/// after mark-read or mark-all-read.
final unreadCountProvider = FutureProvider<Result<UnreadCountResponse>>((ref) {
  return ref.read(notificationRepositoryProvider).unreadCount();
});

/// `GET /users/me/notification-preferences` — channel-level toggles.
final notificationPreferencesProvider =
    FutureProvider<Result<NotificationPreferencesResponse>>((ref) {
      return ref.read(userRepositoryProvider).notificationPreferences();
    });

class _EmptyNotifications implements NotificationRepository {
  @override
  Future<Result<Paginated<NotificationResponse>>> list({
    bool unreadOnly = false,
    int limit = 20,
    int offset = 0,
  }) async =>
      Ok(Paginated(items: const [], total: 0, limit: limit, offset: offset));

  @override
  Future<Result<UnreadCountResponse>> unreadCount() async =>
      const Ok(UnreadCountResponse(unreadCount: 0));

  @override
  Future<Result<NotificationResponse>> markRead(String notificationId) async =>
      const Err(
        UnknownFailure(
          code: 'NOT_IMPLEMENTED',
          message: 'Notifications are empty in mock mode.',
        ),
      );

  @override
  Future<Result<MarkAllReadResponse>> markAllRead() async =>
      const Ok(MarkAllReadResponse(markedRead: 0));
}
