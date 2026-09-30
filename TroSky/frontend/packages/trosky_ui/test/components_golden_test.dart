@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_ui/trosky_ui.dart';

/// Serves `packages/trosky_ui/...` asset keys from disk. A package's own
/// tests only bundle its assets without that prefix.
class _PackageAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(
      key.replaceFirst('packages/trosky_ui/', ''),
    ).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

const _frame = ValueKey('golden-frame');

/// Pumps [child] in a [width] wide frame, shrink-wrapped to its height, and
/// compares it with `goldens/<name>.png`.
///
/// flutter_test draws shadows unblurred by default (`debugDisableShadows`);
/// the goldens switch that off so they show the CSS-matched blur. SVGs decode
/// asynchronously, hence runAsync.
Future<void> _golden(
  WidgetTester tester,
  String name,
  Widget child, {
  double width = 312,
  Color background = TroskyColors.background,
  Gradient? gradient,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 2000);
  addTearDown(tester.view.reset);
  debugDisableShadows = false;
  try {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _PackageAssetBundle(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: TroskyTheme.light(),
            home: Material(
              type: MaterialType.transparency,
              child: Align(
                alignment: Alignment.topLeft,
                // The golden captures this boundary, not the whole view.
                child: RepaintBoundary(
                  key: _frame,
                  child: Container(
                    width: width,
                    decoration: BoxDecoration(
                      color: gradient == null ? background : null,
                      gradient: gradient,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [child],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    // Advance far enough for the loading spinner to show an arc.
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byKey(_frame),
      matchesGoldenFile('goldens/$name.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

/// The four states of one button variant, stacked.
Widget _buttonStates(TroskyButtonVariant variant, {Widget? leading}) {
  void tap() {}
  final states = <Widget>[
    TroskyButton(
      label: 'Enabled',
      variant: variant,
      onPressed: tap,
      leading: leading,
    ),
    TroskyButton(
      label: 'Pressed',
      variant: variant,
      onPressed: tap,
      pressed: true,
      leading: leading,
    ),
    TroskyButton(
      label: 'Disabled',
      variant: variant,
      onPressed: null,
      leading: leading,
    ),
    TroskyButton(
      label: 'Loading',
      variant: variant,
      onPressed: tap,
      loading: true,
    ),
  ];
  return Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
    child: Column(
      children: [
        for (final state in states) ...[state, const SizedBox(height: 28)],
      ],
    ),
  );
}

void main() {
  group('TroskyButton', () {
    testWidgets('onboardingLight on Onboarding 1', (tester) async {
      await _golden(
        tester,
        'trosky_button_onboarding_light',
        _buttonStates(TroskyButtonVariant.onboardingLight),
        gradient: TroskyGradients.onboarding1,
      );
    });

    testWidgets('onboardingGreen on Onboarding 2', (tester) async {
      await _golden(
        tester,
        'trosky_button_onboarding_green',
        _buttonStates(TroskyButtonVariant.onboardingGreen),
        gradient: TroskyGradients.onboarding2,
      );
    });

    testWidgets('amber on Onboarding 3', (tester) async {
      await _golden(
        tester,
        'trosky_button_amber',
        _buttonStates(TroskyButtonVariant.amber),
        gradient: TroskyGradients.onboarding3,
      );
    });

    testWidgets('primary on Sign Up', (tester) async {
      await _golden(
        tester,
        'trosky_button_primary',
        _buttonStates(TroskyButtonVariant.primary),
      );
    });

    testWidgets('outline with the email icon on Sign Up', (tester) async {
      await _golden(
        tester,
        'trosky_button_outline',
        _buttonStates(
          TroskyButtonVariant.outline,
          leading: TroskyIcons.mail(color: TroskyColors.textPrimary),
        ),
      );
    });
  });

  testWidgets('PageDots: onboarding pages and splash', (tester) async {
    Widget row(Gradient gradient, Widget dots) => Container(
      height: 40,
      decoration: BoxDecoration(gradient: gradient),
      alignment: Alignment.center,
      child: dots,
    );
    await _golden(
      tester,
      'page_dots',
      Column(
        children: [
          row(TroskyGradients.onboarding1, const PageDots.onboarding(index: 0)),
          row(
            TroskyGradients.onboarding2,
            const PageDots.onboarding(
              index: 1,
              inactiveColor: TroskyColors.whiteA25,
            ),
          ),
          row(
            TroskyGradients.onboarding3,
            const PageDots.onboarding(
              index: 2,
              inactiveColor: TroskyColors.whiteA25,
            ),
          ),
          row(TroskyGradients.splash, const PageDots.splash()),
        ],
      ),
    );
  });

  testWidgets('SkipText on Onboarding 1 and 2', (tester) async {
    await _golden(
      tester,
      'skip_text',
      Column(
        children: [
          Container(
            decoration: BoxDecoration(gradient: TroskyGradients.onboarding1),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SkipText(onPressed: () {}),
          ),
          Container(
            decoration: BoxDecoration(gradient: TroskyGradients.onboarding2),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SkipText(onPressed: () {}, color: TroskyColors.whiteA55),
          ),
        ],
      ),
    );
  });

  group('DecorativeBackdrop', () {
    Widget screen(Gradient gradient, Widget backdrop) => SizedBox(
      height: 686,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: backdrop,
      ),
    );

    testWidgets('splash', (tester) async {
      await _golden(
        tester,
        'decorative_backdrop_splash',
        screen(TroskyGradients.splash, const DecorativeBackdrop.splash()),
      );
    });

    testWidgets('onboarding 1', (tester) async {
      await _golden(
        tester,
        'decorative_backdrop_onboarding1',
        screen(
          TroskyGradients.onboarding1,
          const DecorativeBackdrop.onboarding1(),
        ),
      );
    });

    testWidgets('onboarding 2', (tester) async {
      await _golden(
        tester,
        'decorative_backdrop_onboarding2',
        screen(
          TroskyGradients.onboarding2,
          const DecorativeBackdrop.onboarding2(),
        ),
      );
    });
  });

  testWidgets('TroskyChip: every colour', (tester) async {
    await _golden(
      tester,
      'trosky_chip',
      const Padding(
        padding: EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TroskyChip(label: 'Green', color: TroskyChipColor.green),
            TroskyChip(label: 'Amber', color: TroskyChipColor.amber),
            TroskyChip(label: 'Gray', color: TroskyChipColor.gray),
            TroskyChip(label: 'Red', color: TroskyChipColor.red),
            TroskyChip(label: 'Blue', color: TroskyChipColor.blue),
          ],
        ),
      ),
      background: TroskyColors.surface,
    );
  });

  testWidgets('SectionLabel', (tester) async {
    await _golden(
      tester,
      'section_label',
      const Padding(
        padding: EdgeInsets.all(24),
        child: SectionLabel('PHONE NUMBER'),
      ),
    );
  });

  testWidgets('TroskyLogo: bright on the splash card, and the mark', (
    tester,
  ) async {
    await _golden(
      tester,
      'trosky_logo',
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Splash logo card: white, radius 32, padding 24 x 32.
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              decoration: BoxDecoration(
                color: TroskyColors.surface,
                borderRadius: BorderRadius.circular(TroskyRadii.r32),
                boxShadow: TroskyShadows.splashLogoCard,
              ),
              child: const TroskyLogo.bright(),
            ),
            const SizedBox(height: 40),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TroskyLogo.mark(height: 20),
                SizedBox(width: 16),
                TroskyLogo.mark(height: 24),
                SizedBox(width: 16),
                TroskyLogo.mark(height: 36),
              ],
            ),
          ],
        ),
      ),
      gradient: TroskyGradients.splash,
    );
  });
}
