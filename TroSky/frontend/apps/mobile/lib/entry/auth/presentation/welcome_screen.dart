import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/auth_inputs.dart';
import 'sign_in_screen.dart';
import 'widgets/auth_layout.dart';

/// S-04 Welcome, from `P4_SignUp` in PassengerDesigns.tsx: the phone number
/// that starts sign-up. "Continue" checks it on the device and moves on to
/// "Your details"; nothing is sent yet (decisions 6 and 11).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _phone = TextEditingController();
  final _actionKey = GlobalKey();
  String? _phoneError;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _continue() {
    final phone = ghanaPhone(_phone.text);
    setState(
      () => _phoneError = phone == null
          ? AppLocalizations.of(context).errorPhoneInvalid
          : null,
    );
    if (phone == null) return;
    FocusScope.of(context).unfocus();
    context.pushNamed(AppRoute.details.name, extra: phone);
  }

  Future<void> _setMode(AppMode mode) =>
      ref.read(appModeControllerProvider.notifier).set(mode);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final driver = ref.watch(appModeControllerProvider).value == AppMode.driver;
    return AuthLayout(
      actionKey: _actionKey,
      header: TroskyAuthHeader(
        title: l10n.welcomeTitle,
        subtitle: l10n.welcomeSubtitle,
      ),
      children: [
        PhoneField(
          controller: _phone,
          errorText: _phoneError,
          onSubmitted: (_) => _continue(),
        ),
        TroskyButton(
          key: _actionKey,
          label: l10n.welcomeContinue,
          variant: TroskyButtonVariant.primary,
          onPressed: _continue,
        ),
        TroskyTextDivider(l10n.welcomeOrContinueWith),
        TroskyButton(
          label: l10n.welcomeContinueWithEmail,
          variant: TroskyButtonVariant.outline,
          leading: TroskyIcons.mail(color: TroskyColors.textPrimary),
          onPressed: () => context.pushNamed(
            AppRoute.signIn.name,
            extra: const SignInArgs(useEmail: true),
          ),
        ),
        // Display only: Ghana Card verification has no endpoint yet (G17).
        TroskyInfoNote(
          emoji: '🪪',
          before: l10n.welcomeGhanaCardBefore,
          highlight: l10n.welcomeGhanaCardHighlight,
          after: l10n.welcomeGhanaCardAfter,
        ),
        // Not in Figma (decisions 6 and 7).
        Column(
          children: [
            TroskyTextLink(
              prompt: l10n.welcomeHaveAccount,
              action: l10n.welcomeSignIn,
              onPressed: () => context.pushNamed(AppRoute.signIn.name),
            ),
            if (driver)
              TroskyTextLink(
                prompt: l10n.welcomeDriverModePrompt,
                action: l10n.welcomeDriverModeAction,
                onPressed: () => _setMode(AppMode.passenger),
              )
            else
              TroskyTextLink(
                prompt: l10n.welcomeDriverPrompt,
                action: l10n.welcomeDriverAction,
                onPressed: () => _setMode(AppMode.driver),
              ),
          ],
        ),
      ],
    );
  }
}

/// The P4 phone field: "PHONE NUMBER", the 🇬🇭 +233 prefix (a one-item
/// country list) and the number.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.errorText,
    this.onSubmitted,
    this.focusNode,
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(l10n.phoneLabel),
        const SizedBox(height: TroskySpacing.s8),
        TroskyInputField(
          controller: controller,
          focusNode: focusNode,
          label: l10n.phoneLabel,
          hintText: l10n.phoneHint,
          errorText: errorText,
          keyboardType: TextInputType.phone,
          textInputAction: textInputAction,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()\-]')),
          ],
          onSubmitted: onSubmitted,
          prefix: TroskyPhonePrefix(
            semanticsLabel: l10n.phoneCountry,
            onTap: () => _showCountries(context),
          ),
        ),
      ],
    );
  }

  static Future<void> _showCountries(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: TroskyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TroskyRadii.r24),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TroskySpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.countrySheetTitle,
                  style: TroskyTypography.heading18Bold.copyWith(
                    color: TroskyColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: TroskySpacing.s16),
              Semantics(
                selected: true,
                button: true,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        const Text(
                          '🇬🇭',
                          style: TroskyTypography.body18Regular,
                        ),
                        const SizedBox(width: TroskySpacing.s12),
                        Expanded(
                          child: Text(
                            l10n.countryGhana,
                            style: TroskyTypography.body14SemiBold.copyWith(
                              color: TroskyColors.textPrimary,
                            ),
                          ),
                        ),
                        TroskyIcons.check(color: TroskyColors.green),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: TroskySpacing.s8),
              Text(
                l10n.countryOnlyGhana,
                style: TroskyTypography.body12Regular.copyWith(
                  color: TroskyColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
