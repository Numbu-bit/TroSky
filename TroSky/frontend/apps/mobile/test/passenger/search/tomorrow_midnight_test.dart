import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/passenger/search/presentation/search_results_screen.dart';

void main() {
  group('tomorrowMidnightLocal', () {
    test('late evening local time → next local day at 00:00', () {
      // Africa/Accra is UTC+0, so local == UTC on staging.
      final now = DateTime(2026, 11, 15, 22, 47);
      final tomorrow = tomorrowMidnightLocal(now);
      expect(tomorrow, DateTime(2026, 11, 16));
      expect(tomorrow.isUtc, isFalse);
      expect(tomorrow.hour, 0);
      expect(tomorrow.minute, 0);
    });

    test('a few minutes before local midnight still returns the next day', () {
      final now = DateTime(2026, 11, 15, 23, 59, 30);
      expect(tomorrowMidnightLocal(now), DateTime(2026, 11, 16));
    });

    test('rolls the month over at month end', () {
      final now = DateTime(2026, 11, 30, 23, 15);
      expect(tomorrowMidnightLocal(now), DateTime(2026, 12, 1));
    });

    test('rolls the year over on 31 Dec', () {
      final now = DateTime(2026, 12, 31, 22, 0);
      expect(tomorrowMidnightLocal(now), DateTime(2027, 1, 1));
    });

    test('a UTC input is normalised to the local day', () {
      // 22:30 UTC on 15 Nov. In Accra (UTC+0) that's still 15 Nov, so
      // tomorrow is 16 Nov at local midnight.
      final utcNow = DateTime.utc(2026, 11, 15, 22, 30);
      expect(tomorrowMidnightLocal(utcNow), DateTime(2026, 11, 16));
    });
  });
}
