// Pure unit tests for the Account group: analytics payload PII contract
// + ProfileSection naming.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/passenger/account/domain/account_args.dart';

void main() {
  group('analytics PII contract', () {
    final events = [
      TelemetryEvent('profile_opened'),
      TelemetryEvent('profile_section_tapped', const {'section': 'wallet'}),
      TelemetryEvent('profile_signout_tapped'),
      TelemetryEvent('pii_edit_opened', const {'field': 'name'}),
      TelemetryEvent('pii_edit_submitted', const {'field': 'name'}),
      TelemetryEvent('pii_edit_failed', const {
        'field': 'name',
        'reason': 'network',
      }),
      TelemetryEvent('account_delete_opened'),
      TelemetryEvent('account_delete_confirmed'),
      TelemetryEvent('account_delete_failed', const {'reason': 'network'}),
      TelemetryEvent('password_reset_requested'),
      TelemetryEvent('password_reset_completed'),
    ];
    // Mirrors the live `TelemetryEvent._bannedKeys` sanitiser.
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

  group('profileSectionName', () {
    test('snake_cases each section', () {
      expect(profileSectionName(ProfileSection.personalInfo), 'personal_info');
      expect(
        profileSectionName(ProfileSection.changePassword),
        'change_password',
      );
      expect(
        profileSectionName(ProfileSection.paymentMethods),
        'payment_methods',
      );
      expect(profileSectionName(ProfileSection.helpCentre), 'help_centre');
    });
  });
}
