import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../debug/design_gallery.dart';
import '../entry/splash/presentation/splash_screen.dart';
import 'placeholder_screen.dart';

part 'routes.g.dart';

/// Every route of the mobile app. Navigate with `context.goNamed(route.name)`.
enum AppRoute {
  splash('/'),
  onboarding('/onboarding'),
  signIn('/sign-in'),
  home('/home'),

  /// Debug builds only: every trosky_ui token and component. Open it with
  /// `flutter run --route /_gallery`.
  gallery('/_gallery');

  const AppRoute(this.path);

  final String path;
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: AppRoute.splash.path,
        name: AppRoute.splash.name,
        builder: (context, state) => const SplashScreen(),
      ),
      // Placeholders until these screens are built.
      for (final route in [AppRoute.onboarding, AppRoute.signIn, AppRoute.home])
        GoRoute(
          path: route.path,
          name: route.name,
          builder: (context, state) => PlaceholderScreen(routeName: route.name),
        ),
      if (kDebugMode)
        GoRoute(
          path: AppRoute.gallery.path,
          name: AppRoute.gallery.name,
          builder: (context, state) => const DesignGallery(),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
