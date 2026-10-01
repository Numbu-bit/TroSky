import 'package:flutter/material.dart';
import 'package:trosky_core/trosky_core.dart';

import '../../../l10n/app_localizations.dart';

/// The message to show for [failure] when no field owns it.
String failureMessage(BuildContext context, AppFailure failure) {
  final l10n = AppLocalizations.of(context);
  return switch (failure) {
    NetworkFailure() => l10n.errorNetwork,
    TimeoutFailure() => l10n.errorTimeout,
    AccountLockedFailure(:final lockedUntil) =>
      lockedUntil == null
          ? l10n.errorRateLimitedNoTime
          : l10n.errorAccountLocked(
              MaterialLocalizations.of(context).formatTimeOfDay(
                TimeOfDay.fromDateTime(lockedUntil.toLocal()),
                alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                  context,
                ),
              ),
            ),
    AccountSuspendedFailure() => l10n.errorAccountSuspended,
    RateLimitedFailure(:final retryAfter)
        when failure.code == 'RATE_LIMIT_EXCEEDED' =>
      retryAfter == null
          ? l10n.errorRateLimitedNoTime
          : l10n.errorRateLimited(retryAfter.inSeconds),
    _ => switch (failure.code) {
      'INVALID_CREDENTIALS' => l10n.errorInvalidCredentials,
      'PHONE_ALREADY_REGISTERED' => l10n.errorPhoneTaken,
      'EMAIL_ALREADY_REGISTERED' => l10n.errorEmailTaken,
      'OTP_INVALID' => l10n.errorCodeInvalid,
      'OTP_EXPIRED' => l10n.errorCodeExpired,
      'OTP_ATTEMPTS_EXCEEDED' => l10n.errorCodeAttempts,
      'OTP_NOT_FOUND' => l10n.errorCodeMissing,
      _ => l10n.errorGeneric,
    },
  };
}
