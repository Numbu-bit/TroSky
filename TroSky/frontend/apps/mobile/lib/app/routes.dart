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
import '../l10n/app_localizations.dart';
import '../passenger/home/presentation/home_screen.dart';
import '../passenger/search/domain/journey.dart';
import '../passenger/search/presentation/search_results_screen.dart';
import '../passenger/search/presentation/search_screen.dart';
import '../passenger/search/presentation/trip_view.dart';
import '../passenger/search/search_prefill.dart';
import '../passenger/shell/passenger_shell.dart';
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

  /// The passenger tabs (decision 12): Home (P-01), then placeholders.
  home('/home'),
  trips('/trips'),
  wallet('/wallet'),
  profile('/profile'),

  /// Opened over the tabs, from Home. Placeholders until built.
  /// Search (P-02); `extra` may be a [SearchPrefill].
  search('/search'),

  /// Search Results (P-03); `extra` is a [JourneySearch].
  searchResults('/search/results'),

  /// Seat Selection (P-05, placeholder); `extra` is a [SeatSelectionArgs].
  seatSelection('/seats'),
  notifications('/notifications'),
  favouriteRoutes('/favourite-routes'),
  subscribe('/subscribe'),
  sos('/sos'),

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
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => PassengerShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              route(AppRoute.home, (context, state) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              route(
                AppRoute.trips,
                (context, state) =>
                    PlaceholderScreen(routeName: AppRoute.trips.name),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              route(
                AppRoute.wallet,
                (context, state) =>
                    PlaceholderScreen(routeName: AppRoute.wallet.name),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              route(
                AppRoute.profile,
                (context, state) =>
                    SignedInPlaceholder(routeName: AppRoute.profile.name),
              ),
            ],
          ),
        ],
      ),
      route(
        AppRoute.search,
        (context, state) => SearchScreen(
          prefill: state.extra is SearchPrefill
              ? state.extra! as SearchPrefill
              : null,
        ),
      ),
      GoRoute(
        path: AppRoute.searchResults.path,
        name: AppRoute.searchResults.name,
        // The search only travels in memory; without it, start again.
        redirect: (context, state) =>
            state.extra is JourneySearch ? null : AppRoute.search.path,
        builder: (context, state) =>
            SearchResultsScreen(search: state.extra! as JourneySearch),
      ),
      GoRoute(
        path: AppRoute.seatSelection.path,
        name: AppRoute.seatSelection.name,
        redirect: (context, state) =>
            state.extra is SeatSelectionArgs ? null : AppRoute.home.path,
        builder: (context, state) {
          final args = state.extra! as SeatSelectionArgs;
          final l10n = AppLocalizations.of(context);
          return PushedPlaceholder(
            title: l10n.placeholderSeats,
            detail: l10n.placeholderSeatsTrip(
              vehicleLabel(l10n, args.trip.vehicleType),
              clockTime(args.trip.scheduledDepartureAt),
              args.boardingStopName,
              args.alightingStop.name,
            ),
          );
        },
      ),
      for (final (pushed, title)
          in <(AppRoute, String Function(AppLocalizations))>[
            (AppRoute.notifications, (l10n) => l10n.placeholderNotifications),
            (
              AppRoute.favouriteRoutes,
              (l10n) => l10n.placeholderFavouriteRoutes,
            ),
            (AppRoute.subscribe, (l10n) => l10n.placeholderSubscribe),
            (AppRoute.sos, (l10n) => l10n.placeholderSos),
          ])
        route(
          pushed,
          (context, state) =>
              PushedPlaceholder(title: title(AppLocalizations.of(context))),
        ),
      // Placeholders until these screens are built.
      for (final signedIn in [
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
