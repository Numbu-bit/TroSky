// S-09 Reset password. Public (no session required).
//
// S-09a: enter identifier → backend sends a 6-digit code (same response
// whether or not the account exists, to avoid existence leaks).
// S-09b: enter target + code + new password → backend rotates the
// password and signs every session out.

import 'package:flutter/material.dart';
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
import '../domain/account_args.dart';

/// S-09a — request a reset code for an identifier.
class RequestResetScreen extends ConsumerStatefulWidget {
  const RequestResetScreen({super.key});

  @override
  ConsumerState<RequestResetScreen> createState() => _RequestResetScreenState();
}

class _RequestResetScreenState extends ConsumerState<RequestResetScreen> {
  final _identifier = TextEditingController();
  bool _submitting = false;
  bool _sent = false;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _identifier.text.trim();
    if (value.isEmpty) return;
    setState(() => _submitting = true);
    ref
        .read(telemetryProvider)
        .emit(TelemetryEvent('password_reset_requested'));
    await ref
        .read(authRepositoryProvider)
        .forgotPassword(ForgotPasswordRequest(identifier: value));
    if (!mounted) return;
    // Always show the same confirmation to avoid leaking account
    // existence (matches the backend's response for both known and
    // unknown identifiers).
    setState(() {
      _submitting = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TroskySecureScreen(
      child: AnnotatedRegion(
        value: TroskySystemUi.darkIcons,
        child: Scaffold(
          backgroundColor: TroskyColors.background,
          appBar: AppBar(
            title: Text(l10n.resetRequestTitle),
            backgroundColor: TroskyColors.surface,
            foregroundColor: TroskyColors.ink,
            elevation: 0,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(TroskySpacing.s16),
              children: [
                Text(
                  l10n.resetRequestInstruction,
                  style: TroskyTypography.body14Regular,
                ),
                const SizedBox(height: TroskySpacing.s12),
                TextField(
                  controller: _identifier,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.resetIdentifierLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_sent) ...[
                  const SizedBox(height: TroskySpacing.s12),
                  Text(
                    l10n.resetRequestNeutralConfirmation,
                    style: TroskyTypography.body14Regular.copyWith(
                      color: TroskyColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: TroskySpacing.s8),
                  TextButton(
                    onPressed: () {
                      context.pushNamed(
                        AppRoute.resetPasswordNew.name,
                        extra: ResetPasswordArgs(
                          target: _identifier.text.trim(),
                        ),
                      );
                    },
                    child: Text(l10n.resetIHaveACode),
                  ),
                ],
                const SizedBox(height: TroskySpacing.s16),
                TroskyButton(
                  label: l10n.resetRequestCta,
                  variant: TroskyButtonVariant.primary,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// S-09b — enter the code + new password. Deep-linkable via
/// `trosky://reset?target=...&code=...` (routing wires that later).
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key, required this.args});
  final ResetPasswordArgs args;

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  late final TextEditingController _code;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.args.code ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid {
    final pw = _password.text;
    return _code.text.trim().isNotEmpty &&
        pw.length >= 8 &&
        pw.contains(RegExp('[A-Za-z]')) &&
        pw.contains(RegExp('[0-9]')) &&
        _confirm.text == pw;
  }

  Future<void> _submit() async {
    if (!_valid) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final result = await ref
        .read(authRepositoryProvider)
        .resetPassword(
          ResetPasswordRequest(
            target: widget.args.target,
            code: _code.text.trim(),
            newPassword: _password.text,
          ),
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref
            .read(telemetryProvider)
            .emit(TelemetryEvent('password_reset_completed'));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).resetSuccess)),
        );
        // Backend signed every session out; land on Sign in.
        context.goNamed(AppRoute.signIn.name);
      case Err(:final failure):
        setState(() {
          _submitting = false;
          _failure = failure.code;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TroskySecureScreen(
      child: AnnotatedRegion(
        value: TroskySystemUi.darkIcons,
        child: Scaffold(
          backgroundColor: TroskyColors.background,
          appBar: AppBar(
            title: Text(l10n.resetNewTitle),
            backgroundColor: TroskyColors.surface,
            foregroundColor: TroskyColors.ink,
            elevation: 0,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(TroskySpacing.s16),
              children: [
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.resetCodeLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: TroskySpacing.s12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.resetNewPasswordLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: TroskySpacing.s12),
                TextField(
                  controller: _confirm,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.resetConfirmPasswordLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_failure != null) ...[
                  const SizedBox(height: TroskySpacing.s8),
                  Text(
                    l10n.resetFailure,
                    style: TroskyTypography.body14Regular.copyWith(
                      color: TroskyColors.red,
                    ),
                  ),
                ],
                const SizedBox(height: TroskySpacing.s16),
                TroskyButton(
                  label: l10n.resetNewCta,
                  variant: TroskyButtonVariant.primary,
                  onPressed: (_valid && !_submitting) ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
