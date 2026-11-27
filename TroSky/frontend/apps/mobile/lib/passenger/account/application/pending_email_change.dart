// Local, device-only "pending email change" state.
//
// The backend does not surface a `pending_email` field on
// `/users/me`, so a pending change can only be shown on the device
// that started it. Keyed by user id so that signing in as a
// different account on the same device doesn't inherit the pending
// state of another user. Nothing is persisted: on app restart the
// pending sub-line disappears until the user starts another change.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pending change-email that was started on THIS device. [newEmail]
/// is the address the OTP was sent to; [startedAt] is when the user
/// submitted P-24a. Expiry is driven off the backend's OTP window,
/// shown in P-24b and refreshed on resend.
class PendingEmailChange {
  const PendingEmailChange({
    required this.userId,
    required this.newEmail,
    required this.startedAt,
  });

  final String userId;
  final String newEmail;
  final DateTime startedAt;
}

/// The pending-change notifier. A single entry at most: starting a
/// new change replaces any earlier one.
class PendingEmailChangeController extends Notifier<PendingEmailChange?> {
  @override
  PendingEmailChange? build() => null;

  void set(PendingEmailChange pending) {
    state = pending;
  }

  /// Clears pending state for [userId], if any — used by the cancel
  /// action on P-22 and by P-24b on confirm. A mismatched userId is a
  /// no-op so sign-out/sign-in as another user cannot wipe the
  /// previous user's state accidentally.
  void clearFor(String userId) {
    if (state?.userId == userId) state = null;
  }
}

final pendingEmailChangeProvider =
    NotifierProvider<PendingEmailChangeController, PendingEmailChange?>(
      PendingEmailChangeController.new,
    );

/// `k***@gmail.com` from `kwame@gmail.com`. Keeps the first character
/// and the domain; replaces everything else before the `@` with
/// three stars. Addresses without `@` return as-is (defensive).
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final head = email.substring(0, at);
  final domain = email.substring(at);
  final first = head.substring(0, 1);
  return '$first***$domain';
}
