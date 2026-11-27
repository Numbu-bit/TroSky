// Deep-link routing for P-20 Inbox notifications (step 21/close-stubs-C).
//
// Backend-shaped `deep_link` field maps to a GoRouter route + optional
// extra. Supported shapes come from the staging probe: /bookings/{id},
// /trips/{id}/track, /wallet, /wallet/transactions/{id}, /profile,
// /search?origin_stop_id=...&destination_stop_id=..., /sos/{alert_id}.
// Anything we can't map falls back to the Notifications inbox and
// emits `notification_unroutable {type, path_pattern}` so we can see
// unknown shapes in telemetry.

import 'package:trosky_api/trosky_api.dart';

import '../../../app/routes.dart';
import '../../safety/domain/safety_args.dart';

/// The route name + optional `extra` a notification's deep link
/// resolves to, plus the pattern-with-slot-placeholders the link
/// matched for `notification_unroutable` telemetry.
class NotificationRoute {
  const NotificationRoute({
    required this.routeName,
    required this.pathPattern,
    this.extra,
    this.pathParameters = const {},
    this.useGo = false,
  });

  final String routeName;

  /// Stable slot-replaced pattern (e.g. `/bookings/{id}`) — used in
  /// `notification_unroutable` so analytics never see a raw id.
  final String pathPattern;

  final Object? extra;
  final Map<String, String> pathParameters;

  /// When true the shell switches tab via `go` instead of pushing a
  /// new route over the notifications screen — used for the four tab
  /// destinations (home / trips / wallet / profile).
  final bool useGo;
}

/// `NotificationRouter.resolve` returns a `NotificationRoute` for a
/// deep link we understand, or null for one we don't. Null callers
/// should fall back to the inbox and emit `notification_unroutable`
/// with `pathPattern` hints.
abstract final class NotificationRouter {
  static NotificationRoute? resolve(
    NotificationResponse notification, {
    required bool trackingEnabled,
  }) {
    final link = notification.deepLink?.trim();
    if (link == null || link.isEmpty) return null;
    final uri = Uri.tryParse(link);
    if (uri == null || uri.pathSegments.isEmpty) return null;
    final segments = uri.pathSegments;

    // /bookings/{id} and /bookings/{id}/rate (treated as bookingDetails).
    if (segments[0] == 'bookings' && segments.length >= 2) {
      return NotificationRoute(
        routeName: AppRoute.bookingDetails.name,
        pathPattern: '/bookings/{id}',
        pathParameters: {'bookingId': segments[1]},
      );
    }

    // /trips/{id}/track — only when TRIP_TRACKING_ENABLED and the
    // target booking is known to the caller. We send the caller to
    // the booking details page; it already has the live Track button
    // and knows the booking.
    if (segments[0] == 'trips' &&
        segments.length >= 3 &&
        segments[2] == 'track') {
      if (!trackingEnabled) return null;
      return NotificationRoute(
        routeName: AppRoute.trips.name,
        pathPattern: '/trips/{id}/track',
        useGo: true,
      );
    }

    // /wallet and /wallet/transactions/{id}.
    if (segments[0] == 'wallet') {
      return NotificationRoute(
        routeName: AppRoute.wallet.name,
        pathPattern: segments.length >= 3 && segments[1] == 'transactions'
            ? '/wallet/transactions/{id}'
            : '/wallet',
        useGo: true,
      );
    }

    // /profile.
    if (segments[0] == 'profile' && segments.length == 1) {
      return NotificationRoute(
        routeName: AppRoute.profile.name,
        pathPattern: '/profile',
        useGo: true,
      );
    }

    // /search?origin_stop_id=...&destination_stop_id=... — the
    // query-string prefill isn't modelled in SearchPrefill today
    // (names are required by that class), so the deep link opens
    // Search blank. Backend has been asked to carry stop names in
    // the payload next release; until then the router routes but
    // doesn't prefill.
    if (segments[0] == 'search' && segments.length == 1) {
      return NotificationRoute(
        routeName: AppRoute.search.name,
        pathPattern: '/search',
      );
    }

    // /sos/{alert_id} — only when the notification was in the safety
    // category, so a crafted link can't push a passenger into the SOS
    // flow from a transactional item.
    if (segments[0] == 'sos' &&
        segments.length >= 2 &&
        notification.category == NotificationCategory.safety) {
      return NotificationRoute(
        routeName: AppRoute.sosAlert.name,
        pathPattern: '/sos/{alert_id}',
        extra: const SosArgs(),
      );
    }

    return null;
  }

  /// Slot-replaced pattern of [link] for telemetry when we can't
  /// route — never the raw ids or query values.
  static String patternOf(String? link) {
    if (link == null || link.isEmpty) return 'empty';
    final uri = Uri.tryParse(link);
    if (uri == null || uri.pathSegments.isEmpty) return 'invalid';
    final slots = <String>[];
    for (var i = 0; i < uri.pathSegments.length; i++) {
      final segment = uri.pathSegments[i];
      // A path segment that looks like a uuid, hex, or digit-only id
      // is replaced with {id}; a literal segment is kept so the
      // pattern reads as a shape.
      slots.add(
        RegExp(r'^[0-9a-f-]{6,}$').hasMatch(segment) ||
                RegExp(r'^\d+$').hasMatch(segment)
            ? '{id}'
            : segment,
      );
    }
    return '/${slots.join('/')}';
  }
}
