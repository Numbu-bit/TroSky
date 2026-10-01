import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/auth_inputs.dart';
import 'failure_messages.dart';
import 'post_sign_in_navigation.dart';
import 'widgets/auth_layout.dart';

/// The backend's resend cooldown (`OTP_RESEND_COOLDOWN_SECONDS`). A 429
/// says how long is left; a successful send doesn't, so this is assumed.
const Duration resendCooldown = Duration(seconds: 60);

/// S-07 Code verification (not in Figma): six boxes for the code sent to
/// [CodeRequest.target], used after registering, for an unverified account,
/// and for "Sign in with a code".
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key, required this.request});

  final CodeRequest request;

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _code = TextEditingController();
  final _actionKey = GlobalKey();
  Timer? _ticker;
  int _wait = 0;
  bool _busy = false;
  bool _sending = false;
  String? _error;
  String? _notice;
  bool _noAccount = false;

  CodeRequest get _request => widget.request;

  @override
  void initState() {
    super.initState();
    if (_request.alreadySent) {
      _startCooldown(resendCooldown);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resend());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown(Duration wait) {
    _ticker?.cancel();
    setState(() => _wait = wait.inSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _wait--);
      if (_wait <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    if (_sending || _wait > 0) return;
    setState(() {
      _sending = true;
      _error = null;
      _notice = null;
    });
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .resendCode(target: _request.target, purpose: _request.otpPurpose);
    if (!mounted) return;
    setState(() => _sending = false);
    switch (result) {
      case Ok():
        _code.clear();
        setState(() => _notice = AppLocalizations.of(context).codeResent);
        _startCooldown(resendCooldown);
      case Err(:final failure):
        final wait = waitFor(failure);
        if (wait != null) {
          // A code was sent a moment ago; wait it out.
          _startCooldown(wait);
        } else {
          setState(() => _error = failureMessage(context, failure));
        }
    }
  }

  Future<void> _verify() async {
    final code = _code.text;
    if (_busy || code.length < 6) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _noAccount = false;
    });
    final session = ref.read(sessionControllerProvider.notifier);
    final Result<UserResponse> result = switch (_request.purpose) {
      CodePurpose.registration ||
      CodePurpose.unverifiedAccount => await session.verifyRegistration(
        otpTarget: _request.target,
        code: code,
        identifier: _request.identifier!,
        password: _request.password!,
      ),
      CodePurpose.signIn => await session.signInWithOtp(
        target: _request.target,
        code: code,
      ),
    };
    if (!mounted) return;
    switch (result) {
      case Ok():
        // Signed in: the next step (a route or a modal sheet) takes over,
        // so the button stops spinning.
        setState(() => _busy = false);
        final failure = await goAfterSignIn(context, ref);
        if (failure != null && mounted) {
          setState(() => _error = failureMessage(context, failure));
        }
      case Err(:final failure)
          when failure is NotFoundFailure && failure.code == 'NOT_FOUND':
        setState(() {
          _error = AppLocalizations.of(context).errorNoAccount;
          _noAccount = true;
        });
      case Err(:final failure):
        setState(() => _error = failureMessage(context, failure));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final masked = maskTarget(_request.target);
    final byEmail = _request.target.contains('@');
    return AuthLayout(
      actionKey: _actionKey,
      header: TroskyAuthHeader(
        title: l10n.codeTitle,
        subtitle: byEmail
            ? l10n.codeSentByEmail(masked)
            : l10n.codeSentByText(masked),
        onBack: () => context.pop(),
        backLabel: l10n.backLabel,
      ),
      children: [
        TroskyOtpInput(
          controller: _code,
          label: l10n.codeFieldLabel,
          hasError: _error != null && !_noAccount,
          enabled: !_busy,
          onCompleted: (_) => _verify(),
        ),
        if (_error != null)
          FormError(
            _error!,
            action: _noAccount
                ? TroskyTextLink(
                    prompt: '',
                    action: l10n.signInCreateAccount,
                    onPressed: () => context.goNamed(AppRoute.welcome.name),
                  )
                : null,
          )
        else if (_notice != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _notice!,
              textAlign: TextAlign.center,
              style: TroskyTypography.body13Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
          ),
        ListenableBuilder(
          listenable: _code,
          builder: (context, _) => TroskyButton(
            key: _actionKey,
            label: l10n.codeVerify,
            variant: TroskyButtonVariant.primary,
            loading: _busy,
            onPressed: _code.text.length == 6 ? _verify : null,
          ),
        ),
        if (_wait > 0)
          Semantics(
            liveRegion: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: Text(
                  l10n.codeResendIn(_wait),
                  style: TroskyTypography.body13Regular.copyWith(
                    color: TroskyColors.textSecondary,
                  ),
                ),
              ),
            ),
          )
        else ...[
          TroskyTextLink(
            prompt: l10n.codeResendPrompt,
            action: l10n.codeResend,
            onPressed: _sending ? null : _resend,
          ),
          if (_request.purpose == CodePurpose.signIn)
            Text(
              l10n.codeNoAccountHint,
              textAlign: TextAlign.center,
              style: TroskyTypography.body12Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
        ],
      ],
    );
  }
}
