import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_core/trosky_core.dart';

void main() {
  // The cases in backend/tests/unit/test_phone_utilities.py.
  group('backend test examples', () {
    test('local Ghana format', () {
      expect(normalizePhoneNumber('0241234567'), '+233241234567');
    });
    test('already E.164', () {
      expect(normalizePhoneNumber('+233241234567'), '+233241234567');
    });
    test('spaces and dashes', () {
      expect(normalizePhoneNumber('024 123-4567'), '+233241234567');
    });
    test('rejects garbage', () {
      expect(
        () => normalizePhoneNumber('not-a-phone-number'),
        throwsA(isA<InvalidPhoneNumberException>()),
      );
    });
    test('rejects too short', () {
      expect(
        () => normalizePhoneNumber('123'),
        throwsA(isA<InvalidPhoneNumberException>()),
      );
    });
    test('explicit region', () {
      expect(normalizePhoneNumber('6502530000', region: 'US'), '+16502530000');
    });
  });

  test('accepts 024…, 24… and +233…', () {
    for (final input in ['0241234567', '241234567', '+233 24 123 4567']) {
      expect(tryNormalizePhoneNumber(input), '+233241234567', reason: input);
    }
  });

  // tool/phone_cases.py ran each input through the backend's
  // normalize_phone_number; the Dart side must give the same answer.
  test('matches the backend on every case in phone_cases.json', () {
    final cases =
        (jsonDecode(File('test/fixtures/phone_cases.json').readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>();
    expect(cases, hasLength(greaterThan(60)));
    for (final c in cases) {
      expect(
        tryNormalizePhoneNumber(
          c['input'] as String,
          region: c['region'] as String,
        ),
        c['e164'],
        reason: '${jsonEncode(c['input'])} (${c['region']})',
      );
    }
  });
}
