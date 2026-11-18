import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trosky_api/trosky_api.dart';

import '../debug/design_gallery.dart';
import '../entry/auth/domain/auth_inputs.dart';
import '../entry/auth/presentation/details_screen.dart';
import '../entry/auth/presentation/sign_in_screen.dart';
import '../entry/auth/presentation/verify_code_screen.dart';
import '../entry/auth/presentation/welcome_screen.dart';
import '../entry/onboarding/presentation/onboarding_screen.dart';
import '../entry/splash/presentation/splash_screen.dart';
import '../l10n/app_localizations.dart';
import '../passenger/booking/presentation/payment_screen.dart';
import '../passenger/home/presentation/home_screen.dart';
import '../passenger/search/domain/journey.dart';
import '../passenger/search/presentation/search_results_screen.dart';
import '../passenger/search/presentation/search_screen.dart';
import '../passenger/search/search_prefill.dart';
import '../passenger/seats/domain/seat_selection_args.dart';
import '../passenger/seats/presentation/seat_selection_screen.dart';
import '../passenger/shell/passenger_shell.dart';
import '../passenger/tracking/domain/track_trip_args.dart';
import '../passenger/tracking/presentation/track_trip_screen.dart';
import '../passenger/trips/domain/ticket_args.dart';
import '../passenger/trips/domain/trip_details_args.dart';
import '../passenger/trips/presentation/booking_details_screen.dart';
import '../passenger/trips/presentation/ticket_screen.dart';
import '../passenger/trips/presentation/trip_details_screen.dart';
import '../passenger/trips/presentation/trips_screen.dart';
import '../passenger/safety/domain/safety_args.dart';
import '../passenger/safety/presentation/rate_screen.dart';
import '../passenger/safety/presentation/report_screen.dart';
import '../passenger/safety/presentation/sos_screen.dart';
import '../passenger/wallet/domain/wallet_args.dart';
import '../passenger/wallet/presentation/top_up_screen.dart';
import '../passenger/wallet/presentation/wallet_screen.dart';
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

  /// The passenger tabs (decision 12): Home (P-01), Trips (P-15), then
  /// placeholders.
  home('/home'),
  trips('/trips'),
  wallet('/wallet'),
  profile('/profile'),

  /// Opened over the tabs, from Home. Placeholders until built.
  /// Search (P-02); `extra` may be a [SearchPrefill].
  search('/search'),

  /// Search Results (P-03); `extra` is a [JourneySearch].
  searchResults('/search/results'),

  /// Seat Selection (P-05); `extra` is a [SeatSelectionArgs].
  seatSelection('/seats'),

  /// Payment (P-07, placeholder): a held booking; `extra` is a
  /// [PaymentArgs].
  payment('/payment'),

  /// Booking details (P-16), from Trips; `extra` may be the
  /// [BookingResponse] as listed.
  bookingDetails('/bookings/:bookingId'),

  /// Ticket / Boarding Pass (P-10): one QR per seat, swipeable;
  /// `extra` is a [TicketArgs]. Gated by `TICKET_QR_ENABLED`.
  ticket('/bookings/:bookingId/ticket'),

  /// Trip details (P-04, derived): the whole trip around a booking
  /// (route, stops, vehicle, driver, seats). `extra` is a
  /// [TripDetailsArgs]. Gated by `TRIP_DETAILS_ENABLED`.
  tripDetails('/bookings/:bookingId/trip-details'),

  /// Live tracking (P-11): full-screen map + bottom card. `extra` is a
  /// [TrackTripArgs]. Gated by `TRIP_TRACKING_ENABLED`.
  trackTrip('/bookings/:bookingId/track'),

  /// Top up (P-18, derived): one screen to add GHS to the in-app wallet
  /// via MoMo. `extra` is a [TopUpArgs]. Gated by `WALLET_ENABLED`.
  topUp('/wallet/top-up'),

  /// SOS (P-12): full-screen Emergency. `extra` may be a [SosArgs] (trip
  /// context). Gated by `SOS_ENABLED`.
  sosAlert('/sos/alert'),

  /// Report (P-13): report an issue on a completed trip. `extra` is a
  /// [ReportArgs]. Gated by `REPORT_ENABLED`.
  report('/bookings/:bookingId/report'),

  /// Rate (P-14): rate a completed trip. `extra` is a [RateArgs]. Gated
  /// by `RATE_ENABLED`.
  rate('/bookings/:bookingId/rate'),
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
              route(AppRoute.trips, (context, state) => const TripsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              route(
                AppRoute.wallet,
                (context, state) => walletEnabled
                    ? const WalletScreen()
                    : PlaceholderScreen(routeName: AppRoute.wallet.name),
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
        builder: (context, state) =>
            SeatSelectionScreen(args: state.extra! as SeatSelectionArgs),
      ),
      GoRoute(
        path: AppRoute.payment.path,
        name: AppRoute.payment.name,
        // The booking only travels in memory; Home's card opens a held one.
        redirect: (context, state) =>
            state.extra is PaymentArgs ? null : AppRoute.home.path,
        builder: (context, state) =>
            PaymentScreen(args: state.extra! as PaymentArgs),
      ),
      GoRoute(
        path: AppRoute.bookingDetails.path,
        name: AppRoute.bookingDetails.name,
        builder: (context, state) => BookingDetailsScreen(
          bookingId: state.pathParameters['bookingId']!,
          initial: state.extra is BookingResponse
              ? state.extra! as BookingResponse
              : null,
        ),
      ),
      GoRoute(
        path: AppRoute.ticket.path,
        name: AppRoute.ticket.name,
        redirect: (context, state) =>
            state.extra is TicketArgs ? null : AppRoute.trips.path,
        builder: (context, state) =>
            TicketScreen(args: state.extra! as TicketArgs),
      ),
      GoRoute(
        path: AppRoute.tripDetails.path,
        name: AppRoute.tripDetails.name,
        redirect: (context, state) =>
            state.extra is TripDetailsArgs ? null : AppRoute.trips.path,
        builder: (context, state) =>
            TripDetailsScreen(args: state.extra! as TripDetailsArgs),
      ),
      GoRoute(
        path: AppRoute.trackTrip.path,
        name: AppRoute.trackTrip.name,
        redirect: (context, state) =>
            state.extra is TrackTripArgs ? null : AppRoute.trips.path,
        builder: (context, state) =>
            TrackTripScreen(args: state.extra! as TrackTripArgs),
      ),
      GoRoute(
        path: AppRoute.topUp.path,
        name: AppRoute.topUp.name,
        redirect: (context, state) => state.extra is TopUpArgs
            ? (walletEnabled ? null : AppRoute.wallet.path)
            : AppRoute.wallet.path,
        builder: (context, state) =>
            TopUpScreen(args: state.extra! as TopUpArgs),
      ),
      GoRoute(
        path: AppRoute.sosAlert.path,
        name: AppRoute.sosAlert.name,
        redirect: (context, state) => sosEnabled ? null : AppRoute.home.path,
        builder: (context, state) => SosScreen(
          args: state.extra is SosArgs
              ? state.extra! as SosArgs
              : const SosArgs(),
        ),
      ),
      GoRoute(
        path: AppRoute.report.path,
        name: AppRoute.report.name,
        redirect: (context, state) => state.extra is ReportArgs
            ? (reportEnabled ? null : AppRoute.trips.path)
            : AppRoute.trips.path,
        builder: (context, state) =>
            ReportScreen(args: state.extra! as ReportArgs),
      ),
      GoRoute(
        path: AppRoute.rate.path,
        name: AppRoute.rate.name,
        redirect: (context, state) => state.extra is RateArgs
            ? (rateEnabled ? null : AppRoute.trips.path)
            : AppRoute.trips.path,
        builder: (context, state) => RateScreen(args: state.extra! as RateArgs),
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
