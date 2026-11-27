// Deep-link router (step 21/close-stubs-C): every supported shape
// gets a fixture and asserts the route path pattern it maps to;
// unknown shapes return null so the tap handler can emit
// `notification_unroutable` with a slot-replaced pattern.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/notifications/application/notification_router.dart';
import 'package:trosky_api/trosky_api.dart';

NotificationResponse _n({
  required String link,
  NotificationCategory category = NotificationCategory.transactional,
}) => NotificationResponse(
  id: 'id',
  category: category,
  title: '',
  body: '',
  isRead: false,
  createdAt: DateTime(2026, 1, 1),
  deepLink: link,
);

void main() {
  group('resolve — supported shapes', () {
    test('/bookings/{id} → bookingDetails', () {
      final r = NotificationRouter.resolve(
        _n(link: '/bookings/85dc74e8-d8d2-411a-8d8d-33cdbf98da9b'),
        trackingEnabled: true,
      );
      expect(r?.routeName, 'bookingDetails');
      expect(r?.pathParameters['bookingId'], isNotNull);
      expect(r?.pathPattern, '/bookings/{id}');
      expect(r?.useGo, isFalse);
    });

    test('/trips/{id}/track with tracking on → trips tab (useGo)', () {
      final r = NotificationRouter.resolve(
        _n(link: '/trips/deadbeef/track'),
        trackingEnabled: true,
      );
      expect(r?.routeName, 'trips');
      expect(r?.pathPattern, '/trips/{id}/track');
      expect(r?.useGo, isTrue);
    });

    test('/trips/{id}/track with tracking off → null (fallback)', () {
      final r = NotificationRouter.resolve(
        _n(link: '/trips/deadbeef/track'),
        trackingEnabled: false,
      );
      expect(r, isNull);
    });

    test('/wallet → wallet tab', () {
      final r = NotificationRouter.resolve(
        _n(link: '/wallet'),
        trackingEnabled: true,
      );
      expect(r?.routeName, 'wallet');
      expect(r?.pathPattern, '/wallet');
      expect(r?.useGo, isTrue);
    });

    test('/wallet/transactions/{id} → wallet tab (pattern distinguishes)', () {
      final r = NotificationRouter.resolve(
        _n(link: '/wallet/transactions/abc123def'),
        trackingEnabled: true,
      );
      expect(r?.routeName, 'wallet');
      expect(r?.pathPattern, '/wallet/transactions/{id}');
    });

    test('/profile → profile tab', () {
      final r = NotificationRouter.resolve(
        _n(link: '/profile'),
        trackingEnabled: true,
      );
      expect(r?.routeName, 'profile');
      expect(r?.useGo, isTrue);
    });

    test('/search → search screen', () {
      final r = NotificationRouter.resolve(
        _n(link: '/search?origin_stop_id=abc&destination_stop_id=def'),
        trackingEnabled: true,
      );
      expect(r?.routeName, 'search');
    });

    test(
      '/sos/{id} in safety category → sosAlert; transactional returns null',
      () {
        final safety = NotificationRouter.resolve(
          _n(
            link: '/sos/fe9f1b00-abcd-4b7c-bde8-01020304abcd',
            category: NotificationCategory.safety,
          ),
          trackingEnabled: true,
        );
        expect(safety?.routeName, 'sosAlert');
        expect(safety?.pathPattern, '/sos/{alert_id}');

        final trans = NotificationRouter.resolve(
          _n(
            link: '/sos/fe9f1b00-abcd-4b7c-bde8-01020304abcd',
            category: NotificationCategory.transactional,
          ),
          trackingEnabled: true,
        );
        expect(trans, isNull);
      },
    );
  });

  group('resolve — unknown shapes return null + patternOf slot-replaces', () {
    test('unknown prefix returns null', () {
      final r = NotificationRouter.resolve(
        _n(link: '/pigeons/9'),
        trackingEnabled: true,
      );
      expect(r, isNull);
    });

    test('patternOf masks uuids and numeric ids', () {
      expect(
        NotificationRouter.patternOf(
          '/pigeons/85dc74e8-d8d2-411a-8d8d-33cdbf98da9b',
        ),
        '/pigeons/{id}',
      );
      expect(NotificationRouter.patternOf('/bookings/42'), '/bookings/{id}');
      expect(
        NotificationRouter.patternOf('/pigeons/wallet/123'),
        '/pigeons/wallet/{id}',
      );
    });

    test('patternOf handles empty + invalid', () {
      expect(NotificationRouter.patternOf(null), 'empty');
      expect(NotificationRouter.patternOf(''), 'empty');
      expect(NotificationRouter.patternOf('::not-a-uri::'), 'invalid');
    });
  });
}
