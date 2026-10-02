import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/entry/auth/presentation/sign_in_screen.dart';
import 'package:mobile/passenger/home/data/home_store.dart';
import 'package:mobile/passenger/home/data/location_service.dart';
import 'package:mobile/passenger/home/presentation/greeting.dart';
import 'package:mobile/passenger/home/presentation/home_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../entry/auth/auth_helpers.dart' show link, tapVisible;
import '../../helpers/fakes.dart';
import 'home_helpers.dart';

/// Refresh fails offline; everything else is the mock.
class _OfflineAuth implements AuthRepository {
  _OfflineAuth(this._inner);

  final AuthRepository _inner;

  @override
  Future<Result<TokenPairResponse>> refresh(RefreshRequest request) async =>
      const Err(NetworkFailure());

  @override
  Future<Result<RegisterResponse>> register(RegisterRequest r) =>
      _inner.register(r);
  @override
  Future<Result<MessageResponse>> verifyOtp(VerifyOtpRequest r) =>
      _inner.verifyOtp(r);
  @override
  Future<Result<MessageResponse>> resendOtp(ResendOtpRequest r) =>
      _inner.resendOtp(r);
  @override
  Future<Result<TokenPairResponse>> login(LoginRequest r) => _inner.login(r);
  @override
  Future<Result<TokenPairResponse>> otpLogin(OtpLoginRequest r) =>
      _inner.otpLogin(r);
  @override
  Future<Result<void>> logout() => _inner.logout();
}

Iterable<TroskyBusPin> _pins(WidgetTester tester) =>
    tester.widgetList<TroskyBusPin>(find.byType(TroskyBusPin));

