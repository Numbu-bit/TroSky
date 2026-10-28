import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/app/app_providers.dart';
import 'package:mobile/app/trosky_mobile_app.dart';
import 'package:mobile/entry/onboarding/data/onboarding_store.dart';
import 'package:mobile/entry/splash/presentation/launch_destination_provider.dart';
import 'package:mobile/passenger/home/application/home_providers.dart';
import 'package:mobile/passenger/home/data/home_store.dart';
import 'package:mobile/passenger/home/data/location_service.dart';
import 'package:mobile/passenger/search/application/search_providers.dart';
import 'package:mobile/passenger/search/data/search_history_store.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

/// Answers `isSeen` with [seen]; a pending store never answers and keeps the
/// splash screen up.
class FakeOnboardingStore implements OnboardingStore {
  FakeOnboardingStore({this.seen = false}) : _pending = false;

  FakeOnboardingStore.pending() : seen = false, _pending = true;

  bool seen;
  final bool _pending;

  @override
  Future<bool> isSeen() =>
      _pending ? Completer<bool>().future : Future.value(seen);

  @override
  Future<void> markSeen() async => seen = true;
}

/// [AppModeStore] in memory.
class InMemoryAppModeStore implements AppModeStore {
  InMemoryAppModeStore([this.mode]);

  AppMode? mode;

  @override
  Future<AppMode?> read() async => mode;

  @override
  Future<void> write(AppMode mode) async => this.mode = mode;
}

/// The server always in one [ServerState], e.g. waking for the bar.
class FixedServerStatus extends ServerStatus {
  FixedServerStatus(this.fixed);

  final ServerState fixed;

  @override
  ServerState build() => fixed;
}

/// A session that is already restored: signed in as a passenger, or not.
class FakeSessionController extends SessionController {
  FakeSessionController({this.signedIn = false});

  final bool signedIn;

  @override
  Future<SessionState> build() async => signedIn
      ? SessionAuthenticated(
          UserResponse(
            id: '2f6b1c0e-7d3a-4b8e-9c1a-5e2f7a9b3c41',
            phoneNumber: MockBackend.passengerPhone,
            isActive: true,
            phoneVerified: true,
            emailVerified: false,
            roles: const ['passenger'],
            createdAt: DateTime.utc(2026, 7),
          ),
        )
      : const SessionUnauthenticated();
}

/// The phone's location, answering from fields. By default location was
/// refused, so Home shows Accra.
class FakeLocationService implements LocationService {
  FakeLocationService({
    this.permission = LocationPermissionStatus.denied,
    this.dialogAnswer = LocationPermissionStatus.granted,
    this.enabled = true,
    this.position,
  });

  LocationPermissionStatus permission;

  /// What the passenger answers in the phone's permission dialog.
  LocationPermissionStatus dialogAnswer;
  bool enabled;
  LatLng? position;

  int dialogs = 0;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  @override
  Future<bool> serviceEnabled() async => enabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async => permission;

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    dialogs++;
    return permission = dialogAnswer;
  }

  @override
  Future<LatLng?> lastKnownPosition() async => position;

  @override
  Future<LatLng?> currentPosition() async => position;

  @override
  Future<void> openAppSettings() async => appSettingsOpened++;

  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;
}

/// Map tiles in one flat colour (OpenStreetMap's land), from memory: tests
/// never reach the tile server.
class FlatTileProvider extends TileProvider {
  static final MemoryImage _tile = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP49P4lAAWhAstl'
      '7N0JAAAAAElFTkSuQmCC',
    ),
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _tile;
}

/// Everything a test app keeps between screens, in memory.
class TestWorld {
  TestWorld({
    AppMode? mode,
    bool onboardingSeen = true,
    this.bookingHistory = false,
  }) : modes = InMemoryAppModeStore(mode),
       onboarding = FakeOnboardingStore(seen: onboardingSeen);

  /// Ama Mensah starts with a week of bookings ([MockBackend.bookingHistory]).
  final bool bookingHistory;

  /// The mock backend's clock, and the phone's; move it to expire codes or
  /// change the time of day.
  DateTime now = DateTime.now();

  late final MockBackend backend = MockBackend(
    clock: () => now,
    bookingHistory: bookingHistory,
  );
  final InMemoryRefreshTokenStore tokens = InMemoryRefreshTokenStore();
  final InMemoryUserCache cache = InMemoryUserCache();
  final InMemoryAppModeStore modes;
  final FakeOnboardingStore onboarding;
  final FakeLocationService location = FakeLocationService();

  /// Location was asked about already, so Home doesn't explain it again.
  final InMemoryHomeStore home = InMemoryHomeStore(asked: true);
  final InMemorySearchHistoryStore searches = InMemorySearchHistoryStore();

  /// Signs in as the seeded passenger (Ama Mensah) on the mock backend and
  /// keeps the refresh token, as a previous run of the app would.
  void savePassengerSession({String phone = '0241234567'}) {
    tokens.token = backend
        .login(
          LoginRequest(identifier: phone, password: MockBackend.seedPassword),
        )
        .valueOrNull!
        .refreshToken;
  }
}

/// The whole app in mock mode, with in-memory storage. With [signedIn] set,
/// the session is a [FakeSessionController] that is already restored;
/// otherwise it's the real one, restoring from [world]'s token store. The
/// test binding never reports a rasterized frame, so the splash counts as
/// shown straight away.
Widget testApp({
  OnboardingStore? onboarding,
  bool? signedIn,
  TestWorld? world,
  Env? env,
  List<Object> overrides = const [],
}) {
  final w = world ?? TestWorld();
  return ProviderScope(
    overrides: [
      envProvider.overrideWithValue(
        env ?? Env.parse(apiBaseUrl: '', wsBaseUrl: '', apiMode: 'mock'),
      ),
      mockBackendProvider.overrideWithValue(w.backend),
      mockLatencyProvider.overrideWithValue(Duration.zero),
      refreshTokenStoreProvider.overrideWithValue(w.tokens),
      userCacheProvider.overrideWithValue(w.cache),
      appModeStoreProvider.overrideWithValue(w.modes),
      onboardingStoreProvider.overrideWithValue(onboarding ?? w.onboarding),
      if (signedIn != null)
        sessionControllerProvider.overrideWith(
          () => FakeSessionController(signedIn: signedIn),
        ),
      firstFrameShownProvider.overrideWith((ref) async {}),
      clockProvider.overrideWithValue(() => w.now),
      locationServiceProvider.overrideWithValue(w.location),
      homeStoreProvider.overrideWithValue(w.home),
      mapTileProviderFactoryProvider.overrideWithValue(FlatTileProvider.new),
      searchHistoryStoreProvider.overrideWithValue(w.searches),
      ...overrides.cast(),
    ],
    child: const TroskyMobileApp(),
  );
}

/// Sets the logical screen size for one test.
void setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Opens the app fresh at [size]: the splash, then onboarding.
Future<void> pumpOnboarding(
  WidgetTester tester,
  OnboardingStore store, {
  Size size = const Size(360, 806),
}) async {
  setScreenSize(tester, size);
  await tester.pumpWidget(testApp(onboarding: store, signedIn: false));
  await tester.pump(splashMinimumDuration);
  // Past the route transition. Not pumpAndSettle: the illustrations float
  // forever.
  await tester.pump(const Duration(seconds: 1));
}
