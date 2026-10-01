import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/trosky_mobile_app.dart';
import 'package:mobile/entry/onboarding/data/onboarding_store.dart';
import 'package:mobile/entry/splash/presentation/launch_destination_provider.dart';
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

/// Everything a test app keeps between screens, in memory.
class TestWorld {
  TestWorld({AppMode? mode, bool onboardingSeen = true})
    : modes = InMemoryAppModeStore(mode),
      onboarding = FakeOnboardingStore(seen: onboardingSeen);

  /// The mock backend's clock; move it to expire codes.
  DateTime now = DateTime.now();

  late final MockBackend backend = MockBackend(clock: () => now);
  final InMemoryRefreshTokenStore tokens = InMemoryRefreshTokenStore();
  final InMemoryUserCache cache = InMemoryUserCache();
  final InMemoryAppModeStore modes;
  final FakeOnboardingStore onboarding;
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
  List<Object> overrides = const [],
}) {
  final w = world ?? TestWorld();
  return ProviderScope(
    overrides: [
      envProvider.overrideWithValue(
        Env.parse(apiBaseUrl: '', wsBaseUrl: '', apiMode: 'mock'),
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
