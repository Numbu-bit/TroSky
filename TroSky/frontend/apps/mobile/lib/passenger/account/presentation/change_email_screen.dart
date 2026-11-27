// P-24a Change email (request) + P-24b Verify new email.
//
// P-24a: show the current email read-only, ask for a new one + current
// password, submit `POST /users/me/change-email` with a stable
// Idempotency-Key reused across retries of the same attempt. On
// success, record a local "pending change" entry (keyed by user id —
// there is no `pending_email` on `/users/me` to drive this from) and
// push P-24b.
//
// P-24b: show a masked form of the new address + a 6-digit code
// field. Resend has a 60 s cooldown, re-uses the new_email but a
// NEW idempotency key. Submit calls `POST /users/me/change-email/
// confirm`, maps the usual verify-otp error codes, and on success
// pops back to P-22 with a toast, clears local pending state and
// writes the refreshed user to the session.
//
// Both screens wrap their content in [TroskySecureScreen] so
// FLAG_SECURE blocks screenshots. Analytics never carry the email,
// password or OTP; only stable `reason` slugs.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/routes.dart';
import '../../../app/secure_window.dart';
import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../application/account_telemetry.dart';
import '../application/pending_email_change.dart';

/// Opens P-24b. Carries the new email the OTP was sent to and the
/// password the user just confirmed with, so Resend can call
/// `POST /users/me/change-email` again without the user having to
/// retype it. The password is held only in memory for the lifetime of
/// the verify screen — never persisted, never serialised, never
/// logged. The screen is wrapped in [TroskySecureScreen] so
/// FLAG_SECURE blocks screenshots and the app-switcher snapshot.
class ChangeEmailVerifyArgs {
  const ChangeEmailVerifyArgs({
    required this.newEmail,
    required this.currentPassword,
    required this.initialExpiresIn,
  });

  final String newEmail;
  final String currentPassword;

  /// How long the backend said the OTP lasts; used to prefill the
  /// soft expiry label on first open. Each resend may refresh it.
  final Duration initialExpiresIn;

  /// Explicit refusal to print the carried password in logs or
  /// breadcrumbs. Overriding `toString` so a stray `print(args)` or
  /// error-handler stringify can never leak the plaintext.
  @override
  String toString() =>
      'ChangeEmailVerifyArgs(newEmail: $newEmail, expiresIn: $initialExpiresIn)';
}

/// P-24a — start a change: new email + current password.
class ChangeEmailRequestScreen extends ConsumerStatefulWidget {
  const ChangeEmailRequestScreen({super.key});

  @override
  ConsumerState<ChangeEmailRequestScreen> createState() =>
      _ChangeEmailRequestScreenState();
}

