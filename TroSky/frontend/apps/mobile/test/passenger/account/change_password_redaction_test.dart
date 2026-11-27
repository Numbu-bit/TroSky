// Redaction + request-shape guards for P-23 / P-24 (step 21/B4).
//
// If this test ever fails for a NEW event or field added by the
// change-password / change-email flows, treat it as a privacy
// regression: tighten the sanitiser OR the emit site, don't loosen
// the allow-list here.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/telemetry.dart';
import 'package:mobile/passenger/account/application/account_telemetry.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

void main() {
  group('telemetry event schema — step 21/B4 events', () {
    const passwordEvents = {
      'password_change_opened': <String>{},
      'password_change_submitted': <String>{},
      'password_change_success': <String>{},
      'password_change_failed': {'reason'},
      'email_change_opened': <String>{},
      'email_change_submitted': <String>{},
      'email_change_verification_resent': <String>{},
      'email_change_confirmed': <String>{},
      'email_change_failed': {'reason'},
    };

    test('every event is registered with the expected allow-list', () {
      for (final entry in passwordEvents.entries) {
        expect(
          telemetrySchemaForTest[entry.key],
          equals(entry.value),
          reason: 'event ${entry.key} missing or has wrong allow-list',
        );
      }
    });

    test(
      'no event allow-list contains password / email / otp / phone / token',
      () {
        final forbidden = RegExp(
          r'password|email|otp|phone|token|address|secret|credential|code$',
          caseSensitive: false,
        );
        for (final entry in passwordEvents.entries) {
          for (final key in entry.value) {
            expect(
              forbidden.hasMatch(key),
              isFalse,
              reason:
                  'event ${entry.key} allow-lists suspicious key "$key" — '
                  'only stable slugs ("reason") are permitted.',
            );
          }
        }
      },
    );
  });

  group('sanitiser drops password / email / OTP values even if a '
      'caller tries to smuggle them under reason', () {
    test('a password string under reason is dropped by scalar bounds + legacy '
        'substring guard', () {
      final e = TelemetryEvent('password_change_failed', const {
        'reason': 'wrong_current',
      });
      expect(e.sanitised, {'reason': 'wrong_current'});

      final leaky = TelemetryEvent('password_change_failed', const {
        'reason': 'wrong_current',
        'password': 'MyPass77', // Dropped: not in allow-list.
        'email': 'kofi@gmail.com', // Dropped: not in allow-list.
        'otp': '123456', // Dropped.
      });
      expect(leaky.sanitised, {'reason': 'wrong_current'});
    });

    test('email_change_failed drops every non-reason key, including the '
        'new email and the OTP', () {
      final leaky = TelemetryEvent('email_change_failed', const {
        'reason': 'wrong_code',
        'new_email': 'kofi@gmail.com',
        'code': '123456',
        'current_password': 'MyPass77',
      });
      expect(leaky.sanitised, {'reason': 'wrong_code'});
    });
  });

  group('reason mapping is stable + enumerable — the `reason` surface '
      'stays independent of the UI copy', () {
    test('password change — all known failures map to a listed slug', () {
      const slugs = {
        PasswordChangeReason.wrongCurrent,
        PasswordChangeReason.sameAsCurrent,
        PasswordChangeReason.weak,
        PasswordChangeReason.network,
        PasswordChangeReason.rateLimited,
        PasswordChangeReason.server5xx,
        PasswordChangeReason.server4xx,
      };
      expect(
        reasonForChangePasswordFailure(
          const UnauthorizedFailure(code: 'INVALID_CREDENTIALS', message: 'x'),
        ),
        PasswordChangeReason.wrongCurrent,
      );
      expect(
        reasonForChangePasswordFailure(
          const ConflictFailure(code: 'PASSWORD_UNCHANGED', message: 'x'),
        ),
        PasswordChangeReason.sameAsCurrent,
      );
      expect(
        reasonForChangePasswordFailure(
          const ValidationFailure(
            code: 'PASSWORD_POLICY_VIOLATION',
            message: 'x',
          ),
        ),
        PasswordChangeReason.weak,
      );
      expect(
        reasonForChangePasswordFailure(const NetworkFailure()),
        PasswordChangeReason.network,
      );
      expect(
        reasonForChangePasswordFailure(
          const RateLimitedFailure(code: 'RATE_LIMIT_EXCEEDED', message: 'x'),
        ),
        PasswordChangeReason.rateLimited,
      );
      expect(
        reasonForChangePasswordFailure(
          const ServerFailure(code: 'INTERNAL_SERVER_ERROR', message: 'x'),
        ),
        PasswordChangeReason.server5xx,
      );
      expect(
        reasonForChangePasswordFailure(
          const NotFoundFailure(code: 'NOT_FOUND', message: 'x'),
        ),
        PasswordChangeReason.server4xx,
      );
      // Belt-and-braces: the mapper never returns a slug outside the set.
      for (final failure in <AppFailure>[
        const UnauthorizedFailure(code: 'INVALID_CREDENTIALS', message: 'x'),
        const ConflictFailure(code: 'PASSWORD_UNCHANGED', message: 'x'),
        const ValidationFailure(
          code: 'PASSWORD_POLICY_VIOLATION',
          message: 'x',
        ),
        const NetworkFailure(),
        const RateLimitedFailure(code: 'RATE_LIMIT_EXCEEDED', message: 'x'),
        const ServerFailure(code: 'INTERNAL_SERVER_ERROR', message: 'x'),
        const NotFoundFailure(code: 'NOT_FOUND', message: 'x'),
      ]) {
        expect(slugs.contains(reasonForChangePasswordFailure(failure)), isTrue);
      }
    });

    test(
      'email change (request) — all known failures map to a listed slug',
      () {
        expect(
          reasonForChangeEmailRequestFailure(
            const UnauthorizedFailure(
              code: 'INVALID_CREDENTIALS',
              message: 'x',
            ),
          ),
          EmailChangeReason.wrongPassword,
        );
        expect(
          reasonForChangeEmailRequestFailure(
            const ConflictFailure(code: 'EMAIL_UNCHANGED', message: 'x'),
          ),
          EmailChangeReason.sameAsCurrent,
        );
        expect(
          reasonForChangeEmailRequestFailure(
            const ConflictFailure(
              code: 'EMAIL_ALREADY_REGISTERED',
              message: 'x',
            ),
          ),
          EmailChangeReason.alreadyInUse,
        );
        expect(
          reasonForChangeEmailRequestFailure(
            const ValidationFailure(
              code: 'EMAIL_DOMAIN_NOT_ALLOWED',
              message: 'x',
            ),
          ),
          EmailChangeReason.domainNotAllowed,
        );
      },
    );

    test('email change (confirm) — OTP failure codes map to wrong/expired/'
        'too-many slugs, never to a code that could leak the input', () {
      expect(
        reasonForChangeEmailConfirmFailure(
          const ValidationFailure(code: 'OTP_INVALID', message: 'x'),
        ),
        EmailChangeReason.wrongCode,
      );
      expect(
        reasonForChangeEmailConfirmFailure(
          const ConflictFailure(code: 'OTP_EXPIRED', message: 'x'),
        ),
        EmailChangeReason.expiredCode,
      );
      expect(
        reasonForChangeEmailConfirmFailure(
          const RateLimitedFailure(code: 'OTP_ATTEMPTS_EXCEEDED', message: 'x'),
        ),
        EmailChangeReason.tooManyAttempts,
      );
    });
  });

  group('request body shape — each DTO carries ONLY the declared '
      'fields, so a future `.toJson` cannot leak extras', () {
    test('ChangePasswordRequest serialises exactly {current_password, '
        'new_password}', () {
      const dto = ChangePasswordRequest(
        currentPassword: 'OldPass99',
        newPassword: 'NewPass77',
      );
      final json = dto.toJson();
      expect(json.keys.toSet(), {'current_password', 'new_password'});
      expect(json['current_password'], 'OldPass99');
      expect(json['new_password'], 'NewPass77');
    });

    test('ChangeEmailRequest serialises exactly {new_email, '
        'current_password}', () {
      const dto = ChangeEmailRequest(
        newEmail: 'kofi@gmail.com',
        currentPassword: 'OldPass99',
      );
      final json = dto.toJson();
      expect(json.keys.toSet(), {'new_email', 'current_password'});
    });

    test('ChangeEmailConfirmRequest serialises exactly {new_email, code}', () {
      const dto = ChangeEmailConfirmRequest(
        newEmail: 'kofi@gmail.com',
        code: '123456',
      );
      final json = dto.toJson();
      expect(json.keys.toSet(), {'new_email', 'code'});
    });
  });

  group('local password strength + email heuristic', () {
    test('localPasswordStrength is 0 for empty and increases with length + '
        'character classes', () {
      expect(localPasswordStrength(''), 0);
      expect(localPasswordStrength('abc'), 0);
      expect(localPasswordStrength('abcdefgh'), greaterThan(0));
      expect(localPasswordStrength('Abcdefgh1'), greaterThanOrEqualTo(2));
      expect(localPasswordStrength('Abcdefghij12!@'), greaterThanOrEqualTo(3));
    });

    test('meetsNewPasswordPolicy matches the backend rule verbatim', () {
      expect(meetsNewPasswordPolicy('short1A'), isFalse);
      expect(meetsNewPasswordPolicy('alllowercase1'), isFalse);
      expect(meetsNewPasswordPolicy('ALLUPPER1234'), isFalse);
      expect(meetsNewPasswordPolicy('NoDigitsHere'), isFalse);
      expect(meetsNewPasswordPolicy('Password1'), isTrue);
    });

    test('looksLikeEmail rejects obvious typos and accepts real shapes', () {
      expect(looksLikeEmail(''), isFalse);
      expect(looksLikeEmail('kofi'), isFalse);
      expect(looksLikeEmail('kofi@gmail'), isFalse);
      expect(looksLikeEmail('kofi@gmail.com'), isTrue);
      expect(looksLikeEmail(' Kofi@gmail.com '), isTrue);
    });
  });
}
