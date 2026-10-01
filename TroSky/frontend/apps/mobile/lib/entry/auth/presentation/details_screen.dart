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
import 'sign_in_screen.dart';
import 'widgets/auth_layout.dart';

/// S-06 Your details (not in Figma; decision 6): name, Gmail address and
/// password for the phone from Welcome, then `POST /auth/register` with
/// the app mode's role.
class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key, required this.phone});

  /// E.164, checked on Welcome.
  final String phone;

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _actionKey = GlobalKey();
  bool _showPassword = false;
  bool _busy = false;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _formError;
  bool _phoneTaken = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final email = _email.text.trim();
    final rules = PasswordRules(_password.text);
    setState(() {
      _nameError = name.length < 2 ? l10n.errorNameRequired : null;
      _emailError = looksLikeEmail(email) ? null : l10n.errorEmailInvalid;
      _passwordError = rules.allMet ? null : l10n.errorPasswordRules;
      _formError = null;
      _phoneTaken = false;
    });
    if (_nameError != null || _emailError != null || _passwordError != null) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final driver = ref.read(appModeControllerProvider).value == AppMode.driver;
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .register(
          RegisterRequest(
            phoneNumber: widget.phone,
            email: email,
            password: _password.text,
            fullName: name,
            role: driver ? RegistrableRole.driver : RegistrableRole.passenger,
          ),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok(:final value):
        await context.pushNamed(
          AppRoute.verifyCode.name,
          extra: CodeRequest(
            purpose: CodePurpose.registration,
            target: value.otpSentTo,
            identifier: widget.phone,
            password: _password.text,
          ),
        );
      case Err(:final failure):
        _show(failure);
    }
  }

  void _show(AppFailure failure) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      switch (failure.code) {
        case 'PHONE_ALREADY_REGISTERED':
          _formError = l10n.errorPhoneTaken;
          _phoneTaken = true;
        case 'EMAIL_ALREADY_REGISTERED':
          _emailError = l10n.errorEmailTaken;
        case 'EMAIL_DOMAIN_NOT_ALLOWED' || 'EMAIL_REQUIRED':
          final domains = failure.details['allowed_domains'];
          _emailError = l10n.errorEmailDomain(
            domains is List && domains.isNotEmpty
                ? domains.map((d) => '@$d').join(', ')
                : '@gmail.com',
          );
        case 'PASSWORD_POLICY_VIOLATION':
          _passwordError = l10n.errorPasswordRules;
        default:
          final fields = failure is ValidationFailure
              ? failure.fieldErrors
              : const <String, List<String>>{};
          if (fields.containsKey('full_name')) {
            _nameError = l10n.errorNameRequired;
          } else if (fields.containsKey('email')) {
            _emailError = l10n.errorEmailInvalid;
          } else if (fields.containsKey('password')) {
            _passwordError = l10n.errorPasswordRules;
          } else if (fields.containsKey('phone_number')) {
            _formError = l10n.errorPhoneInvalid;
          } else {
            _formError = failureMessage(context, failure);
          }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final driver = ref.watch(appModeControllerProvider).value == AppMode.driver;
    final rules = PasswordRules(_password.text);
    return AuthLayout(
      actionKey: _actionKey,
      header: TroskyAuthHeader(
        title: l10n.detailsTitle,
        subtitle: driver ? l10n.detailsSubtitleDriver : l10n.detailsSubtitle,
        onBack: () => context.pop(),
        backLabel: l10n.backLabel,
      ),
      children: [
        _Labelled(
          label: l10n.nameLabel,
          child: TroskyInputField(
            controller: _name,
            label: l10n.nameLabel,
            hintText: l10n.nameHint,
            errorText: _nameError,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
          ),
        ),
        _Labelled(
          label: l10n.emailLabel,
          child: TroskyInputField(
            controller: _email,
            label: l10n.emailLabel,
            hintText: l10n.emailHint,
            helperText: l10n.emailHelper,
            errorText: _emailError,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
        ),
        _Labelled(
          label: l10n.passwordLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TroskyInputField(
                controller: _password,
                label: l10n.passwordLabel,
                hintText: l10n.passwordHint,
                errorText: _passwordError,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                suffix: ShowHideToggle(
                  shown: _showPassword,
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              TroskyChecklist(
                items: [
                  (l10n.passwordRuleLength, rules.length),
                  (l10n.passwordRuleUpper, rules.upper),
                  (l10n.passwordRuleLower, rules.lower),
                  (l10n.passwordRuleDigit, rules.digit),
                ],
              ),
            ],
          ),
        ),
        if (_formError != null)
          FormError(
            _formError!,
            action: _phoneTaken
                ? TroskyTextLink(
                    prompt: '',
                    action: l10n.welcomeSignIn,
                    onPressed: () => context.goNamed(
                      AppRoute.signIn.name,
                      extra: SignInArgs(phone: widget.phone),
                    ),
                  )
                : null,
          ),
        TroskyButton(
          key: _actionKey,
          label: l10n.detailsCreateAccount,
          variant: TroskyButtonVariant.primary,
          loading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// A [SectionLabel] above a field, 8 px apart as on Sign Up.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(label),
        const SizedBox(height: TroskySpacing.s8),
        child,
      ],
    );
  }
}

/// "Show" / "Hide" at the end of a password field. Text, because the design
/// has no eye icon.
class ShowHideToggle extends StatelessWidget {
  const ShowHideToggle({
    super.key,
    required this.shown,
    required this.onPressed,
  });

  final bool shown;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: shown ? l10n.passwordHide : l10n.passwordShow,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Text(
              shown ? l10n.passwordHide : l10n.passwordShow,
              style: TroskyTypography.body13SemiBold.copyWith(
                color: TroskyColors.green,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
