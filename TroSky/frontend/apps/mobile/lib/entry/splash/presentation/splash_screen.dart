import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/launch_destination.dart';
import 'launch_destination_provider.dart';

/// S-01 Splash, from `Splash()` in PassengerDesigns.tsx.
///
/// Shows while [launchDestinationProvider] reads the onboarding flag and
/// looks for a saved session, then replaces itself with the destination.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  /// `bottom: 60` on the loading dots.
  static const double _dotsBottom = 60;

  /// Light status bar icons over the gradient, drawn edge to edge.
  static const SystemUiOverlayStyle _systemUi = SystemUiOverlayStyle(
    statusBarColor: TroskyColors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: TroskyColors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(launchDestinationProvider, (_, next) {
      if (next case AsyncData(:final value)) {
        context.goNamed(_routeFor(value).name);
      }
    });

    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemUi,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: TroskyGradients.splash),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecorativeBackdrop.splash(),
              Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _LogoCard(),
                      const SizedBox(height: TroskySpacing.s32),
                      Text(
                        l10n.splashTagline,
                        textAlign: TextAlign.center,
                        style: TroskyTypography.heading17SemiBoldLs1.copyWith(
                          color: TroskyColors.whiteA85,
                        ),
                      ),
                      const SizedBox(height: TroskySpacing.s6),
                      Text(
                        l10n.splashSubtitle,
                        textAlign: TextAlign.center,
                        style: TroskyTypography.body13Regular.copyWith(
                          color: TroskyColors.whiteA55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: _dotsBottom,
                child: Center(
                  child: LoadingDots(
                    // One full 1 → 2 → 3 cycle per minimum splash time.
                    step: splashMinimumDuration ~/ 3,
                    semanticsLabel: l10n.splashLoading,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static AppRoute _routeFor(LaunchDestination destination) =>
      switch (destination) {
        LaunchDestination.onboarding => AppRoute.onboarding,
        LaunchDestination.signIn => AppRoute.signIn,
        LaunchDestination.home => AppRoute.home,
      };
}

/// White card holding the bright logo: radius 32, padding 24 x 32 and the
/// `0 24px 64px rgba(0,0,0,0.25)` shadow.
class _LogoCard extends StatelessWidget {
  const _LogoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: TroskySpacing.s24,
        horizontal: TroskySpacing.s32,
      ),
      decoration: BoxDecoration(
        color: TroskyColors.surface,
        borderRadius: BorderRadius.circular(TroskyRadii.r32),
        boxShadow: TroskyShadows.splashLogoCard,
      ),
      child: const TroskyLogo.bright(),
    );
  }
}
