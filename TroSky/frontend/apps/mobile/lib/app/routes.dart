import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../debug/design_gallery.dart';
import '../entry/auth/domain/auth_inputs.dart';
import '../entry/auth/presentation/details_screen.dart';
import '../entry/auth/presentation/sign_in_screen.dart';
import '../entry/auth/presentation/verify_code_screen.dart';
import '../entry/auth/presentation/welcome_screen.dart';
import '../entry/onboarding/presentation/onboarding_screen.dart';
import '../entry/splash/presentation/splash_screen.dart';
import 'placeholder_screen.dart';

part 'routes.g.dart';

/// Every route of the mobile app. Navigate with `context.goNamed(route.name)`.
enum AppRoute {
  splash('/'),
  onboarding('/onboarding'),

  /// S-04, the start of sign-up.
  welcome('/welcome'),

  /// S-06; `extra` is the E.164 phone from Welcome.
  details('/welcome/details'),

  /// S-07; `extra` is a [CodeRequest].
  verifyCode('/verify-code'),

  /// S-05; `extra` may be a [SignInArgs].
  signIn('/sign-in'),

  home('/home'),

  /// D-01, driver registration (placeholder).
  driverOnboarding('/driver/onboarding'),
  driverAwaitingApproval('/driver/awaiting-approval'),
  driverHome('/driver/home'),

  /// Debug builds only: every trosky_ui token and component. Open it with
  /// `flutter run --route /_gallery`.
  gallery('/_gallery');

  const AppRoute(this.path);

  final String path;
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  GoRoute route(AppRoute route, GoRouterWidgetBuilder builder) =>
      GoRoute(path: route.path, name: route.name, builder: builder);

  final router = GoRouter(
    routes: [
      route(AppRoute.splash, (context, state) => const SplashScreen()),
      route(AppRoute.onboarding, (context, state) => const OnboardingScreen()),
      route(AppRoute.welcome, (context, state) => const WelcomeScreen()),
      GoRoute(
        path: AppRoute.details.path,
        name: AppRoute.details.name,
        // The phone only travels in memory; without it, start again.
        redirect: (context, state) =>
            state.extra is String ? null : AppRoute.welcome.path,
        builder: (context, state) =>
            DetailsScreen(phone: state.extra! as String),
      ),
      GoRoute(
        path: AppRoute.verifyCode.path,
        name: AppRoute.verifyCode.name,
        redirect: (context, state) =>
            state.extra is CodeRequest ? null : AppRoute.signIn.path,
        builder: (context, state) =>
            VerifyCodeScreen(request: state.extra! as CodeRequest),
      ),
      route(
        AppRoute.signIn,
        (context, state) => SignInScreen(
          args: state.extra is SignInArgs
              ? state.extra! as SignInArgs
              : const SignInArgs(),
        ),
      ),
      // Placeholders until these screens are built.
      for (final signedIn in [
        AppRoute.home,
        AppRoute.driverOnboarding,
        AppRoute.driverAwaitingApproval,
        AppRoute.driverHome,
      ])
        route(
          signedIn,
          (context, state) => SignedInPlaceholder(routeName: signedIn.name),
        ),
      if (kDebugMode)
        route(AppRoute.gallery, (context, state) => const DesignGallery()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
