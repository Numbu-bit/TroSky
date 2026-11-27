// Stable slug mapping for Change-password + Change-email failure
// analytics. Kept apart from the UI so a copy change in one of the
// screens never shifts the analytics `reason` surface.
//
// Hard rule: the slug is derived from the AppFailure code and the
// HTTP status, NEVER from user-entered text. No password, email or
// OTP value ever reaches a sink through this mapper.

import 'package:trosky_core/trosky_core.dart';

/// Slugs for `password_change_failed { reason }`.
abstract final class PasswordChangeReason {
  static const String wrongCurrent = 'wrong_current';
  static const String sameAsCurrent = 'same_as_current';
  static const String weak = 'weak';
  static const String network = 'network';
  static const String rateLimited = 'rate_limited';
  static const String server5xx = 'server_5xx';
  static const String server4xx = 'server_4xx';
}

/// Slugs for `email_change_failed { reason }`.
abstract final class EmailChangeReason {
  static const String wrongPassword = 'wrong_password';
  static const String sameAsCurrent = 'same_as_current';
  static const String alreadyInUse = 'already_in_use';
  static const String domainNotAllowed = 'domain_not_allowed';
  static const String wrongCode = 'wrong_code';
  static const String expiredCode = 'expired_code';
  static const String tooManyAttempts = 'too_many_attempts';
  static const String network = 'network';
  static const String rateLimited = 'rate_limited';
  static const String server5xx = 'server_5xx';
  static const String server4xx = 'server_4xx';
}

/// `password_change_failed` reason for [failure].
String reasonForChangePasswordFailure(AppFailure failure) {
  switch (failure) {
    case NetworkFailure() || TimeoutFailure():
      return PasswordChangeReason.network;
    case RateLimitedFailure():
      return PasswordChangeReason.rateLimited;
    case ServerFailure():
      return PasswordChangeReason.server5xx;
    case UnauthorizedFailure():
      return PasswordChangeReason.wrongCurrent;
    case ConflictFailure() when failure.code == 'PASSWORD_UNCHANGED':
      return PasswordChangeReason.sameAsCurrent;
    case ValidationFailure() when failure.code == 'PASSWORD_POLICY_VIOLATION':
      return PasswordChangeReason.weak;
    default:
      return PasswordChangeReason.server4xx;
  }
}

/// `email_change_failed` reason for [failure] at the P-24a request stage.
String reasonForChangeEmailRequestFailure(AppFailure failure) {
  switch (failure) {
    case NetworkFailure() || TimeoutFailure():
      return EmailChangeReason.network;
    case RateLimitedFailure():
      return EmailChangeReason.rateLimited;
    case ServerFailure():
      return EmailChangeReason.server5xx;
    case UnauthorizedFailure():
      return EmailChangeReason.wrongPassword;
    case ConflictFailure() when failure.code == 'EMAIL_UNCHANGED':
      return EmailChangeReason.sameAsCurrent;
    case ConflictFailure() when failure.code == 'EMAIL_ALREADY_REGISTERED':
      return EmailChangeReason.alreadyInUse;
    case ValidationFailure() when failure.code == 'EMAIL_DOMAIN_NOT_ALLOWED':
      return EmailChangeReason.domainNotAllowed;
    default:
      return EmailChangeReason.server4xx;
  }
}

/// `email_change_failed` reason for [failure] at the P-24b confirm stage.
String reasonForChangeEmailConfirmFailure(AppFailure failure) {
  switch (failure) {
    case NetworkFailure() || TimeoutFailure():
      return EmailChangeReason.network;
    case RateLimitedFailure() when failure.code == 'OTP_ATTEMPTS_EXCEEDED':
      return EmailChangeReason.tooManyAttempts;
    case RateLimitedFailure():
      return EmailChangeReason.rateLimited;
    case ServerFailure():
      return EmailChangeReason.server5xx;
    case UnauthorizedFailure() ||
        ValidationFailure(code: 'OTP_INVALID') ||
        NotFoundFailure(code: 'OTP_NOT_FOUND'):
      return EmailChangeReason.wrongCode;
    case ConflictFailure(code: 'OTP_EXPIRED') ||
        ValidationFailure(code: 'OTP_EXPIRED'):
      return EmailChangeReason.expiredCode;
    default:
      return EmailChangeReason.server4xx;
  }
}

/// A rough 0..4 strength bucket for client-side display only. Never
/// sent to the backend and never logged. Length is the dominant
/// factor; character classes add granularity above the 8-char floor.
int localPasswordStrength(String password) {
  if (password.isEmpty) return 0;
  var score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  final classes = <bool>[
    password.contains(RegExp('[a-z]')),
    password.contains(RegExp('[A-Z]')),
    password.contains(RegExp('[0-9]')),
    password.contains(RegExp(r'[^A-Za-z0-9]')),
  ];
  final classCount = classes.where((hit) => hit).length;
  if (classCount >= 2) score++;
  if (classCount >= 3) score++;
  if (score > 4) return 4;
  return score;
}

/// Validator: matches the backend's `ChangePasswordRequest.new_password`
/// rule (at least 8 chars with upper, lower AND a digit). Client
/// pre-check only — the backend is still authoritative.
bool meetsNewPasswordPolicy(String password) =>
    password.length >= 8 &&
    password.contains(RegExp('[a-z]')) &&
    password.contains(RegExp('[A-Z]')) &&
    password.contains(RegExp('[0-9]'));

/// Rough email validator. Deliberately permissive; the backend is the
/// source of truth. Rejects obvious typos (missing `@`, missing TLD)
/// to avoid round-tripping for them.
bool looksLikeEmail(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  final match = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  return match.hasMatch(trimmed);
}
