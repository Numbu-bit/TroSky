// Pure unit tests for the rate-banner eligibility rule.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/trips/data/rate_banner_cache.dart';

void main() {
  final now = DateTime(2026, 11, 21, 12);

  group('rateBannerEligible', () {
    test('a non-completed booking never shows the banner', () {
      expect(
        rateBannerEligible(
          completed: false,
          completedAt: now.subtract(const Duration(hours: 1)),
          dismissedAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('a completed booking within 7 days with no dismiss shows it', () {
      expect(
        rateBannerEligible(
          completed: true,
          completedAt: now.subtract(const Duration(hours: 1)),
          dismissedAt: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('a completed booking older than 7 days never shows', () {
      expect(
        rateBannerEligible(
          completed: true,
          completedAt: now.subtract(const Duration(days: 8)),
          dismissedAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('a dismissal less than 1 day ago hides the banner', () {
      expect(
        rateBannerEligible(
          completed: true,
          completedAt: now.subtract(const Duration(hours: 2)),
          dismissedAt: now.subtract(const Duration(hours: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a dismissal 1 day+ ago re-shows the banner', () {
      expect(
        rateBannerEligible(
          completed: true,
          completedAt: now.subtract(const Duration(days: 3)),
          dismissedAt: now.subtract(const Duration(days: 1, hours: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('completedAt null (no trip summary) never shows', () {
      expect(
        rateBannerEligible(
          completed: true,
          completedAt: null,
          dismissedAt: null,
          now: now,
        ),
        isFalse,
      );
    });
  });
}
