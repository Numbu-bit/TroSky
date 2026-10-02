import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../l10n/app_localizations.dart';
import 'offline_banner.dart';
import 'routes.dart';

/// Stand-in for a screen that isn't built yet: shows only its route name.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    // Light background, so dark status bar icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.darkIcons,
      child: Scaffold(body: Center(child: Text(routeName))),
    );
  }
}

/// Stand-in for a signed-in screen (the Profile tab, D-01…): the route
/// name, the offline banner after an offline start (decision 9), and
/// "Sign out" so the flows can be tried end to end.
class SignedInPlaceholder extends ConsumerWidget {
  const SignedInPlaceholder({super.key, required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider).value;
    final offline = session is SessionAuthenticated && session.offline;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.darkIcons,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (offline) const OfflineBanner(),
              Expanded(child: Center(child: Text(routeName))),
              TroskyTextLink(
                prompt: '',
                action: l10n.signOut,
                onPressed: () async {
                  await ref.read(sessionControllerProvider.notifier).signOut();
                  if (context.mounted) context.goNamed(AppRoute.signIn.name);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stand-in for a screen opened on top of the tabs (Search, SOS…): a back
/// button, its [title], and [detail] such as a pre-filled journey.
class PushedPlaceholder extends StatelessWidget {
  const PushedPlaceholder({super.key, required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: TroskySystemUi.darkIcons,
      child: Scaffold(
        backgroundColor: TroskyColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: TroskySpacing.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: l10n.backLabel,
                      onTap: () => context.pop(),
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.pop(),
                        child: SizedBox.square(
                          dimension: 48,
                          child: Center(
                            child: TroskyIcons.back(
                              color: TroskyColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: TroskyTypography.heading20Bold.copyWith(
                            color: TroskyColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(TroskySpacing.s24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (detail != null) ...[
                            Text(
                              detail!,
                              textAlign: TextAlign.center,
                              style: TroskyTypography.heading15Bold.copyWith(
                                color: TroskyColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: TroskySpacing.s8),
                          ],
                          Text(
                            l10n.placeholderSoon,
                            textAlign: TextAlign.center,
                            style: TroskyTypography.body14Regular.copyWith(
                              color: TroskyColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
