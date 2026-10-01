import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/session_store_provider.dart';
import 'package:mobile/app/trosky_mobile_app.dart';
import 'package:mobile/entry/onboarding/data/onboarding_store.dart';
import 'package:mobile/entry/splash/presentation/launch_destination_provider.dart';
import 'package:trosky_auth/trosky_auth.dart';

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

class FakeSessionStore implements SessionStore {
  const FakeSessionStore({this.hasSession = false});

  final bool hasSession;

  @override
  Future<bool> hasSavedSession() async => hasSession;
}

/// The whole app with its storage replaced by fakes. The test binding never
/// reports a rasterized frame, so the splash counts as shown straight away.
Widget testApp({
  required OnboardingStore onboarding,
  SessionStore session = const FakeSessionStore(),
}) {
  return ProviderScope(
    overrides: [
      onboardingStoreProvider.overrideWithValue(onboarding),
      sessionStoreProvider.overrideWithValue(session),
      firstFrameShownProvider.overrideWith((ref) async {}),
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
  await tester.pumpWidget(testApp(onboarding: store));
  await tester.pump(splashMinimumDuration);
  // Past the route transition. Not pumpAndSettle: the illustrations float
  // forever.
  await tester.pump(const Duration(seconds: 1));
}
