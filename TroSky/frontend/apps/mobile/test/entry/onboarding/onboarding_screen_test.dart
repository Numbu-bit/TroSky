import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/entry/onboarding/presentation/onboarding_screen.dart';
import 'package:trosky_ui/trosky_ui.dart';

import '../../helpers/fakes.dart';

const _titles = [
  'Book a Seat,\nNot a Whole Car',
  'Share the Ride,\nSplit the Fare',
  'Subscribe Your\nDaily Commute',
];

int _activeDot(WidgetTester tester) =>
    tester.widget<PageDots>(find.byType(PageDots)).index;

Future<void> _tapNext(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('Next steps through the three pages', (tester) async {
    await pumpOnboarding(tester, FakeOnboardingStore());
    expect(find.text(_titles[0]), findsOneWidget);
    expect(_activeDot(tester), 0);

    await _tapNext(tester);
    expect(find.text(_titles[1]), findsOneWidget);
    expect(_activeDot(tester), 1);

    await _tapNext(tester);
    expect(find.text(_titles[2]), findsOneWidget);
    expect(_activeDot(tester), 2);
    expect(find.text('Next'), findsNothing);
    expect(find.text('Get Started'), findsOneWidget);
  });

  group('leaving onboarding saves the flag and opens Sign Up', () {
    for (final page in [0, 1, 2]) {
      testWidgets('Skip on page ${page + 1}', (tester) async {
        final store = FakeOnboardingStore();
        await pumpOnboarding(tester, store);
        for (var i = 0; i < page; i++) {
          await _tapNext(tester);
        }

        await tester.tap(find.text('Skip'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(store.seen, isTrue);
        expect(find.text('signUp'), findsOneWidget);
      });
    }

    testWidgets('Get Started', (tester) async {
      final store = FakeOnboardingStore();
      await pumpOnboarding(tester, store);
      await _tapNext(tester);
      await _tapNext(tester);

      await tester.tap(find.text('Get Started'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(store.seen, isTrue);
      expect(find.text('signUp'), findsOneWidget);
    });
  });

  testWidgets('swiping cross-fades the background, then changes page', (
    tester,
  ) async {
    await pumpOnboarding(tester, FakeOnboardingStore());
    final fadeIn = find.descendant(
      of: find.byKey(const ValueKey('onboarding-backgrounds')),
      matching: find.byKey(const ValueKey('onboarding-fade-in')),
    );
    expect(fadeIn, findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    for (var i = 0; i < 9; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // About halfway: the next page's gradient is part-way in, not cut.
    final opacity = tester.widget<Opacity>(fadeIn).opacity;
    expect(opacity, inExclusiveRange(0.2, 0.8));

    for (var i = 0; i < 9; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_titles[1]), findsOneWidget);
    expect(_activeDot(tester), 1);
  });

  testWidgets('back goes to the previous page, and leaves from page 1', (
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

    await pumpOnboarding(tester, FakeOnboardingStore());
    await _tapNext(tester);
    await _tapNext(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(_titles[1]), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(_titles[0]), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(platformCalls, contains('SystemNavigator.pop'));
  });

  testWidgets('light status bar icons on every page', (tester) async {
    await pumpOnboarding(tester, FakeOnboardingStore());
    for (var page = 0; page < 3; page++) {
      expect(SystemChrome.latestStyle, TroskySystemUi.lightIcons);
      if (page < 2) await _tapNext(tester);
    }
  });

  testWidgets('screen readers hear "Page n of 3"', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpOnboarding(tester, FakeOnboardingStore());
    expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);

    await _tapNext(tester);
    expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('no overflow at 360 x 640 with text scale 1.3', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpOnboarding(
      tester,
      FakeOnboardingStore(),
      size: const Size(360, 640),
    );

    for (var page = 0; page < 3; page++) {
      expect(find.text(_titles[page]), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'page ${page + 1}');
      if (page < 2) await _tapNext(tester);
    }
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
