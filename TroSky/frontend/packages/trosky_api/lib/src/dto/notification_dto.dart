// `/notifications/*` DTOs. Written as plain classes (not freezed) so
// this file doesn't need codegen; the surface is small and read-mostly,
// so the freezed amenities aren't worth another build_runner cycle.

/// `NotificationCategory` (backend/app/models/notifications.py). Three
/// values today: the brief's finer taxonomy (booking/payment/account) is
/// a backend ask; map by the `data` dict's hints until then.
enum NotificationCategory {
  transactional('transactional'),
  safety('safety'),
  promotional('promotional');

  const NotificationCategory(this.wire);
  final String wire;

  static NotificationCategory fromWire(String value) {
    for (final c in values) {
      if (c.wire == value) return c;
    }
    return NotificationCategory.transactional;
  }
}

/// `NotificationResponse`. The backend doesn't expose a dedicated
/// `deep_link` field; routing hints live inside [data] (a free-form
/// JSON blob). Treat [data] as untrusted — never render raw values.
class NotificationResponse {
  const NotificationResponse({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    this.data = const {},
    this.channelResults = const {},
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final Map<String, dynamic> channelResults;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  factory NotificationResponse.fromJson(Map<String, dynamic> json) =>
      NotificationResponse(
        id: json['id'] as String,
        category: NotificationCategory.fromWire(json['category'] as String),
        title: json['title'] as String,
        body: json['body'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
        channelResults: Map<String, dynamic>.from(
          json['channel_results'] as Map? ?? const {},
        ),
        isRead: json['is_read'] as bool,
        readAt: json['read_at'] == null
            ? null
            : DateTime.parse(json['read_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.wire,
    'title': title,
    'body': body,
    'data': data,
    'channel_results': channelResults,
    'is_read': isRead,
    if (readAt != null) 'read_at': readAt!.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

/// `GET /notifications/unread-count` — cheap endpoint for the bell badge.
class UnreadCountResponse {
  const UnreadCountResponse({required this.unreadCount});
  final int unreadCount;

  factory UnreadCountResponse.fromJson(Map<String, dynamic> json) =>
      UnreadCountResponse(unreadCount: json['unread_count'] as int);

  Map<String, dynamic> toJson() => {'unread_count': unreadCount};
}

/// `POST /notifications/read-all` — [markedRead] is how many were unread.
class MarkAllReadResponse {
  const MarkAllReadResponse({required this.markedRead});
  final int markedRead;

  factory MarkAllReadResponse.fromJson(Map<String, dynamic> json) =>
      MarkAllReadResponse(markedRead: json['marked_read'] as int);

  Map<String, dynamic> toJson() => {'marked_read': markedRead};
}

/// `NotificationPreferencesResponse` from
/// `GET /users/me/notification-preferences`. These are **channel-level**
/// opt-outs (push / SMS / email) + a promotional opt-out. The brief's
/// category-level taxonomy (booking_updates/safety/payment/…) would
/// need a backend change; filed as a gap.
class NotificationPreferencesResponse {
  const NotificationPreferencesResponse({
    required this.pushEnabled,
    required this.smsEnabled,
    required this.emailEnabled,
    required this.promotionalOptIn,
  });

  final bool pushEnabled;
  final bool smsEnabled;
  final bool emailEnabled;
  final bool promotionalOptIn;

  factory NotificationPreferencesResponse.fromJson(Map<String, dynamic> json) =>
      NotificationPreferencesResponse(
        pushEnabled: json['push_enabled'] as bool,
        smsEnabled: json['sms_enabled'] as bool,
        emailEnabled: json['email_enabled'] as bool,
        promotionalOptIn: json['promotional_opt_in'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'push_enabled': pushEnabled,
    'sms_enabled': smsEnabled,
    'email_enabled': emailEnabled,
    'promotional_opt_in': promotionalOptIn,
  };
}

/// `PATCH /users/me/notification-preferences`. Any field left out keeps
/// its value.
class NotificationPreferencesUpdateRequest {
  const NotificationPreferencesUpdateRequest({
    this.pushEnabled,
    this.smsEnabled,
    this.emailEnabled,
    this.promotionalOptIn,
  });

  final bool? pushEnabled;
  final bool? smsEnabled;
  final bool? emailEnabled;
  final bool? promotionalOptIn;

  Map<String, dynamic> toJson() => {
    if (pushEnabled != null) 'push_enabled': pushEnabled,
    if (smsEnabled != null) 'sms_enabled': smsEnabled,
    if (emailEnabled != null) 'email_enabled': emailEnabled,
    if (promotionalOptIn != null) 'promotional_opt_in': promotionalOptIn,
  };
}
