import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../l10n/app_localizations.dart';
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

/// Stand-in for a signed-in screen (Home, D-01…): the route name, the
/// offline banner after an offline start (decision 9), and "Sign out" so
/// the flows can be tried end to end.
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
              if (offline)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    color: TroskyColors.amberA15,
                    padding: const EdgeInsets.symmetric(
                      horizontal: TroskySpacing.s16,
                      vertical: TroskySpacing.s8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.offlineBanner,
                            style: TroskyTypography.body13Regular.copyWith(
                              color: TroskyColors.textPrimary,
                            ),
                          ),
                        ),
                        TroskyTextLink(
                          prompt: '',
                          action: l10n.offlineRetry,
                          onPressed: () => ref
                              .read(sessionControllerProvider.notifier)
                              .restore(),
                        ),
                      ],
                    ),
                  ),
                ),
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
