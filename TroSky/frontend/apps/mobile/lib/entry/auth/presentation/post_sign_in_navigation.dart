import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';

/// Sends the signed-in user where their mode and roles lead: a home, D-01,
/// the approval wait, or one of the two role sheets. Returns a failure when
/// the destination couldn't be worked out (e.g. `/drivers/me` offline), for
/// the caller to show.
Future<AppFailure?> goAfterSignIn(BuildContext context, WidgetRef ref) async {
  final session = ref.read(sessionControllerProvider).value;
  if (session is! SessionAuthenticated) return null;
  final mode = await ref.read(appModeControllerProvider.future);
  final result = await resolvePostSignIn(
    session: session,
    mode: mode,
    drivers: ref.read(driverRepositoryProvider),
  );
  if (!context.mounted) return null;
  switch (result) {
    case Err(:final failure):
      return failure;
    case Ok(:final value):
      switch (value) {
        case PostSignInDestination.passengerHome:
          context.goNamed(AppRoute.home.name);
        case PostSignInDestination.driverOnboarding:
          context.goNamed(AppRoute.driverOnboarding.name);
        case PostSignInDestination.driverAwaitingApproval:
          context.goNamed(AppRoute.driverAwaitingApproval.name);
        case PostSignInDestination.driverHome:
          context.goNamed(AppRoute.driverHome.name);
        case PostSignInDestination.notADriverYet:
          await _notADriverYet(context, ref);
        case PostSignInDestination.driverAccount:
          return _driverAccount(context, ref);
      }
  }
  return null;
}

/// S-10: driver mode, but the account has no driver role.
Future<void> _notADriverYet(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final choice = await _showRoleSheet<bool>(
    context,
    title: l10n.roleNotDriverTitle,
    body: l10n.roleNotDriverBody,
    primary: (l10n.roleBecomeDriver, true),
    secondary: (l10n.roleContinuePassenger, false),
  );
  if (!context.mounted || choice == null) return;
  if (choice) {
    // D-01 will call POST /drivers/me, which adds the driver role.
    context.goNamed(AppRoute.driverOnboarding.name);
  } else {
    await ref.read(appModeControllerProvider.notifier).set(AppMode.passenger);
    if (context.mounted) await goAfterSignIn(context, ref);
  }
}

/// Passenger mode, but a driver-only account.
Future<AppFailure?> _driverAccount(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final choice = await _showRoleSheet<bool>(
    context,
    title: l10n.roleDriverAccountTitle,
    body: l10n.roleDriverAccountBody,
    primary: (l10n.roleSwitchToDriver, true),
    secondary: (l10n.roleUseAnotherAccount, false),
  );
  if (!context.mounted || choice == null) return null;
  if (choice) {
    await ref.read(appModeControllerProvider.notifier).set(AppMode.driver);
    if (context.mounted) return goAfterSignIn(context, ref);
  } else {
    await ref.read(sessionControllerProvider.notifier).signOut();
    if (context.mounted) context.goNamed(AppRoute.signIn.name);
  }
  return null;
}

/// A bottom sheet with a title, a sentence and two choices. It can't be
/// swiped away: the user is signed in and has to pick a way on.
Future<T?> _showRoleSheet<T>(
  BuildContext context, {
  required String title,
  required String body,
  required (String, T) primary,
  required (String, T) secondary,
}) => showModalBottomSheet<T>(
  context: context,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: TroskyColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(TroskyRadii.r24)),
  ),
  builder: (context) => PopScope(
    canPop: false,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TroskySpacing.s24,
          TroskySpacing.s28,
          TroskySpacing.s24,
          TroskySpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: TroskyTypography.heading20Bold.copyWith(
                  color: TroskyColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: TroskySpacing.s8),
            Text(
              body,
              style: TroskyTypography.body14Regular.copyWith(
                color: TroskyColors.textSecondary,
              ),
            ),
            const SizedBox(height: TroskySpacing.s24),
            TroskyButton(
              label: primary.$1,
              variant: TroskyButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(primary.$2),
            ),
            const SizedBox(height: TroskySpacing.s12),
            TroskyButton(
              label: secondary.$1,
              variant: TroskyButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(secondary.$2),
            ),
          ],
        ),
      ),
    ),
  ),
);
