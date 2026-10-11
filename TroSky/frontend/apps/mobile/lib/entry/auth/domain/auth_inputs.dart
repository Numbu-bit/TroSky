import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';

/// A Ghana number in E.164 (`+233…`), or null. The app is Ghana-only, so a
/// valid foreign number is refused too.
String? ghanaPhone(String input) {
  final e164 = tryNormalizePhoneNumber(input);
  return e164 != null && e164.startsWith('+233') ? e164 : null;
}

bool looksLikeEmail(String input) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input.trim());

/// The backend's password policy (backend/app/utilities/password_policy.py
/// with the default settings).
class PasswordRules {
  const PasswordRules(this.password);

  final String password;

  bool get length => password.length >= 8;
  bool get upper => password.contains(RegExp('[A-Z]'));
  bool get lower => password.contains(RegExp('[a-z]'));
  bool get digit => password.contains(RegExp('[0-9]'));
  bool get allMet => length && upper && lower && digit;
}

/// Where a code went, for "Code sent to …": most of it hidden.
///
/// `+233241234567` → `+233 24 ••• ••67`; `ama.mensah@gmail.com` →
/// `a•••@gmail.com`.
String maskTarget(String target) {
  if (target.contains('@')) {
    final at = target.indexOf('@');
    return '${target.substring(0, 1)}•••${target.substring(at)}';
  }
  if (target.startsWith('+233') && target.length == 13) {
    return '+233 ${target.substring(4, 6)} ••• ••${target.substring(11)}';
  }
  if (target.length > 4) {
    return '${'•' * (target.length - 2)}${target.substring(target.length - 2)}';
  }
  return target;
}

/// Why the code screen is open.
enum CodePurpose {
  /// After registering: verify, then sign in with the details just typed.
  registration,

  /// Sign-in refused with ACCOUNT_NOT_VERIFIED: verify, then sign in.
  unverifiedAccount,

  /// "Sign in with a code".
  signIn,

  /// Already signed in, but an action (booking) needs a verified account:
  /// verify, then go back to it.
  verifyAccount,
}

/// What the code screen needs.
class CodeRequest {
  const CodeRequest({
    required this.purpose,
    required this.target,
    this.identifier,
    this.password,
    this.alreadySent = true,
  });

  final CodePurpose purpose;

  /// Where the code went: `otp_sent_to`, ACCOUNT_NOT_VERIFIED's
  /// `details.target`, or the phone for sign-in codes. Also the target the
  /// code is checked against.
  final String target;

  /// Phone or email and password to sign in with after verifying.
  final String? identifier;
  final String? password;

  /// False when the screen must ask for a code itself.
  final bool alreadySent;

  OtpPurpose get otpPurpose => switch (purpose) {
    CodePurpose.registration ||
    CodePurpose.unverifiedAccount ||
    CodePurpose.verifyAccount => OtpPurpose.registration,
    CodePurpose.signIn => OtpPurpose.login,
  };
}

/// How long to wait before asking again, from a rate-limit failure.
Duration? waitFor(AppFailure failure) =>
    failure is RateLimitedFailure ? failure.retryAfter : null;
