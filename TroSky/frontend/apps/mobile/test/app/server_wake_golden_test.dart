@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/server_wake_bar.dart';
import 'package:mobile/entry/splash/presentation/launch_destination_provider.dart';
import 'package:mobile/entry/splash/presentation/splash_screen.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../helpers/fakes.dart';

/// The whole app with the server waking, under a 24 px status bar, compared
/// with `goldens/<name>.png` (decision 29).
Future<void> _golden(
  WidgetTester tester,
  String name, {
  required bool signIn,
}) async {
  setScreenSize(tester, const Size(360, 800));
  tester.view.padding = const FakeViewPadding(top: 24);
  debugDisableShadows = false;
  final app = testApp(
    onboarding: signIn
        ? FakeOnboardingStore(seen: true)
        : FakeOnboardingStore.pending(),
    signedIn: false,
    overrides: [
      serverStatusProvider.overrideWith(
        () => FixedServerStatus(ServerState.waking),
      ),
    ],
  );
  try {
    if (signIn) {
      await tester.pumpWidget(app);
      await tester.pump(splashMinimumDuration);
      // Past the route transition. Not pumpAndSettle: the spinner turns
      // for as long as the server wakes.
      await tester.pump(const Duration(seconds: 1));
    } else {
      // The splash's logo decodes in real time; the splash waits for it.
      await tester.runAsync(() async {
        await tester.pumpWidget(app);
        await precacheImage(
          const AssetImage(TroskyLogo.brightAsset, package: TroskyLogo.package),
          tester.element(find.byType(SplashScreen)),
        );
      });
      await tester.pump();
    }
    // A quarter turn in, so the spinner shows as an arc.
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(ServerWakeBar),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  testWidgets('waking, over the splash', (tester) async {
    await _golden(tester, 'server_waking_splash_360', signIn: false);
  });

  testWidgets('waking, over Sign in', (tester) async {
    await _golden(tester, 'server_waking_sign_in_360', signIn: true);
  });
}