class _ChangeEmailRequestScreenState
    extends ConsumerState<ChangeEmailRequestScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _submitting = false;
  String? _idempotencyKey;
  String? _emailError;
  String? _passwordError;
  String? _bannerError;
  Duration? _retryAfter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(telemetryProvider).emit(TelemetryEvent('email_change_opened'));
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _currentEmail() {
    final session = ref.read(sessionControllerProvider).value;
    return session is SessionAuthenticated ? session.user.email : null;
  }

  bool get _clientValid {
    final email = _email.text.trim().toLowerCase();
    final current = _currentEmail()?.toLowerCase();
    return looksLikeEmail(email) &&
        email != current &&
        _password.text.isNotEmpty;
  }

  void _emitFailed(String reason) {
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('email_change_failed', {'reason': reason}));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _emailError = null;
      _passwordError = null;
      _bannerError = null;
      _retryAfter = null;
    });
    final newEmail = _email.text.trim().toLowerCase();
    final password = _password.text;
    if (!looksLikeEmail(newEmail)) {
      setState(() => _emailError = l10n.changeEmailInvalid);
      return;
    }
    final current = _currentEmail()?.toLowerCase();
    if (current != null && newEmail == current) {
      setState(() => _emailError = l10n.changeEmailSameAsCurrent);
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = l10n.changeEmailWrongPassword);
      return;
    }
    setState(() => _submitting = true);
    ref.read(telemetryProvider).emit(TelemetryEvent('email_change_submitted'));
    final key = _idempotencyKey ??= uuidV4();
    final result = await ref
        .read(userRepositoryProvider)
        .changeEmail(
          ChangeEmailRequest(newEmail: newEmail, currentPassword: password),
          idempotencyKey: key,
        );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        final userId = _currentUserId();
        if (userId != null) {
          ref
              .read(pendingEmailChangeProvider.notifier)
              .set(
                PendingEmailChange(
                  userId: userId,
                  newEmail: newEmail,
                  startedAt: DateTime.now(),
                ),
              );
        }
        setState(() {
          _submitting = false;
          _idempotencyKey = null;
        });
        context.pushReplacementNamed(
          AppRoute.changeEmailVerify.name,
          extra: ChangeEmailVerifyArgs(
            newEmail: newEmail,
            currentPassword: password,
            initialExpiresIn: Duration(seconds: value.expiresInSeconds),
          ),
        );
      case Err(:final failure):
        _emitFailed(reasonForChangeEmailRequestFailure(failure));
        _applyFailure(failure, l10n);
    }
  }

  String? _currentUserId() {
    final session = ref.read(sessionControllerProvider).value;
    return session is SessionAuthenticated ? session.user.id : null;
  }

  void _applyFailure(AppFailure failure, AppLocalizations l10n) {
    switch (failure) {
      case UnauthorizedFailure():
        setState(() {
          _submitting = false;
          _passwordError = l10n.changeEmailWrongPassword;
        });
      case ConflictFailure() when failure.code == 'EMAIL_UNCHANGED':
        setState(() {
          _submitting = false;
          _emailError = l10n.changeEmailSameAsCurrent;
        });
      case ConflictFailure() when failure.code == 'EMAIL_ALREADY_REGISTERED':
        setState(() {
          _submitting = false;
          _emailError = l10n.changeEmailAlreadyInUse;
        });
      case ValidationFailure() when failure.code == 'EMAIL_DOMAIN_NOT_ALLOWED':
        setState(() {
          _submitting = false;
          _emailError = l10n.changeEmailDomainNotAllowed;
        });
      case ValidationFailure():
        final fields = failure.fieldErrors;
        setState(() {
          _submitting = false;
          if (fields.containsKey('new_email')) {
            _emailError = fields['new_email']!.first;
          }
          if (fields.containsKey('current_password')) {
            _passwordError = fields['current_password']!.first;
          }
          if (_emailError == null && _passwordError == null) {
            _bannerError = l10n.changeEmailServerError;
          }
        });
      case RateLimitedFailure():
        setState(() {
          _submitting = false;
          _retryAfter = failure.retryAfter;
          _bannerError = failure.retryAfter == null
              ? l10n.changeEmailRateLimited
              : l10n.changeEmailRateLimitedWithSeconds(
                  failure.retryAfter!.inSeconds,
                );
        });
      case NetworkFailure() || TimeoutFailure():
        setState(() {
          _submitting = false;
          _bannerError = l10n.changeEmailOffline;
        });
      default:
        setState(() {
          _submitting = false;
          _bannerError = l10n.changeEmailServerError;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = _currentEmail();
    return TroskySecureScreen(
      child: AnnotatedRegion(
        value: TroskySystemUi.darkIcons,
        child: Scaffold(
          backgroundColor: TroskyColors.background,
          appBar: AppBar(
            title: Text(l10n.changeEmailRequestTitle),
            backgroundColor: TroskyColors.surface,
            foregroundColor: TroskyColors.ink,
            elevation: 0,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(TroskySpacing.s16),
              children: [
                Text(
                  l10n.changeEmailRequestIntro,
                  style: TroskyTypography.body14Regular,
                ),
                const SizedBox(height: TroskySpacing.s16),
                if (_bannerError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TroskySpacing.s12),
                    child: _Banner(message: _bannerError!),
                  ),
                _ReadOnlyField(
                  label: l10n.changeEmailCurrentLabel,
                  value: current ?? l10n.changeEmailCurrentNone,
                ),
                const SizedBox(height: TroskySpacing.s12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.changeEmailNewLabel,
                    errorText: _emailError,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: TroskySpacing.s12),
                _ObscuredField(
                  controller: _password,
                  labelText: l10n.changeEmailPasswordLabel,
                  obscured: !_showPassword,
                  onToggle: () =>
                      setState(() => _showPassword = !_showPassword),
                  errorText: _passwordError,
                  obscuredSemantics: l10n.changePasswordObscuredSemantics,
                  showSemantics: l10n.changePasswordRevealShow,
                  hideSemantics: l10n.changePasswordRevealHide,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: TroskySpacing.s24),
                TroskyButton(
                  label: l10n.changeEmailRequestCta,
                  variant: TroskyButtonVariant.primary,
                  onPressed:
                      (_clientValid && !_submitting && _retryAfter == null)
                      ? _submit
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// P-24b — enter the OTP sent to the new address.
class ChangeEmailVerifyScreen extends ConsumerStatefulWidget {
  const ChangeEmailVerifyScreen({super.key, required this.args});

  final ChangeEmailVerifyArgs args;

  @override
  ConsumerState<ChangeEmailVerifyScreen> createState() =>
      _ChangeEmailVerifyScreenState();
}

class _ChangeEmailVerifyScreenState
    extends ConsumerState<ChangeEmailVerifyScreen> {
  static const Duration _resendCooldown = Duration(seconds: 60);
  final _code = TextEditingController();
  bool _submitting = false;
  bool _resending = false;
  String? _inlineError;
  String? _bannerError;
  DateTime? _nextResendAt;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _nextResendAt = DateTime.now().add(_resendCooldown);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {}); // Re-render the cooldown countdown.
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  int get _cooldownSeconds {
    final left = _nextResendAt?.difference(DateTime.now()) ?? Duration.zero;
    final s = left.inSeconds;
    return s < 0 ? 0 : s;
  }

  bool get _canResend => _cooldownSeconds == 0 && !_resending;

  void _emitFailed(String reason) {
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('email_change_failed', {'reason': reason}));
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() {
      _resending = true;
      _inlineError = null;
      _bannerError = null;
    });
    // Resend reuses new_email + the password the user already
    // confirmed on P-24a; a fresh idempotency key makes the backend
    // treat this as a new attempt.
    final result = await ref
        .read(userRepositoryProvider)
        .changeEmail(
          ChangeEmailRequest(
            newEmail: widget.args.newEmail,
            currentPassword: widget.args.currentPassword,
          ),
          idempotencyKey: uuidV4(),
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref
            .read(telemetryProvider)
            .emit(TelemetryEvent('email_change_verification_resent'));
        setState(() {
          _resending = false;
          _nextResendAt = DateTime.now().add(_resendCooldown);
        });
      case Err(:final failure):
        _emitFailed(reasonForChangeEmailRequestFailure(failure));
        final l10n = AppLocalizations.of(context);
        setState(() {
          _resending = false;
          _bannerError = switch (failure) {
            RateLimitedFailure(:final retryAfter) when retryAfter != null =>
              l10n.changeEmailRateLimitedWithSeconds(retryAfter.inSeconds),
            RateLimitedFailure() => l10n.changeEmailRateLimited,
            NetworkFailure() ||
            TimeoutFailure() => l10n.changeEmailVerifyOffline,
            _ => l10n.changeEmailVerifyServerError,
          };
        });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final code = _code.text.trim();
    if (code.length < 4) return;
    setState(() {
      _submitting = true;
      _inlineError = null;
      _bannerError = null;
    });
    final result = await ref
        .read(userRepositoryProvider)
        .confirmEmailChange(
          ChangeEmailConfirmRequest(newEmail: widget.args.newEmail, code: code),
        );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        ref
            .read(telemetryProvider)
            .emit(TelemetryEvent('email_change_confirmed'));
        // The backend hands back the refreshed UserResponse; feed it
        // into the session so P-22 immediately shows the new email.
        // Await the update so the next frame renders the new user
        // the moment we navigate.
        await ref
            .read(sessionControllerProvider.notifier)
            .applyUpdatedUser(value);
        if (!mounted) return;
        ref.read(pendingEmailChangeProvider.notifier).clearFor(value.id);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.changeEmailVerifySuccess)),
          );
        context.goNamed(AppRoute.personalInfo.name);
      case Err(:final failure):
        _emitFailed(reasonForChangeEmailConfirmFailure(failure));
        setState(() {
          _submitting = false;
          switch (failure) {
            case ValidationFailure(code: 'OTP_EXPIRED') ||
                ConflictFailure(code: 'OTP_EXPIRED'):
              _inlineError = l10n.changeEmailVerifyExpired;
            case RateLimitedFailure(code: 'OTP_ATTEMPTS_EXCEEDED'):
              _bannerError = l10n.changeEmailVerifyTooManyAttempts;
            case RateLimitedFailure(:final retryAfter) when retryAfter != null:
              _bannerError = l10n.changeEmailRateLimitedWithSeconds(
                retryAfter.inSeconds,
              );
            case RateLimitedFailure():
              _bannerError = l10n.changeEmailRateLimited;
            case NetworkFailure() || TimeoutFailure():
              _bannerError = l10n.changeEmailVerifyOffline;
            case UnauthorizedFailure() ||
                ValidationFailure(code: 'OTP_INVALID') ||
                NotFoundFailure(code: 'OTP_NOT_FOUND'):
              _inlineError = l10n.changeEmailVerifyWrongCode;
            default:
              _bannerError = l10n.changeEmailVerifyServerError;
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final masked = maskEmail(widget.args.newEmail);
    return TroskySecureScreen(
      child: AnnotatedRegion(
        value: TroskySystemUi.darkIcons,
        child: Scaffold(
          backgroundColor: TroskyColors.background,
          appBar: AppBar(
            title: Text(l10n.changeEmailVerifyTitle),
            backgroundColor: TroskyColors.surface,
            foregroundColor: TroskyColors.ink,
            elevation: 0,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(TroskySpacing.s16),
              children: [
                Text(
                  l10n.changeEmailVerifySentTo(masked),
                  style: TroskyTypography.body14Regular,
                ),
                const SizedBox(height: TroskySpacing.s16),
                if (_bannerError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TroskySpacing.s12),
                    child: _Banner(message: _bannerError!),
                  ),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (_) => setState(() {
                    _inlineError = null;
                  }),
                  decoration: InputDecoration(
                    labelText: l10n.changeEmailVerifyCodeLabel,
                    helperText: l10n.changeEmailVerifyPasteHint,
                    errorText: _inlineError,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: TroskySpacing.s12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _canResend ? _resend : null,
                      child: Text(
                        _canResend
                            ? l10n.changeEmailVerifyResend
                            : l10n.changeEmailVerifyResendIn(_cooldownSeconds),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TroskySpacing.s16),
                TroskyButton(
                  label: l10n.changeEmailVerifyCta,
                  variant: TroskyButtonVariant.primary,
                  onPressed: (_code.text.trim().length >= 4 && !_submitting)
                      ? _submit
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TroskySpacing.s12),
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TroskyTypography.body12Regular.copyWith(
              color: TroskyColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TroskyTypography.body14SemiBold.copyWith(
              color: TroskyColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ObscuredField extends StatelessWidget {
  const _ObscuredField({
    required this.controller,
    required this.labelText,
    required this.obscured,
    required this.onToggle,
    required this.obscuredSemantics,
    required this.showSemantics,
    required this.hideSemantics,
    this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final bool obscured;
  final VoidCallback onToggle;
  final String obscuredSemantics;
  final String showSemantics;
  final String hideSemantics;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      obscureText: obscured,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: const [AutofillHints.password],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        errorText: errorText,
        border: const OutlineInputBorder(),
        suffixIcon: Semantics(
          button: true,
          label: obscured ? showSemantics : hideSemantics,
          child: IconButton(
            iconSize: 22,
            onPressed: onToggle,
            icon: Icon(
              obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ),
      ),
    );
    if (!obscured) return field;
    return Semantics(label: obscuredSemantics, child: field);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(TroskySpacing.s12),
        decoration: BoxDecoration(
          color: TroskyColors.redA10,
          borderRadius: BorderRadius.circular(TroskyRadii.r12),
          border: Border.all(color: TroskyColors.red),
        ),
        child: Text(
          message,
          style: TroskyTypography.body14Regular.copyWith(
            color: TroskyColors.ink,
          ),
        ),
      ),
    );
  }
}
