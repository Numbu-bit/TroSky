import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/entry/onboarding/presentation/onboarding_screen.dart';
import 'package:mobile/entry/splash/presentation/launch_destination_provider.dart';
import 'package:mobile/entry/splash/presentation/splash_screen.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../helpers/fakes.dart';

int _activeDot(WidgetTester tester) =>
    tester.widget<PageDots>(find.byType(PageDots)).index;

void main() {
  group('routing', () {
    Future<void> expectRoute(
      WidgetTester tester, {
      required bool onboardingSeen,
      required bool hasSession,
      required Finder destination,
    }) async {
      await tester.pumpWidget(
        testApp(
          onboarding: FakeOnboardingStore(seen: onboardingSeen),
          session: FakeSessionStore(hasSession: hasSession),
        ),
      );
      expect(find.byType(SplashScreen), findsOneWidget);

      // The checks answer at once, but the splash stays for 1.5 s.
      await tester.pump(
        splashMinimumDuration - const Duration(milliseconds: 1),
      );
      expect(find.byType(SplashScreen), findsOneWidget);

      // Past the route transition. Not pumpAndSettle: onboarding's
      // illustrations float forever.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SplashScreen), findsNothing);
      expect(destination, findsOneWidget);
    }

    testWidgets('onboarding not seen goes to onboarding', (tester) async {
      await expectRoute(
        tester,
        onboardingSeen: false,
        hasSession: false,
        destination: find.byType(OnboardingScreen),
      );
    });

    testWidgets('onboarding seen, no session goes to sign-in', (tester) async {
      await expectRoute(
        tester,
        onboardingSeen: true,
        hasSession: false,
        destination: find.text('signIn'),
      );
    });

    testWidgets('saved session goes to home', (tester) async {
      await expectRoute(
        tester,
        onboardingSeen: true,
        hasSession: true,
        destination: find.text('home'),
      );
    });
  });

  testWidgets('status bar: light icons on the splash, dark on the next '
      'screen', (tester) async {
    // Onboarding seen and no session: the next screen is the light sign-in
    // placeholder.
    await tester.pumpWidget(
      testApp(onboarding: FakeOnboardingStore(seen: true)),
    );
    expect(SystemChrome.latestStyle, TroskySystemUi.lightIcons);

    await tester.pump(splashMinimumDuration);
    await tester.pumpAndSettle();
    expect(find.text('signIn'), findsOneWidget);
    expect(SystemChrome.latestStyle, TroskySystemUi.darkIcons);
  });

  group('loading dots', () {
    testWidgets('step 1 → 2 → 3 while the splash is up', (tester) async {
      await tester.pumpWidget(
        testApp(onboarding: FakeOnboardingStore.pending()),
      );
      expect(_activeDot(tester), 0);

      await tester.pump(const Duration(milliseconds: 500));
      expect(_activeDot(tester), 1);

      await tester.pump(const Duration(milliseconds: 500));
      expect(_activeDot(tester), 2);

      await tester.pump(const Duration(milliseconds: 500));
      expect(_activeDot(tester), 0);
    });

    testWidgets('reduce motion stops the animation', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        testApp(onboarding: FakeOnboardingStore.pending()),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(_activeDot(tester), 0);
      }
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('text scale 1.3', () {
    for (final size in const [Size(360, 800), Size(412, 915)]) {
      testWidgets('no overflow at ${size.width.toInt()} wide', (tester) async {
        setScreenSize(tester, size);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          testApp(onboarding: FakeOnboardingStore.pending()),
        );
        await tester.pump(splashMinimumDuration);

        expect(tester.takeException(), isNull);
        expect(find.text('Your Journey. On Time.'), findsOneWidget);
        expect(find.text("Ghana's Shared Transport Platform"), findsOneWidget);
      });
    }
  });

  testWidgets('screen readers hear the logo and a loading label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(testApp(onboarding: FakeOnboardingStore.pending()));

    expect(find.bySemanticsLabel('TroSky'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    await tester.pump(splashMinimumDuration);
    semantics.dispose();
  });
}
