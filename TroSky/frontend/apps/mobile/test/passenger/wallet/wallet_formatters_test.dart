// Pure unit tests for the wallet feature: currency formatter, analytics
// payload PII contract, and an idempotency-key stability check.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/passenger/wallet/presentation/wallet_screen.dart'
    show formatCurrencyGhs;
import 'package:trosky_api/trosky_api.dart' show uuidV4;

void main() {
  group('formatCurrencyGhs', () {
    test('formats whole amounts with thousands separator', () {
      expect(formatCurrencyGhs('1234.50'), '₵1,234.50');
    });
    test('formats small amounts', () {
      expect(formatCurrencyGhs('11.50'), '₵11.50');
    });
    test('handles a zero cleanly', () {
      expect(formatCurrencyGhs('0'), '₵0.00');
    });
    test('handles bad input as zero rather than throwing', () {
      expect(formatCurrencyGhs('not-a-number'), '₵0.00');
    });
  });

  group('analytics PII contract', () {
    final events = [
      TelemetryEvent('wallet_opened', {'from': 'tester'}),
      TelemetryEvent('wallet_payment_method_tapped', {'type': 'mtn_momo'}),
      TelemetryEvent('wallet_payment_method_set_default', {'type': 'mtn_momo'}),
      TelemetryEvent('wallet_payment_method_removed', {'type': 'mtn_momo'}),
      TelemetryEvent('wallet_add_method_opened'),
      TelemetryEvent('wallet_add_method_submitted', {'type': 'mtn_momo'}),
      TelemetryEvent('wallet_topup_opened'),
      TelemetryEvent('wallet_topup_preset_picked', {'amount': 100}),
      TelemetryEvent('wallet_topup_submitted', {'amount': 100.0}),
      TelemetryEvent('wallet_topup_success'),
      TelemetryEvent('wallet_topup_failed', {'reason': 'timeout'}),
      TelemetryEvent('wallet_transactions_expanded'),
      TelemetryEvent('wallet_transactions_collapsed'),
      TelemetryEvent('wallet_filter_changed', {'type': 'topUps'}),
      TelemetryEvent('wallet_transaction_opened', {'type': 'topUp'}),
    ];
    for (final e in events) {
      test('${e.name} keys have no PII', () {
        final pii = RegExp(
          r'token|phone|name|email|lat|lng|coord|address|number',
          caseSensitive: false,
        );
        for (final k in e.params.keys) {
          expect(pii.hasMatch(k), isFalse, reason: '${e.name}.$k');
        }
      });
      test('${e.name} sanitised does not drop declared keys', () {
        expect(e.sanitised.keys, e.params.keys);
      });
    }
  });

  group('uuidV4', () {
    test('produces v4-shaped strings (8-4-4-4-12)', () {
      final key = uuidV4();
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(key),
        isTrue,
        reason: 'got: $key',
      );
    });
    test('each call returns a different key (fresh attempt → new key)', () {
      expect(uuidV4() == uuidV4(), isFalse);
    });
  });
}