void main() {
  group('greeting', () {
    test('morning from 5:00, afternoon from 12:00, evening from 17:00', () {
      for (final (hour, part) in [
        (4, DayPart.evening),
        (5, DayPart.morning),
        (11, DayPart.morning),
        (12, DayPart.afternoon),
        (16, DayPart.afternoon),
        (17, DayPart.evening),
        (23, DayPart.evening),
      ]) {
        expect(
          dayPartOf(DateTime(2026, 10, 1, hour, 30)),
          part,
          reason: '$hour',
        );
      }
    });

    for (final (hour, greeting) in [
      (8, 'Good morning'),
      (14, 'Good afternoon'),
      (20, 'Good evening'),
    ]) {
      testWidgets('$greeting at $hour:00, with the cached name', (
        tester,
      ) async {
        final world = TestWorld()..now = DateTime(2026, 10, 1, hour);
        await openHome(tester, world: world);
        expect(find.text(greeting), findsOneWidget);
        expect(find.text('Ama Mensah 👋'), findsOneWidget);
        expect(world.cache.user?.profile?.fullName, 'Ama Mensah');
      });
    }
  });

  group('location', () {
    testWidgets('on: the nearest stop names the chip, the dot shows', (
      tester,
    ) async {
      final world = TestWorld();
      world.location
        ..permission = LocationPermissionStatus.granted
        ..position = nearMadina;
      await openHome(tester, world: world);

      expect(find.text('Madina, Accra'), findsOneWidget);
      expect(find.byType(TroskyLocationDot), findsOneWidget);
      // Low data: the answer is kept for next time.
      expect(world.home.nearbyStop?.stop?.name, 'Madina');
    });

    testWidgets('on, but no stop near: "Accra"', (tester) async {
      final world = TestWorld();
      world.location
        ..permission = LocationPermissionStatus.granted
        ..position = kumasi;
      await openHome(tester, world: world);

      expect(find.text('Accra'), findsOneWidget);
      expect(find.byType(TroskyLocationDot), findsOneWidget);
    });

    testWidgets('a saved stop for the same spot is used without a request', (
      tester,
    ) async {
      final world = TestWorld();
      world.location
        ..permission = LocationPermissionStatus.granted
        ..position = nearMadina;
      final osu = MockBackend.stops['Osu']!;
      world.home.nearbyStop = CachedNearbyStop(
        position: nearMadina,
        stop: NearbyStopResponse(
          id: osu.id,
          name: osu.name,
          city: 'Accra',
          latitude: osu.latitude,
          longitude: osu.longitude,
          distanceM: 80,
        ),
        savedAt: world.now.subtract(const Duration(hours: 2)),
      );
      await openHome(tester, world: world);
      // The saved answer (Osu) wins over the mock's real one (Madina).
      expect(find.text('Osu, Accra'), findsOneWidget);
    });

    testWidgets("the phone's location is off: Accra; my-location says so "
        'and opens the settings', (tester) async {
      final world = TestWorld();
      world.location
        ..permission = LocationPermissionStatus.granted
        ..enabled = false
        ..position = nearMadina;
      await openHome(tester, world: world);

      expect(find.text('Accra'), findsOneWidget);
      expect(find.byType(TroskyLocationDot), findsNothing);

      await tapLabel(tester, 'My location');
      expect(find.text("Your phone's location is off."), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(world.location.locationSettingsOpened, 1);
    });

    testWidgets('first time: explained once; "Not now" keeps Accra', (
      tester,
    ) async {
      final world = TestWorld();
      world.home.asked = false;
      await openHome(tester, world: world);

      expect(find.text('See rides near you'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('See rides near you'), findsNothing);
      expect(find.text('Accra'), findsOneWidget);
      expect(world.home.asked, isTrue);
      expect(world.location.dialogs, 0);
    });

    testWidgets('first time: "Allow location", then the phone asks', (
      tester,
    ) async {
      final world = TestWorld();
      world.home.asked = false;
      world.location.position = nearMadina;
      await openHome(tester, world: world);

      await tester.tap(find.text('Allow location'));
      await tester.pumpAndSettle();

      expect(world.location.dialogs, 1);
      expect(find.text('Madina, Accra'), findsOneWidget);
      expect(find.byType(TroskyLocationDot), findsOneWidget);
    });

    testWidgets('dismissing the explanation counts as "Not now"', (
      tester,
    ) async {
      final world = TestWorld();
      world.home.asked = false;
      await openHome(tester, world: world);

      await tester.tapAt(const Offset(180, 100));
      await tester.pumpAndSettle();
      expect(find.text('See rides near you'), findsNothing);
      expect(world.home.asked, isTrue);
      expect(find.text('Accra'), findsOneWidget);
    });

    testWidgets('refused before: my-location asks again', (tester) async {
      final world = TestWorld();
      world.location.position = nearMadina;
      await openHome(tester, world: world);
      expect(find.text('Accra'), findsOneWidget);

      await tapLabel(tester, 'My location');
      expect(world.location.dialogs, 1);
      expect(find.text('Madina, Accra'), findsOneWidget);
    });

    testWidgets('refused for good: my-location points to Settings', (
      tester,
    ) async {
      final world = TestWorld();
      world.location.permission = LocationPermissionStatus.deniedForever;
      await openHome(tester, world: world);

      await tapLabel(tester, 'My location');
      expect(world.location.dialogs, 0);
      expect(
        find.text('Location is off for TroSky. Turn it on in Settings.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(world.location.appSettingsOpened, 1);
    });
  });

  group('favourite routes (decision 15)', () {
    testWidgets('filled: the routes as chips; a chip opens Search filled in', (
      tester,
    ) async {
      await openHome(tester);
      for (final route in [
        'Madina → Circle',
        'Legon → Osu',
        'Achimota → Tema',
        'Kaneshie → Lapaz',
      ]) {
        expect(find.text(route), findsOneWidget);
      }

      await tapVisible(tester, find.text('Legon → Osu'));
      expect(find.text('From Legon to Osu'), findsOneWidget);
      expect(find.byType(TroskyTabBar), findsNothing);
    });

    testWidgets('empty: one short line instead of the chips', (tester) async {
      final world = TestWorld()..backend.clearFavouriteRoutes('0241234567');
      await openHome(tester, world: world);
      expect(find.text('No favourite routes yet.'), findsOneWidget);
      expect(find.byType(TroskyRouteChip), findsNothing);
    });

    testWidgets('failed with nothing saved: Retry fetches again', (
      tester,
    ) async {
      final world = TestWorld();
      await openHome(
        tester,
        world: world,
        overrides: [wrapUserRepository(world, FlakyFavourites.new)],
      );
      expect(find.text("Couldn't load your favourite routes."), findsOneWidget);

      await tapVisible(tester, link('Retry'));
      expect(find.text('Madina → Circle'), findsOneWidget);
    });

    testWidgets('failed with a saved list: the saved list', (tester) async {
      final world = TestWorld();
      world.home.favourites['2f6b1c0e-7d3a-4b8e-9c1a-5e2f7a9b3c41'] = [
        FavouriteRouteResponse(
          id: 'f-saved',
          originStopId: 'a',
          originStopName: 'Osu',
          destinationStopId: 'b',
          destinationStopName: 'Tema',
          createdAt: DateTime.utc(2026, 9),
        ),
      ];
      await openHome(
        tester,
        world: world,
        overrides: [wrapUserRepository(world, FlakyFavourites.new)],
      );
      expect(find.text('Osu → Tema'), findsOneWidget);
      expect(find.text("Couldn't load your favourite routes."), findsNothing);
    });
  });

  group('subscribe banner (decision 16)', () {
    testWidgets('on in mock mode; opens Subscribe', (tester) async {
      await openHome(tester);
      expect(find.text('Subscribe your commute'), findsOneWidget);
      await tapVisible(tester, find.text('Try it'));
      expect(find.text('This screen is coming soon.'), findsOneWidget);
    });

    testWidgets('off when FEATURES leaves it out', (tester) async {
      await openHome(
        tester,
        env: Env.parse(
          apiBaseUrl: '',
          wsBaseUrl: '',
          apiMode: 'mock',
          features: '',
        ),
      );
      expect(find.text('Subscribe your commute'), findsNothing);
      expect(find.text('Madina → Circle'), findsOneWidget);
    });
  });

  group('vehicle pins (decision 14)', () {
    testWidgets('mock mode: the three design vehicles, 2 seats in amber', (
      tester,
    ) async {
      await openHome(tester);
      final pins = _pins(tester).toList();
      expect(pins.map((p) => p.seats), unorderedEquals([5, 8, 2]));
      expect(pins.where((p) => p.amber).map((p) => p.seats), [2]);
      expect(
        find.bySemanticsLabel('Achimota → Tema, 2 seats free'),
        findsOneWidget,
      );
    });

    testWidgets('live mode with no vehicles on the road: no pins, no banner', (
      tester,
    ) async {
      final world = TestWorld();
      final tracking = FakeTracking(const []);
      final live = liveMode(world, tracking);
      await openHome(
        tester,
        world: world,
        env: live.env,
        overrides: live.overrides,
      );
      expect(tracking.calls, 1);
      expect(find.byType(TroskyBusPin), findsNothing);
      expect(find.text('Subscribe your commute'), findsNothing);
      // Favourites still come from the backend.
      expect(find.text('Madina → Circle'), findsOneWidget);
    });

    testWidgets('live mode: exactly the vehicles the backend reports', (
      tester,
    ) async {
      final world = TestWorld();
      final live = liveMode(world, FakeTracking([liveVehicle()]));
      await openHome(
        tester,
        world: world,
        env: live.env,
        overrides: live.overrides,
      );
      expect(_pins(tester).map((p) => (p.seats, p.amber)), [(9, false)]);
    });

    testWidgets('vehicles failing: a note with Retry; the rest works', (
      tester,
    ) async {
      final world = TestWorld();
      final tracking = FakeTracking([liveVehicle(seats: 1)], failures: 1);
      final live = liveMode(world, tracking);
      await openHome(
        tester,
        world: world,
        env: live.env,
        overrides: live.overrides,
      );
      expect(find.text("Couldn't load vehicles"), findsOneWidget);
      expect(find.text('Madina → Circle'), findsOneWidget);

      await tester.tap(link('Retry'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load vehicles"), findsNothing);
      expect(_pins(tester).single.amber, isTrue);
    });

    testWidgets('pins refresh every 30 s while Home is showing', (
      tester,
    ) async {
      final world = TestWorld();
      final tracking = FakeTracking([liveVehicle()]);
      final live = liveMode(world, tracking);
      await openHome(
        tester,
        world: world,
        env: live.env,
        overrides: live.overrides,
      );
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(tracking.calls, 2);

      // Not while another tab is open.
      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(tracking.calls, 2);
    });
  });

  testWidgets('offline start: the banner over the map, saved favourites, and '
      'Retry checks again', (tester) async {
    final world = TestWorld();
    const userId = '2f6b1c0e-7d3a-4b8e-9c1a-5e2f7a9b3c41';
    world.tokens.token = 'mock.refresh.saved-on-a-previous-run';
    world.cache.user = UserResponse(
      id: userId,
      phoneNumber: MockBackend.passengerPhone,
      isActive: true,
      phoneVerified: true,
      emailVerified: false,
      roles: const ['passenger'],
      createdAt: DateTime.utc(2026, 7),
      profile: const UserProfileResponse(
        fullName: 'Ama Mensah',
        preferredLanguage: 'en',
        ghanaCardVerified: false,
      ),
    );
    world.home.favourites[userId] = [
      FavouriteRouteResponse(
        id: 'f1',
        originStopId: 'a',
        originStopName: 'Madina',
        destinationStopId: 'b',
        destinationStopName: 'Circle',
        createdAt: DateTime.utc(2026, 9),
      ),
    ];
    await openHome(
      tester,
      world: world,
      overrides: [
        authRepositoryProvider.overrideWith(
          (ref) => _OfflineAuth(
            MockAuthRepository(
              world.backend,
              tokens: () => ref.read(tokenManagerProvider),
            ),
          ),
        ),
      ],
    );

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Ama Mensah 👋'), findsOneWidget);
    expect(
      find.text("You're offline. Showing your last saved details."),
      findsOneWidget,
    );
    expect(find.text('Madina → Circle'), findsOneWidget);
    // The vehicles failed too, but the banner already says why.
    expect(find.text("Couldn't load vehicles"), findsNothing);
    expect(world.tokens.token, isNotNull);
  });

  group('tabs (decision 12)', () {
    testWidgets('Home, Trips, Wallet, Profile; Profile has Sign out', (
      tester,
    ) async {
      final world = await openHome(tester);
      for (final (tab, screen) in [
        ('Trips', 'trips'),
        ('Wallet', 'wallet'),
        ('Profile', 'profile'),
      ]) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(find.text(screen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      }
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(link('Sign out'));
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(world.tokens.token, isNull);
    });

    testWidgets('Android back: another tab → Home → leaves the app', (
      tester,
    ) async {
      final platformCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openHome(tester);
      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(platformCalls, isNot(contains('SystemNavigator.pop')));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(platformCalls, contains('SystemNavigator.pop'));
    });

    testWidgets('screen readers hear the selected tab', (tester) async {
      await openHome(tester);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Home')),
        matchesSemantics(
          label: 'Home',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
    });
  });

  group('buttons open their screens; Back returns to Home', () {
    for (final (label, title) in [
      ('SOS, emergency help', 'SOS'),
      ('Notifications', 'Notifications'),
      ('Where are you going?, Now', 'Search'),
    ]) {
      testWidgets(label, (tester) async {
        await openHome(tester);
        await tapLabel(tester, label);
        expect(find.text(title), findsOneWidget);
        expect(find.byType(TroskyTabBar), findsNothing);

        await tapLabel(tester, 'Back');
        expect(find.byType(HomeScreen), findsOneWidget);
      });
    }

    testWidgets('See all', (tester) async {
      await openHome(tester);
      await tapVisible(tester, find.text('See all'));
      expect(find.text('Favourite Routes'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });

  group('360 x 640, text scale 1.3: no overflow, everything reachable', () {
    Future<void> check(WidgetTester tester, TestWorld world) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openHome(tester, world: world, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
    }

    testWidgets('Home, located, banner on', (tester) async {
      final world = TestWorld();
      world.location
        ..permission = LocationPermissionStatus.granted
        ..position = nearMadina;
      await check(tester, world);
      await tapVisible(tester, find.text('Try it'));
      expect(find.text('This screen is coming soon.'), findsOneWidget);
    });

    testWidgets('with the location explanation open', (tester) async {
      final world = TestWorld();
      world.home.asked = false;
      await check(tester, world);
      expect(find.text('Not now'), findsOneWidget);
      await tester.ensureVisible(find.text('Not now'));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
