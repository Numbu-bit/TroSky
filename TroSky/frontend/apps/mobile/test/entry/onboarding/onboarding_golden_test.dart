@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/entry/onboarding/presentation/onboarding_screen.dart';

import '../../helpers/fakes.dart';

/// Each onboarding page at 360 x 806, the TECNO BG6's logical size.
///
/// Reduce motion is on so the illustrations rest where the design draws
/// them. flutter_test draws shadows unblurred by default
/// (`debugDisableShadows`); the goldens switch that off to show the buttons'
/// shadows.
void main() {
  for (final page in [1, 2, 3]) {
    testWidgets('onboarding page $page', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      debugDisableShadows = false;
      try {
        await pumpOnboarding(tester, FakeOnboardingStore());
        for (var i = 1; i < page; i++) {
          await tester.tap(find.text('Next'));
          // The first frame starts the dots' 0.3 s transition; the second
          // ends it.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }
        await expectLater(
          find.byType(OnboardingScreen),
          matchesGoldenFile('goldens/onboarding_$page.png'),
        );
      } finally {
        debugDisableShadows = true;
      }
    });
  }
}
