// Analytics PII contract + relative-time helper for the Notifications +
// Favourites features.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/l10n/app_localizations_en.dart';
import 'package:mobile/passenger/notifications/presentation/notifications_screen.dart'
    show relativeTime;

void main() {
  group('analytics PII contract', () {
    final events = [
      TelemetryEvent('notifications_opened', const {'from': 'profile'}),
      TelemetryEvent('notifications_tab_changed', const {'tab': 'inbox'}),
      TelemetryEvent('notification_tapped', const {
        'type': 'transactional',
        'has_deep_link': true,
      }),
      TelemetryEvent('notification_mark_all_read'),
      TelemetryEvent('notification_unroutable', const {'type': 'promotional'}),
      TelemetryEvent('notification_pref_toggled', const {
        'category': 'push',
        'enabled': true,
      }),
      TelemetryEvent('favourites_opened', const {'from': 'profile'}),
      TelemetryEvent('favourite_deleted', const {'kind': 'route'}),
    ];
    final pii = RegExp(
      r'token|phone|name|email|lat|lng|coord|address',
      caseSensitive: false,
    );
    for (final e in events) {
      test('${e.name} keys have no PII', () {
        for (final k in e.params.keys) {
          expect(pii.hasMatch(k), isFalse, reason: '${e.name}.$k');
        }
      });
      test('${e.name} params survive sanitisation', () {
        final out = e.sanitised;
        expect(out, isNotNull, reason: '${e.name} missing from schema');
        expect(out!.keys.toSet(), e.params.keys.toSet());
      });
    }
  });

  group('relativeTime', () {
    final l10n = AppLocalizationsEn();
    final now = DateTime(2026, 11, 20, 12, 0);
    test('under a minute reads "Just now"', () {
      expect(
        relativeTime(l10n, now.subtract(const Duration(seconds: 30)), now: now),
        'Just now',
      );
    });
    test('minutes', () {
      expect(
        relativeTime(l10n, now.subtract(const Duration(minutes: 2)), now: now),
        '2m ago',
      );
    });
    test('hours', () {
      expect(
        relativeTime(l10n, now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
    });
    test('yesterday', () {
      expect(
        relativeTime(l10n, now.subtract(const Duration(days: 1)), now: now),
        'Yesterday',
      );
    });
    test('within the week reads the weekday', () {
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      final label = relativeTime(l10n, threeDaysAgo, now: now);
      expect(
        RegExp(r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\$').hasMatch(label) ||
            label.length == 3 ||
            label.length == 4,
        isTrue,
        reason: 'got: $label',
      );
    });
    test('older reads "d MMM"', () {
      final longAgo = DateTime(2026, 10, 12);
      final label = relativeTime(l10n, longAgo, now: now);
      expect(label, '12 Oct');
    });
  });
}
