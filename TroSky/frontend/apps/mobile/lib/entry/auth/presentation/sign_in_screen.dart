import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/auth_inputs.dart';
import 'details_screen.dart';
import 'failure_messages.dart';
import 'post_sign_in_navigation.dart';
import 'welcome_screen.dart';
import 'widgets/auth_layout.dart';

/// How S-05 opens.
class SignInArgs {
  const SignInArgs({this.useEmail = false, this.phone});

  /// Start with the email field (from "Continue with Email").
  final bool useEmail;

  /// Fill in the phone (e.g. after PHONE_ALREADY_REGISTERED).
  final String? phone;
}

/// S-05 Sign in (not in Figma): phone or email and password. "Forgot
/// password? Sign in with a code" switches to a code request for a phone
/// (decision 10).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.args = const SignInArgs()});

  final SignInArgs args;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final _phone = TextEditingController(
    text: widget.args.phone == null ? '' : _national(widget.args.phone!),
  );
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _actionKey = GlobalKey();
  late bool _useEmail = widget.args.useEmail;
  bool _codeMode = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _identifierError;
  String? _passwordError;
  String? _formError;

  /// `+233241234567` → `024 123 4567`, to fill the field.
  static String _national(String e164) => e164.startsWith('+233')
      ? '0${e164.substring(4, 6)} ${e164.substring(6, 9)} ${e164.substring(9)}'
      : e164;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearErrors() {
    _identifierError = null;
    _passwordError = null;
    _formError = null;
  }

  Future<void> _signIn() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final identifier = _useEmail ? _email.text.trim() : ghanaPhone(_phone.text);
    setState(() {
      _clearErrors();
      if (identifier == null) {
        _identifierError = l10n.errorPhoneInvalid;
      } else if (_useEmail && !looksLikeEmail(identifier)) {
        _identifierError = l10n.errorEmailInvalid;
      }
      if (_password.text.isEmpty) _passwordError = l10n.errorPasswordRequired;
    });
    if (_identifierError != null || _passwordError != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .signIn(identifier: identifier!, password: _password.text);
    if (!mounted) return;
    switch (result) {
      case Ok():
        // Signed in: the next step (a route or a modal sheet) takes over,
        // so the button stops spinning.
        setState(() => _busy = false);
        final failure = await goAfterSignIn(context, ref);
        if (failure != null && mounted) {
          setState(() => _formError = failureMessage(context, failure));
        }
      case Err(:final failure) when failure.code == 'ACCOUNT_NOT_VERIFIED':
        final target = failure.details['target'] as String? ?? identifier;
        await context.pushNamed(
          AppRoute.verifyCode.name,
          extra: CodeRequest(
            purpose: CodePurpose.unverifiedAccount,
            target: target,
            identifier: identifier,
            password: _password.text,
            alreadySent: false,
          ),
        );
      case Err(:final failure):
        setState(() => _formError = failureMessage(context, failure));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _sendCode() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final phone = ghanaPhone(_phone.text);
    setState(() {
      _clearErrors();
      if (phone == null) _identifierError = l10n.errorPhoneInvalid;
    });
    if (phone == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .requestSignInCode(phone);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok():
        await context.pushNamed(
          AppRoute.verifyCode.name,
          extra: CodeRequest(purpose: CodePurpose.signIn, target: phone),
        );
      case Err(:final failure):
        setState(() => _formError = failureMessage(context, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canPop = context.canPop();
    final header = TroskyAuthHeader(
      title: _codeMode ? l10n.signInCodeTitle : l10n.signInTitle,
      subtitle: _codeMode ? l10n.signInCodeSubtitle : l10n.signInSubtitle,
      onBack: canPop ? () => context.pop() : null,
      backLabel: l10n.backLabel,
    );
    final phoneField = PhoneField(
      controller: _phone,
      errorText: _identifierError,
      textInputAction: _codeMode ? TextInputAction.done : TextInputAction.next,
      onSubmitted: _codeMode ? (_) => _sendCode() : null,
    );

    if (_codeMode) {
      return AuthLayout(
        actionKey: _actionKey,
        header: header,
        children: [
          phoneField,
          if (_formError != null) FormError(_formError!),
          TroskyButton(
            key: _actionKey,
            label: l10n.signInSendCode,
            variant: TroskyButtonVariant.primary,
            loading: _busy,
            onPressed: _sendCode,
          ),
          TroskyTextLink(
            prompt: '',
            action: l10n.signInUsePassword,
            onPressed: () => setState(() {
              _clearErrors();
              _codeMode = false;
            }),
          ),
        ],
      );
    }

    return AuthLayout(
      actionKey: _actionKey,
      header: header,
      children: [
        if (_useEmail)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionLabel(l10n.emailLabel),
              const SizedBox(height: TroskySpacing.s8),
              TroskyInputField(
                controller: _email,
                label: l10n.emailLabel,
                hintText: l10n.emailHint,
                errorText: _identifierError,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
              ),
            ],
          )
        else
          phoneField,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionLabel(l10n.passwordLabel),
            const SizedBox(height: TroskySpacing.s8),
            TroskyInputField(
              controller: _password,
              label: l10n.passwordLabel,
              errorText: _passwordError,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _signIn(),
              suffix: ShowHideToggle(
                shown: _showPassword,
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ],
        ),
        if (_formError != null) FormError(_formError!),
        TroskyButton(
          key: _actionKey,
          label: l10n.signInButton,
          variant: TroskyButtonVariant.primary,
          loading: _busy,
          onPressed: _signIn,
        ),
        Column(
          children: [
            TroskyTextLink(
              prompt: '',
              action: _useEmail ? l10n.signInUsePhone : l10n.signInUseEmail,
              onPressed: () => setState(() {
                _clearErrors();
                _useEmail = !_useEmail;
              }),
            ),
            TroskyTextLink(
              prompt: l10n.signInForgotPrompt,
              action: l10n.signInWithCode,
              onPressed: () => setState(() {
                _clearErrors();
                _codeMode = true;
              }),
            ),
            TroskyTextLink(
              prompt: l10n.signInNewPrompt,
              action: l10n.signInCreateAccount,
              onPressed: () => context.goNamed(AppRoute.welcome.name),
            ),
          ],
        ),
      ],
    );
  }
}
