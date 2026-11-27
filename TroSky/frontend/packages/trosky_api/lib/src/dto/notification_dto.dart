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

/// `NotificationResponse`. [deepLink] is now a first-class backend
/// field (step 21/close-stubs-C); [data] retains free-form routing
/// hints for older clients. Treat both as untrusted — never render
/// raw values.
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
    this.deepLink,
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

  /// Backend-shaped routing hint, e.g. `/bookings/{id}`, `/wallet`,
  /// `/profile`, `/search?origin_stop_id=...`. Null when the backend
  /// has no suggestion for the client — fall back to [data].
  final String? deepLink;

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
        deepLink: json['deep_link'] as String?,
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
    if (deepLink != null) 'deep_link': deepLink,
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
/// `GET /users/me/notification-preferences`. Channel toggles (push /
/// SMS / email + `promotionalOptIn`) plus category toggles
/// (booking / payment / promotions). [safetyEnabled] and
/// [accountEnabled] are reported but **always true** on the backend
/// ("safety notifications can't be turned off"); the UI surfaces
/// them as read-only indicators, not toggles.
class NotificationPreferencesResponse {
  const NotificationPreferencesResponse({
    required this.pushEnabled,
    required this.smsEnabled,
    required this.emailEnabled,
    required this.bookingUpdatesEnabled,
    required this.paymentEnabled,
    required this.promotionsEnabled,
    required this.promotionalOptIn,
    this.safetyEnabled = true,
    this.accountEnabled = true,
  });

  final bool pushEnabled;
  final bool smsEnabled;
  final bool emailEnabled;
  final bool bookingUpdatesEnabled;
  final bool paymentEnabled;
  final bool promotionsEnabled;
  final bool safetyEnabled;
  final bool accountEnabled;

  /// Deprecated on the backend in favour of [promotionsEnabled]; kept
  /// so an older client still parses the field.
  final bool promotionalOptIn;

  factory NotificationPreferencesResponse.fromJson(Map<String, dynamic> json) =>
      NotificationPreferencesResponse(
        pushEnabled: json['push_enabled'] as bool,
        smsEnabled: json['sms_enabled'] as bool,
        emailEnabled: json['email_enabled'] as bool,
        bookingUpdatesEnabled: json['booking_updates_enabled'] as bool? ?? true,
        paymentEnabled: json['payment_enabled'] as bool? ?? true,
        promotionsEnabled:
            json['promotions_enabled'] as bool? ??
            (json['promotional_opt_in'] as bool? ?? false),
        promotionalOptIn: json['promotional_opt_in'] as bool? ?? false,
        safetyEnabled: json['safety_enabled'] as bool? ?? true,
        accountEnabled: json['account_enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'push_enabled': pushEnabled,
    'sms_enabled': smsEnabled,
    'email_enabled': emailEnabled,
    'booking_updates_enabled': bookingUpdatesEnabled,
    'payment_enabled': paymentEnabled,
    'promotions_enabled': promotionsEnabled,
    'safety_enabled': safetyEnabled,
    'account_enabled': accountEnabled,
    'promotional_opt_in': promotionalOptIn,
  };
}

/// `PATCH /users/me/notification-preferences`. "Send only the
/// switches that change" — every field is optional. `safety_enabled`
/// and `account_enabled` are omitted here: the backend rejects
/// attempts to turn them off.
class NotificationPreferencesUpdateRequest {
  const NotificationPreferencesUpdateRequest({
    this.pushEnabled,
    this.smsEnabled,
    this.emailEnabled,
    this.bookingUpdatesEnabled,
    this.paymentEnabled,
    this.promotionsEnabled,
    this.promotionalOptIn,
  });

  final bool? pushEnabled;
  final bool? smsEnabled;
  final bool? emailEnabled;
  final bool? bookingUpdatesEnabled;
  final bool? paymentEnabled;
  final bool? promotionsEnabled;
  final bool? promotionalOptIn;

  Map<String, dynamic> toJson() => {
    if (pushEnabled != null) 'push_enabled': pushEnabled,
    if (smsEnabled != null) 'sms_enabled': smsEnabled,
    if (emailEnabled != null) 'email_enabled': emailEnabled,
    if (bookingUpdatesEnabled != null)
      'booking_updates_enabled': bookingUpdatesEnabled,
    if (paymentEnabled != null) 'payment_enabled': paymentEnabled,
    if (promotionsEnabled != null) 'promotions_enabled': promotionsEnabled,
    if (promotionalOptIn != null) 'promotional_opt_in': promotionalOptIn,
  };
}
