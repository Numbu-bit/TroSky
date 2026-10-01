@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/entry/splash/presentation/splash_screen.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../helpers/fakes.dart';

/// The splash with its logo decoded and the checks still running, compared
/// with `goldens/<name>.png`.
///
/// flutter_test draws shadows unblurred by default (`debugDisableShadows`);
/// the golden switches that off to show the design's card shadow.
Future<void> _golden(WidgetTester tester, Size size, String name) async {
  setScreenSize(tester, size);
  debugDisableShadows = false;
  try {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        testApp(onboarding: FakeOnboardingStore.pending()),
      );
      await precacheImage(
        const AssetImage(TroskyLogo.brightAsset, package: TroskyLogo.package),
        tester.element(find.byType(SplashScreen)),
      );
    });
    await tester.pump();
    await expectLater(
      find.byType(SplashScreen),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  testWidgets('splash at 360 x 800', (tester) async {
    await _golden(tester, const Size(360, 800), 'splash_360x800');
  });

  testWidgets('splash at 412 x 915', (tester) async {
    await _golden(tester, const Size(412, 915), 'splash_412x915');
  });
}
