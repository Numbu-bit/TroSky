// P-23 Change password. Signed-in rotate, replacing the PR #95 stub
// now that `POST /users/me/change-password` is live on staging.
//
// Form fields: Current, New, Confirm. All obscured with a show/hide
// eye toggle. A purely-local strength meter reacts under New. Submit
// validates client-side (length + letters + digits + confirm match
// + new != current) then calls the backend with a stable
// Idempotency-Key reused across retries of the SAME attempt.
//
// The backend signs every other session out on success; THIS session
// stays signed in and the fields are cleared. Toast only, no route
// change. Wrapped in [TroskySecureScreen] (H1) so FLAG_SECURE blocks
// screenshots.
//
// Privacy: no password string ever reaches the sink. The telemetry
// `reason` surface comes from [reasonForChangePasswordFailure], never
// from input text.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/secure_window.dart';
import '../../../app/telemetry.dart';
import '../../../l10n/app_localizations.dart';
import '../application/account_telemetry.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _submitting = false;
  String? _idempotencyKey;
  String? _currentError;
  String? _newError;
  String? _confirmError;
  String? _bannerError;
  Duration? _retryAfter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(telemetryProvider)
          .emit(TelemetryEvent('password_change_opened'));
    });
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _clientValid {
    final current = _current.text;
    final next = _new.text;
    final confirm = _confirm.text;
    return current.isNotEmpty &&
        meetsNewPasswordPolicy(next) &&
        confirm == next &&
        next != current;
  }

  void _emitFailed(String reason) {
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('password_change_failed', {'reason': reason}));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _currentError = null;
      _newError = null;
      _confirmError = null;
      _bannerError = null;
      _retryAfter = null;
    });
    final current = _current.text;
    final next = _new.text;
    final confirm = _confirm.text;
    if (current.isEmpty) {
      setState(() => _currentError = l10n.changePasswordWrongCurrent);
      return;
    }
    if (!meetsNewPasswordPolicy(next)) {
      setState(() => _newError = l10n.changePasswordTooWeak);
      return;
    }
    if (confirm != next) {
      setState(() => _confirmError = l10n.changePasswordMismatch);
      return;
    }
    if (next == current) {
      setState(() => _newError = l10n.changePasswordSameAsCurrent);
      return;
    }
    setState(() => _submitting = true);
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('password_change_submitted'));
    final key = _idempotencyKey ??= uuidV4();
    final result = await ref
        .read<UserRepository>(userRepositoryProvider)
        .changePassword(
          ChangePasswordRequest(currentPassword: current, newPassword: next),
          idempotencyKey: key,
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref
            .read(telemetryProvider)
            .emit(TelemetryEvent('password_change_success'));
        _current.clear();
        _new.clear();
        _confirm.clear();
        setState(() {
          _submitting = false;
          _idempotencyKey = null;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.changePasswordSuccess)));
      case Err(:final failure):
        _emitFailed(reasonForChangePasswordFailure(failure));
        _applyFailure(failure, l10n);
    }
  }

  void _applyFailure(AppFailure failure, AppLocalizations l10n) {
    switch (failure) {
      case UnauthorizedFailure():
        setState(() {
          _submitting = false;
          _currentError = l10n.changePasswordWrongCurrent;
        });
      case ConflictFailure() when failure.code == 'PASSWORD_UNCHANGED':
        setState(() {
          _submitting = false;
          _newError = l10n.changePasswordSameAsCurrent;
        });
      case ValidationFailure() when failure.code == 'PASSWORD_POLICY_VIOLATION':
        setState(() {
          _submitting = false;
          _newError = l10n.changePasswordTooWeak;
        });
      case ValidationFailure():
        final fields = failure.fieldErrors;
        setState(() {
          _submitting = false;
          if (fields.containsKey('current_password')) {
            _currentError = fields['current_password']!.first;
          }
          if (fields.containsKey('new_password')) {
            _newError = fields['new_password']!.first;
          }
          if (_currentError == null && _newError == null) {
            _bannerError = l10n.changePasswordServerError;
          }
        });
      case RateLimitedFailure():
        setState(() {
          _submitting = false;
          _retryAfter = failure.retryAfter;
          _bannerError = failure.retryAfter == null
              ? l10n.changePasswordRateLimited
              : l10n.changePasswordRateLimitedWithSeconds(
                  failure.retryAfter!.inSeconds,
                );
        });
      case NetworkFailure() || TimeoutFailure():
        setState(() {
          _submitting = false;
          _bannerError = l10n.changePasswordOffline;
        });
      default:
        setState(() {
          _submitting = false;
          _bannerError = l10n.changePasswordServerError;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final strength = localPasswordStrength(_new.text);
    return TroskySecureScreen(
      child: AnnotatedRegion(
        value: TroskySystemUi.darkIcons,
        child: Scaffold(
          backgroundColor: TroskyColors.background,
          appBar: AppBar(
            title: Text(l10n.changePasswordTitle),
            backgroundColor: TroskyColors.surface,
            foregroundColor: TroskyColors.ink,
            elevation: 0,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(TroskySpacing.s16),
              children: [
                Text(
                  l10n.changePasswordIntro,
                  style: TroskyTypography.body14Regular,
                ),
                const SizedBox(height: TroskySpacing.s16),
                if (_bannerError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TroskySpacing.s12),
                    child: _Banner(message: _bannerError!),
                  ),
                _PasswordField(
                  controller: _current,
                  labelText: l10n.changePasswordCurrentLabel,
                  obscuredSemantics: l10n.changePasswordObscuredSemantics,
                  showSemantics: l10n.changePasswordRevealShow,
                  hideSemantics: l10n.changePasswordRevealHide,
                  obscured: !_showCurrent,
                  onToggle: () => setState(() => _showCurrent = !_showCurrent),
                  errorText: _currentError,
                  autofillHints: const [AutofillHints.password],
                  onChanged: (_) {
                    if (_currentError != null) setState(() {});
                  },
                ),
                const SizedBox(height: TroskySpacing.s12),
                _PasswordField(
                  controller: _new,
                  labelText: l10n.changePasswordNewLabel,
                  obscuredSemantics: l10n.changePasswordObscuredSemantics,
                  showSemantics: l10n.changePasswordRevealShow,
                  hideSemantics: l10n.changePasswordRevealHide,
                  obscured: !_showNew,
                  onToggle: () => setState(() => _showNew = !_showNew),
                  errorText: _newError,
                  helperText: l10n.changePasswordRule,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: TroskySpacing.s8),
                _StrengthMeter(strength: strength, l10n: l10n),
                const SizedBox(height: TroskySpacing.s12),
                _PasswordField(
                  controller: _confirm,
                  labelText: l10n.changePasswordConfirmLabel,
                  obscuredSemantics: l10n.changePasswordObscuredSemantics,
                  showSemantics: l10n.changePasswordRevealShow,
                  hideSemantics: l10n.changePasswordRevealHide,
                  obscured: !_showConfirm,
                  onToggle: () => setState(() => _showConfirm = !_showConfirm),
                  errorText: _confirmError,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: TroskySpacing.s24),
                TroskyButton(
                  label: l10n.changePasswordCta,
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

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.labelText,
    required this.obscured,
    required this.onToggle,
    required this.obscuredSemantics,
    required this.showSemantics,
    required this.hideSemantics,
    this.errorText,
    this.helperText,
    this.autofillHints,
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
  final String? helperText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      obscureText: obscured,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: autofillHints?.toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
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

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.strength, required this.l10n});

  final int strength;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (label, colour) = switch (strength) {
      <= 1 => (l10n.changePasswordStrengthWeak, TroskyColors.red),
      2 => (l10n.changePasswordStrengthFair, TroskyColors.amber),
      3 => (l10n.changePasswordStrengthGood, TroskyColors.navy),
      _ => (l10n.changePasswordStrengthStrong, TroskyColors.success),
    };
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TroskyRadii.r4),
            child: LinearProgressIndicator(
              value: strength == 0 ? 0 : strength / 4,
              minHeight: 6,
              backgroundColor: TroskyColors.background,
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
        ),
        const SizedBox(width: TroskySpacing.s12),
        Text(
          label,
          style: TroskyTypography.body12SemiBoldH133.copyWith(color: colour),
        ),
      ],
    );
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
